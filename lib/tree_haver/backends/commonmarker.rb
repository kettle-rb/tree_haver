# frozen_string_literal: true

module TreeHaver
  module Backends
    # Commonmarker backend using the Commonmarker gem (comrak Rust parser)
    #
    # This backend wraps Commonmarker, a Ruby gem that provides bindings to
    # comrak, a fast CommonMark-compliant Markdown parser written in Rust.
    #
    # @note This backend only parses Markdown source code
    # @see https://github.com/gjtorikian/commonmarker Commonmarker gem
    #
    # @example Basic usage
    #   parser = TreeHaver::Parser.new
    #   parser.language = TreeHaver::Backends::Commonmarker::Language.markdown
    #   tree = parser.parse(markdown_source)
    #   root = tree.root_node
    #   puts root.type  # => "document"
    module Commonmarker
      @load_attempted = false
      @loaded = false

      # Check if the Commonmarker backend is available
      #
      # @return [Boolean] true if commonmarker gem is available
      class << self
        def available?
          return @loaded if @load_attempted
          @load_attempted = true
          begin
            require "commonmarker"
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
            backend: :commonmarker,
            query: false,
            bytes_field: false,       # Commonmarker uses line/column
            incremental: false,
            pure_ruby: false,         # Uses Rust via FFI
            markdown_only: true,
            error_tolerant: true,     # Markdown is forgiving
          }
        end
      end

      # Commonmarker language wrapper
      #
      # Commonmarker only parses Markdown. This class exists for API compatibility.
      #
      # @example
      #   language = TreeHaver::Backends::Commonmarker::Language.markdown
      #   parser.language = language
      class Language
        include Comparable

        # The language name (always :markdown for Commonmarker)
        # @return [Symbol]
        attr_reader :name

        # The backend this language is for
        # @return [Symbol]
        attr_reader :backend

        # Commonmarker parse options
        # @return [Hash]
        attr_reader :options

        # Create a new Commonmarker language instance
        #
        # @param name [Symbol] Language name (should be :markdown)
        # @param options [Hash] Commonmarker parse options
        def initialize(name = :markdown, options: {})
          @name = name.to_sym
          @backend = :commonmarker
          @options = options
        end

        class << self
          # Create a Markdown language instance
          #
          # @param options [Hash] Commonmarker parse options
          # @return [Language] Markdown language
          def markdown(options: {})
            new(:markdown, options: options)
          end

          # Load language from library path (API compatibility)
          #
          # Commonmarker only supports Markdown, so path and symbol parameters are ignored.
          # This method exists for API consistency with tree-sitter backends,
          # allowing `TreeHaver.parser_for(:markdown)` to work regardless of backend.
          #
          # @param _path [String] Ignored - Commonmarker doesn't load external grammars
          # @param symbol [String, nil] Ignored
          # @param name [String, nil] Language name hint (defaults to :markdown)
          # @return [Language] Markdown language
          # @raise [TreeHaver::NotAvailable] if requested language is not Markdown
          def from_library(_path = nil, symbol: nil, name: nil)
            # Derive language name from symbol if provided
            lang_name = name || (symbol && symbol.to_s.sub(/^tree_sitter_/, ""))&.to_sym || :markdown

            unless lang_name == :markdown
              raise TreeHaver::NotAvailable,
                "Commonmarker backend only supports Markdown, not #{lang_name}. " \
                "Use a tree-sitter backend for #{lang_name} support."
            end

            markdown
          end
        end

        # Comparison for sorting/equality
        def <=>(other)
          return unless other.is_a?(Language)
          name <=> other.name
        end

        def inspect
          "#<TreeHaver::Backends::Commonmarker::Language name=#{name} options=#{options}>"
        end
      end

      # Commonmarker parser wrapper
      class Parser
        attr_accessor :language

        def initialize
          @language = nil
        end

        # Parse Markdown source code
        #
        # @param source [String] Markdown source to parse
        # @return [Tree] Parsed tree
        def parse(source)
          raise "Language not set" unless @language
          Commonmarker.available? or raise "Commonmarker not available"

          options = @language.options || {}
          doc = ::Commonmarker.parse(source, options: options)
          Tree.new(doc, source)
        end

        # Alias for compatibility
        def parse_string(_old_tree, source)
          parse(source)
        end
      end

      # Commonmarker tree wrapper
      class Tree
        attr_reader :inner_tree, :source

        def initialize(document, source)
          @inner_tree = document
          @source = source
          @lines = source.lines
        end

        def root_node
          Node.new(@inner_tree, @source, @lines)
        end

        def errors
          []
        end

        def warnings
          []
        end

        def comments
          []
        end

        def inspect
          "#<TreeHaver::Backends::Commonmarker::Tree>"
        end
      end

      # Commonmarker node wrapper
      #
      # Wraps Commonmarker::Node to provide TreeHaver::Node-compatible interface.
      class Node
        include Comparable
        include Enumerable

        attr_reader :inner_node, :source

        def initialize(node, source, lines = nil)
          @inner_node = node
          @source = source
          @lines = lines || source.lines
        end

        # Get the node type as a string
        #
        # Commonmarker uses symbols like :document, :heading, :paragraph, etc.
        #
        # @return [String] Node type
        def type
          @inner_node.type.to_s
        end

        alias_method :kind, :type

        # Get the text content of this node
        #
        # @return [String] Node text
        def text
          # Commonmarker nodes have string_content for text nodes
          # Container nodes don't have string_content and will raise TypeError
          if @inner_node.respond_to?(:string_content)
            begin
              @inner_node.string_content.to_s
            rescue TypeError
              # Container node - concatenate children's text
              children.map(&:text).join
            end
          else
            # For container nodes, concatenate children's text
            children.map(&:text).join
          end
        end

        # Get child nodes
        #
        # @return [Array<Node>] Child nodes
        def children
          return [] unless @inner_node.respond_to?(:each)

          result = []
          @inner_node.each { |child| result << Node.new(child, @source, @lines) }
          result
        end

        def each(&block)
          return to_enum(__method__) unless block
          children.each(&block)
        end

        def child_count
          children.size
        end

        def child(index)
          children[index]
        end

        # Position information
        # Commonmarker 2.x provides source_position as a hash with start_line, start_column, end_line, end_column

        def start_byte
          sp = start_point
          calculate_byte_offset(sp.row, sp.column)
        end

        def end_byte
          ep = end_point
          calculate_byte_offset(ep.row, ep.column)
        end

        def start_point
          if @inner_node.respond_to?(:source_position)
            pos = begin
              @inner_node.source_position
            rescue
              nil
            end
            if pos && pos[:start_line]
              return Point.new(pos[:start_line] - 1, (pos[:start_column] || 1) - 1)
            end
          end
          pos = begin
            @inner_node.sourcepos
          rescue
            nil
          end
          return Point.new(0, 0) unless pos
          Point.new(pos[0] - 1, pos[1] - 1)
        end

        def end_point
          if @inner_node.respond_to?(:source_position)
            pos = begin
              @inner_node.source_position
            rescue
              nil
            end
            if pos && pos[:end_line]
              return Point.new(pos[:end_line] - 1, (pos[:end_column] || 1) - 1)
            end
          end
          pos = begin
            @inner_node.sourcepos
          rescue
            nil
          end
          return Point.new(0, 0) unless pos
          Point.new(pos[2] - 1, pos[3] - 1)
        end

        def start_line
          if @inner_node.respond_to?(:source_position)
            pos = begin
              @inner_node.source_position
            rescue
              nil
            end
            return pos[:start_line] if pos && pos[:start_line]
          end
          pos = begin
            @inner_node.sourcepos
          rescue
            nil
          end
          pos ? pos[0] : 1
        end

        def end_line
          if @inner_node.respond_to?(:source_position)
            pos = begin
              @inner_node.source_position
            rescue
              nil
            end
            return pos[:end_line] if pos && pos[:end_line]
          end
          pos = begin
            @inner_node.sourcepos
          rescue
            nil
          end
          pos ? pos[2] : 1
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

        def named?
          true
        end

        alias_method :structural?, :named?

        def has_error?
          false
        end

        def missing?
          false
        end

        def <=>(other)
          return unless other.respond_to?(:start_byte)
          cmp = start_byte <=> other.start_byte
          return cmp unless cmp&.zero?
          end_byte <=> other.end_byte
        end

        def inspect
          "#<TreeHaver::Backends::Commonmarker::Node type=#{type}>"
        end

        # Commonmarker-specific methods

        # Get heading level (1-6)
        # @return [Integer, nil]
        def header_level
          return unless type == "heading"
          begin
            @inner_node.header_level
          rescue
            nil
          end
        end

        # Get fence info for code blocks
        # @return [String, nil]
        def fence_info
          return unless type == "code_block"
          begin
            @inner_node.fence_info
          rescue
            nil
          end
        end

        # Get URL for links/images
        # @return [String, nil]
        def url
          @inner_node.url
        rescue
          nil
        end

        # Get title for links/images
        # @return [String, nil]
        def title
          @inner_node.title
        rescue
          nil
        end

        # Get the next sibling
        # @return [Node, nil]
        def next_sibling
          sibling = begin
            @inner_node.next_sibling
          rescue
            nil
          end
          sibling ? Node.new(sibling, @source, @lines) : nil
        end

        # Get the previous sibling
        # @return [Node, nil]
        def prev_sibling
          sibling = begin
            @inner_node.previous_sibling
          rescue
            nil
          end
          sibling ? Node.new(sibling, @source, @lines) : nil
        end

        # Get the parent node
        # @return [Node, nil]
        def parent
          p = begin
            @inner_node.parent
          rescue
            nil
          end
          p ? Node.new(p, @source, @lines) : nil
        end

        private

        def calculate_byte_offset(line, column)
          offset = 0
          @lines.each_with_index do |line_content, idx|
            if idx < line
              offset += line_content.bytesize
            else
              offset += [column, line_content.bytesize].min
              break
            end
          end
          offset
        end
      end

      # Point struct for position information
      Point = Struct.new(:row, :column) do
        def [](key)
          case key
          when :row, "row" then row
          when :column, "column" then column
          end
        end

        def to_h
          {row: row, column: column}
        end

        def to_s
          "(#{row}, #{column})"
        end

        def inspect
          "#<TreeHaver::Backends::Commonmarker::Point row=#{row} column=#{column}>"
        end
      end
    end
  end
end
