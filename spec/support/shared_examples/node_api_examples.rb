# frozen_string_literal: true

# Shared examples for Node API compliance
#
# These examples test the standard Node interface that all backends must implement.
# They ensure consistent behavior across MRI, FFI, Rust, Java, Citrus, Parslet,
# Prism, Psych, and other backends.
#
# @example Usage in backend specs
#   RSpec.describe TreeHaver::Backends::Citrus::Node do
#     # Provide a way to create nodes for testing
#     let(:create_node) { ->(source) { parse_and_get_root(source) } }
#     let(:simple_source) { 'key = "value"' }
#     let(:multiline_source) { "[section]\nkey = \"value\"\nother = 123" }
#
#     it_behaves_like "node api compliance"
#     it_behaves_like "node position api"
#     it_behaves_like "node children api"
#     it_behaves_like "node enumerable behavior"
#   end

# Core Node API that all implementations must provide
RSpec.shared_examples "node api compliance" do
  # Expects `node` to be defined as the node under test

  describe "required interface" do
    it "responds to #type" do
      expect(node).to respond_to(:type)
    end

    it "#type returns a String" do
      expect(node.type).to be_a(String)
    end

    it "#type returns a non-empty string" do
      expect(node.type).not_to be_empty
    end

    it "responds to #start_byte" do
      expect(node).to respond_to(:start_byte)
    end

    it "#start_byte returns an Integer" do
      expect(node.start_byte).to be_a(Integer)
    end

    it "#start_byte is non-negative" do
      expect(node.start_byte).to be >= 0
    end

    it "responds to #end_byte" do
      expect(node).to respond_to(:end_byte)
    end

    it "#end_byte returns an Integer" do
      expect(node.end_byte).to be_a(Integer)
    end

    it "#end_byte is greater than or equal to start_byte" do
      expect(node.end_byte).to be >= node.start_byte
    end

    it "responds to #children" do
      expect(node).to respond_to(:children)
    end

    it "#children returns an Array" do
      expect(node.children).to be_an(Array)
    end

    it "responds to #child_count" do
      expect(node).to respond_to(:child_count)
    end

    it "#child_count returns an Integer" do
      expect(node.child_count).to be_a(Integer)
    end

    it "#child_count matches children.size" do
      expect(node.child_count).to eq(node.children.size)
    end
  end

  describe "optional interface with defaults" do
    it "responds to #text" do
      expect(node).to respond_to(:text)
    end

    it "#text returns a String" do
      expect(node.text).to be_a(String)
    end

    it "responds to #named? (or #structural?)" do
      expect(node).to respond_to(:named?).or respond_to(:structural?)
    end

    it "responds to #has_error?" do
      expect(node).to respond_to(:has_error?)
    end

    it "#has_error? returns a boolean" do
      expect(node.has_error?).to be(true).or be(false)
    end

    it "responds to #missing?" do
      expect(node).to respond_to(:missing?)
    end

    it "#missing? returns a boolean" do
      expect(node.missing?).to be(true).or be(false)
    end
  end
end

# Node position API for row/column information
RSpec.shared_examples "node position api" do
  # Expects `node` to be defined as the node under test

  describe "#start_point" do
    it "responds to #start_point" do
      expect(node).to respond_to(:start_point)
    end

    it "returns an object with row information" do
      point = node.start_point
      row = point.is_a?(Hash) ? point[:row] : point.row
      expect(row).to be_a(Integer)
      expect(row).to be >= 0
    end

    it "returns an object with column information" do
      point = node.start_point
      col = point.is_a?(Hash) ? point[:column] : point.column
      expect(col).to be_a(Integer)
      expect(col).to be >= 0
    end
  end

  describe "#end_point" do
    it "responds to #end_point" do
      expect(node).to respond_to(:end_point)
    end

    it "returns an object with row information" do
      point = node.end_point
      row = point.is_a?(Hash) ? point[:row] : point.row
      expect(row).to be_a(Integer)
      expect(row).to be >= 0
    end

    it "returns an object with column information" do
      point = node.end_point
      col = point.is_a?(Hash) ? point[:column] : point.column
      expect(col).to be_a(Integer)
      expect(col).to be >= 0
    end
  end

  describe "#start_line" do
    it "responds to #start_line" do
      expect(node).to respond_to(:start_line)
    end

    it "returns a 1-based line number" do
      expect(node.start_line).to be_a(Integer)
      expect(node.start_line).to be >= 1
    end
  end

  describe "#end_line" do
    it "responds to #end_line" do
      expect(node).to respond_to(:end_line)
    end

    it "returns a 1-based line number" do
      expect(node.end_line).to be_a(Integer)
      expect(node.end_line).to be >= 1
    end

    it "is greater than or equal to start_line" do
      expect(node.end_line).to be >= node.start_line
    end
  end

  describe "#source_position" do
    it "responds to #source_position" do
      expect(node).to respond_to(:source_position)
    end

    it "returns a Hash" do
      expect(node.source_position).to be_a(Hash)
    end

    it "includes :start_line (1-based)" do
      pos = node.source_position
      expect(pos).to have_key(:start_line)
      expect(pos[:start_line]).to be >= 1
    end

    it "includes :end_line (1-based)" do
      pos = node.source_position
      expect(pos).to have_key(:end_line)
      expect(pos[:end_line]).to be >= pos[:start_line]
    end

    it "includes :start_column (0-based)" do
      pos = node.source_position
      expect(pos).to have_key(:start_column)
      expect(pos[:start_column]).to be >= 0
    end

    it "includes :end_column (0-based)" do
      pos = node.source_position
      expect(pos).to have_key(:end_column)
      expect(pos[:end_column]).to be >= 0
    end
  end
