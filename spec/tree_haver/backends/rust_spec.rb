# frozen_string_literal: true

RSpec.describe TreeHaver::Backends::Rust do
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

    context "when tree_stump is available", :rust_backend do
      it "returns true" do
        expect(backend.available?).to be true
      end
    end

    context "when tree_stump is not available", :not_rust_backend do
      before do
        backend.reset!
      end

      it "returns false" do
        expect(backend.available?).to be false
      end
    end

    it "memoizes the result" do
      first_result = backend.available?
      backend.instance_variable_set(:@loaded, !first_result)
      # Should still return memoized value (load_attempted is still true)
      second_result = backend.available?
      expect(second_result).to eq(!first_result)
    end
  end

  describe "::reset!" do
    it "resets load_attempted flag" do
      backend.available? # Trigger loading
      expect(backend.instance_variable_get(:@load_attempted)).to be true
      backend.reset!
      expect(backend.instance_variable_get(:@load_attempted)).to be false
    end

    it "resets loaded flag" do
      backend.available?
      backend.reset!
      expect(backend.instance_variable_get(:@loaded)).to be false
    end
  end

  describe "::capabilities" do
    context "when available", :rust_backend do
      it "returns a hash with backend info" do
        caps = backend.capabilities
        expect(caps).to be_a(Hash)
        expect(caps[:backend]).to eq(:rust)
        expect(caps[:query]).to be true
        expect(caps[:bytes_field]).to be true
        expect(caps[:incremental]).to be true
      end
    end

    context "when not available" do
      before do
        allow(backend).to receive(:available?).and_return(false)
      end

      it "returns empty hash" do
        expect(backend.capabilities).to eq({})
      end
    end
  end

  describe "Language" do
    describe "::from_library" do
      context "when Rust backend is not available" do
        before do
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises NotAvailable" do
          expect {
            backend::Language.from_library("/path/to/lib.so")
          }.to raise_error(TreeHaver::NotAvailable, /tree_stump not available/)
        end
      end

      context "when Rust backend is available", :rust_backend do
        it "raises NotAvailable for non-existent library path" do
          expect {
            backend::Language.from_library("/nonexistent/libtree-sitter-toml.so")
          }.to raise_error(TreeHaver::NotAvailable, /Language library not found/)
        end

        it "raises NotAvailable with explicit name parameter for non-existent path" do
          expect {
            backend::Language.from_library("/nonexistent/path/to/json.so", name: "json")
          }.to raise_error(TreeHaver::NotAvailable, /Language library not found/)
        end

        it "raises NotAvailable when library file doesn't exist" do
          expect {
            backend::Language.from_library("/nonexistent/lib/libtree-sitter-yaml.dylib")
          }.to raise_error(TreeHaver::NotAvailable, /Language library not found/)
        end

        it "accepts symbol parameter for API consistency (but ignores it)" do
          expect {
            backend::Language.from_library("/nonexistent/lib.so", symbol: "ignored", name: "toml")
          }.to raise_error(TreeHaver::NotAvailable, /Language library not found/)
        end
      end

      context "with valid TOML grammar", :rust_backend, :toml_grammar do
        it "loads the language successfully" do
          path = TreeHaverDependencies.find_toml_grammar_path
          lang = backend::Language.from_library(path)
          expect(lang).to be_a(backend::Language)
          expect(lang.name).to eq("toml")
        end

        it "derives language name from path" do
          path = TreeHaverDependencies.find_toml_grammar_path
          lang = backend::Language.from_library(path)
          expect(lang.name).to eq("toml")
        end

        it "accepts explicit name parameter" do
          path = TreeHaverDependencies.find_toml_grammar_path
          lang = backend::Language.from_library(path, name: "toml")
          expect(lang).to be_a(backend::Language)
          expect(lang.name).to eq("toml")
        end
      end
    end

    describe "::from_path", :rust_backend, :toml_grammar do
      it "delegates to from_library" do
        path = TreeHaverDependencies.find_toml_grammar_path
        lang = backend::Language.from_path(path)
        expect(lang).to be_a(backend::Language)
      end
    end
  end

  describe "Parser" do
    describe "#initialize" do
      context "when Rust backend is not available" do
        before do
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises NotAvailable" do
          expect {
            backend::Parser.new
          }.to raise_error(TreeHaver::NotAvailable, /tree_stump not available/)
        end
      end

      context "when Rust backend is available", :rust_backend do
        it "creates a new parser" do
          parser = backend::Parser.new
          expect(parser).to be_a(backend::Parser)
        end

        it "creates a TreeStump::Parser internally" do
          parser = backend::Parser.new
          expect(parser.instance_variable_get(:@parser)).to be_a(TreeStump::Parser)
        end
      end
    end

    describe "#language=", :rust_backend, :toml_grammar do
      it "sets the language on the underlying parser" do
        parser = backend::Parser.new
        path = TreeHaverDependencies.find_toml_grammar_path
        lang = backend::Language.from_library(path)
        result = parser.language = lang
        expect(result).to eq(lang)
      end

      it "accepts a string language name" do
        parser = backend::Parser.new
        path = TreeHaverDependencies.find_toml_grammar_path
        backend::Language.from_library(path) # register the language first
        result = parser.language = "toml"
        expect(result).to eq("toml")
      end
    end

    describe "#parse", :rust_backend, :toml_grammar do
      let(:parser) do
        p = backend::Parser.new
        path = TreeHaverDependencies.find_toml_grammar_path
        p.language = backend::Language.from_library(path)
        p
      end

      it "parses source code and returns a tree" do
        tree = parser.parse("x = 42")
        expect(tree).to be_a(TreeHaver::Tree)
        expect(tree.inner_tree).to be_a(TreeStump::Tree)
      end

      it "parses valid TOML and provides access to root node" do
        tree = parser.parse("title = \"Hi\"")
        root = tree.root_node
        expect(root).to be_a(TreeHaver::Node)
        expect(root.inner_node).to be_a(TreeStump::Node)
      end
    end

    describe "#parse_string", :rust_backend, :toml_grammar do
      let(:parser) do
        p = backend::Parser.new
        path = TreeHaverDependencies.find_toml_grammar_path
        p.language = backend::Language.from_library(path)
        p
      end

      it "parses source code with nil old_tree" do
        tree = parser.parse_string(nil, "x = 42")
        expect(tree).to be_a(TreeHaver::Tree)
        expect(tree.inner_tree).to be_a(TreeStump::Tree)
      end

      it "parses source code with existing tree for incremental parsing" do
        old_tree = parser.parse("x = 1")
        new_tree = parser.parse_string(old_tree, "x = 42")
        expect(new_tree).to be_a(TreeHaver::Tree)
        expect(new_tree.inner_tree).to be_a(TreeStump::Tree)
      end
    end
  end
end
