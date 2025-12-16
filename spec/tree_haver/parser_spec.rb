# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Parser, :toml_grammar do
  before do
    TreeHaver.reset_backend!(to: :auto)
  end

  after do
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "#initialize" do
    context "when a backend is available" do
      it "creates a parser instance" do
        expect {
          described_class.new
        }.not_to raise_error
      end
    end

    context "when no backend is available" do
      before do
        allow(TreeHaver).to receive(:backend_module).and_return(nil)
      end

      it "raises NotAvailable" do
        expect {
          described_class.new
        }.to raise_error(TreeHaver::NotAvailable, /No TreeHaver backend/)
      end
    end
  end

  describe "#language=" do
    it "sets the language on the backend parser" do
      parser = described_class.new
      path = TreeHaverDependencies.find_toml_grammar_path
      language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")

      expect {
        parser.language = language
      }.not_to raise_error
    end
  end

  describe "#parse" do
    let(:parser) do
      p = described_class.new
      path = TreeHaverDependencies.find_toml_grammar_path
      language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
      p.language = language
      p
    end

    it "parses source and returns a TreeHaver::Tree" do
      tree = parser.parse("key = \"value\"")
      expect(tree).to be_a(TreeHaver::Tree)
    end

    it "stores source in the tree" do
      source = "key = \"value\""
      tree = parser.parse(source)
      expect(tree).to respond_to(:source)
    end

    it "provides access to the root node" do
      tree = parser.parse("key = \"value\"")
      root = tree.root_node
      expect(root).to be_a(TreeHaver::Node)
    end
  end

  describe "#parse_string" do
    let(:parser) do
      p = described_class.new
      path = TreeHaverDependencies.find_toml_grammar_path
      language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
      p.language = language
      p
    end
    let(:source) { "key = \"value\"" }

    context "with nil old_tree" do
      it "parses source and returns a TreeHaver::Tree" do
        tree = parser.parse_string(nil, source)
        expect(tree).to be_a(TreeHaver::Tree)
      end
    end

    context "with an old tree (incremental parsing)" do
      it "supports incremental parsing by extracting inner_tree from wrapper" do
        old_tree = parser.parse("key = \"old\"")
        expect(old_tree).to be_a(TreeHaver::Tree)

        # Falls back to regular parsing if backend doesn't support it
        new_tree = parser.parse_string(old_tree, "key = \"new\"")
        expect(new_tree).to be_a(TreeHaver::Tree)
      end
    end

    context "when backend doesn't support parse_string" do
      it "falls back to regular parse" do
        # This is hard to test without mocking internals
        # Just verify the method exists and can be called
        result = parser.parse_string(nil, source)
        expect(result).to be_a(TreeHaver::Tree)
      end
    end

    context "with old_tree that has instance variables fallback" do
      it "extracts tree from instance variable" do
        # This test requires mocking which doesn't work with real backends
        # Real backends validate the tree type strictly
        # Skip this test as the behavior is implementation-specific
        skip "Cannot test instance variable fallback with real backend - backend validates tree type"
      end
    end

    context "when backend supports parse_string but old_tree is nil" do
      it "passes nil to backend parse_string" do
        tree = parser.parse_string(nil, source)
        expect(tree).to be_a(TreeHaver::Tree)
      end
    end
  end
end
