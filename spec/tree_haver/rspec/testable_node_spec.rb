# frozen_string_literal: true

require "tree_haver"
require "tree_haver/rspec/testable_node"

RSpec.describe TreeHaver::RSpec::TestableNode do
  describe ".create" do
    it "creates a node with the given type" do
      node = described_class.create(type: :heading, text: "# Hello")
      expect(node.type).to eq("heading")
    end

    it "creates a node with the given text" do
      node = described_class.create(type: :paragraph, text: "Hello world")
      expect(node.text).to eq("Hello world")
    end

    it "creates a node with correct start_line (1-based)" do
      node = described_class.create(type: :paragraph, text: "Text", start_line: 5)
      expect(node.start_line).to eq(5)
    end

    it "creates a node with correct end_line" do
      node = described_class.create(type: :paragraph, text: "Line 1\nLine 2", start_line: 3)
      expect(node.end_line).to eq(4)
    end

    it "creates a node with explicit end_line" do
      node = described_class.create(type: :code_block, text: "code", start_line: 1, end_line: 10)
      expect(node.end_line).to eq(10)
    end

    it "creates a node with correct start_byte" do
      node = described_class.create(type: :paragraph, text: "Text", start_byte: 100)
      expect(node.start_byte).to eq(100)
    end

    it "calculates end_byte from text length" do
      node = described_class.create(type: :paragraph, text: "Hello", start_byte: 0)
      expect(node.end_byte).to eq(5)
    end

    it "creates a node with source_position" do
      node = described_class.create(type: :paragraph, text: "Text", start_line: 3, start_column: 5)
      pos = node.source_position
      expect(pos[:start_line]).to eq(3)
      expect(pos[:start_column]).to eq(5)
    end

    it "creates nodes with children" do
      node = described_class.create(
        type: :document,
        text: "# Title\n\nPara",
        children: [
          {type: :heading, text: "# Title", start_row: 0},
          {type: :paragraph, text: "Para", start_row: 2},
        ],
      )
      expect(node.inner_node.child_count).to eq(2)
    end

    it "accepts symbol type" do
      node = described_class.create(type: :heading, text: "Test")
      expect(node.type).to eq("heading")
    end

    it "accepts string type" do
      node = described_class.create(type: "paragraph", text: "Test")
      expect(node.type).to eq("paragraph")
    end
  end

  describe ".create_list" do
    it "creates multiple nodes from specifications" do
      nodes = described_class.create_list(
        {type: :heading, text: "# One"},
        {type: :paragraph, text: "Two"},
      )
      expect(nodes.length).to eq(2)
      expect(nodes[0].type).to eq("heading")
      expect(nodes[1].type).to eq("paragraph")
    end

    it "flattens nested arrays" do
      specs = [{type: :heading, text: "One"}, {type: :paragraph, text: "Two"}]
      nodes = described_class.create_list(specs)
      expect(nodes.length).to eq(2)
    end
  end

  describe "#testable?" do
    it "returns true" do
      node = described_class.create(type: :paragraph, text: "Test")
      expect(node.testable?).to be true
    end
  end

  # ============================================================
  # Node API Compliance Tests
  # ============================================================
  # These use the shared example groups from tree_haver to ensure
  # TestableNode provides the full TreeHaver::Node API.

  describe "Node API compliance" do
    let(:node) { described_class.create(type: :paragraph, text: "Hello world", start_line: 1) }

    it_behaves_like "node api compliance"
  end

  describe "Node position API compliance" do
    let(:node) { described_class.create(type: :heading, text: "# Title", start_line: 5, start_column: 2) }

    it_behaves_like "node position api"
  end

  describe "Node children API compliance" do
    let(:node_with_children) do
      described_class.create(
        type: :document,
        text: "# Title\n\nParagraph content",
        start_line: 1,
        children: [
          {type: :heading, text: "# Title", start_row: 0, start_column: 0},
          {type: :paragraph, text: "Paragraph content", start_row: 2, start_column: 0},
        ],
      )
    end

    it_behaves_like "node children api"
  end

  describe "Node enumerable behavior compliance" do
    let(:node_with_children) do
      described_class.create(
        type: :list,
        text: "- item 1\n- item 2\n- item 3",
        start_line: 1,
        children: [
          {type: :list_item, text: "- item 1", start_row: 0},
          {type: :list_item, text: "- item 2", start_row: 1},
          {type: :list_item, text: "- item 3", start_row: 2},
        ],
      )
    end

    it_behaves_like "node enumerable behavior"
  end

  # ============================================================
  # TreeHaver::Node compatibility verification
  # ============================================================

  describe "TreeHaver::Node inheritance" do
    let(:node) { described_class.create(type: :heading, text: "## Section", start_line: 5, start_column: 2) }

    it "is a TreeHaver::Node" do
      expect(node).to be_a(TreeHaver::Node)
    end

    it "responds to type" do
      expect(node).to respond_to(:type)
    end

    it "responds to text" do
      expect(node).to respond_to(:text)
    end

    it "responds to start_line" do
      expect(node).to respond_to(:start_line)
    end

    it "responds to end_line" do
      expect(node).to respond_to(:end_line)
    end

    it "responds to start_byte" do
      expect(node).to respond_to(:start_byte)
    end

    it "responds to end_byte" do
      expect(node).to respond_to(:end_byte)
    end

    it "responds to source_position" do
      expect(node).to respond_to(:source_position)
    end

    it "responds to inner_node" do
      expect(node).to respond_to(:inner_node)
    end
  end

  describe TreeHaver::RSpec::MockInnerNode do
    describe "#initialize" do
      it "stores the type" do
        node = described_class.new(type: :paragraph)
        expect(node.type).to eq("paragraph")
      end

      it "stores text content" do
        node = described_class.new(type: :paragraph, text: "Hello")
        expect(node.text).to eq("Hello")
        expect(node.string_content).to eq("Hello")
      end

      it "calculates end_byte from text" do
        node = described_class.new(type: :paragraph, text: "Hello", start_byte: 10)
        expect(node.end_byte).to eq(15)
      end
    end

    describe "#start_point" do
      it "returns a Point" do
        node = described_class.new(type: :paragraph, start_row: 5, start_column: 10)
        point = node.start_point
        expect(point.row).to eq(5)
        expect(point.column).to eq(10)
      end
    end

    describe "#end_point" do
      it "returns a Point" do
        node = described_class.new(type: :paragraph, end_row: 8, end_column: 15)
        point = node.end_point
        expect(point.row).to eq(8)
        expect(point.column).to eq(15)
      end
    end

    describe "#named?" do
      it "returns true" do
        node = described_class.new(type: :paragraph)
        expect(node.named?).to be true
      end
    end

    describe "#child_count" do
      it "returns the number of children" do
        node = described_class.new(type: :document, children: [{}, {}, {}])
        expect(node.child_count).to eq(3)
      end
    end
  end

  describe "Top-level TestableNode constant" do
    it "is available" do
      expect(defined?(TestableNode)).to be_truthy
    end

    it "references TreeHaver::RSpec::TestableNode" do
      expect(TestableNode).to eq(described_class)
    end
  end
end
