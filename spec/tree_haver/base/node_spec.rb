# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Base::Node do
  # Create a concrete test subclass that implements required methods
  let(:concrete_node_class) do
    Class.new(described_class) do
      attr_accessor :mock_type, :mock_start_byte, :mock_end_byte, :mock_children

      def initialize(inner = nil, **options)
        @mock_type = options.delete(:type) || "test_type"
        @mock_start_byte = options.delete(:start_byte) || 0
        @mock_end_byte = options.delete(:end_byte) || 10
        @mock_children = options.delete(:children) || []
        super(inner, **options)
      end

      def type
        @mock_type
      end

      def start_byte
        @mock_start_byte
      end

      def end_byte
        @mock_end_byte
      end

      def children
        @mock_children
      end
    end
  end

  let(:node) { concrete_node_class.new(nil, source: "test source") }

  describe "#initialize" do
    it "accepts source parameter" do
      n = concrete_node_class.new(nil, source: "hello world")
      expect(n.source).to eq("hello world")
    end

    it "accepts lines parameter" do
      n = concrete_node_class.new(nil, lines: %w[line1 line2])
      expect(n.lines).to eq(%w[line1 line2])
    end
  end

  describe "#type" do
    it "raises NotImplementedError in base class" do
      base_node = described_class.new(nil)
      expect { base_node.type }.to raise_error(NotImplementedError)
    end

    it "returns the type in concrete class" do
      expect(node.type).to eq("test_type")
    end
  end

  describe "#start_byte" do
    it "raises NotImplementedError in base class" do
      base_node = described_class.new(nil)
      expect { base_node.start_byte }.to raise_error(NotImplementedError)
    end
  end

  describe "#end_byte" do
    it "raises NotImplementedError in base class" do
      base_node = described_class.new(nil)
      expect { base_node.end_byte }.to raise_error(NotImplementedError)
    end
  end

  describe "#children" do
    it "raises NotImplementedError in base class" do
      base_node = described_class.new(nil)
      expect { base_node.children }.to raise_error(NotImplementedError)
    end
  end

  describe "#child_count" do
    it "returns the number of children" do
      child1 = concrete_node_class.new(nil)
      child2 = concrete_node_class.new(nil)
      n = concrete_node_class.new(nil, children: [child1, child2])
      expect(n.child_count).to eq(2)
    end

    it "returns 0 for no children" do
      expect(node.child_count).to eq(0)
    end
  end

  describe "#child" do
    it "returns child at index" do
      child1 = concrete_node_class.new(nil, type: "child1")
      child2 = concrete_node_class.new(nil, type: "child2")
      n = concrete_node_class.new(nil, children: [child1, child2])

      expect(n.child(0)).to eq(child1)
      expect(n.child(1)).to eq(child2)
    end

    it "returns nil for out of bounds index" do
      expect(node.child(99)).to be_nil
    end
  end

  describe "#each" do
    it "yields each child" do
      child1 = concrete_node_class.new(nil, type: "child1")
      child2 = concrete_node_class.new(nil, type: "child2")
      n = concrete_node_class.new(nil, children: [child1, child2])

      yielded = []
      n.each { |c| yielded << c }

      expect(yielded).to eq([child1, child2])
    end

    it "returns enumerator when no block given" do
      child1 = concrete_node_class.new(nil)
      n = concrete_node_class.new(nil, children: [child1])

      expect(n.each).to be_an(Enumerator)
      expect(n.each.to_a).to eq([child1])
    end
  end

  describe "#first_child" do
    it "returns the first child" do
      child1 = concrete_node_class.new(nil, type: "first")
      child2 = concrete_node_class.new(nil, type: "second")
      n = concrete_node_class.new(nil, children: [child1, child2])

      expect(n.first_child).to eq(child1)
    end

    it "returns nil when no children" do
      expect(node.first_child).to be_nil
    end
  end

  describe "#last_child" do
    it "returns the last child" do
      child1 = concrete_node_class.new(nil, type: "first")
      child2 = concrete_node_class.new(nil, type: "last")
      n = concrete_node_class.new(nil, children: [child1, child2])

      expect(n.last_child).to eq(child2)
    end

    it "returns nil when no children" do
      expect(node.last_child).to be_nil
    end
  end

  describe "#parent" do
    it "returns nil by default" do
      expect(node.parent).to be_nil
    end
  end

  describe "#next_sibling" do
    it "returns nil by default" do
      expect(node.next_sibling).to be_nil
    end
  end

  describe "#prev_sibling" do
    it "returns nil by default" do
      expect(node.prev_sibling).to be_nil
    end
  end

  describe "#named?" do
    it "returns true by default" do
      expect(node.named?).to be true
    end
  end

  describe "#structural?" do
    it "is an alias for named?" do
      expect(node.structural?).to eq(node.named?)
    end
  end

  describe "#has_error?" do
    it "returns false by default" do
      expect(node.has_error?).to be false
    end
  end

  describe "#missing?" do
    it "returns false by default" do
      expect(node.missing?).to be false
    end
  end

  describe "#text" do
    it "returns substring of source" do
      n = concrete_node_class.new(nil, source: "hello world", start_byte: 0, end_byte: 5)
      expect(n.text).to eq("hello")
    end

    it "returns empty string when no source" do
      n = concrete_node_class.new(nil, source: nil)
      expect(n.text).to eq("")
    end
  end

  describe "#child_by_field_name" do
    it "returns nil by default" do
      expect(node.child_by_field_name("name")).to be_nil
    end
  end

  describe "#start_point" do
    it "returns hash with row and column" do
      expect(node.start_point).to eq({row: 0, column: 0})
    end
  end

  describe "#end_point" do
    it "returns hash with row and column" do
      expect(node.end_point).to eq({row: 0, column: 0})
    end
  end

  describe "#<=>" do
    it "compares by byte range" do
      node1 = concrete_node_class.new(nil, start_byte: 0, end_byte: 5)
      node2 = concrete_node_class.new(nil, start_byte: 5, end_byte: 10)

      expect(node1 <=> node2).to eq(-1)
      expect(node2 <=> node1).to eq(1)
    end

    it "returns 0 for equal ranges" do
      node1 = concrete_node_class.new(nil, start_byte: 0, end_byte: 5)
      node2 = concrete_node_class.new(nil, start_byte: 0, end_byte: 5)

      expect(node1 <=> node2).to eq(0)
    end

    it "returns nil for incompatible types" do
      expect(node <=> "not a node").to be_nil
    end
  end

  describe "#==" do
    it "returns true for same byte range and type" do
      node1 = concrete_node_class.new(nil, type: "test", start_byte: 0, end_byte: 5)
      node2 = concrete_node_class.new(nil, type: "test", start_byte: 0, end_byte: 5)

      expect(node1 == node2).to be true
    end

    it "returns false for different type" do
      node1 = concrete_node_class.new(nil, type: "type1", start_byte: 0, end_byte: 5)
      node2 = concrete_node_class.new(nil, type: "type2", start_byte: 0, end_byte: 5)

      expect(node1 == node2).to be false
    end

    it "returns false for different byte range" do
      node1 = concrete_node_class.new(nil, type: "test", start_byte: 0, end_byte: 5)
      node2 = concrete_node_class.new(nil, type: "test", start_byte: 0, end_byte: 10)

      expect(node1 == node2).to be false
    end

    it "returns false when other object lacks required methods" do
      expect(node == "not a node").to be false
      expect(node == 123).to be false
      expect(node.nil?).to be false
    end

    it "returns false when other lacks type method" do
      other = Object.new
      def other.start_byte = 0
      def other.end_byte = 10
      # No type method

      expect(node == other).to be false
    end

    it "returns false when other lacks start_byte method" do
      other = Object.new
      def other.type = "test"
      def other.end_byte = 10
      # No start_byte method

      expect(node == other).to be false
    end
  end

  describe "#inspect" do
    it "returns a readable string" do
      expect(node.inspect).to be_a(String)
      expect(node.inspect).to include("type=")
    end

    it "handles anonymous classes" do
      # The concrete_node_class is anonymous, so inspect should handle it gracefully
      expect(node.inspect).to match(/type=test_type/)
    end

    it "handles NotImplementedError from type method" do
      # The base class raises NotImplementedError for type
      base_node = described_class.new(nil)
      expect(base_node.inspect).to include("(not implemented)")
    end
  end

  describe "#to_s" do
    it "returns the text content" do
      n = concrete_node_class.new(nil, source: "hello", start_byte: 0, end_byte: 5)
      expect(n.to_s).to eq("hello")
    end
  end

  describe "#start_line" do
    it "returns 1-based line number from start_point row" do
      # Default start_point returns {row: 0, column: 0}, so start_line should be 1
      expect(node.start_line).to eq(1)
    end

    context "when start_point returns an object with row method" do
      let(:point_object_node_class) do
        Class.new(described_class) do
          def type
            "test"
          end

          def start_byte
            0
          end

          def end_byte
            10
          end

          def children
            []
          end

          def start_point
            # Return object with .row method instead of Hash
            Struct.new(:row, :column).new(5, 10)
          end

          def end_point
            Struct.new(:row, :column).new(8, 15)
          end
        end
      end

      it "extracts row from point object" do
        n = point_object_node_class.new(nil)
        expect(n.start_line).to eq(6) # 5 + 1
      end
    end
  end

  describe "#end_line" do
    it "returns 1-based line number from end_point row" do
      # Default end_point returns {row: 0, column: 0}, so end_line should be 1
      expect(node.end_line).to eq(1)
    end

    context "when end_point returns an object with row method" do
      let(:point_object_node_class) do
        Class.new(described_class) do
          def type
            "test"
          end

          def start_byte
            0
          end

          def end_byte
            10
          end

          def children
            []
          end

          def start_point
            Struct.new(:row, :column).new(5, 10)
          end

          def end_point
            Struct.new(:row, :column).new(8, 15)
          end
        end
      end

      it "extracts row from point object" do
        n = point_object_node_class.new(nil)
        expect(n.end_line).to eq(9) # 8 + 1
      end
    end
  end

  describe "#source_position" do
    it "returns a hash with position info" do
      pos = node.source_position
      expect(pos).to be_a(Hash)
      expect(pos).to have_key(:start_line)
      expect(pos).to have_key(:end_line)
      expect(pos).to have_key(:start_column)
      expect(pos).to have_key(:end_column)
    end

    it "returns 1-based line numbers and 0-based columns" do
      pos = node.source_position
      # Default points return row: 0, column: 0
      expect(pos[:start_line]).to eq(1)
      expect(pos[:end_line]).to eq(1)
      expect(pos[:start_column]).to eq(0)
      expect(pos[:end_column]).to eq(0)
    end

    context "when points return objects with row/column methods" do
      let(:point_object_node_class) do
        Class.new(described_class) do
          def type
            "test"
          end

          def start_byte
            0
          end

          def end_byte
            10
          end

          def children
            []
          end

          def start_point
            Struct.new(:row, :column).new(2, 5)
          end

          def end_point
            Struct.new(:row, :column).new(4, 12)
          end
        end
      end

      it "extracts position from point objects" do
        n = point_object_node_class.new(nil)
        pos = n.source_position
        expect(pos[:start_line]).to eq(3)  # 2 + 1
        expect(pos[:end_line]).to eq(5)    # 4 + 1
        expect(pos[:start_column]).to eq(5)
        expect(pos[:end_column]).to eq(12)
      end
    end
  end

  describe "#calculate_byte_offset (protected)" do
    it "returns 0 for empty lines" do
      n = concrete_node_class.new(nil, lines: [])
      offset = n.send(:calculate_byte_offset, 0, 0)
      expect(offset).to eq(0)
    end

    it "calculates offset for line and column" do
      n = concrete_node_class.new(nil, lines: ["hello\n", "world\n"])
      # Line 0, column 3 should be offset 3
      expect(n.send(:calculate_byte_offset, 0, 3)).to eq(3)
      # Line 1, column 2 should be offset 6 (length of "hello\n") + 2 = 8
      expect(n.send(:calculate_byte_offset, 1, 2)).to eq(8)
    end

    it "clamps column to line length" do
      n = concrete_node_class.new(nil, lines: ["hi\n"])
      # Requesting column 100 should clamp to line length (3)
      offset = n.send(:calculate_byte_offset, 0, 100)
      expect(offset).to eq(3) # "hi\n".bytesize
    end
  end
end
