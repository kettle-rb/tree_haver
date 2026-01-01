# frozen_string_literal: true

require "spec_helper"

# The :ffi_backend tag ensures the before hook in dependency_tags.rb skips these tests
# when FFI is not available (e.g., after MRI has been loaded)
#
# The :ffi_backend_only tag allows running these tests in isolation (via `rake ffi_specs`)
# WITHOUT triggering mri_backend_available? check, which prevents MRI from being loaded.
RSpec.describe TreeHaver::Backends::FFI, :check_output, :ffi_backend, :ffi_backend_only do
  let(:backend) { described_class }

  before do
    TreeHaver::LanguageRegistry.clear_cache!
    TreeHaver.reset_backend!(to: :ffi)
  end

  after do
    backend.reset!
    TreeHaver::LanguageRegistry.clear_cache!
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "::available?" do
    it "returns a boolean" do
      result = backend.available?
      expect(result).to be(true).or be(false)
    end

    it "returns true when FFI gem is available" do
      # FFI availability now only checks for the FFI gem
      # MRI conflict is handled by BackendConflict at runtime
      expect(backend.available?).to be true
    end
  end

  describe "::capabilities" do
    it "returns a hash with backend info" do
      caps = backend.capabilities
      expect(caps).to include(:backend, :parse)
      expect(caps[:backend]).to eq(:ffi)
      expect(caps[:parse]).to be true
      expect(caps[:query]).to be false
      expect(caps[:bytes_field]).to be true
    end
  end

  describe "Native module" do
    describe "::lib_candidates" do
      it "returns an array of library names to try" do
        candidates = backend::Native.lib_candidates
        expect(candidates).to be_an(Array)
        expect(candidates).to include("tree-sitter")
        expect(candidates).to include("libtree-sitter.so")
      end

      it "includes TREE_SITTER_RUNTIME_LIB from ENV when set" do
        stub_env("TREE_SITTER_RUNTIME_LIB" => "/custom/path/lib.so")
        candidates = backend::Native.lib_candidates
        expect(candidates).to include("/custom/path/lib.so")
      end

      it "does not include nil when ENV is not set" do
        stub_env("TREE_SITTER_RUNTIME_LIB" => nil)
        candidates = backend::Native.lib_candidates
        expect(candidates).not_to include(nil)
      end
    end

    describe "::loaded?" do
      it "returns a boolean" do
        result = backend::Native.loaded?
        expect(result).to be(true).or be(false)
      end

      it "returns true after try_load! succeeds", :libtree_sitter do
        backend::Native.try_load!
        expect(backend::Native.loaded?).to be true
      end
    end

    describe "::try_load!", :libtree_sitter do
      it "loads the native library successfully" do
        backend::Native.try_load!
        expect(backend::Native.loaded?).to be true
      end
    end

    describe "TSNode struct" do
      it "is defined when FFI is available" do
        expect(backend::Native::TSNode).to be < FFI::Struct
      end
    end
  end

  describe "Language.from_path and parsing", :native_parsing do
    it "raises NotAvailable for a missing library path" do
      bogus = File.join(Dir.pwd, "tmp", "nope", "missing-libtree-sitter-toml.so")
      expect {
        TreeHaver::Language.from_path(bogus)
      }.to raise_error(TreeHaver::NotAvailable, /Could not open language library|No TreeHaver backend is available|No such file/i)
    end

    it "can parse a minimal TOML and expose node types" do
      lang_path = TreeHaverDependencies.find_toml_grammar_path
      lang = TreeHaver::Language.from_path(lang_path)
      parser = TreeHaver::Parser.new
      parser.language = lang
      tree = parser.parse("title = \"TOML\"\n")
      root = tree.root_node
      expect(root).to respond_to(:each)
      child_types = root.each.map(&:type)
      expect(child_types).not_to be_empty
      expect(child_types.join(",")).to match(/key|table|pair/i)
    end
  end

  describe "error cases for symbol resolution", :native_parsing do
    it "raises NotAvailable if symbol override cannot be resolved" do
      lang_path = TreeHaverDependencies.find_toml_grammar_path
      invalid = "totally_nonexistent_symbol_#{rand(1_000_000)}"
      TreeHaver::LanguageRegistry.clear_cache!
      stub_env("TREE_SITTER_LANG_SYMBOL" => invalid)
      expect {
        TreeHaver::Language.from_path(lang_path)
      }.to raise_error(TreeHaver::NotAvailable, /Could not resolve language symbol/i)
    end

    it "honors TREE_SITTER_LANG_SYMBOL when provided" do
      lang_path = TreeHaverDependencies.find_toml_grammar_path
      TreeHaver::LanguageRegistry.clear_cache!
      stub_env("TREE_SITTER_LANG_SYMBOL" => "tree_sitter_toml")
      expect {
        TreeHaver::Language.from_path(lang_path)
      }.not_to raise_error
    end
  end

  describe "Language" do
    describe "::from_library" do
      context "when FFI is not available" do
        before do
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises NotAvailable" do
          expect {
            backend::Language.from_library("/path/to/lib.so")
          }.to raise_error(TreeHaver::NotAvailable, /FFI not available/)
        end
      end

      context "with symbol guessing", :ffi_backend do
        it "guesses symbol from libtree-sitter-<lang> filename" do
          bogus_path = "/tmp/libtree-sitter-yaml.so"
          expect {
            backend::Language.from_library(bogus_path)
          }.to raise_error(TreeHaver::NotAvailable, /Could not open language library/)
        end

        it "handles libtree_sitter_ prefix with underscores" do
          bogus_path = "/tmp/libtree_sitter_json.so"
          expect {
            backend::Language.from_library(bogus_path)
          }.to raise_error(TreeHaver::NotAvailable, /Could not open language library/)
        end
      end
    end

    describe "#to_ptr", :ffi_backend do
      it "returns the FFI pointer" do
        fake_ptr = double("FFI::Pointer", null?: false)
        lang = backend::Language.new(fake_ptr)
        expect(lang.to_ptr).to eq(fake_ptr)
      end
    end

    describe "#pointer", :ffi_backend do
      it "exposes the pointer attribute" do
        fake_ptr = double("FFI::Pointer")
        lang = backend::Language.new(fake_ptr)
        expect(lang.pointer).to eq(fake_ptr)
      end
    end
  end

  describe "Parser" do
    describe "#initialize" do
      context "when FFI is not available" do
        before do
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises NotAvailable" do
          expect {
            backend::Parser.new
          }.to raise_error(TreeHaver::NotAvailable, /FFI not available/)
        end
      end
    end

    describe "Parser", :ffi_backend do
      it "does not use finalizers (intentional design decision)" do
        # Parser objects intentionally don't use finalizers because ts_parser_delete
        # can segfault during GC. Parser cleanup relies on process exit.
        expect(backend::Parser).not_to respond_to(:finalizer)
      end
    end

    describe "Tree::finalizer", :ffi_backend do
      it "returns a Proc that safely deletes trees" do
        # Tree objects DO use finalizers (unlike Parser) because trees are
        # short-lived and numerous, and ts_tree_delete is safer during GC
        fake_ptr = double("FFI::Pointer")
        finalizer = backend::Tree.finalizer(fake_ptr)
        expect(finalizer).to be_a(Proc)
      end
    end

    describe "#language=", :libtree_sitter do
      it "sets the language on the parser" do
        parser = backend::Parser.new
        expect(parser).to respond_to(:language=)
      end
    end
  end

  describe "Tree", :ffi_backend do
    describe "::finalizer" do
      it "does not define a finalizer method (intentional design decision)" do
        # We intentionally don't use finalizers because ts_parser_delete can segfault
        # during GC in certain scenarios. Parser cleanup relies on process exit.
        expect(backend::Parser).not_to respond_to(:finalizer)
      end
    end
  end

  describe "Node", :ffi_backend do
    describe "#each" do
      it "returns Enumerator when no block given" do
        fake_val = double("TSNode")
        allow(backend::Native).to receive(:ts_node_child_count).and_return(0)
        node = backend::Node.new(fake_val)
        expect(node.each).to be_an(Enumerator)
      end
    end
  end
end
