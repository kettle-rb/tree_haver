# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Base::Tree do
  # Create a concrete test subclass
  let(:concrete_tree_class) do
    Class.new(described_class) do
      attr_reader :mock_root

      def initialize(mock_root = nil, **options)
        @mock_root = mock_root
        super(**options)
      end

      def root_node
        @mock_root
      end
    end
  end

  let(:mock_node) do
    node = double("node")
    allow(node).to receive_messages(has_error?: false, missing?: false)
    allow(node).to receive(:each).and_yield(nil).and_return([])
    node
  end

  let(:tree) { concrete_tree_class.new(mock_node) }

  describe "#initialize" do
    it "accepts source parameter" do
      tree = concrete_tree_class.new(mock_node, source: "test content")
      expect(tree.source).to eq("test content")
    end

    it "accepts lines parameter" do
      tree = concrete_tree_class.new(mock_node, lines: %w[line1 line2])
      expect(tree.lines).to eq(%w[line1 line2])
    end

    it "derives lines from source if not provided" do
      tree = concrete_tree_class.new(mock_node, source: "line1\nline2")
      expect(tree.lines).to eq(["line1\n", "line2"])
    end
  end

  describe "#root_node" do
    it "raises NotImplementedError in base class" do
      base_tree = described_class.new
      expect { base_tree.root_node }.to raise_error(NotImplementedError)
    end
  end

  describe "#errors" do
    it "returns empty array by default" do
      expect(tree.errors).to eq([])
    end
  end

  describe "#warnings" do
    it "returns empty array by default" do
      expect(tree.warnings).to eq([])
    end
  end

  describe "#comments" do
    it "returns empty array by default" do
      expect(tree.comments).to eq([])
    end
  end

  describe "#edit" do
    it "is a no-op by default (incremental parsing not supported)" do
      # Should not raise, just do nothing
      expect {
        tree.edit(
          start_byte: 0,
          old_end_byte: 1,
          new_end_byte: 2,
          start_point: {row: 0, column: 0},
          old_end_point: {row: 0, column: 1},
          new_end_point: {row: 0, column: 2},
        )
      }.not_to raise_error
    end
  end

  describe "#has_error?" do
    context "when root node is nil" do
      let(:tree) { concrete_tree_class.new(nil) }

      it "returns false" do
        expect(tree.has_error?).to be false
      end
    end

    context "when root node has error" do
      before do
        allow(mock_node).to receive(:has_error?).and_return(true)
      end

      it "returns true" do
        expect(tree.has_error?).to be true
      end
    end

    context "when child node has error" do
      let(:child_node) do
        child = double("child_node")
        allow(child).to receive_messages(has_error?: true, missing?: false)
        allow(child).to receive(:each).and_return([].each)
        child
      end

      before do
        allow(mock_node).to receive(:each).and_yield(child_node)
      end

      it "returns true via deep traversal" do
        expect(tree.has_error?).to be true
      end
    end

    context "when child node is missing" do
      let(:child_node) do
        child = double("child_node")
        allow(child).to receive_messages(has_error?: false, missing?: true)
        allow(child).to receive(:each).and_return([].each)
        child
      end

      before do
        allow(mock_node).to receive(:each).and_yield(child_node)
      end

      it "returns true via deep traversal" do
        expect(tree.has_error?).to be true
      end
    end

    context "when no errors" do
      let(:child_node) do
        child = double("child_node")
        allow(child).to receive_messages(has_error?: false, missing?: false)
        allow(child).to receive(:each).and_return([].each)
        child
      end

      before do
        allow(mock_node).to receive(:each).and_yield(child_node)
      end

      it "returns false" do
        expect(tree.has_error?).to be false
      end
    end
  end

  describe "#inspect" do
    it "returns a readable string" do
      expect(tree.inspect).to match(/^#<.*>$/)
    end
  end
end
