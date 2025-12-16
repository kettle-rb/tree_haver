# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Node do
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
    it "wraps a backend node with source", :toml_grammar do
      node = described_class.new(root_node.inner_node, source: source)
      expect(node.inner_node).to eq(root_node.inner_node)
      expect(node.source).to eq(source)
    end

    it "wraps a backend node without source", :toml_grammar do
      node = described_class.new(root_node.inner_node)
      expect(node.inner_node).to eq(root_node.inner_node)
      expect(node.source).to be_nil
    end
  end

  describe "#type" do
    it "returns the node type as a string", :toml_grammar do
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
    it "returns byte offsets", :toml_grammar do
      expect(root_node.start_byte).to be_a(Integer)
      expect(root_node.end_byte).to be_a(Integer)
      expect(root_node.end_byte).to be > root_node.start_byte
    end
  end

  describe "#start_point and #end_point" do
    context "when backend supports start_point" do
      it "returns Point objects", :toml_grammar do
        expect(root_node.start_point).to be_a(TreeHaver::Point)
        expect(root_node.end_point).to be_a(TreeHaver::Point)
      end

      it "provides row and column", :toml_grammar do
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
    it "returns the node's text content", :toml_grammar do
      expect(root_node.text).to be_a(String)
    end

    context "when backend supports text method" do
      it "uses the backend's text method", :toml_grammar do
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
    it "returns a boolean", :toml_grammar do
      expect([true, false]).to include(root_node.has_error?)
    end
  end

  describe "#missing?" do
    it "returns false when node is not missing", :toml_grammar do
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
    it "returns a boolean", :toml_grammar do
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
    it "returns the number of children", :toml_grammar do
      expect(root_node.child_count).to be_a(Integer)
      expect(root_node.child_count).to be >= 0
    end
  end

  describe "#child" do
    it "returns a wrapped Node for valid index", :toml_grammar do
      if root_node.child_count > 0
        child = root_node.child(0)
        expect(child).to be_a(TreeHaver::Node)
      end
    end

    it "returns nil or raises for invalid index", :toml_grammar do
      # Different backends handle invalid indices differently:
      # - Some return nil
      # - Some raise IndexError

      result = root_node.child(9999)
      expect(result).to be_nil
    rescue IndexError
      # This is also acceptable behavior
    end

    it "returns nil when backend child returns nil" do
      mock_node = double(
        "MockNode",
        child_count: 1,
        type: "parent",
      )
      allow(mock_node).to receive(:child).with(0).and_return(nil)

      node = described_class.new(mock_node, source: source)
      expect(node.child(0)).to be_nil
    end

    it "passes source to child nodes", :toml_grammar do
      if root_node.child_count > 0
        child = root_node.child(0)
        expect(child).to respond_to(:source)
      end
    end
  end

  describe "#children" do
    it "returns an array of wrapped Nodes", :toml_grammar do
      children = root_node.children
      expect(children).to be_an(Array)
      expect(children).to all(be_a(TreeHaver::Node))
    end

    it "passes source to all children", :toml_grammar do
      expect(root_node.children).to all(respond_to(:source))
    end
  end

  describe "#named_children" do
    it "returns only named children", :toml_grammar do
      named = root_node.named_children
      expect(named).to be_an(Array)
      named.each do |child|
        expect(child.named?).to be true
      end
    end
  end

  describe "#child_by_field_name" do
    context "when backend supports field names" do
      it "returns wrapped node for valid field", :toml_grammar do
        # This test will only run if the backend actually supports fields
        if root_node.inner_node.respond_to?(:child_by_field_name)
          result = root_node.child_by_field_name(:nonexistent_field)
          # Result will be nil for non-existent field, which is fine
          expect(result).to be_a(TreeHaver::Node).or be_nil
        end
      end

      it "wraps returned child node" do
        child_node = double("ChildNode", type: "value", child_count: 0)
        field_node = double("FieldNode", child_count: 0, type: "parent")
        # Stub respond_to? to return true for common methods and child_by_field_name
        allow(field_node).to receive(:respond_to?) do |method, *|
          [:child_by_field_name, :type, :child_count].include?(method)
        end
        allow(field_node).to receive(:child_by_field_name).with("key").and_return(child_node)

        node = described_class.new(field_node, source: source)
        result = node.child_by_field_name(:key)
        expect(result).to be_a(TreeHaver::Node)
        expect(result.inner_node).to eq(child_node)
      end

      it "returns nil when field child is nil" do
        field_node = double("FieldNode", child_count: 0, type: "parent")
        # Stub respond_to? to return true for common methods and child_by_field_name
        allow(field_node).to receive(:respond_to?) do |method, *|
          [:child_by_field_name, :type, :child_count].include?(method)
        end
        allow(field_node).to receive(:child_by_field_name).with("missing").and_return(nil)

        node = described_class.new(field_node, source: source)
        expect(node.child_by_field_name(:missing)).to be_nil
      end
    end

    context "when backend doesn't support field names" do
      it "returns nil" do
        simple_node = double("SimpleNode", child_count: 0, type: "test")
        # Stub respond_to? with default true, then override specific case
        allow(simple_node).to receive(:respond_to?).and_return(true)
        allow(simple_node).to receive(:respond_to?).with(:child_by_field_name).and_return(false)

        node = described_class.new(simple_node, source: source)
        expect(node.child_by_field_name(:any_field)).to be_nil
      end
    end

    it "has field as an alias" do
      expect(root_node).to respond_to(:field)
      expect(root_node.method(:field)).to eq(root_node.method(:child_by_field_name))
    end
  end

  describe "#each" do
    it "iterates over children", :toml_grammar do
      count = 0
      root_node.each do |child|
        expect(child).to be_a(TreeHaver::Node)
        count += 1
      end
      expect(count).to eq(root_node.child_count)
    end

    it "returns an enumerator when no block given", :toml_grammar do
      enumerator = root_node.each
      expect(enumerator).to be_a(Enumerator)
    end
  end

  describe "#field" do
    it "is an alias for child_by_field_name", :toml_grammar do
      expect(root_node.method(:field)).to eq(root_node.method(:child_by_field_name))
    end
  end

  describe "#parent" do
    context "when backend supports parent" do
      it "returns wrapped parent or nil", :toml_grammar do
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
      it "returns wrapped sibling or nil", :toml_grammar do
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
      it "returns wrapped sibling or nil", :toml_grammar do
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
    it "returns a debug-friendly string", :toml_grammar do
      result = root_node.inspect
      expect(result).to include("TreeHaver::Node")
      expect(result).to include("type=")
      expect(result).to include("bytes=")
    end
  end

  describe "#to_s" do
    it "returns the node text", :toml_grammar do
      expect(root_node.to_s).to eq(root_node.text)
    end
  end

  describe "#respond_to_missing?" do
    it "returns true for methods on inner_node", :toml_grammar do
      method = root_node.inner_node.methods.first
      expect(root_node.respond_to?(method)).to be true
    end

    it "returns false for non-existent methods" do
      expect(root_node.respond_to?(:totally_fake_method_xyz)).to be false
    end
  end

  describe "#method_missing" do
    it "delegates to inner_node if method exists", :toml_grammar do
      # Find a method that exists on inner_node but not on Node
      # Filter out methods that require arguments by checking arity
      backend_specific_method = root_node.inner_node.methods.find do |m|
        next false if described_class.instance_methods.include?(m)
        begin
          method_obj = root_node.inner_node.method(m)
          # Only use methods with zero required arguments
          method_obj.arity == 0 || method_obj.arity == -1
        rescue NameError
          false
        end
      end

      if backend_specific_method
        # Method exists and takes no required arguments - should not raise NoMethodError
        expect {
          begin
            root_node.public_send(backend_specific_method)
          rescue ArgumentError
            # Some methods may still fail due to other reasons, but not NoMethodError
          end
        }.not_to raise_error(NoMethodError)
      end
    end

    it "raises NoMethodError for non-existent methods" do
      expect {
        root_node.totally_fake_method_xyz
      }.to raise_error(NoMethodError)
    end
  end

  describe "#==" do
    it "compares based on inner_node", :toml_grammar do
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
        double(
          "MinimalNode",
          child_count: 0,
          type: "minimal",
          start_byte: 0,
          end_byte: 10,
        )
      end

      let(:node) { described_class.new(minimal_node) }

      describe "#type" do
        it "uses kind when type not available" do
          kind_only_node = double(
            "KindOnlyNode",
            child_count: 0,
            start_byte: 0,
            end_byte: 10,
          )
          # Stub respond_to? with default true, then override specific cases
          allow(kind_only_node).to receive(:respond_to?).and_return(true)
          allow(kind_only_node).to receive(:respond_to?).with(:type).and_return(false)
          allow(kind_only_node).to receive(:respond_to?).with(:kind).and_return(true)
          allow(kind_only_node).to receive(:kind).and_return("some_kind")

          node_with_kind = described_class.new(kind_only_node)
          expect(node_with_kind.type).to eq("some_kind")
        end

        it "raises error when neither type nor kind available" do
          no_type_node = double(
            "NoTypeNode",
            child_count: 0,
            start_byte: 0,
            end_byte: 10,
          )
          # Stub respond_to? with default true, then override specific cases
          allow(no_type_node).to receive(:respond_to?).and_return(true)
          allow(no_type_node).to receive(:respond_to?).with(:type).and_return(false)
          allow(no_type_node).to receive(:respond_to?).with(:kind).and_return(false)

          node_no_type = described_class.new(no_type_node)
          expect { node_no_type.type }.to raise_error(TreeHaver::Error, /does not support type\/kind/)
        end
      end

      describe "#start_point" do
        it "uses start_position as fallback" do
          position_only_node = double(
            "PositionOnlyNode",
            child_count: 0,
            type: "test",
            start_byte: 0,
            end_byte: 10,
          )
          allow(position_only_node).to receive(:respond_to?) do |method, *|
            case method
            when :start_point then false
            when :start_position then true
            else true
            end
          end
          position = double("Position", row: 10, column: 5)
          allow(position_only_node).to receive(:start_position).and_return(position)

          node_with_position = described_class.new(position_only_node)
          point = node_with_position.start_point
          expect(point.row).to eq(10)
          expect(point.column).to eq(5)
        end

        it "raises error when node has neither start_point nor start_position" do
          no_point_node = double(
            "NoPointNode",
            child_count: 0,
            type: "test",
            start_byte: 0,
            end_byte: 10,
          )
          allow(no_point_node).to receive(:respond_to?) do |method, *|
            case method
            when :start_point, :start_position then false
            else true
            end
          end

          node_no_point = described_class.new(no_point_node)
          expect { node_no_point.start_point }.to raise_error(TreeHaver::Error, /does not support start_point\/start_position/)
        end
      end

      describe "#end_point" do
        it "uses end_position as fallback" do
          position_only_node = double(
            "PositionOnlyNode",
            child_count: 0,
            type: "test",
            start_byte: 0,
            end_byte: 10,
          )
          allow(position_only_node).to receive(:respond_to?) do |method, *|
            case method
            when :end_point then false
            when :end_position then true
            else true
            end
          end
          position = double("Position", row: 20, column: 15)
          allow(position_only_node).to receive(:end_position).and_return(position)

          node_with_position = described_class.new(position_only_node)
          point = node_with_position.end_point
          expect(point.row).to eq(20)
          expect(point.column).to eq(15)
        end

        it "raises error when node has neither end_point nor end_position" do
          no_point_node = double(
            "NoPointNode",
            child_count: 0,
            type: "test",
            start_byte: 0,
            end_byte: 10,
          )
          allow(no_point_node).to receive(:respond_to?) do |method, *|
            case method
            when :end_point, :end_position then false
            else true
            end
          end

          node_no_point = described_class.new(no_point_node)
          expect { node_no_point.end_point }.to raise_error(TreeHaver::Error, /does not support end_point\/end_position/)
        end
      end

      describe "#text" do
        it "extracts from source when node doesn't have text method" do
          no_text_node = double(
            "NoTextNode",
            child_count: 0,
            type: "test",
            start_byte: 0,
            end_byte: 5,
          )
          allow(no_text_node).to receive(:respond_to?) do |method, *|
            method != :text
          end

          node_with_source = described_class.new(no_text_node, source: "hello world")
          expect(node_with_source.text).to eq("hello")
        end

        it "raises error when node has no text method and no source" do
          no_text_node = double(
            "NoTextNode",
            child_count: 0,
            type: "test",
            start_byte: 0,
            end_byte: 5,
          )
          allow(no_text_node).to receive(:respond_to?) do |method, *|
            method != :text
          end

          node_no_source = described_class.new(no_text_node)
          expect { node_no_source.text }.to raise_error(TreeHaver::Error, /Cannot extract text/)
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
        it "uses is_named? as fallback" do
          is_named_node = double(
            "IsNamedNode",
            child_count: 0,
            type: "test",
          )
          allow(is_named_node).to receive(:respond_to?) do |method, *|
            case method
            when :named? then false
            when :is_named? then true
            else true
            end
          end
          allow(is_named_node).to receive(:is_named?).and_return(false)

          node_with_is_named = described_class.new(is_named_node)
          expect(node_with_is_named.named?).to be false
        end

        it "returns true by default when backend doesn't support named?" do
          no_named_node = double(
            "NoNamedNode",
            child_count: 0,
            type: "test",
          )
          allow(no_named_node).to receive(:respond_to?) do |method, *|
            case method
            when :named?, :is_named? then false
            else true
            end
          end

          node_no_named = described_class.new(no_named_node)
          expect(node_no_named.named?).to be true
        end
      end
    end

    context "with child iteration" do
      let(:parent_node) do
        double(
          "ParentNode",
          child_count: 3,
          type: "parent",
        )
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
        # Stub respond_to? to return true for all common methods
        [child1, child2, child3].each do |child|
          allow(child).to receive(:respond_to?).and_return(true)
        end

        allow(child1).to receive(:named?).and_return(true)
        allow(child2).to receive(:named?).and_return(false)
        allow(child3).to receive(:named?).and_return(true)

        node = described_class.new(parent_node)
        named = node.named_children

        expect(named.length).to eq(2)
        expect(named.map(&:type)).to eq(["child1", "child3"])
      end
    end
  end
end
