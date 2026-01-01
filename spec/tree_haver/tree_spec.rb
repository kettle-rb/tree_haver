# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Tree, :toml_parsing do
  let(:source) { "[package]\nname = \"test\"" }
  let(:parser) { TreeHaver.parser_for(:toml) }
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

    context "when NoMethodError is raised for unrelated method" do
      let(:simple_tree) { double("tree", root_node: double("node")) }
      let(:tree_wrapper) { described_class.new(simple_tree, source: source) }

      before do
        # Stub edit to raise NoMethodError for an unrelated method
        allow(simple_tree).to receive(:edit).and_raise(NoMethodError.new("undefined method `other_method'", :other_method))
      end

      it "re-raises the original error" do
        expect {
          tree_wrapper.edit(
            start_byte: 0,
            old_end_byte: 1,
            new_end_byte: 2,
            start_point: {row: 0, column: 0},
            old_end_point: {row: 0, column: 1},
            new_end_point: {row: 0, column: 2},
          )
        }.to raise_error(NoMethodError, /other_method/)
      end
    end

    context "when backend accepts keyword arguments directly" do
      let(:mock_tree) { double("tree", root_node: double("node")) }
      let(:tree_wrapper) { described_class.new(mock_tree, source: source) }

      it "passes keyword arguments to inner_tree.edit" do
        expect(mock_tree).to receive(:edit).with(
          start_byte: 0,
          old_end_byte: 1,
          new_end_byte: 2,
          start_point: {row: 0, column: 0},
          old_end_point: {row: 0, column: 1},
          new_end_point: {row: 0, column: 2},
        )

        tree_wrapper.edit(
          start_byte: 0,
          old_end_byte: 1,
          new_end_byte: 2,
          start_point: {row: 0, column: 0},
          old_end_point: {row: 0, column: 1},
          new_end_point: {row: 0, column: 2},
        )
      end
    end

    context "when MRI backend (TreeSitter) is available", :mri_backend do
      # These tests cover the InputEdit code path when TreeSitter is available
      # The :mri_backend tag handles skipping when MRI backend is not available

      it "uses InputEdit object when TreeSitter::InputEdit is defined" do
        # Create a tree with MRI backend
        mri_parser = TreeHaver::Parser.new(backend: :mri)
        mri_parser.language = TreeHaver::Language.toml
        mri_tree = mri_parser.parse(source)

        # Skip if this backend doesn't support editing (runtime capability check)
        skip "MRI backend doesn't support editing" unless mri_tree.supports_editing?

        # Just call edit - the MRI backend handles it internally
        expect {
          mri_tree.edit(
            start_byte: 0,
            old_end_byte: 1,
            new_end_byte: 2,
            start_point: {row: 0, column: 0},
            old_end_point: {row: 0, column: 1},
            new_end_point: {row: 0, column: 2},
          )
        }.not_to raise_error
      end

      it "converts point hashes to TreeSitter::Point objects" do
        mri_parser = TreeHaver::Parser.new(backend: :mri)
        mri_parser.language = TreeHaver::Language.toml
        mri_tree = mri_parser.parse(source)

        # Skip if this backend doesn't support editing (runtime capability check)
        skip "MRI backend doesn't support editing" unless mri_tree.supports_editing?

        # Verify we can call edit - the make_point conversion happens internally
        expect {
          mri_tree.edit(
            start_byte: 4,
            old_end_byte: 5,
            new_end_byte: 6,
            start_point: {row: 0, column: 4},
            old_end_point: {row: 0, column: 5},
            new_end_point: {row: 0, column: 6},
          )
        }.not_to raise_error
      end
    end

    context "with simulated MRI backend via mocking" do
      # These tests mock the TreeSitter classes to test the InputEdit code path
      # even when MRI backend is not available

      let(:mock_tree_sitter_tree) { double("TreeSitter::Tree") }
      let(:tree_wrapper) { described_class.new(mock_tree_sitter_tree, source: source) }
      let(:mock_input_edit) { double("TreeSitter::InputEdit") }
      let(:mock_point) { double("TreeSitter::Point") }

      before do
        # Stub the TreeSitter classes to simulate MRI backend
        stub_const("::TreeSitter::InputEdit", Class.new)
        stub_const("::TreeSitter::Point", Class.new)
        stub_const("::TreeSitter::Tree", Class.new)

        allow(TreeSitter::InputEdit).to receive(:new).and_return(mock_input_edit)
        allow(TreeSitter::Point).to receive(:new).and_return(mock_point)

        # Mock InputEdit setters
        allow(mock_input_edit).to receive(:start_byte=)
        allow(mock_input_edit).to receive(:old_end_byte=)
        allow(mock_input_edit).to receive(:new_end_byte=)
        allow(mock_input_edit).to receive(:start_point=)
        allow(mock_input_edit).to receive(:old_end_point=)
        allow(mock_input_edit).to receive(:new_end_point=)

        # Mock Point setters
        allow(mock_point).to receive(:row=)
        allow(mock_point).to receive(:column=)

        # Make mock_tree_sitter_tree appear as TreeSitter::Tree
        allow(mock_tree_sitter_tree).to receive(:is_a?).and_return(false)
        allow(mock_tree_sitter_tree).to receive(:is_a?).with(TreeSitter::Tree).and_return(true)
        allow(mock_tree_sitter_tree).to receive(:edit)
      end

      it "creates InputEdit object and sets byte offsets" do
        allow(TreeSitter::InputEdit).to receive(:new).and_return(mock_input_edit)
        expect(mock_input_edit).to receive(:start_byte=).with(0)
        expect(mock_input_edit).to receive(:old_end_byte=).with(1)
        expect(mock_input_edit).to receive(:new_end_byte=).with(2)

        tree_wrapper.edit(
          start_byte: 0,
          old_end_byte: 1,
          new_end_byte: 2,
          start_point: {row: 0, column: 0},
          old_end_point: {row: 0, column: 1},
          new_end_point: {row: 0, column: 2},
        )
      end

      it "creates Point objects for start_point, old_end_point, new_end_point" do
        # Expect Point.new to be called 3 times (once for each point)
        expect(TreeSitter::Point).to receive(:new).exactly(3).times.and_return(mock_point)

        tree_wrapper.edit(
          start_byte: 0,
          old_end_byte: 1,
          new_end_byte: 2,
          start_point: {row: 0, column: 0},
          old_end_point: {row: 0, column: 1},
          new_end_point: {row: 0, column: 2},
        )
      end

      it "sets row and column on Point objects" do
        expect(mock_point).to receive(:row=).with(0)
        expect(mock_point).to receive(:column=).with(0)
        expect(mock_point).to receive(:row=).with(0)
        expect(mock_point).to receive(:column=).with(1)
        expect(mock_point).to receive(:row=).with(0)
        expect(mock_point).to receive(:column=).with(2)

        tree_wrapper.edit(
          start_byte: 0,
          old_end_byte: 1,
          new_end_byte: 2,
          start_point: {row: 0, column: 0},
          old_end_point: {row: 0, column: 1},
          new_end_point: {row: 0, column: 2},
        )
      end

      it "passes InputEdit to inner_tree.edit" do
        expect(mock_tree_sitter_tree).to receive(:edit).with(mock_input_edit)

        tree_wrapper.edit(
          start_byte: 0,
          old_end_byte: 1,
          new_end_byte: 2,
          start_point: {row: 0, column: 0},
          old_end_point: {row: 0, column: 1},
          new_end_point: {row: 0, column: 2},
        )
      end
    end

    context "when TreeSitter::Point is not defined (make_point fallback)" do
      # This tests the else branch of make_point that returns the point_hash directly
      let(:mock_tree_sitter_tree) { double("TreeSitter::Tree") }
      let(:tree_wrapper) { described_class.new(mock_tree_sitter_tree, source: source) }
      let(:mock_input_edit) { double("TreeSitter::InputEdit") }

      before do
        # Only stub InputEdit and Tree, NOT Point - to test the fallback path
        stub_const("::TreeSitter::InputEdit", Class.new)
        stub_const("::TreeSitter::Tree", Class.new)

        # Hide TreeSitter::Point by not defining it
        # (The stub_const above only defines InputEdit and Tree)
        hide_const("::TreeSitter::Point") if defined?(TreeSitter::Point)

        allow(TreeSitter::InputEdit).to receive(:new).and_return(mock_input_edit)

        # Mock InputEdit setters
        allow(mock_input_edit).to receive(:start_byte=)
        allow(mock_input_edit).to receive(:old_end_byte=)
        allow(mock_input_edit).to receive(:new_end_byte=)
        allow(mock_input_edit).to receive(:start_point=)
        allow(mock_input_edit).to receive(:old_end_point=)
        allow(mock_input_edit).to receive(:new_end_point=)

        # Make mock_tree_sitter_tree appear as TreeSitter::Tree
        allow(mock_tree_sitter_tree).to receive(:is_a?).and_return(false)
        allow(mock_tree_sitter_tree).to receive(:is_a?).with(TreeSitter::Tree).and_return(true)
        allow(mock_tree_sitter_tree).to receive(:edit)
      end

      it "passes point hashes directly when TreeSitter::Point is not defined" do
        start_point_hash = {row: 0, column: 0}
        old_end_point_hash = {row: 0, column: 1}
        new_end_point_hash = {row: 0, column: 2}

        # When TreeSitter::Point is not defined, make_point should return the hash directly
        expect(mock_input_edit).to receive(:start_point=).with(start_point_hash)
        expect(mock_input_edit).to receive(:old_end_point=).with(old_end_point_hash)
        expect(mock_input_edit).to receive(:new_end_point=).with(new_end_point_hash)

        tree_wrapper.edit(
          start_byte: 0,
          old_end_byte: 1,
          new_end_byte: 2,
          start_point: start_point_hash,
          old_end_point: old_end_point_hash,
          new_end_point: new_end_point_hash,
        )
      end
    end
  end

  describe "#supports_editing?" do
    it "returns a boolean indicating edit support" do
      result = tree.supports_editing?
      expect(result).to be(true).or be(false)
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

    it "includes source length when source is present" do
      result = tree.inspect
      expect(result).to include("TreeHaver::Tree")
      expect(result).to include("source_length")
      expect(result).to include(source.bytesize.to_s)
    end

    context "when source is nil" do
      let(:tree_no_source) { described_class.new(tree.inner_tree, source: nil) }

      it "shows unknown length" do
        result = tree_no_source.inspect
        expect(result).to include("source_length=unknown")
      end

      it "shows 'unknown' in inspect output" do
        tree_without_source = described_class.new(tree.inner_tree, source: nil)
        result = tree_without_source.inspect
        expect(result).to include("TreeHaver::Tree")
        expect(result).to include("source_length=unknown")
      end
    end

    context "when inner_tree is nil" do
      let(:tree_nil_inner) { described_class.new(nil, source: source) }

      it "shows nil in inspect output" do
        result = tree_nil_inner.inspect
        expect(result).to include("TreeHaver::Tree")
        expect(result).to include("inner_tree=nil")
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

  describe "#respond_to_missing? with mock inner_tree" do
    let(:mock_inner_tree) do
      double("InnerTree", root_node: double("Node"))
    end

    it "returns true for methods on inner_tree" do
      allow(mock_inner_tree).to receive(:respond_to?).with(:custom_method, false).and_return(true)
      tree_wrapper = described_class.new(mock_inner_tree, source: "test")
      expect(tree_wrapper.respond_to?(:custom_method)).to be true
    end

    it "returns false for methods not on inner_tree" do
      allow(mock_inner_tree).to receive(:respond_to?).with(:nonexistent_xyz, false).and_return(false)
      tree_wrapper = described_class.new(mock_inner_tree, source: "test")
      expect(tree_wrapper.respond_to?(:nonexistent_xyz)).to be false
    end
  end
end
