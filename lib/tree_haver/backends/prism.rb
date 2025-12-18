# frozen_string_literal: true

module TreeHaver
  module Backends
    # Prism backend using Ruby's built-in Prism parser
    #
    # This backend wraps Prism, Ruby's official parser (stdlib in Ruby 3.4+,
    # available as a gem for 3.2+). Unlike tree-sitter backends which are
    # language-agnostic runtime parsers, Prism is specifically designed for
    # parsing Ruby source code.
    #
    # Prism provides excellent error recovery, detailed location information,
    # and is the future of Ruby parsing (used by CRuby, JRuby, TruffleRuby).
    #
    # @note This backend only parses Ruby source code
    # @see https://github.com/ruby/prism Prism parser
    #
    # @example Basic usage
    #   parser = TreeHaver::Parser.new
    #   parser.language = TreeHaver::Backends::Prism::Language.ruby
    #   tree = parser.parse(ruby_source)
    #   root = tree.root_node
    #   puts root.type  # => "program_node"
    module Prism
      @load_attempted = false
      @loaded = false

      # Check if the Prism backend is available
      #
      # Attempts to require prism on first call and caches the result.
      # On Ruby 3.4+, Prism is in stdlib. On 3.2-3.3, it's a gem.
      #
      # @return [Boolean] true if prism is available
      # @example
      #   if TreeHaver::Backends::Prism.available?
      #     puts "Prism backend is ready"
      #   end
      class << self
        def available?
          return @loaded if @load_attempted # rubocop:disable ThreadSafety/ClassInstanceVariable
          @load_attempted = true # rubocop:disable ThreadSafety/ClassInstanceVariable
          begin
            require "prism"

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
        #   TreeHaver::Backends::Prism.capabilities
        #   # => { backend: :prism, query: false, bytes_field: true, incremental: false, ruby_only: true }
        def capabilities
          return {} unless available?
          {
            backend: :prism,
            query: false,           # Prism doesn't have tree-sitter-style queries (has pattern matching)
            bytes_field: true,      # Prism provides byte offsets via Location
            incremental: false,     # Prism doesn't support incremental parsing (yet)
            pure_ruby: false,       # Prism has native C extension (but also pure Ruby mode)
            ruby_only: true,        # Prism only parses Ruby source code
            error_tolerant: true,   # Prism has excellent error recovery
          }
        end
      end

      # Prism language wrapper
      #
      # Unlike tree-sitter which supports many languages via grammar files,
      # Prism only parses Ruby. This class exists for API compatibility with
      # other tree_haver backends.
      #
      # @example
      #   language = TreeHaver::Backends::Prism::Language.ruby
      #   parser.language = language
      class Language
        include Comparable

        # The language name (always :ruby for Prism)
        # @return [Symbol]
        attr_reader :name

        # The backend this language is for
        # @return [Symbol]
        attr_reader :backend

        # Prism parsing options
        # @return [Hash]
        attr_reader :options

        # @param name [Symbol] language name (should be :ruby)
        # @param options [Hash] Prism parsing options (e.g., frozen_string_literal, version)
        def initialize(name = :ruby, options: {})
          @name = name.to_sym
          @backend = :prism
          @options = options

          unless @name == :ruby
            raise TreeHaver::NotAvailable,
              "Prism only supports Ruby parsing. " \
                "Got language: #{name.inspect}"
          end
        end

        # Compare languages for equality
        #
        # Prism languages are equal if they have the same backend and options.
        #
        # @param other [Object] object to compare with
        # @return [Integer, nil] -1, 0, 1, or nil if not comparable
        def <=>(other)
          return unless other.is_a?(Language)
          return unless other.backend == @backend

          @options.to_a.sort <=> other.options.to_a.sort
        end

        # Hash value for this language (for use in Sets/Hashes)
        # @return [Integer]
        def hash
          [@backend, @name, @options.to_a.sort].hash
        end

        # Alias eql? to ==
        alias_method :eql?, :==

        class << self
          # Create a Ruby language instance (convenience method)
          #
          # @param options [Hash] Prism parsing options
          # @option options [Boolean] :frozen_string_literal frozen string literal pragma
          # @option options [String] :version Ruby version to parse as (e.g., "3.3.0")
          # @option options [Symbol] :command_line command line option (-e, -n, etc.)
          # @return [Language]
          # @example
          #   lang = TreeHaver::Backends::Prism::Language.ruby
          #   lang = TreeHaver::Backends::Prism::Language.ruby(frozen_string_literal: true)
          def ruby(options = {})
            new(:ruby, options: options)
          end

          # Not applicable for Prism (tree-sitter-specific)
          #
          # Prism is Ruby-only and doesn't load external grammar libraries.
          # This method exists for API compatibility but will raise an error.
          #
          # @raise [TreeHaver::NotAvailable] always raises
          def from_library(path, symbol: nil, name: nil)
            raise TreeHaver::NotAvailable,
              "Prism backend doesn't use shared libraries. " \
                "Use Prism::Language.ruby instead."
          end

          alias_method :from_path, :from_library
        end
      end

      # Prism parser wrapper
      #
      # Wraps Prism to provide a tree-sitter-like API for parsing Ruby code.
      class Parser
        # Create a new Prism parser instance
        #
        # @raise [TreeHaver::NotAvailable] if prism is not available
        def initialize
          raise TreeHaver::NotAvailable, "prism not available" unless Prism.available?
          @language = nil
          @options = {}
        end

        # Set the language for this parser
        #
        # Note: TreeHaver::Parser unwraps language objects before calling this method.
        # This backend receives the Language wrapper (since Prism::Language stores options).
        #
        # @param lang [Language, Symbol] Prism language (should be :ruby or Language instance)
        # @return [void]
        def language=(lang)
          case lang
          when Language
            @language = lang
            @options = lang.options
          when Symbol, String
            if lang.to_sym == :ruby
              @language = Language.ruby
              @options = {}
            else
              raise ArgumentError,
                "Prism only supports Ruby parsing. Got: #{lang.inspect}"
            end
          else
            raise ArgumentError,
              "Expected Prism::Language or :ruby, got #{lang.class}"
          end
        end

        # Parse source code
        #
        # @param source [String] the Ruby source code to parse
        # @return [Tree] raw backend tree (wrapping happens in TreeHaver::Parser)
        # @raise [TreeHaver::NotAvailable] if no language is set
        def parse(source)
          raise TreeHaver::NotAvailable, "No language loaded (use parser.language = :ruby)" unless @language

          # Use Prism.parse with options
          prism_result = ::Prism.parse(source, **@options)
          Tree.new(prism_result, source)
        end

        # Parse source code (compatibility with tree-sitter API)
        #
        # Prism doesn't support incremental parsing, so old_tree is ignored.
        #
        # @param old_tree [TreeHaver::Tree, nil] ignored (no incremental parsing support)
        # @param source [String] the Ruby source code to parse
        # @return [Tree] raw backend tree (wrapping happens in TreeHaver::Parser)
        def parse_string(old_tree, source) # rubocop:disable Lint/UnusedMethodArgument
          parse(source)  # Prism doesn't support incremental parsing
        end
      end

      # Prism tree wrapper
      #
      # Wraps a Prism::ParseResult to provide tree-sitter-compatible API.
      #
      # @api private
      class Tree
        # @return [::Prism::ParseResult] the underlying Prism parse result
        attr_reader :parse_result

        # @return [String] the source code
        attr_reader :source

        def initialize(parse_result, source)
          @parse_result = parse_result
          @source = source
        end

        # Get the root node of the parse tree
        #
        # @return [Node] wrapped root node
        def root_node
          Node.new(@parse_result.value, @source)
        end

        # Check if the parse had errors
        #
        # @return [Boolean]
        def has_errors?
          @parse_result.failure?
        end

        # Get parse errors
        #
        # @return [Array<::Prism::ParseError>]
        def errors
          @parse_result.errors
        end

        # Get parse warnings
        #
        # @return [Array<::Prism::ParseWarning>]
        def warnings
          @parse_result.warnings
        end

        # Get comments from the parse
        #
        # @return [Array<::Prism::Comment>]
        def comments
          @parse_result.comments
        end

        # Get magic comments (e.g., frozen_string_literal)
        #
        # @return [Array<::Prism::MagicComment>]
        def magic_comments
          @parse_result.magic_comments
        end

        # Get data locations (__END__ section)
        #
        # @return [::Prism::Location, nil]
        def data_loc
          @parse_result.data_loc
        end

        # Access the underlying Prism result (passthrough)
        #
        # @return [::Prism::ParseResult]
        def inner_tree
          @parse_result
        end
      end

      # Prism node wrapper
      #
      # Wraps Prism::Node objects to provide tree-sitter-compatible node API.
      #
      # Prism nodes provide:
      # - type: class name without "Node" suffix (e.g., ProgramNode → "program")
      # - location: ::Prism::Location with start/end offsets and line/column
      # - child_nodes: array of child nodes
      # - Various node-specific accessors
      #
      # @api private
      class Node
        # @return [::Prism::Node] the underlying Prism node
        attr_reader :inner_node

        # @return [String] the source code
        attr_reader :source

        def initialize(node, source)
          @inner_node = node
          @source = source
        end

        # Get node type from Prism class name
        #
        # Converts PrismClassName to tree-sitter-style type string.
        # Example: CallNode → "call_node", ProgramNode → "program_node"
        #
        # @return [String] node type in snake_case
        def type
          return "nil" if @inner_node.nil?

          # Convert class name to snake_case type
          # ProgramNode → program_node, CallNode → call_node
          class_name = @inner_node.class.name.split("::").last
          class_name.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, "")
        end

        # Alias for tree-sitter compatibility
        alias_method :kind, :type

        # Get byte offset where the node starts
        #
        # @return [Integer]
        def start_byte
          return 0 if @inner_node.nil? || !@inner_node.respond_to?(:location)
          loc = @inner_node.location
          loc&.start_offset || 0
        end

        # Get byte offset where the node ends
        #
        # @return [Integer]
        def end_byte
          return 0 if @inner_node.nil? || !@inner_node.respond_to?(:location)
          loc = @inner_node.location
          loc&.end_offset || 0
        end

        # Get the start position as row/column
        #
        # @return [Hash{Symbol => Integer}] with :row and :column keys
        def start_point
          return {row: 0, column: 0} if @inner_node.nil? || !@inner_node.respond_to?(:location)
          loc = @inner_node.location
          return {row: 0, column: 0} unless loc

          # Prism uses 1-based lines internally but we need 0-based for tree-sitter compat
          {row: (loc.start_line - 1), column: loc.start_column}
        end

        # Get the end position as row/column
        #
        # @return [Hash{Symbol => Integer}] with :row and :column keys
        def end_point
          return {row: 0, column: 0} if @inner_node.nil? || !@inner_node.respond_to?(:location)
          loc = @inner_node.location
          return {row: 0, column: 0} unless loc

          # Prism uses 1-based lines internally but we need 0-based for tree-sitter compat
          {row: (loc.end_line - 1), column: loc.end_column}
        end

        # Get the 1-based line number where this node starts
        #
        # @return [Integer] 1-based line number
        def start_line
          return 1 if @inner_node.nil? || !@inner_node.respond_to?(:location)
          loc = @inner_node.location
          loc&.start_line || 1
        end

        # Get the 1-based line number where this node ends
        #
        # @return [Integer] 1-based line number
        def end_line
          return 1 if @inner_node.nil? || !@inner_node.respond_to?(:location)
          loc = @inner_node.location
          loc&.end_line || 1
        end

        # Get position information as a hash
        #
        # Returns a hash with 1-based line numbers and 0-based columns.
        # Compatible with *-merge gems' FileAnalysisBase.
        #
        # @return [Hash{Symbol => Integer}] Position hash
        def source_position
          {
            start_line: start_line,
            end_line: end_line,
            start_column: start_point[:column],
            end_column: end_point[:column],
          }
        end

        # Get the first child node
        #
        # @return [Node, nil] First child or nil
        def first_child
          child(0)
        end

        # Get the text content of this node
        #
        # @return [String]
        def text
          return "" if @inner_node.nil?

          if @inner_node.respond_to?(:slice)
            @inner_node.slice
          elsif @source
            @source[start_byte...end_byte] || ""
          else
            ""
          end
        end

        # Alias for Prism compatibility
        alias_method :slice, :text

        # Get the number of child nodes
        #
        # @return [Integer]
        def child_count
          return 0 if @inner_node.nil?
          return 0 unless @inner_node.respond_to?(:child_nodes)
          @inner_node.child_nodes.compact.size
        end

        # Get a child node by index
        #
        # @param index [Integer] child index
        # @return [Node, nil] wrapped child node
        def child(index)
          return if @inner_node.nil?
          return unless @inner_node.respond_to?(:child_nodes)

          children_array = @inner_node.child_nodes.compact
          return if index >= children_array.size

          Node.new(children_array[index], @source)
        end

        # Get all child nodes
        #
        # @return [Array<Node>] array of wrapped child nodes
        def children
          return [] if @inner_node.nil?
          return [] unless @inner_node.respond_to?(:child_nodes)

          @inner_node.child_nodes.compact.map { |n| Node.new(n, @source) }
        end

        # Iterate over child nodes
        #
        # @yield [Node] each child node
        # @return [Enumerator, nil]
        def each(&block)
          return to_enum(__method__) unless block_given?
          children.each(&block)
        end

        # Check if this node has errors
        #
        # @return [Boolean]
        def has_error?
          return false if @inner_node.nil?

          # Check if this is an error node type
          return true if type.include?("missing") || type.include?("error")

          # Check children recursively (Prism error nodes are usually children)
          return false unless @inner_node.respond_to?(:child_nodes)
          @inner_node.child_nodes.compact.any? { |n| n.class.name.to_s.include?("Missing") }
        end

        # Check if this node is a "missing" node (error recovery)
        #
        # @return [Boolean]
        def missing?
          return false if @inner_node.nil?
          type.include?("missing")
        end

        # Check if this is a "named" node (structural vs punctuation)
        #
        # In Prism, all nodes are "named" in tree-sitter terminology
        # (there's no distinction between named and anonymous nodes).
        #
        # @return [Boolean]
        def named?
          true
        end

        # Check if this is a structural node
        #
        # @return [Boolean]
        def structural?
          true
        end

        # Get a child by field name (Prism node accessor)
        #
        # Prism nodes have specific accessors for their children.
        # This method tries to call that accessor.
        #
        # @param name [String, Symbol] field/accessor name
        # @return [Node, nil] wrapped child node
        def child_by_field_name(name)
          return if @inner_node.nil?
          return unless @inner_node.respond_to?(name)

          result = @inner_node.public_send(name)
          return if result.nil?

          # Wrap if it's a node, otherwise return nil
          if result.is_a?(::Prism::Node)
            Node.new(result, @source)
          end
        end

        alias_method :field, :child_by_field_name

        # Get the parent node
        #
        # @note Prism nodes don't have built-in parent references.
        #       This always returns nil. Use tree traversal instead.
        # @return [nil]
        def parent
          nil  # Prism doesn't track parent references
        end

        # Get next sibling
        #
        # @note Prism nodes don't have sibling references.
        # @return [nil]
        def next_sibling
          nil
        end

        # Get previous sibling
        #
        # @note Prism nodes don't have sibling references.
        # @return [nil]
        def prev_sibling
          nil
        end

        # String representation for debugging
        #
        # @return [String]
        def inspect
          "#<#{self.class} type=#{type} bytes=#{start_byte}..#{end_byte}>"
        end

        # String representation
        #
        # @return [String]
        def to_s
          text
        end

        # Check if node responds to a method (includes delegation to inner_node)
        #
        # @param method_name [Symbol] method to check
        # @param include_private [Boolean] include private methods
        # @return [Boolean]
        def respond_to_missing?(method_name, include_private = false)
          return false if @inner_node.nil?
          @inner_node.respond_to?(method_name, include_private) || super
        end

        # Delegate unknown methods to the underlying Prism node
        #
        # This provides passthrough access for Prism-specific node methods
        # like `receiver`, `message`, `arguments`, etc.
        #
        # @param method_name [Symbol] method to call
        # @param args [Array] arguments to pass
        # @param kwargs [Hash] keyword arguments
        # @param block [Proc] block to pass
        # @return [Object] result from the underlying node
        def method_missing(method_name, *args, **kwargs, &block)
          if @inner_node&.respond_to?(method_name)
            @inner_node.public_send(method_name, *args, **kwargs, &block)
          else
            super
          end
        end
      end
    end
  end
end

