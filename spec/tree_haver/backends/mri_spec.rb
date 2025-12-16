# frozen_string_literal: true

RSpec.describe TreeHaver::Backends::MRI do
  let(:backend) { described_class }

  # Store original state to restore after tests
  before do
    @original_load_attempted = backend.instance_variable_get(:@load_attempted)
    @original_loaded = backend.instance_variable_get(:@loaded)
  end

  after do
    # Restore original state
    backend.instance_variable_set(:@load_attempted, @original_load_attempted)
    backend.instance_variable_set(:@loaded, @original_loaded)
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "::available?" do
    it "returns a boolean" do
      result = backend.available?
      expect(result).to be(true).or be(false)
    end

    context "when ruby_tree_sitter is available", :mri_backend do
      it "returns true" do
        expect(backend.available?).to be true
      end

      it "sets @loaded to true after successful require" do
        # Reset to force re-evaluation
        backend.instance_variable_set(:@load_attempted, false)
        backend.instance_variable_set(:@loaded, false)
        backend.available?
        expect(backend.instance_variable_get(:@loaded)).to be true
      end
    end

    context "when ruby_tree_sitter is not available" do
      it "returns false after reset and failed require" do
        # Reset the memoized state using the API
        backend.reset!

        # Stub require to fail
        allow(backend).to receive(:require).with("tree_sitter").and_raise(LoadError)

        expect(backend.available?).to be false
      end
    end

    it "memoizes the result" do
      first_result = backend.available?
      second_result = backend.available?
      expect(first_result).to eq(second_result)
    end
  end

  describe "::capabilities", :mri_backend do
    it "returns a hash with backend info" do
      caps = backend.capabilities
      expect(caps).to be_a(Hash)
      expect(caps[:backend]).to eq(:mri)
      expect(caps[:query]).to be true
      expect(caps[:bytes_field]).to be true
      expect(caps[:incremental]).to be true
    end

    it "returns the full capabilities hash" do
      caps = backend.capabilities
      expect(caps.keys).to contain_exactly(:backend, :query, :bytes_field, :incremental)
    end
  end

  describe "::capabilities when not available" do
    before do
      allow(backend).to receive(:available?).and_return(false)
    end

    it "returns empty hash" do
      expect(backend.capabilities).to eq({})
    end
  end

  describe "Language" do
    describe "::from_path" do
      context "when MRI backend is not available" do
        before do
          # Stub TreeSitter constant to not exist
          hide_const("TreeSitter")
        end

        it "raises NotAvailable" do
          expect {
            backend::Language.from_path("/path/to/lib.so")
          }.to raise_error(TreeHaver::NotAvailable, /ruby_tree_sitter not available/)
        end
      end

      context "when path does not exist", :mri_backend do
        it "raises an error for non-existent path" do
          expect {
            backend::Language.from_path("/nonexistent/path/to/lib.so")
          }.to raise_error(StandardError)
        end
      end

      context "with valid TOML grammar", :mri_backend, :toml_grammar do
        it "loads the language successfully" do
          path = TreeHaverDependencies.find_toml_grammar_path
          lang = backend::Language.from_path(path)
          expect(lang).to be_a(TreeSitter::Language)
        end

        it "calls TreeSitter::Language.load" do
          path = TreeHaverDependencies.find_toml_grammar_path
          # This actually exercises line 67: ::TreeSitter::Language.load(path)
          lang = backend::Language.from_path(path)
          expect(lang).not_to be_nil
        end
      end
    end
  end

  describe "Parser", :mri_backend do
    describe "#initialize" do
      context "when MRI backend is not available" do
        before do
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises NotAvailable" do
          expect {
            backend::Parser.new
          }.to raise_error(TreeHaver::NotAvailable, /ruby_tree_sitter not available/)
        end
      end

      it "creates a new parser wrapping TreeSitter::Parser" do
        parser = backend::Parser.new
        expect(parser).to be_a(backend::Parser)
        # Verify it actually created the underlying parser (line 80)
        expect(parser.instance_variable_get(:@parser)).to be_a(TreeSitter::Parser)
      end
    end

    describe "#language=", :toml_grammar do
      it "sets the language on the underlying parser" do
        parser = backend::Parser.new
        path = TreeHaverDependencies.find_toml_grammar_path
        lang = backend::Language.from_path(path)
        # This actually exercises line 88: @parser.language = lang
        result = parser.language = lang
        expect(result).to eq(lang)
      end
    end

    describe "#parse", :toml_grammar do
      let(:parser) do
        p = backend::Parser.new
        path = TreeHaverDependencies.find_toml_grammar_path
        p.language = backend::Language.from_path(path)
        p
      end

      it "parses source code and returns a tree" do
        # This actually exercises line 96: @parser.parse(source)
        tree = parser.parse("key = \"value\"\n")
        expect(tree).to be_a(TreeSitter::Tree)
      end

      it "parses valid TOML and provides access to root node" do
        tree = parser.parse("title = \"TOML\"\n")
        root = tree.root_node
        expect(root).to be_a(TreeSitter::Node)
        expect(root.type).to eq("document")
      end
    end

    describe "#parse_string", :toml_grammar do
      let(:parser) do
        p = backend::Parser.new
        path = TreeHaverDependencies.find_toml_grammar_path
        p.language = backend::Language.from_path(path)
        p
      end

      it "parses source code with nil old_tree" do
        # This actually exercises line 105: @parser.parse_string(old_tree, source)
        tree = parser.parse_string(nil, "key = \"value\"\n")
        expect(tree).to be_a(TreeSitter::Tree)
      end

      it "parses source code with existing tree for incremental parsing" do
        old_tree = parser.parse("key = \"old\"\n")
        new_tree = parser.parse_string(old_tree, "key = \"new\"\n")
        expect(new_tree).to be_a(TreeSitter::Tree)
        expect(new_tree.root_node.type).to eq("document")
      end
    end
  end

  context "Tree" do
    it "doesn't define a separate Tree class (passes through to TreeSitter::Tree)" do
      # MRI backend doesn't define Tree/Node - it passes through to ruby_tree_sitter
      # The public API returns TreeHaver::Tree which wraps ::TreeSitter::Tree
      expect(defined?(backend::Tree)).to be_nil
    end
  end

  context "Node" do
    it "doesn't define a separate Node class (passes through to TreeSitter::Node)" do
      # MRI backend doesn't define Tree/Node - it passes through to ruby_tree_sitter
      # The public API returns TreeHaver::Node which wraps ::TreeSitter::Node
      expect(defined?(backend::Node)).to be_nil
    end
  end

  describe "full parsing workflow", :mri_backend, :toml_grammar do
    it "can parse TOML and traverse the AST" do
      path = TreeHaverDependencies.find_toml_grammar_path
      lang = backend::Language.from_path(path)
      parser = backend::Parser.new
      parser.language = lang

      tree = parser.parse(<<~TOML)
        [package]
        name = "example"
        version = "1.0.0"
      TOML

      root = tree.root_node
      expect(root.type).to eq("document")
      expect(root.child_count).to be > 0

      # Check that we can access children
      first_child = root.child(0)
      expect(first_child).to be_a(TreeSitter::Node)
    end
  end
end
