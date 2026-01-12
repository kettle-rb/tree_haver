# frozen_string_literal: true

# Ensure TreeHaver::Node and TreeHaver::Point are loaded
require "tree_haver"

module TreeHaver
  module RSpec
    # A mock inner node that provides the minimal interface TreeHaver::Node expects.
    #
    # This is what TreeHaver::Node wraps - it simulates the backend-specific node
    # (like tree-sitter's Node, Markly::Node, etc.)
    #
    # @api private
    class MockInnerNode
      attr_reader :type, :start_byte, :end_byte, :children_data

      def initialize(
        type:,
        text: nil,
        start_byte: 0,
        end_byte: nil,
        start_row: 0,
        start_column: 0,
        end_row: nil,
        end_column: nil,
        children: []
      )
        @type = type.to_s
        @text_content = text
        @start_byte = start_byte
        @end_byte = end_byte || (text ? start_byte + text.length : start_byte)
        @start_row = start_row
        @start_column = start_column
        @end_row = end_row || start_row
        @end_column = end_column || (text ? start_column + text.length : start_column)
        @children_data = children
      end

      def start_point
        TreeHaver::Point.new(@start_row, @start_column)
      end

      def end_point
        TreeHaver::Point.new(@end_row, @end_column)
      end

      def child_count
        @children_data.length
      end

      def child(index)
        return nil if index.nil? || index < 0 || index >= @children_data.length

        @children_data[index]
      end

      # Return children array (for enumerable behavior)
      def children
        @children_data
      end

      def first_child
        @children_data.first
      end

      def last_child
        @children_data.last
      end

      # Iterate over children
      def each(&block)
        return enum_for(:each) unless block

        @children_data.each(&block)
      end

      def named?
        true
      end

      # Test nodes are always valid (no parse errors)
      def has_error?
        false
      end

      # Test nodes are never missing (not error recovery insertions)
      def missing?
        false
      end

      # Some backends provide text directly
      def text
        @text_content
      end

      # For backends that use string_content (like Markly/Commonmarker)
      def string_content
        @text_content
      end
    end

    # A real TreeHaver::Node that wraps a MockInnerNode.
    #
    # This gives us full TreeHaver::Node behavior (#text, #type, #source_position, etc.)
    # while allowing us to control the underlying data for testing.
    #
    # TestableNode is designed for testing code that works with TreeHaver nodes
    # without requiring an actual parser backend. It creates real TreeHaver::Node
    # instances with controlled, predictable data.
    #
    # @example Creating a testable node
    #   node = TreeHaver::RSpec::TestableNode.create(
    #     type: :heading,
    #     text: "## My Heading",
    #     start_line: 1
    #   )
    #   node.text       # => "## My Heading"
    #   node.type       # => "heading"
    #   node.start_line # => 1
    #
    # @example Creating with children
    #   parent = TreeHaver::RSpec::TestableNode.create(
    #     type: :document,
    #     text: "# Title\n\nParagraph",
    #     children: [
    #       { type: :heading, text: "# Title", start_line: 1 },
    #       { type: :paragraph, text: "Paragraph", start_line: 3 },
    #     ]
    #   )
    #
    # @example Using the convenience constant
    #   # After requiring tree_haver/rspec/testable_node, you can use:
    #   node = TestableNode.create(type: :paragraph, text: "Hello")
    #
    class TestableNode < TreeHaver::Node
      class << self
        # Create a TestableNode with the given attributes.
        #
        # @param type [Symbol, String] Node type (e.g., :heading, :paragraph)
        # @param text [String] The text content of the node
        # @param start_line [Integer] 1-based start line number (default: 1)
        # @param end_line [Integer, nil] 1-based end line number (default: calculated from text)
        # @param start_column [Integer] 0-based start column (default: 0)
        # @param end_column [Integer, nil] 0-based end column (default: calculated from text)
        # @param start_byte [Integer] Start byte offset (default: 0)
        # @param end_byte [Integer, nil] End byte offset (default: calculated from text)
        # @param children [Array<Hash>] Child node specifications
        # @param source [String, nil] Full source text (default: uses text param)
        # @return [TestableNode]
        def create(
          type:,
          text: "",
          start_line: 1,
          end_line: nil,
          start_column: 0,
          end_column: nil,
          start_byte: 0,
          end_byte: nil,
          children: [],
          source: nil
        )
          # Convert 1-based line to 0-based row
          start_row = start_line - 1
          end_row = end_line ? end_line - 1 : start_row + text.count("\n")

          # Calculate end_column if not provided
          if end_column.nil?
            lines = text.split("\n", -1)
            end_column = lines.last&.length || 0
          end

          # Build children as MockInnerNodes
          child_nodes = children.map do |child_spec|
            MockInnerNode.new(**child_spec)
          end

          inner = MockInnerNode.new(
            type: type,
            text: text,
            start_byte: start_byte,
            end_byte: end_byte,
            start_row: start_row,
            start_column: start_column,
            end_row: end_row,
            end_column: end_column,
            children: child_nodes,
          )

          # Create a real TreeHaver::Node wrapping our mock
          # Pass source so TreeHaver::Node can extract text if needed
          new(inner, source: source || text)
        end

        # Create multiple nodes from an array of specifications.
        #
        # @param specs [Array<Hash>] Array of node specifications
        # @return [Array<TestableNode>]
        def create_list(*specs)
          specs.flatten.map { |spec| create(**spec) }
        end
      end

      # Additional test helper methods

      # Check if this is a testable node (for test assertions)
      #
      # @return [Boolean] true
      def testable?
        true
      end
    end
  end
end

# Make TestableNode available at top level for convenience in specs.
# This allows specs to use `TestableNode.create(...)` without the full namespace.
TestableNode = TreeHaver::RSpec::TestableNode
