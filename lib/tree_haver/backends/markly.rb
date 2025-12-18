# frozen_string_literal: true

module TreeHaver
  module Backends
    # Markly backend using the Markly gem (cmark-gfm C library)
    #
    # This backend wraps Markly, a Ruby gem that provides bindings to
    # cmark-gfm, GitHub's fork of the CommonMark C library with extensions.
    #
    # @note This backend only parses Markdown source code
    # @see https://github.com/ioquatix/markly Markly gem
    #
    # @example Basic usage
    #   parser = TreeHaver::Parser.new
    #   parser.language = TreeHaver::Backends::Markly::Language.markdown(
    #     flags: Markly::DEFAULT,
    #     extensions: [:table, :strikethrough]
    #   )
    #   tree = parser.parse(markdown_source)
    #   root = tree.root_node
    #   puts root.type  # => "document"
    module Markly
      @load_attempted = false
      @loaded = false

      # Check if the Markly backend is available
      #
      # @return [Boolean] true if markly gem is available
      class << self
        def available?
          return @loaded if @load_attempted
          @load_attempted = true
          begin
            require "markly"
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
            backend: :markly,
            query: false,
            bytes_field: false,       # Markly uses line/column
            incremental: false,
            pure_ruby: false,         # Uses C via FFI
            markdown_only: true,
            error_tolerant: true,     # Markdown is forgiving
            gfm_extensions: true,     # Supports GitHub Flavored Markdown
          }
        end
      end

      # Markly language wrapper
      #
      # Markly only parses Markdown. This class exists for API compatibility
      # and to pass through Markly-specific options (flags, extensions).
      #
      # @example
      #   language = TreeHaver::Backends::Markly::Language.markdown(
      #     flags: Markly::DEFAULT | Markly::FOOTNOTES,
      #     extensions: [:table, :strikethrough]
      #   )
      #   parser.language = language
      class Language
        include Comparable

        # The language name (always :markdown for Markly)
        # @return [Symbol]
        attr_reader :name

        # The backend this language is for
        # @return [Symbol]
        attr_reader :backend

        # Markly parse flags
        # @return [Integer]
        attr_reader :flags

        # Markly extensions to enable
        # @return [Array<Symbol>]
        attr_reader :extensions

        # Create a new Markly language instance
        #
        # @param name [Symbol] Language name (should be :markdown)
        # @param flags [Integer] Markly parse flags (default: Markly::DEFAULT)
        # @param extensions [Array<Symbol>] Extensions to enable (default: [:table])
        def initialize(name = :markdown, flags: nil, extensions: [:table])
          @name = name.to_sym
          @backend = :markly
          @flags = flags  # Will use Markly::DEFAULT if nil at parse time
          @extensions = extensions
        end

        class << self
          # Create a Markdown language instance
          #
          # @param flags [Integer] Markly parse flags
          # @param extensions [Array<Symbol>] Extensions to enable
          # @return [Language] Markdown language
          def markdown(flags: nil, extensions: [:table])
            new(:markdown, flags: flags, extensions: extensions)
          end
        end

        # Comparison for sorting/equality
        def <=>(other)
          return unless other.is_a?(Language)
          name <=> other.name
        end

        def inspect
          "#<TreeHaver::Backends::Markly::Language name=#{name} flags=#{flags} extensions=#{extensions}>"
        end
      end

      # Markly parser wrapper
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
          Markly.available? or raise "Markly not available"

          flags = @language.flags || ::Markly::DEFAULT
          extensions = @language.extensions || [:table]
          doc = ::Markly.parse(source, flags: flags, extensions: extensions)
          Tree.new(doc, source)
        end

        # Alias for compatibility
        def parse_string(_old_tree, source)
          parse(source)
        end
      end

      # Markly tree wrapper
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
          "#<TreeHaver::Backends::Markly::Tree>"
        end
      end

      # Markly node wrapper
      #
      # Wraps Markly::Node to provide TreeHaver::Node-compatible interface.
      #
      # Note: Markly uses different type names than Commonmarker:
      # - :header instead of :heading
      # - :hrule instead of :thematic_break
      # - :blockquote instead of :block_quote
      # - :html instead of :html_block
      class Node
        include Comparable

        # Type normalization map (Markly → canonical)
        TYPE_MAP = {
          header: "heading",
          hrule: "thematic_break",
          html: "html_block",
          # blockquote is the same
          # Most types are the same between Markly and Commonmarker
        }.freeze

        # Default source position for nodes that don't have position info
        DEFAULT_SOURCE_POSITION = {
          start_line: 1,
          start_column: 1,
          end_line: 1,
          end_column: 1,
        }.freeze

        attr_reader :inner_node, :source

        def initialize(node, source, lines = nil)
          @inner_node = node
          @source = source
          @lines = lines || source.lines
        end

        # Get source position from the inner Markly node
        #
        # Markly provides source_position as a hash with :start_line, :start_column,
        # :end_line, :end_column (all 1-based).
        #
        # @return [Hash{Symbol => Integer}] Source position from Markly
        # @api private
        def inner_source_position
          @inner_source_position ||= if @inner_node.respond_to?(:source_position)
            @inner_node.source_position || DEFAULT_SOURCE_POSITION
          else
            DEFAULT_SOURCE_POSITION
          end
        end

        # Get the node type as a string
        #
        # Normalizes Markly types to canonical names for consistency.
        #
        # @return [String] Node type
        def type
          raw_type = @inner_node.type.to_s
          TYPE_MAP[raw_type.to_sym]&.to_s || raw_type
        end

        alias_method :kind, :type

        # Get the raw (non-normalized) type
        # @return [String]
        def raw_type
          @inner_node.type.to_s
        end

        # Get the text content of this node
        #
        # @return [String] Node text
        def text
          # Markly nodes have string_content for leaf nodes
          if @inner_node.respond_to?(:string_content)
            @inner_node.string_content.to_s
          elsif @inner_node.respond_to?(:to_plaintext)
            # For container nodes, use to_plaintext or concatenate
            begin
              @inner_node.to_plaintext
            rescue
              children.map(&:text).join
            end
          else
            children.map(&:text).join
          end
        end

        # Get child nodes
        #
        # Markly uses first_child/next pattern
        #
        # @return [Array<Node>] Child nodes
        def children
          result = []
          child = begin
            @inner_node.first_child
          rescue
            nil
          end
          while child
            result << Node.new(child, @source, @lines)
            child = begin
              child.next
            rescue
              nil
            end
          end
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
        # Markly provides source_position as a hash with :start_line, :start_column, :end_line, :end_column (1-based)

        def start_byte
          pos = inner_source_position
          line = pos[:start_line] - 1
          col = pos[:start_column] - 1
          calculate_byte_offset(line, col)
        end

        def end_byte
          pos = inner_source_position
          line = pos[:end_line] - 1
          col = pos[:end_column] - 1
          calculate_byte_offset(line, col)
        end

        def start_point
          pos = inner_source_position
          line = pos[:start_line] - 1
          col = pos[:start_column] - 1
          Point.new(line, col)
        end

        def end_point
          pos = inner_source_position
          line = pos[:end_line] - 1
          col = pos[:end_column] - 1
          Point.new(line, col)
        end

        # Get the 1-based line number where this node starts
        #
        # Markly provides 1-based line numbers via source_position hash.
        #
        # @return [Integer] 1-based line number
        def start_line
          inner_source_position[:start_line]
        end

        # Get the 1-based line number where this node ends
        #
        # @return [Integer] 1-based line number
        def end_line
          inner_source_position[:end_line]
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
          "#<TreeHaver::Backends::Markly::Node type=#{type} raw_type=#{raw_type}>"
        end

        # Convert node to CommonMark format
        #
        # Delegates to the inner Markly node's to_commonmark method.
        #
        # @return [String] CommonMark representation
        def to_commonmark
          @inner_node.to_commonmark
        end

        # Convert node to Markdown format
        #
        # Delegates to the inner Markly node's to_markdown method.
        #
        # @return [String] Markdown representation
        def to_markdown
          @inner_node.to_markdown
        end

        # Convert node to plain text
        #
        # Delegates to the inner Markly node's to_plaintext method.
        #
        # @return [String] Plain text representation
        def to_plaintext
          @inner_node.to_plaintext
        end

        # Convert node to HTML
        #
        # Delegates to the inner Markly node's to_html method.
        #
        # @return [String] HTML representation
        def to_html
          @inner_node.to_html
        end

        # Markly-specific methods

        # Get heading level (1-6)
        # @return [Integer, nil]
        def header_level
          return unless raw_type == "header"
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

        # Get the next sibling (Markly uses .next)
        # @return [Node, nil]
        def next_sibling
          sibling = begin
            @inner_node.next
          rescue
            nil
          end
          sibling ? Node.new(sibling, @source, @lines) : nil
        end

        # Get the previous sibling
        # @return [Node, nil]
        def previous_sibling
          sibling = begin
            @inner_node.previous
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
          "#<TreeHaver::Backends::Markly::Point row=#{row} column=#{column}>"
        end
      end
    end
  end
end
