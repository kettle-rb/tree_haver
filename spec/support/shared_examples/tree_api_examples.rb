# frozen_string_literal: true

# Shared examples for Tree API compliance
#
# These examples test the standard Tree interface that all backends must implement.
# They ensure consistent behavior across MRI, FFI, Rust, Java, Citrus, Parslet,
# Prism, Psych, and other backends.
#
# @example Usage in backend specs
#   RSpec.describe TreeHaver::Backends::Citrus::Tree do
#     let(:create_tree) { ->(source) { parser.parse(source) } }
#     let(:simple_source) { 'key = "value"' }
#
#     it_behaves_like "tree api compliance"
#     it_behaves_like "tree error handling"
#   end

# Core Tree API that all implementations must provide
RSpec.shared_examples "tree api compliance" do
  # Expects `tree` to be defined as the tree under test
  # Expects `source` to be defined as the source that was parsed

  describe "required interface" do
    it "responds to #root_node" do
      expect(tree).to respond_to(:root_node)
    end

    it "#root_node returns a node" do
      root = tree.root_node
      expect(root).not_to be_nil
      expect(root).to respond_to(:type)
      expect(root).to respond_to(:start_byte)
      expect(root).to respond_to(:end_byte)
      expect(root).to respond_to(:children)
    end

    it "#root_node returns same node on multiple calls" do
      first = tree.root_node
      second = tree.root_node
      # They should be equivalent (same type and position)
      expect(first.type).to eq(second.type)
      expect(first.start_byte).to eq(second.start_byte)
      expect(first.end_byte).to eq(second.end_byte)
    end
  end

  describe "source tracking" do
    it "responds to #source" do
      expect(tree).to respond_to(:source)
    end

    it "#source returns the original source" do
      expect(tree.source).to eq(source)
    end
  end

  describe "optional interface with defaults" do
    it "responds to #errors" do
      expect(tree).to respond_to(:errors)
    end

    it "#errors returns an Array" do
      expect(tree.errors).to be_an(Array)
    end

    it "responds to #warnings" do
      expect(tree).to respond_to(:warnings)
    end

    it "#warnings returns an Array" do
      expect(tree.warnings).to be_an(Array)
    end

    it "responds to #comments" do
      expect(tree).to respond_to(:comments)
    end

    it "#comments returns an Array" do
      expect(tree.comments).to be_an(Array)
    end
  end

  describe "#inspect" do
    it "returns a String" do
      expect(tree.inspect).to be_a(String)
    end

    it "includes class information" do
      expect(tree.inspect).to include("Tree")
    end
  end
end

# Tree error detection
RSpec.shared_examples "tree error handling" do
  # Expects `valid_tree` to be a tree parsed from valid source
  # Expects `invalid_tree` to be a tree parsed from invalid source (if supported)

  describe "#has_error?" do
    it "responds to #has_error?" do
      expect(valid_tree).to respond_to(:has_error?)
    end

    it "returns false for valid source" do
      expect(valid_tree.has_error?).to be false
    end

    context "with invalid source", if: -> { defined?(invalid_tree) && invalid_tree } do
      it "returns true for invalid source" do
        expect(invalid_tree.has_error?).to be true
      end
    end
  end

  describe "#errors" do
    it "returns empty array for valid source" do
      expect(valid_tree.errors).to be_empty
    end
  end
end

# Tree traversal capabilities
RSpec.shared_examples "tree traversal" do
  # Expects `tree` to be defined with at least one node with children

  describe "depth-first traversal via root_node" do
    it "root_node children can be traversed" do
      root = tree.root_node
      visited = []

      # Simple depth-first traversal
      stack = [root]
      while (node = stack.pop)
        visited << node.type
        # Add children in reverse order so first child is processed first
        node.children.reverse_each { |c| stack.push(c) }
      end

      expect(visited).not_to be_empty
      expect(visited.first).to eq(root.type)
    end

    it "all nodes in tree respond to node API" do
      root = tree.root_node
      stack = [root]

      while (node = stack.pop)
        expect(node).to respond_to(:type)
        expect(node).to respond_to(:start_byte)
        expect(node).to respond_to(:end_byte)
        expect(node).to respond_to(:children)

        node.children.each { |c| stack.push(c) }
      end
    end
  end
end

