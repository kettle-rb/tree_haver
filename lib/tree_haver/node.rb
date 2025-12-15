# frozen_string_literal: true

module TreeHaver
  # Point class that works as both a Hash and an object with row/column accessors
  #
  # This provides compatibility with code expecting either:
  # - Hash access: point[:row], point[:column]
  # - Method access: point.row, point.column
  class Point
    attr_reader :row, :column

    def initialize(row, column)
      @row = row
      @column = column
    end

    # Hash-like access for compatibility
    def [](key)
      case key
      when :row, "row" then @row
      when :column, "column" then @column
      end
    end

    def to_h
      {row: @row, column: @column}
    end

    def to_s
      "(#{@row}, #{@column})"
    end

    def inspect
      "#<TreeHaver::Point row=#{@row} column=#{@column}>"
    end
  end

  # Unified Node wrapper providing a consistent API across all backends
  #
  # This class wraps backend-specific node objects (TreeSitter::Node, TreeStump::Node, etc.)
  # and provides a unified interface so code works identically regardless of which backend
  # is being used.
  #
  # The wrapper automatically maps backend differences:
  # - TreeStump uses `node.kind` → mapped to `node.type`
  # - TreeStump uses `node.is_named?` → mapped to `node.named?`
  # - All backends return consistent Point objects from position methods
  #
  # @example Basic node traversal
  #   tree = parser.parse(source)
  #   root = tree.root_node
  #
  #   puts root.type        # => "document"
  #   puts root.start_byte  # => 0
  #   puts root.text        # => full source text
  #
  #   root.children.each do |child|
  #     puts "#{child.type} at line #{child.start_point.row + 1}"
  #   end
  #
  # @example Position information
  #   node = tree.root_node.children.first
  #
  #   # Point objects work as both objects and hashes
  #   point = node.start_point
  #   point.row              # => 0 (method access)
  #   point[:row]            # => 0 (hash access)
  #   point.column           # => 0
  #
  #   # Byte offsets
  #   node.start_byte        # => 0
  #   node.end_byte          # => 23
  #
  # @example Error detection
  #   if node.has_error?
  #     puts "Parse error in subtree"
  #   end
  #
  #   if node.missing?
  #     puts "This node was inserted by error recovery"
  #   end
  #
  # @example Accessing backend-specific features
  #   # Via passthrough (method_missing delegates to inner_node)
  #   node.grammar_name  # TreeStump-specific, automatically delegated
  #
  #   # Or explicitly via inner_node
  #   node.inner_node.grammar_name  # Same result
  #
  #   # Check if backend supports a feature
  #   if node.inner_node.respond_to?(:some_feature)
  #     node.some_feature
  #   end
  #
  # @note This is the key to tree_haver's "write once, run anywhere" promise
  class Node
    # The wrapped backend-specific node object
    #
    # This provides direct access to the underlying backend node for advanced usage
    # when you need backend-specific features not exposed by the unified API.
    #
    # @return [Object] The underlying node (TreeSitter::Node, TreeStump::Node, etc.)
    # @example Accessing backend-specific methods
    #   # TreeStump-specific: grammar information
    #   if node.inner_node.respond_to?(:grammar_name)
    #     puts node.inner_node.grammar_name  # => "toml"
    #     puts node.inner_node.grammar_id    # => Integer
    #   end
    #
    #   # Check backend type
    #   case node.inner_node.class.name
    #   when /TreeStump/
    #     # TreeStump-specific code
    #   when /TreeSitter/
    #     # ruby_tree_sitter-specific code
    #   end
    attr_reader :inner_node

    # The source text for text extraction
    # @return [String]
    attr_reader :source

    # @param node [Object] Backend-specific node object
    # @param source [String] Source text for text extraction
    def initialize(node, source: nil)
      @inner_node = node
      @source = source
    end

    # Get the node's type/kind as a string
    #
    # Maps backend-specific methods to a unified API:
    # - ruby_tree_sitter: node.type
    # - tree_stump: node.kind
    # - FFI: node.type
    #
    # @return [String] The node type
    def type
      if @inner_node.respond_to?(:type)
        @inner_node.type.to_s
      elsif @inner_node.respond_to?(:kind)
        @inner_node.kind.to_s
      else
        raise TreeHaver::Error, "Backend node does not support type/kind"
      end
    end

    # Get the node's start byte offset
    # @return [Integer]
    def start_byte
      @inner_node.start_byte
    end

    # Get the node's end byte offset
    # @return [Integer]
    def end_byte
      @inner_node.end_byte
    end

    # Get the node's start position (row, column)
    #
    # @return [Point] with row and column accessors (also works as Hash)
    def start_point
      if @inner_node.respond_to?(:start_point)
        point = @inner_node.start_point
        Point.new(point.row, point.column)
      elsif @inner_node.respond_to?(:start_position)
        point = @inner_node.start_position
        Point.new(point.row, point.column)
      else
        raise TreeHaver::Error, "Backend node does not support start_point/start_position"
      end
    end

    # Get the node's end position (row, column)
    #
    # @return [Point] with row and column accessors (also works as Hash)
    def end_point
      if @inner_node.respond_to?(:end_point)
        point = @inner_node.end_point
        Point.new(point.row, point.column)
      elsif @inner_node.respond_to?(:end_position)
        point = @inner_node.end_position
        Point.new(point.row, point.column)
      else
        raise TreeHaver::Error, "Backend node does not support end_point/end_position"
      end
    end

    # Get the node's text content
    #
    # @return [String]
    def text
      if @inner_node.respond_to?(:text)
        @inner_node.text
      elsif @source
        # Fallback: extract from source using byte positions
        @source[start_byte...end_byte] || ""
      else
        raise TreeHaver::Error, "Cannot extract text: node has no text method and no source provided"
      end
    end

    # Check if the node has an error
    # @return [Boolean]
    def has_error?
      @inner_node.has_error?
    end

    # Check if the node is missing
    # @return [Boolean]
    def missing?
      return false unless @inner_node.respond_to?(:missing?)
      @inner_node.missing?
    end

    # Check if the node is named
    # @return [Boolean]
    def named?
      if @inner_node.respond_to?(:named?)
        @inner_node.named?
      elsif @inner_node.respond_to?(:is_named?)
        @inner_node.is_named?
      else
        true # Default to true if not supported
      end
    end

    # Get the number of children
    # @return [Integer]
    def child_count
      @inner_node.child_count
    end

    # Get a child by index
    #
    # @param index [Integer] Child index
    # @return [Node, nil] Wrapped child node
    def child(index)
      child_node = @inner_node.child(index)
      return if child_node.nil?
      Node.new(child_node, source: @source)
    end

    # Get all children as wrapped nodes
    #
    # @return [Array<Node>] Array of wrapped child nodes
    def children
      (0...child_count).map { |i| child(i) }.compact
    end

    # Get named children only
    #
    # @return [Array<Node>] Array of named child nodes
    def named_children
      children.select(&:named?)
    end

    # Iterate over children
    #
    # @yield [Node] Each child node
    # @return [Enumerator, nil]
    def each(&block)
      return to_enum(__method__) unless block_given?
      children.each(&block)
    end

    # Get a child by field name
    #
    # @param name [String, Symbol] Field name
    # @return [Node, nil] The child node for that field
    def child_by_field_name(name)
      if @inner_node.respond_to?(:child_by_field_name)
        child_node = @inner_node.child_by_field_name(name.to_s)
        return if child_node.nil?
        Node.new(child_node, source: @source)
      else
        # Not all backends support field names
        nil
      end
    end

    # Alias for child_by_field_name
    alias_method :field, :child_by_field_name

    # Get the parent node
    #
    # @return [Node, nil] The parent node
    def parent
      return unless @inner_node.respond_to?(:parent)
      parent_node = @inner_node.parent
      return if parent_node.nil?
      Node.new(parent_node, source: @source)
    end

    # Get next sibling
    #
    # @return [Node, nil]
    def next_sibling
      return unless @inner_node.respond_to?(:next_sibling)
      sibling = @inner_node.next_sibling
      return if sibling.nil?
      Node.new(sibling, source: @source)
    end

    # Get previous sibling
    #
    # @return [Node, nil]
    def prev_sibling
      return unless @inner_node.respond_to?(:prev_sibling)
      sibling = @inner_node.prev_sibling
      return if sibling.nil?
      Node.new(sibling, source: @source)
    end

    # String representation for debugging
    # @return [String]
    def inspect
      "#<#{self.class} type=#{type} bytes=#{start_byte}..#{end_byte}>"
    end

    # String representation
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
      @inner_node.respond_to?(method_name, include_private) || super
    end

    # Delegate unknown methods to the underlying backend-specific node
    #
    # This provides passthrough access for advanced usage when you need
    # backend-specific features not exposed by TreeHaver's unified API.
    #
    # The delegation is automatic and transparent - you can call backend-specific
    # methods directly on the TreeHaver::Node and they'll be forwarded to the
    # underlying node implementation.
    #
    # @param method_name [Symbol] method to call
    # @param args [Array] arguments to pass
    # @param block [Proc] block to pass
    # @return [Object] result from the underlying node
    #
    # @example Using TreeStump-specific methods
    #   # These methods don't exist in the unified API but are in TreeStump
    #   node.grammar_name      # => "toml" (delegated to inner_node)
    #   node.grammar_id        # => Integer (delegated to inner_node)
    #   node.kind_id           # => Integer (delegated to inner_node)
    #
    # @example Safe usage with respond_to? check
    #   if node.respond_to?(:grammar_name)
    #     puts "Using #{node.grammar_name} grammar"
    #   end
    #
    # @example Equivalent explicit access
    #   node.grammar_name              # Via passthrough (method_missing)
    #   node.inner_node.grammar_name   # Explicit access (same result)
    #
    # @note This maintains backward compatibility with code written for
    #   specific backends while providing the benefits of the unified API
    def method_missing(method_name, *args, **kwargs, &block)
      if @inner_node.respond_to?(method_name)
        @inner_node.public_send(method_name, *args, **kwargs, &block)
      else
        super
      end
    end
  end
end
