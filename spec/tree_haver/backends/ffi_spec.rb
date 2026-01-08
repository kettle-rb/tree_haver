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

    context "when MRI backend has been loaded" do
      before do
        # Simulate MRI backend being loaded
        stub_const("::TreeSitter::Parser", Class.new)
      end

      it "returns false" do
        expect(backend.available?).to be false
      end
    end
  end

  describe "::ffi_gem_available?" do
    it "returns true when FFI gem is loaded" do
      expect(backend.ffi_gem_available?).to be true
    end

    it "caches the result after first check" do
      backend.reset!
      result1 = backend.ffi_gem_available?
      result2 = backend.ffi_gem_available?
      expect(result1).to eq(result2)
    end

    context "when running on TruffleRuby", :truffleruby_engine do
      it "returns false due to STRUCT_BY_VALUE limitation" do
        backend.reset!
        expect(backend.ffi_gem_available?).to be false
      end
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

    context "when FFI is not available" do
      before do
        allow(backend).to receive(:available?).and_return(false)
      end

      it "returns empty hash" do
        expect(backend.capabilities).to eq({})
      end
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
        hide_env("TREE_SITTER_RUNTIME_LIB")
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

    describe "::ensure_ffi_extended!" do
      context "when FFI gem is not available" do
        before do
          allow(backend).to receive(:ffi_gem_available?).and_return(false)
        end

        it "raises NotAvailable" do
          # Need to reset internal state to test this path
          backend::Native.instance_variable_set(:@ffi_extended, false)
          expect {
            backend::Native.ensure_ffi_extended!
          }.to raise_error(TreeHaver::NotAvailable, /FFI gem is not available/)
        end
      end
    end

    describe "::ts_node_class" do
      it "returns the TSNode FFI struct class" do
        klass = backend::Native.ts_node_class
        expect(klass).to be < FFI::Struct
        expect(klass.name).to include("TSNode")
      end
    end

    describe "TSNode struct" do
      it "is defined when FFI is available" do
        expect(backend::Native::TSNode).to be < FFI::Struct
      end
    end

    describe "TSPoint struct" do
      it "is defined when FFI is available" do
        expect(backend::Native::TSPoint).to be < FFI::Struct
      end

      it "has row and column fields" do
        point = backend::Native::TSPoint.new
        expect(point.members).to include(:row, :column)
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

      context "with symbol guessing" do
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

    describe "#initialize" do
      it "stores the pointer and path" do
        fake_ptr = double("FFI::Pointer", null?: false)
        lang = backend::Language.new(fake_ptr, nil, path: "/path/to/lib.so", symbol: "tree_sitter_test")
        expect(lang.pointer).to eq(fake_ptr)
        expect(lang.path).to eq("/path/to/lib.so")
        expect(lang.symbol).to eq("tree_sitter_test")
        expect(lang.backend).to eq(:ffi)
      end
    end

    describe "#<=>" do
      let(:fake_ptr_first) { double("FFI::Pointer1") }
      let(:fake_ptr_second) { double("FFI::Pointer2") }

      it "compares by path and symbol" do
        lang1 = backend::Language.new(fake_ptr_first, nil, path: "/a/lib.so", symbol: "sym1")
        lang2 = backend::Language.new(fake_ptr_second, nil, path: "/a/lib.so", symbol: "sym1")
        lang3 = backend::Language.new(fake_ptr_second, nil, path: "/b/lib.so", symbol: "sym1")

        expect(lang1 <=> lang2).to eq(0)
        expect(lang1 <=> lang3).to be < 0
      end

      it "returns nil for non-Language objects" do
        lang = backend::Language.new(fake_ptr_first, nil, path: "/a/lib.so")
        expect(lang <=> "not a language").to be_nil
      end

      it "returns nil for different backend types" do
        lang = backend::Language.new(fake_ptr_first, nil, path: "/a/lib.so")
        other = double("OtherLanguage", backend: :mri, is_a?: true)
        allow(other).to receive(:is_a?).with(backend::Language).and_return(true)
        # Different backend should return nil
        expect(lang <=> other).to be_nil
      end
    end

    describe "#hash" do
      it "returns consistent hash for same path/symbol" do
        fake_ptr = double("FFI::Pointer")
        lang1 = backend::Language.new(fake_ptr, nil, path: "/a/lib.so", symbol: "sym")
        lang2 = backend::Language.new(fake_ptr, nil, path: "/a/lib.so", symbol: "sym")
        expect(lang1.hash).to eq(lang2.hash)
      end
    end

    describe "#to_ptr" do
      it "returns the FFI pointer" do
        fake_ptr = double("FFI::Pointer", null?: false)
        lang = backend::Language.new(fake_ptr)
        expect(lang.to_ptr).to eq(fake_ptr)
      end
    end

    describe "#pointer" do
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

    describe "Parser" do
      it "does not use finalizers (intentional design decision)" do
        # Parser objects intentionally don't use finalizers because ts_parser_delete
        # can segfault during GC. Parser cleanup relies on process exit.
        expect(backend::Parser).not_to respond_to(:finalizer)
      end
    end

    describe "#language=" do
      context "with invalid language type" do
        it "raises NotAvailable when given non-FFI::Language" do
          parser = backend::Parser.new
          wrong_lang = double("WrongLanguage")
          allow(wrong_lang).to receive(:is_a?).with(backend::Language).and_return(false)

          expect {
            parser.language = wrong_lang
          }.to raise_error(TreeHaver::NotAvailable, /FFI backend expected FFI::Language wrapper/)
        end
      end

      context "with wrong backend language" do
        it "raises NotAvailable when language backend is not :ffi" do
          parser = backend::Parser.new
          wrong_backend_lang = backend::Language.new(double("ptr"))
          allow(wrong_backend_lang).to receive(:backend).and_return(:mri)

          expect {
            parser.language = wrong_backend_lang
          }.to raise_error(TreeHaver::NotAvailable, /FFI backend received Language for wrong backend/)
        end
      end

      context "with missing library reference" do
        it "raises NotAvailable when language has no @library" do
          parser = backend::Parser.new
          lang = backend::Language.new(double("ptr"), nil, path: "/test.so")
          lang.instance_variable_set(:@library, nil)

          expect {
            parser.language = lang
          }.to raise_error(TreeHaver::NotAvailable, /FFI Language has no library reference/)
        end
      end

      context "with invalid pointer type" do
        it "raises NotAvailable when to_ptr returns non-FFI::Pointer" do
          parser = backend::Parser.new
          fake_lib = double("DynamicLibrary")
          lang = backend::Language.new("not_a_pointer", fake_lib, path: "/test.so")

          expect {
            parser.language = lang
          }.to raise_error(TreeHaver::NotAvailable, /returned.*expected FFI::Pointer/)
        end
      end

      context "with NULL pointer" do
        it "raises NotAvailable when pointer address is zero" do
          parser = backend::Parser.new
          fake_lib = double("DynamicLibrary")
          null_ptr = double("NullPointer", is_a?: true, address: 0, nil?: true)
          allow(null_ptr).to receive(:is_a?).with(FFI::Pointer).and_return(true)
          lang = backend::Language.new(null_ptr, fake_lib, path: "/test.so")

          expect {
            parser.language = lang
          }.to raise_error(TreeHaver::NotAvailable, /NULL pointer/)
        end
      end

      context "with invalid small address" do
        it "raises NotAvailable when pointer address is < 4096" do
          parser = backend::Parser.new
          fake_lib = double("DynamicLibrary")
          invalid_ptr = double("InvalidPointer", is_a?: true, address: 64, nil?: false)
          allow(invalid_ptr).to receive(:is_a?).with(FFI::Pointer).and_return(true)
          lang = backend::Language.new(invalid_ptr, fake_lib, path: "/test.so")

          expect {
            parser.language = lang
          }.to raise_error(TreeHaver::NotAvailable, /invalid pointer.*0x40/)
        end
      end

      it "sets the language on the parser", :libtree_sitter do
        parser = backend::Parser.new
        expect(parser).to respond_to(:language=)
      end
    end

    describe "Tree::finalizer" do
      it "returns a Proc that safely deletes trees" do
        # Tree objects DO use finalizers (unlike Parser) because trees are
        # short-lived and numerous, and ts_tree_delete is safer during GC
        fake_ptr = double("FFI::Pointer")
        finalizer = backend::Tree.finalizer(fake_ptr)
        expect(finalizer).to be_a(Proc)
      end

      it "silently handles errors during finalization" do
        fake_ptr = double("FFI::Pointer")
        allow(backend::Native).to receive(:ts_tree_delete).and_raise(StandardError, "simulated error")

        finalizer = backend::Tree.finalizer(fake_ptr)
        # Should not raise
        expect { finalizer.call }.not_to raise_error
      end
    end
  end

  describe "Tree" do
    describe "::finalizer" do
      it "does not define a finalizer method (intentional design decision)" do
        # We intentionally don't use finalizers because ts_parser_delete can segfault
        # during GC in certain scenarios. Parser cleanup relies on process exit.
        expect(backend::Parser).not_to respond_to(:finalizer)
      end
    end
  end

  describe "Node" do
    let(:fake_val) { double("TSNode") }

    before do
      allow(backend::Native).to receive(:ts_node_child_count).and_return(0)
    end

    describe "#each" do
      it "returns Enumerator when no block given" do
        node = backend::Node.new(fake_val)
        expect(node.each).to be_an(Enumerator)
      end

      it "yields child nodes when block given" do
        allow(backend::Native).to receive(:ts_node_child_count).and_return(2)
        child1 = double("Child1")
        child2 = double("Child2")
        allow(backend::Native).to receive(:ts_node_child).with(fake_val, 0).and_return(child1)
        allow(backend::Native).to receive(:ts_node_child).with(fake_val, 1).and_return(child2)

        node = backend::Node.new(fake_val)
        children = []
        node.each { |c| children << c }
        expect(children.size).to eq(2)
        expect(children).to all(be_a(backend::Node))
      end
    end

    describe "#child" do
      it "returns nil for negative index" do
        node = backend::Node.new(fake_val)
        expect(node.child(-1)).to be_nil
      end

      it "returns nil for index >= child_count" do
        allow(backend::Native).to receive(:ts_node_child_count).and_return(2)
        node = backend::Node.new(fake_val)
        expect(node.child(5)).to be_nil
      end

      it "returns a Node for valid index" do
        allow(backend::Native).to receive(:ts_node_child_count).and_return(1)
        child_val = double("ChildTSNode")
        allow(backend::Native).to receive(:ts_node_child).with(fake_val, 0).and_return(child_val)

        node = backend::Node.new(fake_val)
        child = node.child(0)
        expect(child).to be_a(backend::Node)
      end
    end

    describe "#<=>" do
      let(:node1_val) { double("TSNode1") }
      let(:node2_val) { double("TSNode2") }

      before do
        allow(backend::Native).to receive(:ts_node_start_byte).with(node1_val).and_return(0)
        allow(backend::Native).to receive(:ts_node_end_byte).with(node1_val).and_return(10)
        allow(backend::Native).to receive(:ts_node_type).with(node1_val).and_return("type_a")

        allow(backend::Native).to receive(:ts_node_start_byte).with(node2_val).and_return(0)
        allow(backend::Native).to receive(:ts_node_end_byte).with(node2_val).and_return(10)
        allow(backend::Native).to receive(:ts_node_type).with(node2_val).and_return("type_a")
      end

      it "returns nil for non-Node objects" do
        node = backend::Node.new(node1_val)
        expect(node <=> "not a node").to be_nil
      end

      it "compares by start_byte first" do
        allow(backend::Native).to receive(:ts_node_start_byte).with(node2_val).and_return(5)

        node1 = backend::Node.new(node1_val)
        node2 = backend::Node.new(node2_val)
        expect(node1 <=> node2).to be < 0
      end

      it "compares by end_byte when start_byte is equal" do
        allow(backend::Native).to receive(:ts_node_end_byte).with(node2_val).and_return(15)

        node1 = backend::Node.new(node1_val)
        node2 = backend::Node.new(node2_val)
        expect(node1 <=> node2).to be < 0
      end

      it "compares by type when start_byte and end_byte are equal" do
        allow(backend::Native).to receive(:ts_node_type).with(node2_val).and_return("type_b")

        node1 = backend::Node.new(node1_val)
        node2 = backend::Node.new(node2_val)
        expect(node1 <=> node2).to be < 0
      end

      it "returns 0 for equal nodes" do
        node1 = backend::Node.new(node1_val)
        node2 = backend::Node.new(node2_val)
        expect(node1 <=> node2).to eq(0)
      end
    end

    describe "#has_error?" do
      it "calls ts_node_has_error native function" do
        allow(backend::Native).to receive(:ts_node_has_error).with(fake_val).and_return(false)
        node = backend::Node.new(fake_val)
        expect(node.has_error?).to be false
        expect(backend::Native).to have_received(:ts_node_has_error).with(fake_val)
      end

      it "returns true when node has error" do
        allow(backend::Native).to receive(:ts_node_has_error).with(fake_val).and_return(true)
        node = backend::Node.new(fake_val)
        expect(node.has_error?).to be true
      end
    end

    describe "#has_error? integration", :libtree_sitter, :toml_grammar do
      it "returns false for valid TOML" do
        lang_path = TreeHaverDependencies.find_toml_grammar_path
        lang = TreeHaver::Language.from_path(lang_path)
        parser = TreeHaver::Parser.new
        parser.language = lang
        tree = parser.parse("key = \"value\"\n")
        root = tree.root_node

        expect(root.has_error?).to be false
      end

      it "returns true for invalid TOML with missing bracket" do
        lang_path = TreeHaverDependencies.find_toml_grammar_path
        lang = TreeHaver::Language.from_path(lang_path)
        parser = TreeHaver::Parser.new
        parser.language = lang
        # Invalid TOML - missing closing bracket
        tree = parser.parse("[server\nhost = \"localhost\"\n")
        root = tree.root_node

        expect(root.has_error?).to be true
      end
    end

    describe "#start_point and #end_point", :libtree_sitter do
      it "returns TreeHaver::Point objects" do
        lang_path = TreeHaverDependencies.find_toml_grammar_path
        lang = TreeHaver::Language.from_path(lang_path)
        parser = TreeHaver::Parser.new
        parser.language = lang
        tree = parser.parse("key = \"value\"\n")
        root = tree.root_node

        expect(root.start_point).to be_a(TreeHaver::Point)
        expect(root.end_point).to be_a(TreeHaver::Point)
        expect(root.start_point.row).to be >= 0
        expect(root.start_point.column).to be >= 0
      end
    end
  end
end