end

# Node children API for tree traversal
RSpec.shared_examples "node children api" do
  # Expects `node_with_children` to be defined with at least one child

  describe "#child" do
    it "returns nil for negative index" do
      expect(node_with_children.child(-1)).to be_nil
    end

    it "returns nil for out-of-bounds index" do
      out_of_bounds = node_with_children.child_count + 10
      expect(node_with_children.child(out_of_bounds)).to be_nil
    end

    it "returns a node for valid index" do
      skip "Node has no children" if node_with_children.child_count == 0
      child = node_with_children.child(0)
      expect(child).not_to be_nil
      expect(child).to respond_to(:type)
    end
  end

  describe "#first_child" do
    it "responds to #first_child" do
      expect(node_with_children).to respond_to(:first_child)
    end

    it "returns the first child or nil" do
      first = node_with_children.first_child
      if node_with_children.child_count > 0
        expect(first).not_to be_nil
        expect(first).to respond_to(:type)
      else
        expect(first).to be_nil
      end
    end
  end

  describe "#last_child" do
    it "responds to #last_child" do
      expect(node_with_children).to respond_to(:last_child)
    end

    it "returns the last child or nil" do
      last = node_with_children.last_child
      if node_with_children.child_count > 0
        expect(last).not_to be_nil
        expect(last).to respond_to(:type)
      else
        expect(last).to be_nil
      end
    end
  end
end

# Node Enumerable behavior
RSpec.shared_examples "node enumerable behavior" do
  # Expects `node_with_children` to be defined

  describe "#each" do
    it "responds to #each" do
      expect(node_with_children).to respond_to(:each)
    end

    it "returns an Enumerator when no block given" do
      expect(node_with_children.each).to be_an(Enumerator)
    end

    it "yields each child when block given" do
      yielded = []
      node_with_children.each { |c| yielded << c }
      expect(yielded.size).to eq(node_with_children.child_count)
    end

    it "all yielded items respond to node API" do
      children = node_with_children.to_a
      expect(children).to all(respond_to(:type))
      expect(children).to all(respond_to(:start_byte))
      expect(children).to all(respond_to(:end_byte))
    end
  end

  describe "Enumerable methods" do
    it "supports #map" do
      types = node_with_children.map(&:type)
      expect(types).to be_an(Array)
      expect(types.size).to eq(node_with_children.child_count)
    end

    it "supports #select" do
      # Select all children (trivial filter)
      selected = node_with_children.select { |_| true }
      expect(selected.size).to eq(node_with_children.child_count)
    end

    it "supports #find" do
      if node_with_children.child_count > 0
        found = node_with_children.find { |_| true }
        expect(found).not_to be_nil
      end
    end
  end
end

# Node comparison and equality
RSpec.shared_examples "node comparison behavior" do
  # Expects `node` and `same_node` (equal to node) and `different_node` to be defined

  describe "#==" do
    it "returns true for equivalent nodes" do
      expect(node == same_node).to be true
    end

    it "returns false for different nodes" do
      expect(node == different_node).to be false
    end

    it "returns false for non-node objects" do
      expect(node == "not a node").to be false
    end
  end

  describe "#<=>" do
    it "returns 0 for equivalent nodes" do
      expect(node <=> same_node).to eq(0)
    end

    it "returns non-zero for different nodes" do
      result = node <=> different_node
      expect(result).not_to eq(0) if result
    end

    it "returns nil for non-comparable objects" do
      expect(node <=> "not a node").to be_nil
    end
  end

  describe "#hash" do
    it "returns the same hash for equivalent nodes" do
      expect(node.hash).to eq(same_node.hash)
    end
  end
end

# Node text extraction
RSpec.shared_examples "node text extraction" do
  # Expects `node` and `source` to be defined

  describe "#text" do
    it "returns a substring of the source" do
      text = node.text
      expect(source).to include(text) unless text.empty?
    end

    it "matches the byte range" do
      text = node.text
      expected = source[node.start_byte...node.end_byte]
      expect(text).to eq(expected) if expected
    end
  end

  describe "#to_s" do
    it "returns the text content" do
      expect(node.to_s).to eq(node.text)
    end
  end
end

# Node inspection and debugging
RSpec.shared_examples "node inspection" do
  # Expects `node` to be defined

  describe "#inspect" do
    it "returns a String" do
      expect(node.inspect).to be_a(String)
    end

    it "includes the class name" do
      expect(node.inspect).to include(node.class.name.to_s.split("::").last)
    end

    it "includes the node type" do
      expect(node.inspect).to include(node.type)
    end
  end
end

