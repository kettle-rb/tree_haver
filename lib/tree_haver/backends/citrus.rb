# frozen_string_literal: true

module TreeHaver
  module Backends
    # Citrus backend using pure Ruby PEG parser
    #
    # This backend wraps Citrus-based parsers (like toml-rb) to provide a
    # pure Ruby alternative to tree-sitter. Citrus is a PEG (Parsing Expression
    # Grammar) parser generator written in Ruby.
    #
    # Unlike tree-sitter backends which are language-agnostic runtime parsers,
    # Citrus parsers are grammar-specific and compiled into Ruby code. Each
    # language needs its own Citrus grammar (e.g., toml-rb for TOML).
    #
    # @note This backend requires a Citrus grammar for the specific language
    # @see https://github.com/mjackson/citrus Citrus parser generator
    # @see https://github.com/emancu/toml-rb toml-rb (TOML Citrus grammar)
    #
    # @example Using with toml-rb
    #   require "toml-rb"
    #
    #   parser = TreeHaver::Parser.new
    #   # For Citrus, "language" is actually a grammar module
    #   parser.language = TomlRB::Document
    #   tree = parser.parse(toml_source)
    module Citrus
      @load_attempted = false
      @loaded = false

      # Check if the Citrus backend is available
      #
      # Attempts to require citrus on first call and caches the result.
      #
      # @return [Boolean] true if citrus gem is available
      # @example
      #   if TreeHaver::Backends::Citrus.available?
      #     puts "Citrus backend is ready"
      #   end
      class << self
        def available?
          return @loaded if @load_attempted # rubocop:disable ThreadSafety/ClassInstanceVariable
          @load_attempted = true # rubocop:disable ThreadSafety/ClassInstanceVariable
          begin
            require "citrus"

            @loaded = true # rubocop:disable ThreadSafety/ClassInstanceVariable
          rescue LoadError
            @loaded = false # rubocop:disable ThreadSafety/ClassInstanceVariable
          end
          @loaded # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        # Reset the load state (primarily for testing)
        #
        # @return [void]
        # @api private
        def reset!
          @load_attempted = false # rubocop:disable ThreadSafety/ClassInstanceVariable
          @loaded = false # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        # Get capabilities supported by this backend
        #
        # @return [Hash{Symbol => Object}] capability map
        # @example
        #   TreeHaver::Backends::Citrus.capabilities
        #   # => { backend: :citrus, query: false, bytes_field: true, incremental: false }
        def capabilities
          return {} unless available?
          {
            backend: :citrus,
            query: false,          # Citrus doesn't have a query API like tree-sitter
            bytes_field: true,     # Citrus::Match provides offset and length
            incremental: false,    # Citrus doesn't support incremental parsing
            pure_ruby: true,       # Citrus is pure Ruby (portable)
          }
        end
      end

      # Citrus grammar wrapper
      #
      # Unlike tree-sitter which loads compiled .so files, Citrus uses Ruby modules
      # that define grammars. This class wraps a Citrus grammar module.
      #
      # @example
      #   # For TOML, use toml-rb's grammar
      #   language = TreeHaver::Backends::Citrus::Language.new(TomlRB::Document)
      class Language
        # The Citrus grammar module
        # @return [Module] Citrus grammar module (e.g., TomlRB::Document)
        attr_reader :grammar_module

        # @param grammar_module [Module] A Citrus grammar module with a parse method
        def initialize(grammar_module)
          unless grammar_module.respond_to?(:parse)
            raise TreeHaver::NotAvailable,
              "Grammar module must respond to :parse. " \
                "Expected a Citrus grammar module (e.g., TomlRB::Document)."
          end
          @grammar_module = grammar_module
        end

        # Not applicable for Citrus (tree-sitter-specific)
        #
        # Citrus grammars are Ruby modules, not shared libraries.
        # This method exists for API compatibility but will raise an error.
        #
        # @raise [TreeHaver::NotAvailable] always raises
        class << self
          def from_library(path, symbol: nil, name: nil)
            raise TreeHaver::NotAvailable,
              "Citrus backend doesn't use shared libraries. " \
                "Use Citrus::Language.new(GrammarModule) instead."
          end

          alias_method :from_path, :from_library
        end
      end

      # Citrus parser wrapper
      #
      # Wraps Citrus grammar modules to provide a tree-sitter-like API.
      class Parser
        # Create a new Citrus parser instance
        #
        # @raise [TreeHaver::NotAvailable] if citrus gem is not available
        def initialize
          raise TreeHaver::NotAvailable, "citrus gem not available" unless Citrus.available?
          @grammar = nil
        end

        # Set the grammar for this parser
        #
        # @param grammar [Language, Module] Citrus grammar module or Language wrapper
        # @return [Language, Module] the grammar that was set
        # @example
        #   require "toml-rb"
        #   parser.language = TomlRB::Document  # Pass module directly
        #   # or
        #   parser.language = TreeHaver::Backends::Citrus::Language.new(TomlRB::Document)
        def language=(grammar)
          @grammar = if grammar.respond_to?(:grammar_module)
            grammar.grammar_module
          elsif grammar.respond_to?(:parse)
            grammar
          else
            raise ArgumentError,
              "Expected Citrus grammar module or Language wrapper, " \
                "got #{grammar.class}"
          end
          grammar
        end

        # Parse source code
        #
        # @param source [String] the source code to parse
        # @return [Tree] raw backend tree (wrapping happens in TreeHaver::Parser)
        # @raise [TreeHaver::NotAvailable] if no grammar is set
        # @raise [::Citrus::ParseError] if parsing fails
        def parse(source)
          raise TreeHaver::NotAvailable, "No grammar loaded" unless @grammar

          begin
            citrus_match = @grammar.parse(source)
            # Return raw Citrus::Tree - TreeHaver::Parser will wrap it
            Tree.new(citrus_match, source)
          rescue ::Citrus::ParseError => e
            # Re-raise with more context
            raise TreeHaver::Error, "Parse error: #{e.message}"
          end
        end

        # Parse source code (compatibility with tree-sitter API)
        #
        # Citrus doesn't support incremental parsing, so old_tree is ignored.
        #
        # @param old_tree [TreeHaver::Tree, nil] ignored (no incremental parsing support)
        # @param source [String] the source code to parse
        # @return [TreeHaver::Tree] wrapped tree
        def parse_string(old_tree, source)
          parse(source)  # Citrus doesn't support incremental parsing
        end
      end

      # Citrus tree wrapper
      #
      # Wraps a Citrus::Match (which represents the parse tree) to provide
      # tree-sitter-compatible API.
      #
      # @api private
      class Tree
        attr_reader :root_match, :source

        def initialize(root_match, source)
          @root_match = root_match
          @source = source
        end

        def root_node
          Node.new(@root_match, @source)
        end
      end

      # Citrus node wrapper
      #
      # Wraps Citrus::Match objects to provide tree-sitter-compatible node API.
      #
      # Citrus::Match provides:
      # - events[0]: rule name (Symbol) - used as type
      # - offset: byte position
      # - length: byte length
      # - string: matched text
      # - matches: child matches
      # - captures: named groups
      #
      # Language-specific helpers can be mixed in for convenience:
      #   require "tree_haver/backends/citrus/toml_helpers"
      #   TreeHaver::Backends::Citrus::Node.include(TreeHaver::Backends::Citrus::TomlHelpers)
      #
      # @api private
      class Node
        attr_reader :match, :source

        def initialize(match, source)
          @match = match
          @source = source
        end

        # Get node type from Citrus rule name
        #
        # Uses Citrus grammar introspection to dynamically determine node types.
        # Works with any Citrus grammar without language-specific knowledge.
        #
        # Strategy:
        # 1. Check if first event has a .name method (returns Symbol) - use that
        # 2. If first event is a Symbol directly - use that
        # 3. For compound rules (Repeat, Choice), recurse into first match
        #
        # @return [String] rule name from grammar
        def type
          return "unknown" unless @match.respond_to?(:events)
          return "unknown" unless @match.events.is_a?(Array)
          return "unknown" if @match.events.empty?

          extract_type_from_event(@match.events.first)
        end

        # Check if this node represents a structural element vs a terminal/token
        #
        # Uses Citrus grammar's terminal? method to determine if this is
        # a structural rule (like "table", "keyvalue") vs a terminal token
        # (like "[", "=", whitespace).
        #
        # @return [Boolean] true if this is a structural (non-terminal) node
        def structural?
          return false unless @match.respond_to?(:events)
          return false if @match.events.empty?

          first_event = @match.events.first

          # Check if event has terminal? method (Citrus rule object)
          if first_event.respond_to?(:terminal?)
            return !first_event.terminal?
          end

          # For Symbol events, try to look up in grammar
          if first_event.is_a?(Symbol) && @match.respond_to?(:grammar)
            grammar = @match.grammar
            if grammar.respond_to?(:rules) && grammar.rules.key?(first_event)
              rule = grammar.rules[first_event]
              return !rule.terminal? if rule.respond_to?(:terminal?)
            end
          end

          # Default: assume structural if not a simple string/regex terminal
          true
        end

        private

        # Extract type name from a Citrus event object
        #
        # Handles different event types:
        # - Objects with .name method (Citrus rule objects) -> use .name
        # - Symbol -> use directly
        # - Compound rules (Repeat, Choice) -> check string representation
        #
        # @param event [Object] Citrus event object
        # @return [String] type name
        def extract_type_from_event(event)
          # Case 1: Event has .name method (returns Symbol)
          if event.respond_to?(:name)
            name = event.name
            return name.to_s if name.is_a?(Symbol)
          end

          # Case 2: Event is a Symbol directly (most common for child nodes)
          return event.to_s if event.is_a?(Symbol)

          # Case 3: Event is a String
          return event if event.is_a?(String)

          # Case 4: For compound rules (Repeat, Choice), try string parsing first
          # This avoids recursion issues
          str = event.to_s

          # Try to extract rule name from string representation
          # Examples: "table", "(comment | table)*", "space?", etc.
          if str =~ /^([a-z_][a-z0-9_]*)/i
            return $1
          end

          # If we have a pattern like "(rule1 | rule2)*", we can't determine
          # the type without looking at actual matches, but that causes recursion
          # So just return a generic type based on the pattern
          if str =~ /^\(.*\)\*$/
            return "repeat"
          elsif str =~ /^\(.*\)\?$/
            return "optional"
          elsif str =~ /^.*\|.*$/
            return "choice"
          end

          "unknown"
        end

        public

        def start_byte
          @match.offset
        end

        def end_byte
          @match.offset + @match.length
        end

        def start_point
          calculate_point(@match.offset)
        end

        def end_point
          calculate_point(@match.offset + @match.length)
        end

        def text
          @match.string
        end

        def child_count
          @match.respond_to?(:matches) ? @match.matches.size : 0
        end

        def child(index)
          return unless @match.respond_to?(:matches)
          return if index >= @match.matches.size

          Node.new(@match.matches[index], @source)
        end

        def children
          return [] unless @match.respond_to?(:matches)
          @match.matches.map { |m| Node.new(m, @source) }
        end

        def each(&block)
          return to_enum(__method__) unless block_given?
          children.each(&block)
        end

        def has_error?
          false  # Citrus raises on parse error, so successful parse has no errors
        end

        def missing?
          false  # Citrus doesn't have the concept of missing nodes
        end

        def named?
          true  # Citrus matches are typically "named" in tree-sitter terminology
        end

        private

        def calculate_point(offset)
          lines_before = @source[0...offset].count("\n")
          line_start = @source.rindex("\n", offset - 1) || -1
          column = offset - line_start - 1
          {row: lines_before, column: column}
        end
      end
    end
  end
end
