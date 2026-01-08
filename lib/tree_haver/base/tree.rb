# frozen_string_literal: true

module TreeHaver
  module Base
    # Base class for all backend Tree implementations
    #
    # This class defines the API contract for Tree objects across all backends.
    # It provides shared implementation and documents required/optional methods.
    #
    # == Backend Architecture
    #
    # TreeHaver supports two categories of backends:
    #
    # === Tree-sitter Backends (MRI, Rust, FFI, Java)
    #
    # These backends use the native tree-sitter library (via different bindings).
    # They return raw `::TreeSitter::Tree` objects which are wrapped by
    # `TreeHaver::Tree` (which inherits from this class).
    #
    # - Backend Parser returns: `::TreeSitter::Tree` (raw)
    # - TreeHaver::Parser wraps it in: `TreeHaver::Tree`
    # - These backends do NOT define their own Tree/Node classes
    #
    # === Pure-Ruby/Plugin Backends (Citrus, Prism, Psych, Commonmarker, Markly)
    #
    # These backends define their own complete implementations:
    # - `Backend::X::Tree` - wraps parser-specific tree objects
    # - `Backend::X::Node` - wraps parser-specific node objects
    #
    # For consistency, these should also inherit from `Base::Tree` and `Base::Node`.
    #
    # @abstract Subclasses must implement #root_node
    # @see TreeHaver::Tree The main wrapper class that inherits from this
    # @see TreeHaver::Backends::Citrus::Tree Example of a backend-specific Tree
    class Tree
      # The underlying backend-specific tree object
      # @return [Object] Backend tree
      attr_reader :inner_tree

      # The source text
      # @return [String] The original source code
      attr_reader :source

      # Source lines for byte offset calculations
      # @return [Array<String>] Lines of source
      attr_reader :lines

      # Create a new Tree
      #
      # @param inner_tree [Object] The backend-specific tree object
      # @param source [String, nil] The source code
      # @param lines [Array<String>, nil] Pre-split lines (optional, derived from source if not provided)
      def initialize(inner_tree = nil, source: nil, lines: nil)
        @inner_tree = inner_tree
        @source = source
        @lines = lines || source&.lines || []
      end

      # -- Required API Methods ------------------------------------------------

      # Get the root node of the tree
      # @return [Node] Root node
      def root_node
        raise NotImplementedError, "#{self.class}#root_node must be implemented"
      end

      # -- Optional API Methods (with defaults) --------------------------------

      # Get parse errors
      # @return [Array] Errors (empty for most pure-Ruby backends)
      def errors
        []
      end

      # Get parse warnings
      # @return [Array] Warnings (empty for most pure-Ruby backends)
      def warnings
        []
      end

      # Get comments from the document
      # @return [Array] Comments (empty for most pure-Ruby backends)
      def comments
        []
      end

      # Mark the tree as edited for incremental re-parsing
      # @return [void]
      def edit(
        start_byte:,
        old_end_byte:,
        new_end_byte:,
        start_point:,
        old_end_point:,
        new_end_point:
      )
        # Default implementation: no-op (incremental parsing not supported)
        # Backends that support it should override this
      end

      # Check if this tree has syntax errors
      # @return [Boolean]
      def has_error?
        root = root_node
        return false unless root
        return true if root.has_error?

        # Deep check: traverse tree looking for error nodes
        # Use queue-based traversal to avoid deep recursion
        queue = [root]
        while (node = queue.shift)
          return true if node.has_error? || node.missing?

          # Add children to queue
          node.each { |child| queue.push(child) }
        end

        false
      end

      # Human-readable representation
      # @return [String]
      def inspect
        "#<#{self.class.name}>"
      end
    end
  end
end

