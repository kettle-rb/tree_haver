# frozen_string_literal: true

require "spec_helper"

# Integration tests for Node edge cases and fallback behaviors
# These test behaviors when backend nodes don't implement all optional methods
RSpec.describe "TreeHaver::Node edge cases", :toml_grammar do
  let(:source) { "x = 42\ny = 13" }
  let(:parser) do
    p = TreeHaver::Parser.new
    path = TreeHaverDependencies.find_toml_grammar_path
    language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
    p.language = language
    p
  end
  let(:tree) { parser.parse(source) }
  let(:root_node) { tree.root_node }

  describe "fallback behaviors when backend doesn't implement optional methods" do
    describe "#named_child_count" do
      context "when backend doesn't support named_child_count directly" do
        it "manually counts named children" do
          # Create a mock node that doesn't support named_child_count
          mock_inner = double("mock_node", child_count: 3)
          allow(mock_inner).to receive(:respond_to?) do |method, *|
            method != :named_child_count
          end

          # Create mock children: 2 named, 1 unnamed
          child1 = double("child1", named?: true, child_count: 0, type: "named1")
          child2 = double("child2", named?: false, child_count: 0, type: "unnamed")
          child3 = double("child3", named?: true, child_count: 0, type: "named2")

          [child1, child2, child3].each do |child|
            allow(child).to receive(:respond_to?).and_return(true)
          end

          allow(mock_inner).to receive(:child).with(0).and_return(child1)
          allow(mock_inner).to receive(:child).with(1).and_return(child2)
          allow(mock_inner).to receive(:child).with(2).and_return(child3)

          node = TreeHaver::Node.new(mock_inner, source: source)
          expect(node.named_child_count).to eq(2)
        end
      end
    end

    describe "#named_child" do
      context "when backend doesn't support named_child directly" do
        it "manually finds the nth named child" do
          mock_inner = double("mock_node", child_count: 4)
          allow(mock_inner).to receive(:respond_to?) do |method, *|
            method != :named_child
          end

          # Create children: index 1 and 3 are named
          child0 = double("child0", named?: false, child_count: 0, type: "unnamed0")
          child1 = double("child1", named?: true, type: "first_named", child_count: 0)
          child2 = double("child2", named?: false, child_count: 0, type: "unnamed2")
          child3 = double("child3", named?: true, type: "second_named", child_count: 0)

          [child0, child1, child2, child3].each do |child|
            allow(child).to receive(:respond_to?).and_return(true)
          end

          allow(mock_inner).to receive(:child).with(0).and_return(child0)
          allow(mock_inner).to receive(:child).with(1).and_return(child1)
          allow(mock_inner).to receive(:child).with(2).and_return(child2)
          allow(mock_inner).to receive(:child).with(3).and_return(child3)

          node = TreeHaver::Node.new(mock_inner, source: source)

          # Get first named child (index 0)
          first = node.named_child(0)
          expect(first).to be_a(TreeHaver::Node)
          expect(first.inner_node).to eq(child1)

          # Get second named child (index 1)
          second = node.named_child(1)
          expect(second).to be_a(TreeHaver::Node)
          expect(second.inner_node).to eq(child3)
        end

        it "returns nil when index is out of bounds" do
          mock_inner = double("mock_node")
          allow(mock_inner).to receive(:respond_to?).with(:named_child).and_return(false)
          allow(mock_inner).to receive(:child_count).and_return(2)

          child0 = double("child0", named?: true)
          child1 = double("child1", named?: false)

          allow(mock_inner).to receive(:child).with(0).and_return(child0)
          allow(mock_inner).to receive(:child).with(1).and_return(child1)

          node = TreeHaver::Node.new(mock_inner, source: source)

          # Only 1 named child, so index 5 is out of bounds
          expect(node.named_child(5)).to be_nil
        end
      end
    end

    describe "#start_point and #end_point wrapping" do
      it "wraps Point objects properly" do
        # Real nodes from tree-sitter return Point objects
        if root_node.child_count > 0
          first_child = root_node.child(0)
          start_pt = first_child.start_point
          end_pt = first_child.end_point

          # Should be wrapped as TreeHaver::Point
          expect(start_pt).to be_a(TreeHaver::Point)
          expect(end_pt).to be_a(TreeHaver::Point)

          # Should have row and column
          expect(start_pt.row).to be_a(Integer)
          expect(start_pt.column).to be_a(Integer)
          expect(end_pt.row).to be_a(Integer)
          expect(end_pt.column).to be_a(Integer)
        end
      end
    end

    describe "#type when backend has :kind instead of :type" do
      it "uses kind when type not available" do
        mock_inner = double("mock_node_with_kind")
        allow(mock_inner).to receive(:respond_to?).with(:type).and_return(false)
        allow(mock_inner).to receive(:respond_to?).with(:kind).and_return(true)
        allow(mock_inner).to receive(:kind).and_return(:identifier)

        node = TreeHaver::Node.new(mock_inner, source: source)
        expect(node.type).to eq("identifier")
      end

      it "raises error when neither type nor kind available" do
        mock_inner = double("mock_node_no_type")
        allow(mock_inner).to receive(:respond_to?).with(:type).and_return(false)
        allow(mock_inner).to receive(:respond_to?).with(:kind).and_return(false)

        node = TreeHaver::Node.new(mock_inner, source: source)
        expect {
          node.type
        }.to raise_error(TreeHaver::Error, /does not support type\/kind/)
      end
    end
  end

  describe "text extraction edge cases" do
    it "extracts text using source when available" do
      if root_node.child_count > 0
        child = root_node.child(0)
        # Node should have source for text extraction
        text = child.text
        expect(text).to be_a(String)
        expect(text.length).to be > 0
      end
    end

    it "handles nodes without source gracefully" do
      mock_inner = double("mock_node")
      allow(mock_inner).to receive(:respond_to?).with(:text).and_return(true)
      allow(mock_inner).to receive(:text).and_return("backend_text")

      # Create node without source
      node = TreeHaver::Node.new(mock_inner)
      expect(node.text).to eq("backend_text")
    end
  end

  describe "equality comparison" do
    it "considers nodes with same inner_node equal" do
      node1 = TreeHaver::Node.new(root_node.inner_node, source: source)
      node2 = TreeHaver::Node.new(root_node.inner_node, source: source)

      expect(node1).to eq(node2)
      expect(node1.hash).to eq(node2.hash)
    end

    it "considers nodes with different inner_node unequal" do
      if root_node.child_count > 1
        node1 = root_node.child(0)
        node2 = root_node.child(1)

        expect(node1).not_to eq(node2)
      end
    end
  end
end
