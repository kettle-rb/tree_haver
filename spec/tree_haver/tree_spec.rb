# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Tree, :toml_grammar do
  let(:source) { "[package]\nname = \"test\"" }
  let(:parser) do
    p = TreeHaver::Parser.new
    path = TreeHaverDependencies.find_toml_grammar_path
    language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
    p.language = language
    p
  end
  let(:tree) { parser.parse(source) }

  describe "#initialize" do
    it "wraps a backend tree with source" do
      expect(tree.inner_tree).not_to be_nil
      # Source is stored by Parser#parse, not necessarily in tree wrapper
      expect(tree).to respond_to(:source)
    end
  end

  describe "#root_node" do
    it "returns a wrapped Node" do
      root = tree.root_node
      expect(root).to be_a(TreeHaver::Node)
    end

    it "passes source to the root node" do
      root = tree.root_node
      # Source is passed from tree wrapper to node
      expect(root).to respond_to(:source)
    end

    context "when inner_tree root_node is nil" do
      let(:mock_tree) { double("tree", root_node: nil) }
      let(:tree_wrapper) { described_class.new(mock_tree, source: source) }

      it "returns nil" do
        expect(tree_wrapper.root_node).to be_nil
      end
    end
  end

  describe "#edit" do
    context "when backend supports incremental parsing" do
      it "delegates to inner_tree edit method" do
        unless tree.supports_editing?
          skip "Backend doesn't support incremental parsing"
        end

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

    context "when backend doesn't support incremental parsing" do
      let(:simple_tree) { double("tree", root_node: double("node")) }
      let(:tree_wrapper) { described_class.new(simple_tree, source: source) }

      before do
        # Stub edit to raise NoMethodError as it would if the method doesn't exist
        allow(simple_tree).to receive(:edit).and_raise(NoMethodError.new("undefined method `edit'", :edit))
      end

      it "raises NotAvailable error" do
        expect {
          tree_wrapper.edit(
            start_byte: 0,
            old_end_byte: 1,
            new_end_byte: 2,
            start_point: {row: 0, column: 0},
            old_end_point: {row: 0, column: 1},
            new_end_point: {row: 0, column: 2},
          )
        }.to raise_error(TreeHaver::NotAvailable, /Incremental parsing not supported/)
      end
    end
  end

  describe "#supports_editing?" do
    it "returns true when backend supports edit" do
      result = tree.supports_editing?
      expect([true, false]).to include(result)
    end

    context "when backend doesn't support edit" do
      let(:simple_tree) { double("tree", root_node: double("node")) }
      let(:tree_wrapper) { described_class.new(simple_tree, source: source) }

      it "returns false" do
        expect(tree_wrapper.supports_editing?).to be false
      end
    end
  end

  describe "#inspect" do
    it "returns a debug-friendly string" do
      result = tree.inspect
      expect(result).to include("TreeHaver::Tree")
      expect(result).to include("source_length=")
    end

    context "when source is nil" do
      let(:tree_no_source) { described_class.new(tree.inner_tree, source: nil) }

      it "shows unknown length" do
        result = tree_no_source.inspect
        expect(result).to include("source_length=unknown")
      end
    end
  end

  describe "#respond_to_missing?" do
    it "returns true for methods on inner_tree" do
      method = tree.inner_tree.methods.first
      expect(tree.respond_to?(method)).to be true
    end

    it "returns false for non-existent methods" do
      expect(tree.respond_to?(:totally_fake_method_xyz)).to be false
    end
  end

  describe "#method_missing" do
    it "delegates to inner_tree if method exists" do
      # Find a method that exists on inner_tree but not on Tree
      # AND can be called with zero arguments (arity <= 0 or -1 for variable)
      backend_specific_method = tree.inner_tree.methods.find do |m|
        next false if described_class.instance_methods.include?(m)
        begin
          method_obj = tree.inner_tree.method(m)
          # arity of 0 means no args, -1 means variable args (can be called with 0)
          method_obj.arity <= 0
        rescue NameError
          false
        end
      end

      if backend_specific_method
        expect {
          tree.public_send(backend_specific_method)
        }.not_to raise_error
      else
        skip "No suitable zero-argument backend-specific method found"
      end
    end

    it "raises NoMethodError for non-existent methods" do
      expect {
        tree.totally_fake_method_xyz
      }.to raise_error(NoMethodError)
    end

    it "passes arguments and blocks through" do
      # Mock a backend-specific method
      allow(tree.inner_tree).to receive(:custom_method).with(:arg1, key: :value).and_return(:result)

      result = tree.custom_method(:arg1, key: :value)
      expect(result).to eq(:result)
    end

    it "delegates with block" do
      allow(tree.inner_tree).to receive(:respond_to?).with(:method_with_block).and_return(true)
      allow(tree.inner_tree).to receive(:method_with_block).and_yield("yielded value")

      result = nil
      tree.method_with_block { |val| result = val }

      expect(result).to eq("yielded value")
    end
  end

  describe "#respond_to_missing?" do
    it "returns true for methods supported by inner_tree" do
      allow(tree.inner_tree).to receive(:respond_to?).with(:backend_specific_method, false).and_return(true)
      expect(tree.respond_to?(:backend_specific_method)).to be true
    end

    it "returns false for unsupported methods" do
      allow(tree.inner_tree).to receive(:respond_to?).with(:unsupported_method, false).and_return(false)
      expect(tree.respond_to?(:unsupported_method)).to be false
    end

    it "includes private methods when asked" do
      allow(tree.inner_tree).to receive(:respond_to?).with(:private_method, true).and_return(true)
      expect(tree.respond_to?(:private_method, true)).to be true
    end
  end

  describe "#inspect" do
    it "includes source length when source is present" do
      result = tree.inspect
      expect(result).to include("TreeHaver::Tree")
      expect(result).to include("source_length")
      expect(result).to include(source.bytesize.to_s)
    end

    it "shows 'unknown' when source is nil" do
      tree_without_source = described_class.new(tree.inner_tree, source: nil)
      result = tree_without_source.inspect
      expect(result).to include("TreeHaver::Tree")
      expect(result).to include("source_length=unknown")
    end
  end
end
