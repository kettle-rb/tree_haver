# frozen_string_literal: true

# Shared examples for TOML parsing tests
#
# These examples test parsing behavior that should work identically across
# all TOML backends (tree-sitter-toml, toml-rb/Citrus, etc.)
#
# @example Usage in specs
#   RSpec.describe "TOML parsing" do
#     # Tree-sitter backend - requires native backend and grammar
#     context "with tree-sitter backend", :native_parsing do
#       let(:parser) { TreeHaver.parser_for(:toml) }
#
#       it_behaves_like "toml parsing basics"
#     end
#
#     # Citrus backend - requires citrus gem and toml-rb
#     context "with Citrus backend", :citrus_backend, :toml_rb do
#       around do |example|
#         TreeHaver.with_backend(:citrus) do
#           example.run
#         end
#       end
#
#       let(:parser) { TreeHaver.parser_for(:toml) }
#
#       it_behaves_like "toml parsing basics"
#     end
#   end

RSpec.shared_examples "toml parsing basics" do
  let(:simple_source) { 'key = "value"' }
  let(:multiline_source) { "[section]\nkey = \"value\"\nother = 123" }

  describe "basic parsing" do
    it "parses simple TOML" do
      tree = parser.parse(simple_source)
      expect(tree).not_to be_nil
      expect(tree.root_node).not_to be_nil
    end

    it "parses multiline TOML" do
      tree = parser.parse(multiline_source)
      expect(tree).not_to be_nil
      expect(tree.root_node).not_to be_nil
    end

    it "root node has type" do
      tree = parser.parse(simple_source)
      expect(tree.root_node.type).to be_a(String)
      expect(tree.root_node.type).not_to be_empty
    end
  end

  describe "node positions" do
    it "provides valid byte positions" do
      tree = parser.parse(simple_source)
      root = tree.root_node

      expect(root.start_byte).to be_a(Integer)
      expect(root.end_byte).to be_a(Integer)
      expect(root.start_byte).to be >= 0
      expect(root.end_byte).to be > root.start_byte
    end

    it "provides valid point positions" do
      tree = parser.parse(simple_source)
      root = tree.root_node

      start_pt = root.start_point
      end_pt = root.end_point

      expect(start_pt.row).to be >= 0
      expect(start_pt.column).to be >= 0
      expect(end_pt.row).to be >= 0
      expect(end_pt.column).to be >= 0
    end

    it "provides valid source_position hash" do
      tree = parser.parse(simple_source)
      root = tree.root_node
      pos = root.source_position

      expect(pos).to be_a(Hash)
      expect(pos[:start_line]).to be >= 1
      expect(pos[:end_line]).to be >= pos[:start_line]
      expect(pos[:start_column]).to be >= 0
      expect(pos[:end_column]).to be >= 0
    end

    it "provides valid positions for multiline content" do
      tree = parser.parse(multiline_source)
      root = tree.root_node

      # Root should span multiple lines
      expect(root.end_point.row).to be > root.start_point.row
    end
  end

  describe "node children" do
    it "has children for structured content" do
      tree = parser.parse(multiline_source)
      root = tree.root_node

      expect(root.child_count).to be > 0
    end

    it "can access children by index" do
      tree = parser.parse(multiline_source)
      root = tree.root_node

      if root.child_count > 0
        child = root.child(0)
        expect(child).not_to be_nil
        expect(child.type).to be_a(String)
      end
    end

    it "returns nil for out of bounds child index" do
      tree = parser.parse(simple_source)
      root = tree.root_node

      expect(root.child(9999)).to be_nil
    end

    it "can iterate over children" do
      tree = parser.parse(multiline_source)
      root = tree.root_node

      children = root.children
      expect(children).to be_an(Array)
      children.each do |child|
        expect(child.type).to be_a(String)
      end
    end
  end

  describe "node text" do
    it "can extract node text" do
      tree = parser.parse(simple_source)
      root = tree.root_node

      # Root should contain the full source
      expect(root.text).to include("key")
    end
  end

  describe "error detection" do
    it "reports no errors for valid TOML" do
      tree = parser.parse(simple_source)
      root = tree.root_node

      expect(root.has_error?).to be false
    end
  end
end

RSpec.shared_examples "toml node navigation" do
  let(:nested_source) do
    <<~TOML
      [package]
      name = "test"
      version = "1.0.0"

      [dependencies]
      foo = "1.0"
    TOML
  end

  describe "first_child" do
    it "returns the first child" do
      tree = parser.parse(nested_source)
      root = tree.root_node

      if root.child_count > 0
        first = root.first_child
        expect(first).not_to be_nil
        expect(first.type).to be_a(String)
      end
    end
  end

  describe "named_children" do
    it "returns only named children" do
      tree = parser.parse(nested_source)
      root = tree.root_node

      named = root.named_children
      expect(named).to be_an(Array)
      named.each do |child|
        expect(child.named?).to be true
      end
    end

    it "named children have valid positions" do
      tree = parser.parse(nested_source)
      root = tree.root_node

      root.named_children.each do |child|
        pos = child.source_position

        expect(pos[:start_line]).to be >= 1
        expect(pos[:end_line]).to be >= pos[:start_line]
        expect(pos[:start_column]).to be >= 0
        expect(pos[:end_column]).to be >= 0
      end
    end
  end
end
