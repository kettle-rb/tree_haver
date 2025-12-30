# frozen_string_literal: true

require "spec_helper"

# Integration tests for Tree edge cases and method delegation
# Uses parser_for which auto-discovers backend (tree-sitter or Citrus fallback)
RSpec.describe "TreeHaver::Tree edge cases", :toml_parsing do
  let(:source) { "[package]\nname = \"test\"" }
  let(:parser) { TreeHaver.parser_for(:toml) }
  let(:tree) { parser.parse(source) }

  describe "method delegation to inner_tree" do
    it "delegates methods not defined on wrapper" do
      # Try to call a backend-specific method if it exists
      if tree.inner_tree.respond_to?(:changed_ranges)
        # This is a tree-sitter specific method
        expect { tree.changed_ranges(tree.inner_tree) }.not_to raise_error
      end
    end

    it "passes blocks through to inner_tree methods" do
      mock_inner = double("mock_tree")
      allow(mock_inner).to receive(:root_node).and_return(double("node", type: "test"))
      allow(mock_inner).to receive(:walk) do |&block|
        block&.call("walked")
        "walk_result"
      end

      tree_wrapper = TreeHaver::Tree.new(mock_inner, source: source)

      result = nil
      return_value = tree_wrapper.walk { |val| result = val }

      expect(result).to eq("walked")
      expect(return_value).to eq("walk_result")
    end

    it "raises NoMethodError for truly non-existent methods" do
      expect {
        tree.completely_undefined_method_xyz_123
      }.to raise_error(NoMethodError)
    end
  end

  describe "#respond_to?" do
    it "returns true for methods on inner_tree" do
      # root_node should exist on inner_tree
      expect(tree.respond_to?(:root_node)).to be true
    end

    it "returns false for methods not on inner_tree" do
      expect(tree.respond_to?(:nonexistent_method_xyz)).to be false
    end

    it "handles private method checks" do
      mock_inner = double("mock_tree")
      allow(mock_inner).to receive(:root_node).and_return(double("node"))
      allow(mock_inner).to receive(:respond_to?).with(:private_method, true).and_return(true)
      allow(mock_inner).to receive(:respond_to?).with(:private_method, false).and_return(false)

      tree_wrapper = TreeHaver::Tree.new(mock_inner)

      # Public check should return false
      expect(tree_wrapper.respond_to?(:private_method, false)).to be false

      # Private check should return true
      expect(tree_wrapper.respond_to?(:private_method, true)).to be true
    end
  end

  describe "#inspect" do
    it "includes source length when source is present" do
      result = tree.inspect

      expect(result).to include("TreeHaver::Tree")
      expect(result).to include("source_length=")
      expect(result).to include(source.bytesize.to_s)
    end

    it "shows 'unknown' when source is nil" do
      tree_no_source = TreeHaver::Tree.new(tree.inner_tree, source: nil)
      result = tree_no_source.inspect

      expect(result).to include("TreeHaver::Tree")
      expect(result).to include("source_length=unknown")
    end

    it "includes inner_tree class info" do
      result = tree.inspect
      expect(result).to match(/inner_tree=/)
    end
  end

  describe "root_node edge cases" do
    it "returns nil when inner_tree.root_node is nil" do
      mock_inner = double("mock_tree")
      allow(mock_inner).to receive(:root_node).and_return(nil)

      tree_wrapper = TreeHaver::Tree.new(mock_inner, source: source)
      expect(tree_wrapper.root_node).to be_nil
    end

    it "wraps non-nil root_node" do
      root = tree.root_node
      expect(root).to be_a(TreeHaver::Node)
      expect(root.inner_node).not_to be_nil
    end

    it "passes source to root_node" do
      root = tree.root_node
      expect(root.source).to eq(source)
    end
  end
end
