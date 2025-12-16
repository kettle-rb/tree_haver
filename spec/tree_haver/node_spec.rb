# frozen_string_literal: true

RSpec.describe TreeHaver::Node, :toml_grammar do
  let(:source) { "x = 42" }
  let(:parser) do
    p = TreeHaver::Parser.new
    path = TreeHaverDependencies.find_toml_grammar_path
    language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
    p.language = language
    p
  end
  let(:tree) { parser.parse(source) }
  let(:root_node) { tree.root_node }

  describe "#initialize" do
    it "wraps a backend node with source" do
      node = described_class.new(root_node.inner_node, source: source)
      expect(node.inner_node).to eq(root_node.inner_node)
      expect(node.source).to eq(source)
    end

    it "wraps a backend node without source" do
      node = described_class.new(root_node.inner_node)
      expect(node.inner_node).to eq(root_node.inner_node)
      expect(node.source).to be_nil
    end
  end

  describe "#type" do
    it "returns the node type as a string" do
      expect(root_node.type).to be_a(String)
    end

    context "when backend node has neither type nor kind" do
      let(:bad_node) { double("node") }

      it "raises an error" do
        node = described_class.new(bad_node, source: source)
        expect {
          node.type
        }.to raise_error(TreeHaver::Error, /does not support type\/kind/)
      end
    end
  end

  describe "#start_byte and #end_byte" do
    it "returns byte offsets" do
      expect(root_node.start_byte).to be_a(Integer)
      expect(root_node.end_byte).to be_a(Integer)
      expect(root_node.end_byte).to be > root_node.start_byte
    end
  end

  describe "#start_point and #end_point" do
    context "when backend supports start_point" do
      it "returns Point objects" do
        expect(root_node.start_point).to be_a(TreeHaver::Point)
        expect(root_node.end_point).to be_a(TreeHaver::Point)
      end

      it "provides row and column" do
        point = root_node.start_point
        expect(point.row).to be_a(Integer)
        expect(point.column).to be_a(Integer)
      end
    end

    context "when backend node lacks start_point" do
      let(:bad_node) { double("node") }

      it "raises an error for start_point" do
        node = described_class.new(bad_node, source: source)
        expect {
          node.start_point
        }.to raise_error(TreeHaver::Error, /does not support start_point/)
      end

      it "raises an error for end_point" do
        node = described_class.new(bad_node, source: source)
        expect {
          node.end_point
        }.to raise_error(TreeHaver::Error, /does not support end_point/)
      end
    end
  end

  describe "#text" do
    it "returns the node's text content" do
      expect(root_node.text).to be_a(String)
    end

    context "when backend supports text method" do
      it "uses the backend's text method" do
        expect(root_node.inner_node).to receive(:text).and_return("test")
        expect(root_node.text).to eq("test")
      end
    end

    context "when backend lacks text but source is provided" do
      let(:mock_node) do
        double(
          "node",
          start_byte: 0,
          end_byte: 6,
        )
      end

      it "extracts text from source using byte offsets" do
        node = described_class.new(mock_node, source: source)
        expect(node.text).to eq("x = 42")
      end
    end

    context "when backend lacks text and no source" do
      let(:bad_node) { double("node") }

      it "raises an error" do
        node = described_class.new(bad_node)
        expect {
          node.text
        }.to raise_error(TreeHaver::Error, /Cannot extract text/)
      end
    end
  end

  describe "#has_error?" do
    it "returns a boolean" do
      expect([true, false]).to include(root_node.has_error?)
    end
  end

  describe "#missing?" do
    it "returns false when node is not missing" do
      expect(root_node.missing?).to be false
    end

    context "when backend doesn't support missing?" do
      let(:simple_node) do
        double(
          "node",
          has_error?: false,
          child_count: 0,
          type: "test",
        )
      end

      it "returns false by default" do
        node = described_class.new(simple_node, source: source)
        expect(node.missing?).to be false
      end
    end
  end

  describe "#named?" do
    it "returns a boolean" do
      expect([true, false]).to include(root_node.named?)
    end

    context "when backend uses is_named?" do
      let(:treestump_node) do
        double(
          "node",
          is_named?: true,
          child_count: 0,
          type: "test",
        )
      end

      it "maps is_named? to named?" do
        node = described_class.new(treestump_node, source: source)
        expect(node.named?).to be true
      end
    end

    context "when backend supports neither named? nor is_named?" do
      let(:simple_node) do
        double(
          "node",
          child_count: 0,
          type: "test",
        )
      end

      it "defaults to true" do
        node = described_class.new(simple_node, source: source)
        expect(node.named?).to be true
      end
    end
  end

  describe "#child_count" do
    it "returns the number of children" do
      expect(root_node.child_count).to be_a(Integer)
      expect(root_node.child_count).to be >= 0
    end
  end

  describe "#child" do
    it "returns a wrapped Node for valid index" do
      if root_node.child_count > 0
        child = root_node.child(0)
        expect(child).to be_a(TreeHaver::Node)
      end
    end

    it "returns nil for invalid index" do
      expect(root_node.child(9999)).to be_nil
    end

    it "passes source to child nodes" do
      if root_node.child_count > 0
        child = root_node.child(0)
        expect(child).to respond_to(:source)
      end
    end
  end

  describe "#children" do
    it "returns an array of wrapped Nodes" do
      children = root_node.children
      expect(children).to be_an(Array)
      expect(children).to all(be_a(TreeHaver::Node))
    end

    it "passes source to all children" do
      expect(root_node.children).to all(respond_to(:source))
    end
  end

  describe "#named_children" do
    it "returns only named children" do
      named = root_node.named_children
      expect(named).to be_an(Array)
      named.each do |child|
        expect(child.named?).to be true
      end
    end
  end

  describe "#each" do
    it "iterates over children" do
      count = 0
      root_node.each do |child|
        expect(child).to be_a(TreeHaver::Node)
        count += 1
      end
      expect(count).to eq(root_node.child_count)
    end

    it "returns an enumerator when no block given" do
      enumerator = root_node.each
      expect(enumerator).to be_a(Enumerator)
    end
  end

  describe "#child_by_field_name" do
    context "when backend supports field names" do
      it "returns nil for non-existent field" do
        expect(root_node.child_by_field_name(:nonexistent)).to be_nil
      end

      it "wraps the result in a Node" do
        # Find a node that has fields
        node_with_fields = root_node.children.find do |child|
          child.child_by_field_name(:key) || child.child_by_field_name(:value)
        end

        if node_with_fields
          field_node = node_with_fields.child_by_field_name(:key) || node_with_fields.child_by_field_name(:value)
          expect(field_node).to be_a(TreeHaver::Node) if field_node
        end
      end
    end

    context "when backend doesn't support field names" do
      let(:simple_node) do
        double(
          "node",
          child_count: 0,
          type: "test",
        )
      end

      it "returns nil" do
        node = described_class.new(simple_node, source: source)
        expect(node.child_by_field_name(:key)).to be_nil
      end
    end
  end

  describe "#field" do
    it "is an alias for child_by_field_name" do
      expect(root_node.method(:field)).to eq(root_node.method(:child_by_field_name))
    end
  end

  describe "#parent" do
    context "when backend supports parent" do
      it "returns wrapped parent or nil" do
        if root_node.child_count > 0
          child = root_node.child(0)
          parent = child.parent
          expect(parent).to be_a(TreeHaver::Node).or be_nil
        end
      end
    end

    context "when backend doesn't support parent" do
      let(:simple_node) do
        double(
          "node",
          child_count: 0,
          type: "test",
        )
      end

      it "returns nil" do
        node = described_class.new(simple_node, source: source)
        expect(node.parent).to be_nil
      end
    end
  end

  describe "#next_sibling" do
    context "when backend supports next_sibling" do
      it "returns wrapped sibling or nil" do
        if root_node.child_count > 0
          child = root_node.child(0)
          sibling = child.next_sibling
          expect(sibling).to be_a(TreeHaver::Node).or be_nil
        end
      end
    end

    context "when backend doesn't support next_sibling" do
      let(:simple_node) do
        double(
          "node",
          child_count: 0,
          type: "test",
        )
      end

      it "returns nil" do
        node = described_class.new(simple_node, source: source)
        expect(node.next_sibling).to be_nil
      end
    end
  end

  describe "#prev_sibling" do
    context "when backend supports prev_sibling" do
      it "returns wrapped sibling or nil" do
        if root_node.child_count > 1
          child = root_node.child(1)
          sibling = child.prev_sibling
          expect(sibling).to be_a(TreeHaver::Node).or be_nil
        end
      end
    end

    context "when backend doesn't support prev_sibling" do
      let(:simple_node) do
        double(
          "node",
          child_count: 0,
          type: "test",
        )
      end

      it "returns nil" do
        node = described_class.new(simple_node, source: source)
        expect(node.prev_sibling).to be_nil
      end
    end
  end

  describe "#inspect" do
    it "returns a debug-friendly string" do
      result = root_node.inspect
      expect(result).to include("TreeHaver::Node")
      expect(result).to include("type=")
      expect(result).to include("bytes=")
    end
  end

  describe "#to_s" do
    it "returns the node text" do
      expect(root_node.to_s).to eq(root_node.text)
    end
  end

  describe "#respond_to_missing?" do
    it "returns true for methods on inner_node" do
      method = root_node.inner_node.methods.first
      expect(root_node.respond_to?(method)).to be true
    end

    it "returns false for non-existent methods" do
      expect(root_node.respond_to?(:totally_fake_method_xyz)).to be false
    end
  end

  describe "#method_missing" do
    it "delegates to inner_node if method exists" do
      # Find a method that exists on inner_node but not on Node
      backend_specific_method = root_node.inner_node.methods.find do |m|
        !described_class.instance_methods.include?(m)
      end

      if backend_specific_method
        expect {
          root_node.public_send(backend_specific_method)
        }.not_to raise_error
      end
    end

    it "raises NoMethodError for non-existent methods" do
      expect {
        root_node.totally_fake_method_xyz
      }.to raise_error(NoMethodError)
    end
  end

  describe "#field_name_for_child" do
    context "when backend doesn't support field_name_for_child" do
      let(:mock_node) { double("node") }
      let(:node) { described_class.new(mock_node, source: source) }

      it "returns nil" do
        allow(mock_node).to receive(:respond_to?).with(:field_name_for_child).and_return(false)
        expect(node.field_name_for_child(0)).to be_nil
      end
    end
  end

  describe "#child_by_field_name" do
    context "when backend doesn't support child_by_field_name" do
      let(:mock_node) { double("node") }
      let(:node) { described_class.new(mock_node, source: source) }

      it "returns nil" do
        allow(mock_node).to receive(:respond_to?).with(:child_by_field_name).and_return(false)
        expect(node.child_by_field_name("name")).to be_nil
      end
    end
  end

  describe "#child_by_field_id" do
    context "when backend doesn't support child_by_field_id" do
      let(:mock_node) { double("node") }
      let(:node) { described_class.new(mock_node, source: source) }

      it "returns nil" do
        allow(mock_node).to receive(:respond_to?).with(:child_by_field_id).and_return(false)
        expect(node.child_by_field_id(1)).to be_nil
      end
    end
  end

  describe "#==" do
    it "compares based on inner_node" do
      node1 = described_class.new(root_node.inner_node, source: source)
      node2 = described_class.new(root_node.inner_node, source: source)
      different_node = root_node.child(0) if root_node.child_count > 0

      expect(node1).to eq(node2)
      expect(node1).not_to eq(different_node) if different_node
    end
  end

  describe "edge cases and error paths" do
    context "when backend node doesn't support required methods" do
      let(:minimal_node) do
        double("MinimalNode",
          child_count: 0,
          type: "minimal",
          start_byte: 0,
          end_byte: 10)
      end

      let(:node) { described_class.new(minimal_node) }

      describe "#type" do
        it "uses kind when type not available" do
          allow(minimal_node).to receive(:respond_to?).with(:type).and_return(false)
          allow(minimal_node).to receive(:respond_to?).with(:kind).and_return(true)
          allow(minimal_node).to receive(:kind).and_return(:test_kind)

          expect(node.type).to eq("test_kind")
        end
      end

      describe "#start_point" do
        it "raises error when node has neither start_point nor start_position" do
          allow(minimal_node).to receive(:respond_to?).with(:start_point).and_return(false)
          allow(minimal_node).to receive(:respond_to?).with(:start_position).and_return(false)

          expect { node.start_point }.to raise_error(TreeHaver::Error, /does not support start_point\/start_position/)
        end

        it "uses start_position as fallback" do
          allow(minimal_node).to receive(:respond_to?).with(:start_point).and_return(false)
          allow(minimal_node).to receive(:respond_to?).with(:start_position).and_return(true)
          position = double("Position", row: 10, column: 5)
          allow(minimal_node).to receive(:start_position).and_return(position)

          point = node.start_point
          expect(point.row).to eq(10)
          expect(point.column).to eq(5)
        end
      end

      describe "#end_point" do
        it "raises error when node has neither end_point nor end_position" do
          allow(minimal_node).to receive(:respond_to?).with(:end_point).and_return(false)
          allow(minimal_node).to receive(:respond_to?).with(:end_position).and_return(false)

          expect { node.end_point }.to raise_error(TreeHaver::Error, /does not support end_point\/end_position/)
        end

        it "uses end_position as fallback" do
          allow(minimal_node).to receive(:respond_to?).with(:end_point).and_return(false)
          allow(minimal_node).to receive(:respond_to?).with(:end_position).and_return(true)
          position = double("Position", row: 20, column: 15)
          allow(minimal_node).to receive(:end_position).and_return(position)

          point = node.end_point
          expect(point.row).to eq(20)
          expect(point.column).to eq(15)
        end
      end

      describe "#text" do
        it "raises error when node has no text method and no source" do
          allow(minimal_node).to receive(:respond_to?).with(:text).and_return(false)

          expect { node.text }.to raise_error(TreeHaver::Error, /Cannot extract text/)
        end

        it "extracts from source when node doesn't have text method" do
          allow(minimal_node).to receive(:respond_to?).with(:text).and_return(false)
          allow(minimal_node).to receive(:start_byte).and_return(0)
          allow(minimal_node).to receive(:end_byte).and_return(5)

          node_with_source = described_class.new(minimal_node, source: "hello world")
          expect(node_with_source.text).to eq("hello")
        end

        it "returns empty string when byte range is out of bounds" do
          allow(minimal_node).to receive(:respond_to?).with(:text).and_return(false)
          allow(minimal_node).to receive(:start_byte).and_return(100)
          allow(minimal_node).to receive(:end_byte).and_return(200)

          node_with_source = described_class.new(minimal_node, source: "short")
          expect(node_with_source.text).to eq("")
        end
      end

      describe "#missing?" do
        it "returns false when backend doesn't support missing?" do
          allow(minimal_node).to receive(:respond_to?).with(:missing?).and_return(false)

          expect(node.missing?).to be false
        end

        it "delegates when backend supports missing?" do
          allow(minimal_node).to receive(:respond_to?).with(:missing?).and_return(true)
          allow(minimal_node).to receive(:missing?).and_return(true)

          expect(node.missing?).to be true
        end
      end

      describe "#named?" do
        it "returns true by default when backend doesn't support named?" do
          allow(minimal_node).to receive(:respond_to?).with(:named?).and_return(false)
          allow(minimal_node).to receive(:respond_to?).with(:is_named?).and_return(false)

          expect(node.named?).to be true
        end

        it "uses is_named? as fallback" do
          allow(minimal_node).to receive(:respond_to?).with(:named?).and_return(false)
          allow(minimal_node).to receive(:respond_to?).with(:is_named?).and_return(true)
          allow(minimal_node).to receive(:is_named?).and_return(false)

          expect(node.named?).to be false
        end
      end
    end

    context "with child iteration" do
      let(:parent_node) do
        double("ParentNode",
          child_count: 3,
          type: "parent")
      end

      let(:child1) { double("Child1", type: "child1", child_count: 0) }
      let(:child2) { double("Child2", type: "child2", child_count: 0) }
      let(:child3) { double("Child3", type: "child3", child_count: 0) }

      before do
        allow(parent_node).to receive(:child).with(0).and_return(child1)
        allow(parent_node).to receive(:child).with(1).and_return(child2)
        allow(parent_node).to receive(:child).with(2).and_return(child3)
      end

      it "handles child returning nil" do
        allow(parent_node).to receive(:child).with(1).and_return(nil)

        node = described_class.new(parent_node)
        children = node.children

        expect(children.length).to eq(2)  # nil child is filtered out
      end

      it "filters named_children correctly" do
        allow(child1).to receive(:respond_to?).with(:named?).and_return(true)
        allow(child1).to receive(:named?).and_return(true)
        allow(child2).to receive(:respond_to?).with(:named?).and_return(true)
        allow(child2).to receive(:named?).and_return(false)
        allow(child3).to receive(:respond_to?).with(:named?).and_return(true)
        allow(child3).to receive(:named?).and_return(true)

        node = described_class.new(parent_node)
        named = node.named_children

        expect(named.length).to eq(2)
        expect(named.map(&:type)).to eq(["child1", "child3"])
      end
    end
  end
end
