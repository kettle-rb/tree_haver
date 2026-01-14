# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Node do
  let(:source) { "x = 42" }
  let(:parser) { TreeHaver.parser_for(:toml) }
  let(:tree) { parser.parse(source) }
  let(:root_node) { tree.root_node }

  describe "#initialize" do
    it "wraps a backend node with source", :toml_parsing do
      node = described_class.new(root_node.inner_node, source: source)
      expect(node.inner_node).to eq(root_node.inner_node)
      expect(node.source).to eq(source)
    end

    it "wraps a backend node without source", :toml_parsing do
      node = described_class.new(root_node.inner_node)
      expect(node.inner_node).to eq(root_node.inner_node)
      expect(node.source).to be_nil
    end
  end

  describe "#type" do
    it "returns the node type as a string", :toml_parsing do
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
    it "returns byte offsets", :toml_parsing do
      expect(root_node.start_byte).to be_a(Integer)
      expect(root_node.end_byte).to be_a(Integer)
      expect(root_node.end_byte).to be > root_node.start_byte
    end
  end

  describe "#start_point and #end_point" do
    context "when backend supports start_point" do
      it "returns Point objects", :toml_parsing do
        expect(root_node.start_point).to be_a(TreeHaver::Point)
        expect(root_node.end_point).to be_a(TreeHaver::Point)
      end

      it "provides row and column", :toml_parsing do
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

  describe "#start_line" do
    it "returns 1-based line number", :toml_parsing do
      expect(root_node.start_line).to be_a(Integer)
      expect(root_node.start_line).to be >= 1
    end

    it "converts 0-based row to 1-based line", :toml_parsing do
      # If start_point.row is 0, start_line should be 1
      expect(root_node.start_line).to eq(root_node.start_point.row + 1)
    end

    context "with multiline source" do
      let(:source) { "x = 1\ny = 2\nz = 3" }

      it "returns correct line numbers for nodes on different lines", :toml_parsing do
        root_node.children.each do |child|
          # Each line should have a 1-based line number
          expect(child.start_line).to be >= 1
          expect(child.start_line).to be <= 3
        end
      end
    end
  end

  describe "#end_line" do
    it "returns 1-based line number", :toml_parsing do
      expect(root_node.end_line).to be_a(Integer)
      expect(root_node.end_line).to be >= 1
    end

    it "converts 0-based row to 1-based line", :toml_parsing do
      # If end_point.row is 0, end_line should be 1
      expect(root_node.end_line).to eq(root_node.end_point.row + 1)
    end

    it "end_line is greater than or equal to start_line", :toml_parsing do
      expect(root_node.end_line).to be >= root_node.start_line
    end

    context "with multiline node" do
      let(:source) { "[table]\nx = 1\ny = 2" }

      it "returns the line where the node ends", :toml_parsing do
        # Root node should span multiple lines
        if root_node.end_point.row > root_node.start_point.row
          expect(root_node.end_line).to be > root_node.start_line
        end
      end
    end
  end

  describe "#source_position" do
    it "returns a hash with position information", :toml_parsing do
      pos = root_node.source_position
      expect(pos).to be_a(Hash)
      expect(pos).to include(
        :start_line,
        :end_line,
        :start_column,
        :end_column,
      )
    end

    it "has 1-based line numbers", :toml_parsing do
      pos = root_node.source_position
      expect(pos[:start_line]).to be >= 1
      expect(pos[:end_line]).to be >= 1
      expect(pos[:end_line]).to be >= pos[:start_line]
    end

    it "has 0-based column numbers", :toml_parsing do
      pos = root_node.source_position
      expect(pos[:start_column]).to be >= 0
      expect(pos[:end_column]).to be >= 0
    end

    it "matches start_line and end_line methods", :toml_parsing do
      pos = root_node.source_position
      expect(pos[:start_line]).to eq(root_node.start_line)
      expect(pos[:end_line]).to eq(root_node.end_line)
    end

    it "matches start_point and end_point columns", :toml_parsing do
      pos = root_node.source_position
      expect(pos[:start_column]).to eq(root_node.start_point.column)
      expect(pos[:end_column]).to eq(root_node.end_point.column)
    end

    context "with complex multiline source" do
      let(:source) { "[section]\nkey = \"value\"\n# comment\nother = 123" }

      # Note: Only named (structural) children are checked because anonymous nodes
      # (like whitespace, punctuation) may have invalid position data in some backends
      it "provides correct positions for named children", :toml_parsing do
        root_node.named_children.each do |child|
          pos = child.source_position

          # All values should be valid integers
          expect(pos[:start_line]).to be_a(Integer)
          expect(pos[:end_line]).to be_a(Integer)
          expect(pos[:start_column]).to be_a(Integer)
          expect(pos[:end_column]).to be_a(Integer)

          # Lines should be 1-based
          expect(pos[:start_line]).to be >= 1
          expect(pos[:end_line]).to be >= pos[:start_line]

          # Columns should be 0-based and non-negative
          expect(pos[:start_column]).to be >= 0
          expect(pos[:end_column]).to be >= 0
        end
      end
    end
  end

  describe "#first_child" do
    it "returns the first child node", :toml_parsing do
      if root_node.child_count > 0
        expect(root_node.first_child).to be_a(described_class)
        # Use type and byte range comparison instead of eq since backends may return
        # different wrapper objects for the same underlying node
        first_child = root_node.first_child
        children_first = root_node.children.first
        child_zero = root_node.child(0)
        expect(first_child.type).to eq(children_first.type)
        expect(first_child.start_byte).to eq(children_first.start_byte)
        expect(first_child.type).to eq(child_zero.type)
        expect(first_child.start_byte).to eq(child_zero.start_byte)
      end
    end

    it "returns nil when node has no children", :toml_parsing do
      # Find a leaf node (no children)
      leaf_node = nil
      root_node.children.each do |child|
        if child.child_count == 0
          leaf_node = child
          break
        end
      end

      if leaf_node
        expect(leaf_node.first_child).to be_nil
      end
    end

    context "with multiple children" do
      let(:source) { "x = 1\ny = 2\nz = 3" }

      it "returns the first child consistently", :toml_parsing do
        if root_node.child_count > 1
          first = root_node.first_child
          expect(first).to be_a(described_class)

          # Should be the same as children[0]
          expect(first.start_byte).to eq(root_node.children[0].start_byte)
          expect(first.end_byte).to eq(root_node.children[0].end_byte)
        end
      end
    end
  end

  describe "#text" do
    it "returns the node's text content", :toml_parsing do
      expect(root_node.text).to be_a(String)
    end

    context "when backend supports text method" do
      it "uses the backend's text method", :toml_parsing do
        allow(root_node.inner_node).to receive(:text).and_return("test")
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

    context "when backend text method requires source argument (arity >= 1)" do
      let(:text_with_source_node) do
        node = Object.new
        node.define_singleton_method(:start_byte) { 0 }
        node.define_singleton_method(:end_byte) { 5 }
        node.define_singleton_method(:text) { |src| src[0...5] }
        node
      end

      it "passes source to text method" do
        node = described_class.new(text_with_source_node, source: "hello world")
        expect(node.text).to eq("hello")
      end

      it "raises error when arity requires source but source not provided" do
        node_needing_source = Object.new
        node_needing_source.define_singleton_method(:start_byte) { 0 }
        node_needing_source.define_singleton_method(:end_byte) { 5 }
        node_needing_source.define_singleton_method(:text) { |src| src[0...5] }

        node = described_class.new(node_needing_source, source: nil)
        expect {
          node.text
        }.to raise_error(TreeHaver::Error, /Cannot extract text/)
      end
    end

    context "when backend text method has optional arguments (arity == -1)" do
      let(:optional_args_node) do
        node = Object.new
        node.define_singleton_method(:start_byte) { 0 }
        node.define_singleton_method(:end_byte) { 5 }
        node.define_singleton_method(:text) { |*_args| "optional" }
        node
      end

      it "calls text with no arguments" do
        node = described_class.new(optional_args_node, source: "hello world")
        expect(node.text).to eq("optional")
      end
    end
  end

  describe "#has_error?" do
    it "returns a boolean", :toml_parsing do
      expect(root_node.has_error?).to be(true).or be(false)
    end
  end

  describe "#missing?" do
    it "returns false when node is not missing", :toml_parsing do
      expect(root_node.missing?).to be false
    end

    context "when backend doesn't support missing?" do
      let(:simple_node) do
        double(
          "node",
          missing?: false,
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
    it "returns a boolean", :toml_parsing do
      expect(root_node.named?).to be(true).or be(false)
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
    it "returns the number of children", :toml_parsing do
      expect(root_node.child_count).to be_a(Integer)
      expect(root_node.child_count).to be >= 0
    end
  end

  describe "#child" do
    it "returns a wrapped Node for valid index", :toml_parsing do
      if root_node.child_count > 0
        child = root_node.child(0)
        expect(child).to be_a(described_class)
      end
    end

    it "returns nil or raises for invalid index", :toml_parsing do
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

    it "passes source to child nodes", :toml_parsing do
      if root_node.child_count > 0
        child = root_node.child(0)
        expect(child).to respond_to(:source)
      end
    end

    context "when backend raises IndexError for out of bounds" do
      let(:indexing_node) do
        double(
          "IndexingNode",
          child_count: 1,
          type: "parent",
        )
      end

      it "rescues IndexError and returns nil" do
        allow(indexing_node).to receive(:child).with(99).and_raise(IndexError, "index out of bounds")

        node = described_class.new(indexing_node, source: source)
        expect(node.child(99)).to be_nil
      end
    end
  end

  describe "#children" do
    it "returns an array of wrapped Nodes", :toml_parsing do
      children = root_node.children
      expect(children).to be_an(Array)
      expect(children).to all(be_a(described_class))
    end

    it "passes source to all children", :toml_parsing do
      expect(root_node.children).to all(respond_to(:source))
    end
  end

  describe "#named_children" do
    it "returns only named children", :toml_parsing do
      named = root_node.named_children
      expect(named).to be_an(Array)
      named.each do |child|
        expect(child.named?).to be true
      end
    end
  end

  describe "#child_by_field_name" do
    context "when backend supports field names" do
      it "returns wrapped node for valid field", :toml_parsing do
        # This test will only run if the backend actually supports fields
        if root_node.inner_node.respond_to?(:child_by_field_name)
          result = root_node.child_by_field_name(:nonexistent_field)
          # Result will be nil for non-existent field, which is fine
          expect(result).to be_a(described_class).or be_nil
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
        expect(result).to be_a(described_class)
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

    it "has field as an alias", :toml_parsing do
      expect(root_node).to respond_to(:field)
      expect(root_node.method(:field)).to eq(root_node.method(:child_by_field_name))
    end
  end

  describe "#each" do
    it "iterates over children", :toml_parsing do
      count = 0
      root_node.each do |child|
        expect(child).to be_a(described_class)
        count += 1
      end
      expect(count).to eq(root_node.child_count)
    end

    it "returns an enumerator when no block given", :toml_parsing do
      enumerator = root_node.each
      expect(enumerator).to be_a(Enumerator)
    end
  end

  describe "#field" do
    it "is an alias for child_by_field_name", :toml_parsing do
      expect(root_node.method(:field)).to eq(root_node.method(:child_by_field_name))
    end
  end

  describe "#parent" do
    context "when backend supports parent" do
      it "returns wrapped parent or nil", :toml_parsing do
        if root_node.child_count > 0
          child = root_node.child(0)
          parent = child.parent
          expect(parent).to be_a(described_class).or be_nil
        end
      end

      it "returns wrapped parent node when parent exists", :toml_parsing do
        # Create a source that will have a child with a parent
        if root_node.child_count > 0
          child = root_node.child(0)
          parent = child.parent
          if parent
            expect(parent).to be_a(described_class)
            expect(parent.inner_node).not_to be_nil
          end
        end
      end

      it "wraps the parent with source", :toml_parsing do
        if root_node.child_count > 0
          child = root_node.child(0)
          parent = child.parent
          if parent
            expect(parent.source).to eq(source)
          end
        end
      end

      context "with mock backend that returns parent" do
        let(:parent_inner) { double("ParentInner", type: "parent", child_count: 0) }
        let(:child_inner) do
          double(
            "ChildInner",
            type: "child",
            child_count: 0,
          )
        end

        it "returns wrapped parent node" do
          allow(child_inner).to receive(:respond_to?).with(:parent).and_return(true)
          allow(child_inner).to receive(:parent).and_return(parent_inner)

          node = described_class.new(child_inner, source: source)
          parent = node.parent
          expect(parent).to be_a(described_class)
          expect(parent.inner_node).to eq(parent_inner)
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

    context "when parent returns nil" do
      let(:orphan_node) { double("OrphanNode", type: "orphan", child_count: 0) }

      it "returns nil" do
        allow(orphan_node).to receive(:respond_to?).with(:parent).and_return(true)
        allow(orphan_node).to receive(:parent).and_return(nil)

        node = described_class.new(orphan_node, source: source)
        expect(node.parent).to be_nil
      end
    end
  end

  describe "#next_sibling" do
    context "when backend supports next_sibling" do
      it "returns wrapped sibling or nil", :toml_parsing do
        if root_node.child_count > 0
          child = root_node.child(0)
          sibling = child.next_sibling
          expect(sibling).to be_a(described_class).or be_nil
        end
      end

      it "returns wrapped sibling when sibling exists", :toml_parsing do
        if root_node.child_count > 1
          child = root_node.child(0)
          sibling = child.next_sibling
          if sibling
            expect(sibling).to be_a(described_class)
            expect(sibling.inner_node).not_to be_nil
          end
        end
      end

      context "with mock backend that returns next_sibling" do
        let(:sibling_inner) { double("SiblingInner", type: "sibling", child_count: 0) }
        let(:node_inner) do
          double(
            "NodeInner",
            type: "node",
            child_count: 0,
          )
        end

        it "returns wrapped sibling node" do
          allow(node_inner).to receive(:respond_to?).with(:next_sibling).and_return(true)
          allow(node_inner).to receive(:next_sibling).and_return(sibling_inner)

          node = described_class.new(node_inner, source: source)
          sibling = node.next_sibling
          expect(sibling).to be_a(described_class)
          expect(sibling.inner_node).to eq(sibling_inner)
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

    context "when next_sibling returns nil (last sibling)" do
      let(:last_sibling_node) { double("LastSiblingNode", type: "last", child_count: 0) }

      it "returns nil" do
        allow(last_sibling_node).to receive(:respond_to?).with(:next_sibling).and_return(true)
        allow(last_sibling_node).to receive(:next_sibling).and_return(nil)

        node = described_class.new(last_sibling_node, source: source)
        expect(node.next_sibling).to be_nil
      end
    end
  end

  describe "#prev_sibling" do
    context "when backend supports prev_sibling" do
      it "returns wrapped sibling or nil", :toml_parsing do
        if root_node.child_count > 1
          child = root_node.child(1)
          sibling = child.prev_sibling
          expect(sibling).to be_a(described_class).or be_nil
        end
      end

      it "returns wrapped sibling when sibling exists", :toml_parsing do
        if root_node.child_count > 1
          child = root_node.child(1)
          sibling = child.prev_sibling
          if sibling
            expect(sibling).to be_a(described_class)
            expect(sibling.inner_node).not_to be_nil
          end
        end
      end

      context "with mock backend that returns prev_sibling" do
        let(:sibling_inner) { double("PrevSiblingInner", type: "prev_sibling", child_count: 0) }
        let(:node_inner) do
          double(
            "NodeInner",
            type: "node",
            child_count: 0,
          )
        end

        it "returns wrapped sibling node" do
          allow(node_inner).to receive(:respond_to?).with(:prev_sibling).and_return(true)
          allow(node_inner).to receive(:prev_sibling).and_return(sibling_inner)

          node = described_class.new(node_inner, source: source)
          sibling = node.prev_sibling
          expect(sibling).to be_a(described_class)
          expect(sibling.inner_node).to eq(sibling_inner)
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

    context "when prev_sibling returns nil (first sibling)" do
      let(:first_sibling_node) { double("FirstSiblingNode", type: "first", child_count: 0) }

      it "returns nil" do
        allow(first_sibling_node).to receive(:respond_to?).with(:prev_sibling).and_return(true)
        allow(first_sibling_node).to receive(:prev_sibling).and_return(nil)

        node = described_class.new(first_sibling_node, source: source)
        expect(node.prev_sibling).to be_nil
      end
    end
  end

  describe "#inspect" do
    it "returns a debug-friendly string", :toml_parsing do
      result = root_node.inspect
      expect(result).to include("TreeHaver::Node")
      expect(result).to include("type=")
      expect(result).to include("bytes=")
    end
  end

  describe "#to_s" do
    it "returns the node text", :toml_parsing do
      expect(root_node.to_s).to eq(root_node.text)
    end
  end

  describe "#respond_to_missing?" do
    it "returns true for methods on inner_node", :toml_parsing do
      method = root_node.inner_node.methods.first
      expect(root_node.respond_to?(method)).to be true
    end

    it "returns false for non-existent methods", :toml_parsing do
      expect(root_node.respond_to?(:totally_fake_method_xyz)).to be false
    end
  end

  describe "#method_missing" do
    it "delegates to inner_node if method exists", :toml_parsing do
      # Find a method that exists on inner_node but not on Node
      # Filter out methods that require arguments by checking arity
      backend_specific_method = root_node.inner_node.methods.find do |m|
        next false if described_class.method_defined?(m)
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
        }.not_to raise_error
      end
    end

    it "raises NoMethodError for non-existent methods", :toml_parsing do
      expect {
        root_node.totally_fake_method_xyz
      }.to raise_error(NoMethodError)
    end
  end

  describe "#==" do
    it "compares based on inner_node", :toml_parsing do
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
          allow(kind_only_node).to receive_messages(kind: "some_kind")
          allow(kind_only_node).to receive(:respond_to?).with(:type).and_return(false)
          allow(kind_only_node).to receive(:respond_to?).with(:kind, anything).and_return(true)

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

      let(:first_child) { double("Child1", type: "child1", child_count: 0) }
      let(:middle_child) { double("Child2", type: "child2", child_count: 0) }
      let(:last_child) { double("Child3", type: "child3", child_count: 0) }

      before do
        allow(parent_node).to receive(:child).with(0).and_return(first_child)
        allow(parent_node).to receive(:child).with(1).and_return(middle_child)
        allow(parent_node).to receive(:child).with(2).and_return(last_child)
      end

      it "handles child returning nil" do
        allow(parent_node).to receive(:child).with(1).and_return(nil)

        node = described_class.new(parent_node)
        children = node.children

        expect(children.length).to eq(2)  # nil child is filtered out
      end

      it "filters named_children correctly" do
        # Stub respond_to? to return true for all common methods
        [first_child, middle_child, last_child].each do |child|
          allow(child).to receive(:respond_to?).and_return(true)
        end

        allow(first_child).to receive(:named?).and_return(true)
        allow(middle_child).to receive(:named?).and_return(false)
        allow(last_child).to receive(:named?).and_return(true)

        node = described_class.new(parent_node)
        named = node.named_children

        expect(named.length).to eq(2)
        expect(named.map(&:type)).to eq(["child1", "child3"])
      end
    end
  end

  describe "#structural?" do
    context "when backend has its own structural? method" do
      let(:citrus_style_node) do
        double(
          "CitrusNode",
          type: "element",
          child_count: 0,
          structural?: true,
        )
      end

      it "delegates to inner_node structural?" do
        node = described_class.new(citrus_style_node)
        expect(node.structural?).to be true
      end
    end

    context "when backend lacks structural? method" do
      let(:tree_sitter_node) do
        double(
          "TreeSitterNode",
          type: "element",
          child_count: 0,
          named?: true,
        )
      end

      it "falls back to named?" do
        allow(tree_sitter_node).to receive(:respond_to?).and_return(false)
        allow(tree_sitter_node).to receive(:respond_to?).with(:structural?).and_return(false)
        allow(tree_sitter_node).to receive(:respond_to?).with(:named?).and_return(true)
        node = described_class.new(tree_sitter_node)
        expect(node.structural?).to be true
      end
    end
  end

  describe "#named_child with fallback" do
    context "when backend supports named_child natively" do
      let(:native_child) { double("NativeChild", type: "named_child", child_count: 0) }
      let(:native_node) do
        double(
          "NativeNode",
          type: "parent",
          child_count: 2,
        )
      end

      it "uses native named_child" do
        allow(native_node).to receive(:respond_to?).with(:named_child).and_return(true)
        allow(native_node).to receive(:named_child).with(0).and_return(native_child)

        node = described_class.new(native_node)
        result = node.named_child(0)
        expect(result).to be_a(described_class)
        expect(result.type).to eq("named_child")
      end

      it "returns nil when native named_child returns nil" do
        allow(native_node).to receive(:respond_to?).with(:named_child).and_return(true)
        allow(native_node).to receive(:named_child).with(99).and_return(nil)

        node = described_class.new(native_node)
        result = node.named_child(99)
        expect(result).to be_nil
      end
    end

    context "when backend lacks named_child" do
      let(:named_child) { double("Child1", type: "named", child_count: 0, named?: true) }
      let(:unnamed_child) { double("Child2", type: "unnamed", child_count: 0, named?: false) }
      let(:another_named_child) { double("Child3", type: "also_named", child_count: 0) }
      let(:fallback_node) do
        double(
          "FallbackNode",
          type: "parent",
          child_count: 3,
        )
      end

      before do
        allow(fallback_node).to receive(:respond_to?).with(:named_child).and_return(false)
        allow(fallback_node).to receive(:child).with(0).and_return(named_child)
        allow(fallback_node).to receive(:child).with(1).and_return(unnamed_child)
        allow(fallback_node).to receive(:child).with(2).and_return(another_named_child)

        # Allow respond_to? for type check (used in Node#type)
        [named_child, unnamed_child, another_named_child].each do |child|
          allow(child).to receive(:respond_to?).and_return(false)
          allow(child).to receive(:respond_to?).with(:type).and_return(true)
        end

        allow(named_child).to receive(:respond_to?).with(:named?).and_return(true)
        allow(unnamed_child).to receive(:respond_to?).with(:named?).and_return(true)
        allow(another_named_child).to receive(:respond_to?).with(:named?).and_return(false)
        allow(another_named_child).to receive(:respond_to?).with(:is_named?).and_return(false)
      end

      it "falls back to manual iteration" do
        node = described_class.new(fallback_node)
        result = node.named_child(0)
        expect(result.type).to eq("named")
      end

      it "skips unnamed children" do
        node = described_class.new(fallback_node)
        result = node.named_child(1)
        # Second named child is child3 (assumes named when no method available)
        expect(result.type).to eq("also_named")
      end

      it "returns nil when index out of bounds" do
        node = described_class.new(fallback_node)
        result = node.named_child(99)
        expect(result).to be_nil
      end

      context "with is_named? fallback" do
        let(:is_named_child) { double("IsNamedChild", type: "is_named_style", child_count: 0) }
        let(:is_named_node) do
          double(
            "IsNamedNode",
            type: "parent",
            child_count: 1,
          )
        end

        before do
          allow(is_named_node).to receive(:respond_to?).with(:named_child).and_return(false)
          allow(is_named_node).to receive(:child).with(0).and_return(is_named_child)

          # Child uses is_named? instead of named?
          allow(is_named_child).to receive_messages(
            respond_to?: false,
            is_named?: true,
          )
          allow(is_named_child).to receive(:respond_to?).with(:type).and_return(true)
          allow(is_named_child).to receive(:respond_to?).with(:named?).and_return(false)
          allow(is_named_child).to receive(:respond_to?).with(:is_named?).and_return(true)
        end

        it "uses is_named? when named? is not available" do
          node = described_class.new(is_named_node)
          result = node.named_child(0)
          expect(result).to be_a(described_class)
          expect(result.type).to eq("is_named_style")
        end

        it "returns nil when is_named? returns false" do
          allow(is_named_child).to receive(:is_named?).and_return(false)

          node = described_class.new(is_named_node)
          result = node.named_child(0)
          expect(result).to be_nil
        end
      end
    end
  end

  describe "#named_child_count with fallback" do
    context "when backend supports named_child_count natively" do
      let(:native_node) do
        double(
          "NativeNode",
          type: "parent",
          child_count: 5,
          named_child_count: 3,
        )
      end

      it "uses native named_child_count" do
        allow(native_node).to receive(:respond_to?).with(:named_child_count).and_return(true)
        node = described_class.new(native_node)
        expect(node.named_child_count).to eq(3)
      end
    end

    context "when backend lacks named_child_count" do
      let(:named_count_child) { double("Child1", type: "named", child_count: 0, named?: true) }
      let(:unnamed_count_child) { double("Child2", type: "unnamed", child_count: 0, named?: false) }
      let(:fallback_node) do
        double(
          "FallbackNode",
          type: "parent",
          child_count: 2,
        )
      end

      before do
        allow(fallback_node).to receive(:respond_to?).with(:named_child_count).and_return(false)
        allow(fallback_node).to receive(:child).with(0).and_return(named_count_child)
        allow(fallback_node).to receive(:child).with(1).and_return(unnamed_count_child)

        allow(named_count_child).to receive(:respond_to?).with(:named?).and_return(true)
        allow(unnamed_count_child).to receive(:respond_to?).with(:named?).and_return(true)
      end

      it "counts named children manually" do
        node = described_class.new(fallback_node)
        expect(node.named_child_count).to eq(1)
      end
    end
  end

  describe "#start_point and #end_point with Hash returns" do
    context "when backend returns Hash for points" do
      let(:hash_point_node) do
        double(
          "HashPointNode",
          type: "test",
          child_count: 0,
          start_byte: 0,
          end_byte: 10,
          start_point: {row: 0, column: 5},
          end_point: {row: 2, column: 10},
        )
      end

      it "converts start_point Hash to Point" do
        allow(hash_point_node).to receive(:respond_to?).with(:start_point).and_return(true)
        node = described_class.new(hash_point_node)
        point = node.start_point
        expect(point).to be_a(TreeHaver::Point)
        expect(point.row).to eq(0)
        expect(point.column).to eq(5)
      end

      it "converts end_point Hash to Point" do
        allow(hash_point_node).to receive(:respond_to?).with(:end_point).and_return(true)
        node = described_class.new(hash_point_node)
        point = node.end_point
        expect(point).to be_a(TreeHaver::Point)
        expect(point.row).to eq(2)
        expect(point.column).to eq(10)
      end
    end

    context "when backend uses start_position/end_position" do
      let(:position_node) do
        double(
          "PositionNode",
          type: "test",
          child_count: 0,
          start_byte: 0,
          end_byte: 10,
          start_position: {row: 1, column: 3},
          end_position: {row: 4, column: 7},
        )
      end

      it "falls back to start_position for start_point" do
        allow(position_node).to receive(:respond_to?).with(:start_point).and_return(false)
        allow(position_node).to receive(:respond_to?).with(:start_position).and_return(true)
        node = described_class.new(position_node)
        point = node.start_point
        expect(point).to be_a(TreeHaver::Point)
        expect(point.row).to eq(1)
        expect(point.column).to eq(3)
      end

      it "falls back to end_position for end_point" do
        allow(position_node).to receive(:respond_to?).with(:end_point).and_return(false)
        allow(position_node).to receive(:respond_to?).with(:end_position).and_return(true)
        node = described_class.new(position_node)
        point = node.end_point
        expect(point).to be_a(TreeHaver::Point)
        expect(point.row).to eq(4)
        expect(point.column).to eq(7)
      end
    end
  end

  describe "#prev_sibling when sibling is nil" do
    let(:node_with_nil_sibling) do
      double(
        "NodeWithNilSibling",
        type: "test",
        child_count: 0,
      )
    end

    it "returns nil when prev_sibling returns nil" do
      allow(node_with_nil_sibling).to receive(:respond_to?).with(:prev_sibling).and_return(true)
      allow(node_with_nil_sibling).to receive(:prev_sibling).and_return(nil)
      node = described_class.new(node_with_nil_sibling)
      expect(node.prev_sibling).to be_nil
    end
  end

  describe "#named_child fallback with is_named? method" do
    context "when child uses is_named? instead of named?" do
      let(:named_child) { double("NamedChild", type: "named", child_count: 0) }
      let(:parent_node) do
        double("ParentNode", type: "parent", child_count: 1)
      end

      before do
        allow(parent_node).to receive(:respond_to?).with(:named_child).and_return(false)
        allow(parent_node).to receive(:child).with(0).and_return(named_child)

        # Child uses is_named? instead of named?
        allow(named_child).to receive_messages(respond_to?: true, is_named?: true)
        allow(named_child).to receive(:respond_to?).with(:named?).and_return(false)
        allow(named_child).to receive(:respond_to?).with(:is_named?).and_return(true)
      end

      it "uses is_named? fallback in named_child iteration" do
        node = described_class.new(parent_node, source: source)
        result = node.named_child(0)
        expect(result.type).to eq("named")
      end
    end

    context "when child has neither named? nor is_named?" do
      let(:unknown_child) { double("UnknownChild", type: "unknown", child_count: 0) }
      let(:parent_node) do
        double("ParentNode", type: "parent", child_count: 1)
      end

      before do
        allow(parent_node).to receive(:respond_to?).with(:named_child).and_return(false)
        allow(parent_node).to receive(:child).with(0).and_return(unknown_child)

        # Child has neither method - stub defaults first
        allow(unknown_child).to receive(:respond_to?).and_return(true) # default
        allow(unknown_child).to receive(:respond_to?).with(:named?).and_return(false)
        allow(unknown_child).to receive(:respond_to?).with(:is_named?).and_return(false)
      end

      it "assumes child is named (default true)" do
        node = described_class.new(parent_node, source: source)
        result = node.named_child(0)
        expect(result.type).to eq("unknown")
      end
    end
  end

  describe "#named_child_count fallback with is_named? method" do
    context "when children use is_named? instead of named?" do
      let(:named_child) { double("NamedChild", type: "named", child_count: 0) }
      let(:unnamed_child) { double("UnnamedChild", type: "unnamed", child_count: 0) }
      let(:parent_node) do
        double("ParentNode", type: "parent", child_count: 2)
      end

      before do
        allow(parent_node).to receive(:respond_to?).with(:named_child_count).and_return(false)
        allow(parent_node).to receive(:child).with(0).and_return(named_child)
        allow(parent_node).to receive(:child).with(1).and_return(unnamed_child)

        # Children use is_named?
        allow(named_child).to receive(:respond_to?).with(:named?).and_return(false)
        allow(named_child).to receive(:respond_to?).with(:is_named?).and_return(true)
        allow(named_child).to receive(:is_named?).and_return(true)

        allow(unnamed_child).to receive(:respond_to?).with(:named?).and_return(false)
        allow(unnamed_child).to receive(:respond_to?).with(:is_named?).and_return(true)
        allow(unnamed_child).to receive(:is_named?).and_return(false)
      end

      it "uses is_named? fallback in count" do
        node = described_class.new(parent_node, source: source)
        expect(node.named_child_count).to eq(1)
      end
    end

    context "when children have neither named? nor is_named?" do
      let(:first_unknown_child) { double("Unknown1", type: "u1", child_count: 0) }
      let(:second_unknown_child) { double("Unknown2", type: "u2", child_count: 0) }
      let(:parent_node) do
        double("ParentNode", type: "parent", child_count: 2)
      end

      before do
        allow(parent_node).to receive(:respond_to?).with(:named_child_count).and_return(false)
        allow(parent_node).to receive(:child).with(0).and_return(first_unknown_child)
        allow(parent_node).to receive(:child).with(1).and_return(second_unknown_child)

        [first_unknown_child, second_unknown_child].each do |child|
          allow(child).to receive(:respond_to?).with(:named?).and_return(false)
          allow(child).to receive(:respond_to?).with(:is_named?).and_return(false)
        end
      end

      it "counts all children as named (default true)" do
        node = described_class.new(parent_node, source: source)
        expect(node.named_child_count).to eq(2)
      end
    end

    context "when child returns nil during iteration" do
      let(:valid_child) { double("ValidChild", type: "valid", child_count: 0) }
      let(:parent_node) do
        double("ParentNode", type: "parent", child_count: 2)
      end

      before do
        allow(parent_node).to receive(:respond_to?).with(:named_child_count).and_return(false)
        allow(parent_node).to receive(:child).with(0).and_return(valid_child)
        allow(parent_node).to receive(:child).with(1).and_return(nil)

        allow(valid_child).to receive(:respond_to?).with(:named?).and_return(true)
        allow(valid_child).to receive(:named?).and_return(true)
      end

      it "skips nil children" do
        node = described_class.new(parent_node, source: source)
        expect(node.named_child_count).to eq(1)
      end
    end
  end

  describe "#<=> comparison operator edge cases" do
    let(:mock_node1) do
      double("Node1", type: "a", start_byte: 0, end_byte: 10, child_count: 0)
    end

    context "when comparing with non-Node object" do
      it "returns nil for string" do
        node = described_class.new(mock_node1, source: source)
        expect(node <=> "not a node").to be_nil
      end

      it "returns nil for integer" do
        node = described_class.new(mock_node1, source: source)
        expect(node <=> 42).to be_nil
      end

      it "returns nil for nil" do
        node = described_class.new(mock_node1, source: source)
        expect(node <=> nil).to be_nil
      end
    end

    context "when start_bytes differ" do
      let(:mock_node2) do
        double("Node2", type: "b", start_byte: 5, end_byte: 15, child_count: 0)
      end

      it "compares by start_byte first" do
        node1 = described_class.new(mock_node1, source: source)
        node2 = described_class.new(mock_node2, source: source)

        expect(node1 <=> node2).to eq(-1)
        expect(node2 <=> node1).to eq(1)
      end
    end

    context "when start_bytes are equal but end_bytes differ" do
      let(:mock_shorter) do
        double("Shorter", type: "short", start_byte: 0, end_byte: 5, child_count: 0)
      end
      let(:mock_longer) do
        double("Longer", type: "long", start_byte: 0, end_byte: 10, child_count: 0)
      end

      it "compares by end_byte second" do
        shorter = described_class.new(mock_shorter, source: source)
        longer = described_class.new(mock_longer, source: source)

        expect(shorter <=> longer).to eq(-1)
        expect(longer <=> shorter).to eq(1)
      end
    end

    context "when start_byte and end_byte are equal" do
      let(:mock_type_a) do
        double("TypeA", type: "aaa", start_byte: 0, end_byte: 10, child_count: 0)
      end
      let(:mock_type_z) do
        double("TypeZ", type: "zzz", start_byte: 0, end_byte: 10, child_count: 0)
      end

      it "compares by type for deterministic ordering" do
        node_a = described_class.new(mock_type_a, source: source)
        node_z = described_class.new(mock_type_z, source: source)

        expect(node_a <=> node_z).to eq(-1)
        expect(node_z <=> node_a).to eq(1)
      end

      it "returns 0 for nodes with same position and type" do
        mock_same = double("Same", type: "same", start_byte: 5, end_byte: 10, child_count: 0)
        mock_identical = double("Identical", type: "same", start_byte: 5, end_byte: 10, child_count: 0)

        node1 = described_class.new(mock_same, source: source)
        node2 = described_class.new(mock_identical, source: source)

        expect(node1 <=> node2).to eq(0)
      end
    end
  end

  describe "#== equality edge cases" do
    let(:mock_node) do
      double("Node", type: "test", start_byte: 0, end_byte: 10, child_count: 0)
    end

    it "returns false when compared with string" do
      node = described_class.new(mock_node, source: source)
      expect(node == "string").to be false
    end

    it "returns false when compared with integer" do
      node = described_class.new(mock_node, source: source)
      expect(node == 42).to be false
    end

    it "returns false when compared with nil" do
      node = described_class.new(mock_node, source: source)
      expect(node == nil).to be false # rubocop:disable Style/NilComparison
    end
  end

  describe "#hash delegation" do
    let(:mock_node) do
      double("Node", type: "test", start_byte: 0, end_byte: 10, child_count: 0, hash: 12345)
    end

    it "delegates to inner_node hash" do
      node = described_class.new(mock_node, source: source)
      expect(node.hash).to eq(12345)
    end
  end
end
