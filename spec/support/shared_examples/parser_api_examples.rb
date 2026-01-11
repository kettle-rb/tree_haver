# frozen_string_literal: true

# Shared examples for Parser API compliance
#
# These examples test the standard Parser interface that all backends must implement.
# They ensure consistent behavior across MRI, FFI, Rust, Java, Citrus, Parslet,
# Prism, Psych, and other backends.
#
# @example Usage in backend specs
#   RSpec.describe TreeHaver::Backends::Citrus::Parser do
#     let(:parser) { create_parser_for_backend }
#     let(:simple_source) { 'key = "value"' }
#
#     it_behaves_like "parser api compliance"
#   end

# Core Parser API that all implementations must provide
RSpec.shared_examples "parser api compliance" do
  # Expects `parser` to be defined as the parser under test
  # Expects `simple_source` to be defined as valid source for parsing
  # Expects `language` to be defined if the backend requires language setting

  describe "required interface" do
    it "responds to #parse" do
      expect(parser).to respond_to(:parse)
    end

    it "#parse accepts a string" do
      expect { parser.parse(simple_source) }.not_to raise_error
    end

    it "#parse returns a tree" do
      tree = parser.parse(simple_source)
      expect(tree).to respond_to(:root_node)
      expect(tree).to respond_to(:source)
    end

    it "responds to #parse_string" do
      expect(parser).to respond_to(:parse_string)
    end

    it "#parse_string accepts old_tree and source" do
      # old_tree can be nil for initial parse
      tree = parser.parse_string(nil, simple_source)
      expect(tree).to respond_to(:root_node)
    end
  end

  describe "language setting" do
    it "responds to #language=" do
      expect(parser).to respond_to(:language=)
    end
  end

  describe "parsing behavior" do
    it "returns a tree with root_node" do
      tree = parser.parse(simple_source)
      expect(tree.root_node).not_to be_nil
    end

    it "preserves source in the tree" do
      tree = parser.parse(simple_source)
      expect(tree.source).to eq(simple_source)
    end

    it "root_node has valid type" do
      tree = parser.parse(simple_source)
      expect(tree.root_node.type).to be_a(String)
      expect(tree.root_node.type).not_to be_empty
    end
  end
end

# Parser incremental parsing support (optional)
RSpec.shared_examples "parser incremental parsing" do
  # Expects `parser` to be defined
  # Expects `simple_source` and `modified_source` to be defined

  describe "#parse_string with old_tree" do
    it "accepts an existing tree for incremental parsing" do
      old_tree = parser.parse(simple_source)
      new_tree = parser.parse_string(old_tree, modified_source)
      expect(new_tree).to respond_to(:root_node)
    end

    it "old_tree can be nil" do
      tree = parser.parse_string(nil, simple_source)
      expect(tree).to respond_to(:root_node)
    end
  end
end

# Parser error handling
RSpec.shared_examples "parser error handling" do
  # Expects `parser` to be defined
  # Expects `invalid_source` to be defined (source that will cause parse errors)

  describe "with invalid source" do
    it "returns a tree even for invalid source (error recovery)" do
      tree = parser.parse(invalid_source)
      expect(tree).to respond_to(:root_node)
    end

    it "tree indicates errors" do
      tree = parser.parse(invalid_source)
      has_errors = tree.has_error? || tree.errors.any? || tree.root_node.has_error?
      expect(has_errors).to be true
    end
  end
end
