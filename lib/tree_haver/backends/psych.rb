# frozen_string_literal: true

module TreeHaver
  module Backends
    # Psych backend using Ruby's built-in YAML parser
    #
    # This backend wraps Psych, Ruby's standard library YAML parser.
    # Psych provides AST access via Psych.parse_stream which returns
    # Psych::Nodes::* objects (Stream, Document, Mapping, Sequence, Scalar, Alias).
    #
    # @note This backend only parses YAML source code
    # @see https://ruby-doc.org/stdlib/libdoc/psych/rdoc/Psych.html Psych documentation
    #
    # @example Basic usage
    #   parser = TreeHaver::Parser.new
    #   parser.language = TreeHaver::Backends::Psych::Language.yaml
    #   tree = parser.parse(yaml_source)
    #   root = tree.root_node
    #   puts root.type  # => "stream"
    module Psych
      @load_attempted = false
      @loaded = false

      # Check if the Psych backend is available
      #
      # Psych is part of Ruby stdlib, so it should always be available.
      #
      # @return [Boolean] true if psych is available
      class << self
        def available?
          return @loaded if @load_attempted
          @load_attempted = true
          begin
            require "psych"
            @loaded = true
          rescue LoadError
            @loaded = false
          end
          @loaded
        end

        # Reset the load state (primarily for testing)
        #
        # @return [void]
        # @api private
        def reset!
          @load_attempted = false
          @loaded = false
        end

        # Get capabilities supported by this backend
        #
        # @return [Hash{Symbol => Object}] capability map
        def capabilities
          return {} unless available?
          {
            backend: :psych,
            query: false,           # Psych doesn't have tree-sitter-style queries
            bytes_field: false,     # Psych uses line/column, not byte offsets
            incremental: false,     # Psych doesn't support incremental parsing
            pure_ruby: false,       # Psych has native libyaml C extension
            yaml_only: true,        # Psych only parses YAML
            error_tolerant: false,  # Psych raises on syntax errors
          }
        end
      end

      # Psych language wrapper
      #
      # Unlike tree-sitter which supports many languages via grammar files,
      # Psych only parses YAML. This class exists for API compatibility with
      # other tree_haver backends.
      #
      # @example
      #   language = TreeHaver::Backends::Psych::Language.yaml
      #   parser.language = language
      class Language
        include Comparable

        # The language name (always :yaml for Psych)
        # @return [Symbol]
        attr_reader :name

        # The backend this language is for
        # @return [Symbol]
        attr_reader :backend

        # Create a new Psych language instance
        #
        # @param name [Symbol] Language name (should be :yaml)
        def initialize(name = :yaml)
          @name = name.to_sym
          @backend = :psych
        end

        class << self
          # Create a YAML language instance
          #
          # @return [Language] YAML language
          def yaml
            new(:yaml)
          end

          # Load language from library path (API compatibility)
          #
          # Psych only supports YAML, so path and symbol parameters are ignored.
          # This method exists for API consistency with tree-sitter backends,
          # allowing `TreeHaver.parser_for(:yaml)` to work regardless of backend.
          #
          # @param _path [String] Ignored - Psych doesn't load external grammars
          # @param symbol [String, nil] Ignored
          # @param name [String, nil] Language name hint (defaults to :yaml)
          # @return [Language] YAML language
          # @raise [TreeHaver::NotAvailable] if requested language is not YAML
          def from_library(_path = nil, symbol: nil, name: nil)
            # Derive language name from symbol if provided
            lang_name = name || symbol&.to_s&.sub(/^tree_sitter_/, "")&.to_sym || :yaml

            unless lang_name == :yaml
              raise TreeHaver::NotAvailable,
                "Psych backend only supports YAML, not #{lang_name}. " \
                  "Use a tree-sitter backend for #{lang_name} support."
            end

            yaml
          end
        end

        # Comparison for sorting/equality
        #
        # @param other [Language] other language
        # @return [Integer, nil] comparison result
        def <=>(other)
          return unless other.is_a?(Language)
          name <=> other.name
        end

        # @return [String] human-readable representation
        def inspect
          "#<TreeHaver::Backends::Psych::Language name=#{name}>"
        end
      end

      # Psych parser wrapper
      #
      # Wraps Psych.parse_stream to provide TreeHaver-compatible parsing.
      #
      # @example
      #   parser = TreeHaver::Backends::Psych::Parser.new
      #   parser.language = Language.yaml
      #   tree = parser.parse(yaml_source)
      class Parser
        # @return [Language, nil] The language to parse
        attr_accessor :language

        # Create a new Psych parser
        def initialize
          @language = nil
        end

        # Parse YAML source code
        #
        # @param source [String] YAML source to parse
        # @return [Tree] Parsed tree
        # @raise [::Psych::SyntaxError] on syntax errors
        def parse(source)
          raise "Language not set" unless @language
          Psych.available? or raise "Psych not available"

          ast = ::Psych.parse_stream(source)
          Tree.new(ast, source)
        end

        # Alias for compatibility with tree-sitter API
        #
        # @param _old_tree [nil] Ignored (Psych doesn't support incremental parsing)
        # @param source [String] YAML source to parse
        # @return [Tree] Parsed tree
        def parse_string(_old_tree, source)
          parse(source)
        end
      end

      # Psych tree wrapper
      #
      # Wraps a Psych::Nodes::Stream to provide TreeHaver-compatible tree interface.
      class Tree
        # @return [::Psych::Nodes::Stream] The underlying Psych stream
        attr_reader :inner_tree

        # @return [String] The original source
        attr_reader :source

        # Create a new tree wrapper
        #
        # @param stream [::Psych::Nodes::Stream] Psych stream node
        # @param source [String] Original source
        def initialize(stream, source)
          @inner_tree = stream
          @source = source
          @lines = source.lines
        end

        # Get the root node
        #
        # For YAML, the stream is the root. We wrap it as a Node.
        #
        # @return [Node] Root node
        def root_node
          Node.new(@inner_tree, @source, @lines)
        end

        # Get parse errors
        #
        # Psych raises exceptions on parse errors rather than recording them,
        # so this is always empty if we got a tree.
        #
        # @return [Array] Empty array (no errors if parsing succeeded)
        def errors
          []
        end

        # Get parse warnings
        #
        # @return [Array] Empty array (Psych doesn't produce warnings)
        def warnings
          []
        end

        # Get comments from the document
        #
        # Psych doesn't preserve comments in the AST by default.
        #
        # @return [Array] Empty array
        def comments
          []
        end

        # @return [String] human-readable representation
        def inspect
          "#<TreeHaver::Backends::Psych::Tree documents=#{@inner_tree.children&.size || 0}>"
        end
      end

      # Psych node wrapper
      #
      # Wraps Psych::Nodes::* classes to provide TreeHaver::Node-compatible interface.
      #
      # Psych node types:
      # - Stream: Root container
      # - Document: YAML document (multiple per stream possible)
      # - Mapping: Hash/object
      # - Sequence: Array/list
      # - Scalar: Primitive value (string, number, boolean, null)
      # - Alias: YAML anchor reference
      class Node
        include Comparable
        include Enumerable

        # @return [::Psych::Nodes::Node] The underlying Psych node
        attr_reader :inner_node

        # @return [String] The original source
        attr_reader :source

        # Create a new node wrapper
        #
        # @param node [::Psych::Nodes::Node] Psych node
        # @param source [String] Original source
        # @param lines [Array<String>] Source lines for text extraction
        def initialize(node, source, lines = nil)
          @inner_node = node
          @source = source
          @lines = lines || source.lines
        end

        # Get the node type as a string
        #
        # Maps Psych class names to lowercase type strings:
        # - Psych::Nodes::Stream → "stream"
        # - Psych::Nodes::Document → "document"
        # - Psych::Nodes::Mapping → "mapping"
        # - Psych::Nodes::Sequence → "sequence"
        # - Psych::Nodes::Scalar → "scalar"
        # - Psych::Nodes::Alias → "alias"
        #
        # @return [String] Node type
        def type
          @inner_node.class.name.split("::").last.downcase
        end

        # Alias for tree-sitter compatibility
        alias_method :kind, :type

        # Get the text content of this node
        #
        # For Scalar nodes, returns the value. For containers, returns
        # the source text spanning the node's location.
        #
        # @return [String] Node text
        def text
          case @inner_node
          when ::Psych::Nodes::Scalar
            @inner_node.value.to_s
          when ::Psych::Nodes::Alias
            "*#{@inner_node.anchor}"
          else
            # For container nodes, extract from source using location
            extract_text_from_location
          end
        end

        # Get child nodes
        #
        # @return [Array<Node>] Child nodes
        def children
          return [] unless @inner_node.respond_to?(:children) && @inner_node.children

          @inner_node.children.map { |child| Node.new(child, @source, @lines) }
        end

        # Iterate over child nodes
        #
        # @yield [Node] Each child node
        # @return [Enumerator, nil]
        def each(&block)
          return to_enum(__method__) unless block
          children.each(&block)
        end

        # Get the number of children
        #
        # @return [Integer] Child count
        def child_count
          children.size
        end

        # Get child by index
        #
        # @param index [Integer] Child index
        # @return [Node, nil] Child node
        def child(index)
          children[index]
        end

        # Get start byte offset
        #
        # Psych doesn't provide byte offsets directly, so we calculate from line/column.
        #
        # @return [Integer] Start byte offset
        def start_byte
          return 0 unless @inner_node.respond_to?(:start_line)

          line = @inner_node.start_line || 0
          col = @inner_node.start_column || 0
          calculate_byte_offset(line, col)
        end

        # Get end byte offset
        #
        # @return [Integer] End byte offset
        def end_byte
          return start_byte + text.bytesize unless @inner_node.respond_to?(:end_line)

          line = @inner_node.end_line || 0
          col = @inner_node.end_column || 0
          calculate_byte_offset(line, col)
        end

        # Get start point (row, column)
        #
        # @return [Point] Start position (0-based)
        def start_point
          row = (@inner_node.respond_to?(:start_line) ? @inner_node.start_line : 0) || 0
          col = (@inner_node.respond_to?(:start_column) ? @inner_node.start_column : 0) || 0
          Point.new(row, col)
        end

        # Get end point (row, column)
        #
        # @return [Point] End position (0-based)
        def end_point
          row = (@inner_node.respond_to?(:end_line) ? @inner_node.end_line : 0) || 0
          col = (@inner_node.respond_to?(:end_column) ? @inner_node.end_column : 0) || 0
          Point.new(row, col)
        end

        # Get the 1-based line number where this node starts
        #
        # Psych provides 0-based line numbers, so we add 1.
        #
        # @return [Integer] 1-based line number
        def start_line
          row = start_point.row
          row + 1
        end

        # Get the 1-based line number where this node ends
        #
        # @return [Integer] 1-based line number
        def end_line
          row = end_point.row
          row + 1
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
            start_column: start_point.column,
            end_column: end_point.column,
          }
        end

        # Get the first child node
        #
        # @return [Node, nil] First child or nil
        def first_child
          children.first
        end

        # Check if this is a named (structural) node
        #
        # All Psych nodes are structural.
        #
        # @return [Boolean] true
        def named?
          true
        end

        # Alias for tree-sitter compatibility
        alias_method :structural?, :named?

        # Check if the node or any descendant has an error
        #
        # Psych raises on errors rather than embedding them.
        #
        # @return [Boolean] false
        def has_error?
          false
        end

        # Check if this is a missing node
        #
        # Psych doesn't have missing nodes.
        #
        # @return [Boolean] false
        def missing?
          false
        end

        # Comparison for sorting
        #
        # @param other [Node] other node
        # @return [Integer, nil] comparison result
        def <=>(other)
          return unless other.respond_to?(:start_byte)
          cmp = start_byte <=> other.start_byte
          return cmp unless cmp&.zero?
          end_byte <=> other.end_byte
        end

        # @return [String] human-readable representation
        def inspect
          "#<TreeHaver::Backends::Psych::Node type=#{type} children=#{child_count}>"
        end

        # Get the next sibling
        #
        # @raise [NotImplementedError] Psych nodes don't have sibling references
        # @return [void]
        def next_sibling
          raise NotImplementedError, "Psych backend does not support sibling navigation"
        end

        # Get the previous sibling
        #
        # @raise [NotImplementedError] Psych nodes don't have sibling references
        # @return [void]
        def prev_sibling
          raise NotImplementedError, "Psych backend does not support sibling navigation"
        end

        # Get the parent node
        #
        # @raise [NotImplementedError] Psych nodes don't have parent references
        # @return [void]
        def parent
          raise NotImplementedError, "Psych backend does not support parent navigation"
        end

        # Psych-specific: Get the anchor name for Alias/anchored nodes
        #
        # @return [String, nil] Anchor name
        def anchor
          @inner_node.anchor if @inner_node.respond_to?(:anchor)
        end

        # Psych-specific: Get the tag for tagged nodes
        #
        # @return [String, nil] Tag
        def tag
          @inner_node.tag if @inner_node.respond_to?(:tag)
        end

        # Psych-specific: Get the scalar value
        #
        # @return [String, nil] Value for scalar nodes
        def value
          @inner_node.value if @inner_node.respond_to?(:value)
        end

        # Psych-specific: Check if this is a mapping (hash)
        #
        # @return [Boolean]
        def mapping?
          @inner_node.is_a?(::Psych::Nodes::Mapping)
        end

        # Psych-specific: Check if this is a sequence (array)
        #
        # @return [Boolean]
        def sequence?
          @inner_node.is_a?(::Psych::Nodes::Sequence)
        end

        # Psych-specific: Check if this is a scalar (primitive)
        #
        # @return [Boolean]
        def scalar?
          @inner_node.is_a?(::Psych::Nodes::Scalar)
        end

        # Psych-specific: Check if this is an alias
        #
        # @return [Boolean]
        def alias?
          @inner_node.is_a?(::Psych::Nodes::Alias)
        end

        # Psych-specific: Get mapping entries as key-value pairs
        #
        # For Mapping nodes, children alternate key, value, key, value...
        #
        # @return [Array<Array(Node, Node)>] Key-value pairs
        def mapping_entries
          return [] unless mapping?

          pairs = []
          children.each_slice(2) do |key, val|
            pairs << [key, val] if key && val
          end
          pairs
        end

        private

        # Calculate byte offset from line and column
        #
        # @param line [Integer] 0-based line number
        # @param column [Integer] 0-based column
        # @return [Integer] Byte offset
        def calculate_byte_offset(line, column)
          offset = 0
          @lines.each_with_index do |line_content, idx|
            if idx < line
              offset += line_content.bytesize
              offset += 1 unless line_content.end_with?("\n") # Add newline
            else
              offset += [column, line_content.bytesize].min
              break
            end
          end
          offset
        end

        # Extract text from source using location
        #
        # @return [String] Extracted text
        def extract_text_from_location
          return "" unless @inner_node.respond_to?(:start_line) && @inner_node.respond_to?(:end_line)

          start_line = @inner_node.start_line || 0
          end_line = @inner_node.end_line || start_line
          start_col = @inner_node.start_column || 0
          end_col = @inner_node.end_column || 0

          if start_line == end_line
            line = @lines[start_line] || ""
            line[start_col...end_col] || ""
          else
            result = []
            (start_line..end_line).each do |ln|
              line = @lines[ln] || ""
              result << if ln == start_line
                line[start_col..]
              elsif ln == end_line
                line[0...end_col]
              else
                line
              end
            end
            result.compact.join
          end
        end
      end

      # Point struct for position information
      #
      # Provides both method and hash-style access for compatibility.
      Point = Struct.new(:row, :column) do
        # Hash-like access
        #
        # @param key [Symbol, String] :row or :column
        # @return [Integer, nil]
        def [](key)
          case key
          when :row, "row" then row
          when :column, "column" then column
          end
        end

        # @return [Hash]
        def to_h
          {row: row, column: column}
        end

        # @return [String]
        def to_s
          "(#{row}, #{column})"
        end

        # @return [String]
        def inspect
          "#<TreeHaver::Backends::Psych::Point row=#{row} column=#{column}>"
        end
      end
    end
  end
end
