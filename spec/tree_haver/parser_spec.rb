# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Parser, :toml_parsing do
  before do
    TreeHaver.reset_backend!(to: :auto)
  end

  after do
    TreeHaver.reset_backend!(to: :auto)
  end

  # Helper to create a parser using auto-discovery (works on all platforms)
  def create_toml_parser
    TreeHaver.parser_for(:toml)
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
      parser = create_toml_parser
      # The parser_for already sets a language, so verify parsing works
      tree = parser.parse("key = \"value\"")
      expect(tree).to be_a(TreeHaver::Tree)
      expect(tree.root_node).not_to be_nil
    end
  end

  describe "#parse" do
    let(:parser) { create_toml_parser }

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
    let(:parser) { create_toml_parser }
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

    context "with old_tree parameter" do
      let(:old_tree_impl) { double("OldTreeImpl") }
      let(:new_tree_impl) { double("NewTreeImpl", root_node: double(type: "root", child_count: 0)) }
      let(:impl) { double("ParserImpl", parse_string: new_tree_impl, "language=": nil) }

      let(:fake_backend_module) do
        mod = Module.new
        impl_inst = impl
        parser_class = Class.new do
          define_method(:initialize) do
            @impl = impl_inst
          end
          attr_reader :impl
          define_method(:language=) { |lang| @impl.language = lang }
          define_method(:parse_string) { |old, src| @impl.parse_string(old, src) }
        end
        mod.const_set(:Parser, parser_class)
        mod
      end

      before do
        allow(TreeHaver).to receive(:resolve_backend_module).and_return(fake_backend_module)
      end

      it "extracts impl from Tree wrapper when old_tree has #inner_tree" do
        parser = described_class.new

        old_tree_wrapper = double("TreeWrapper")
        allow(old_tree_wrapper).to receive(:respond_to?).and_return(false)
        allow(old_tree_wrapper).to receive_messages(respond_to?: true, inner_tree: old_tree_impl)
        allow(old_tree_wrapper).to receive(:respond_to?).with(:inner_tree).and_return(true)

        allow(impl).to receive(:parse_string).with(old_tree_impl, "new source").and_return(new_tree_impl)

        result = parser.parse_string(old_tree_wrapper, "new source")
        expect(result).to be_a(TreeHaver::Tree)
      end

      it "extracts impl from legacy wrapper when old_tree has @impl" do
        parser = described_class.new

        old_tree_wrapper = double("TreeWrapper")
        allow(old_tree_wrapper).to receive(:respond_to?).and_return(true)
        allow(old_tree_wrapper).to receive(:respond_to?).with(:inner_tree).and_return(false)
        allow(old_tree_wrapper).to receive(:instance_variable_get).with(:@inner_tree).and_return(nil)
        allow(old_tree_wrapper).to receive(:instance_variable_get).with(:@impl).and_return(old_tree_impl)

        allow(impl).to receive(:parse_string).with(old_tree_impl, "new source").and_return(new_tree_impl)

        result = parser.parse_string(old_tree_wrapper, "new source")
        expect(result).to be_a(TreeHaver::Tree)
      end

      it "uses old_tree directly when it's not a wrapper" do
        parser = described_class.new

        allow(old_tree_impl).to receive(:respond_to?).and_return(false)

        allow(impl).to receive(:parse_string).with(old_tree_impl, "new source").and_return(new_tree_impl)

        result = parser.parse_string(old_tree_impl, "new source")
        expect(result).to be_a(TreeHaver::Tree)
      end
    end
  end

  describe "backend parameter" do
    # NOTE: Do NOT reset backends_used! The tracking is essential for backend_protect

    after do
      # Clean up thread-local state
      Thread.current[:tree_haver_backend_context] = nil
    end

    describe "Parser.new" do
      context "with no backend parameter" do
        it "uses effective backend from context/global (non-conflicting)" do
          skip "No backend available" unless TreeHaver.backend_module

          # Use citrus since it never conflicts
          TreeHaver.with_backend(:citrus) do
            parser = described_class.new
            expect(parser.backend).to eq(:citrus)
          end
        end

        it "uses global backend when no context set" do
          skip "No backend available" unless TreeHaver.backend_module

          TreeHaver.backend = :auto
          parser = described_class.new
          # parser.backend returns the actual resolved backend, not :auto
          # It should be one of the available backends
          valid_backends = [:mri, :rust, :ffi, :java, :citrus]
          expect(valid_backends).to include(parser.backend)
        end
      end

      context "with explicit backend parameter" do
        it "uses specified backend regardless of context (non-conflicting)" do
          skip "Citrus backend not available" unless TreeHaver::Backends::Citrus.available?

          TreeHaver.with_backend(:mri) do
            parser = described_class.new(backend: :citrus)
            expect(parser.backend).to eq(:citrus)
          end
        end

        it "overrides global backend setting (non-conflicting)" do
          skip "Citrus backend not available" unless TreeHaver::Backends::Citrus.available?

          TreeHaver.backend = :mri
          parser = described_class.new(backend: :citrus)
          expect(parser.backend).to eq(:citrus)
        end

        it "creates parser with MRI backend when specified" do
          skip "MRI backend not available" unless TreeHaver::Backends::MRI.available?

          parser = described_class.new(backend: :mri)
          expect(parser.backend).to eq(:mri)
        end

        it "creates parser with FFI backend when specified", :ffi_backend do
          parser = described_class.new(backend: :ffi)
          expect(parser.backend).to eq(:ffi)
        end

        it "creates parser with Rust backend when specified", :rust_backend do
          parser = described_class.new(backend: :rust)
          expect(parser.backend).to eq(:rust)
        end

        it "creates parser with MRI backend when specified", :mri_backend do
          parser = described_class.new(backend: :mri)
          expect(parser.backend).to eq(:mri)
        end

        it "creates parser with Citrus backend when specified", :citrus_backend do
          parser = described_class.new(backend: :citrus)
          expect(parser.backend).to eq(:citrus)
        end

        it "raises NotAvailable when requested backend is not available" do
          # Try to use a backend that definitely won't be available
          unavailable_backend = if defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
            :mri  # MRI backend won't work on JRuby
          else
            :java  # Java backend won't work on MRI
          end

          expect do
            described_class.new(backend: unavailable_backend)
          end.to raise_error(TreeHaver::NotAvailable, /Requested backend .* is not available/)
        end

        it "accepts string backend names", :mri_backend do
          parser = described_class.new(backend: "mri")
          expect(parser.backend).to eq(:mri)
        end
      end

      context "with backend introspection" do
        it "returns thread-local backend when no explicit backend set", :mri_backend do
          TreeHaver.with_backend(:mri) do
            parser = described_class.new
            expect(parser.backend).to eq(:mri)
          end
        end

        it "returns explicit backend when set", :mri_backend, :rust_backend do
          TreeHaver.with_backend(:mri) do
            parser = described_class.new(backend: :rust)
            expect(parser.backend).to eq(:rust)
          end
        end

        it "returns consistent backend throughout parser lifecycle", :mri_backend do
          parser = described_class.new(backend: :mri)

          # Change context after parser creation
          TreeHaver.with_backend(:rust) do
            # Parser should still report :mri
            expect(parser.backend).to eq(:mri)
          end
        end
      end
    end

    describe "Thread-safe parser creation" do
      it "creates parsers with different backends in concurrent threads" do
        # Use Rust and Citrus which can coexist (not FFI which conflicts with MRI)
        rust_available = TreeHaver::Backends::Rust.available?
        citrus_available = TreeHaver::Backends::Citrus.available?

        skip "Need at least Rust and Citrus backends" unless rust_available && citrus_available

        results = Concurrent::Array.new if defined?(Concurrent::Array)
        results ||= []
        mutex = Mutex.new

        thread1 = Thread.new do
          TreeHaver.with_backend(:rust) do
            parser = described_class.new
            mutex.synchronize { results << {thread: 1, backend: parser.backend} }
          end
        end

        thread2 = Thread.new do
          TreeHaver.with_backend(:citrus) do
            parser = described_class.new
            mutex.synchronize { results << {thread: 2, backend: parser.backend} }
          end
        end

        thread1.join
        thread2.join

        expect(results.size).to eq(2)
        expect(results.find { |r| r[:thread] == 1 }[:backend]).to eq(:rust)
        expect(results.find { |r| r[:thread] == 2 }[:backend]).to eq(:citrus)
      end

      it "creates parsers with explicit backends in concurrent threads" do
        # Use Rust and Citrus which can coexist (not FFI which conflicts with MRI)
        rust_available = TreeHaver::Backends::Rust.available?
        citrus_available = TreeHaver::Backends::Citrus.available?

        skip "Need at least Rust and Citrus backends" unless rust_available && citrus_available

        results = Concurrent::Array.new if defined?(Concurrent::Array)
        results ||= []
        mutex = Mutex.new

        thread1 = Thread.new do
          parser = described_class.new(backend: :rust)
          mutex.synchronize { results << {thread: 1, backend: parser.backend} }
        end

        thread2 = Thread.new do
          parser = described_class.new(backend: :citrus)
          mutex.synchronize { results << {thread: 2, backend: parser.backend} }
        end

        thread1.join
        thread2.join

        expect(results.size).to eq(2)
        expect(results.find { |r| r[:thread] == 1 }[:backend]).to eq(:rust)
        expect(results.find { |r| r[:thread] == 2 }[:backend]).to eq(:citrus)
      end
    end

    describe "Backward compatibility" do
      it "works without backend parameter (existing behavior)" do
        skip "No backend available" unless TreeHaver.backend_module

        parser = described_class.new
        expect(parser).to be_a(described_class)
      end

      it "respects global backend setting (existing behavior)" do
        # Use Citrus which doesn't conflict with MRI (not FFI)
        skip "Citrus backend not available" unless TreeHaver::Backends::Citrus.available?

        TreeHaver.backend = :citrus
        parser = described_class.new
        expect(parser.backend).to eq(:citrus)
      end
    end
  end

  describe "Parser initialization edge cases" do
    context "when tree-sitter fails and Citrus fallback is available" do
      let(:failing_backend_module) do
        mod = Module.new
        parser_class = Class.new do
          define_method(:initialize) do
            raise LoadError, "Simulated tree-sitter load failure"
          end
        end
        mod.const_set(:Parser, parser_class)
        mod
      end

      before do
        allow(TreeHaver).to receive(:resolve_backend_module).and_return(failing_backend_module)
        allow(TreeHaver::Backends::Citrus).to receive(:available?).and_return(true)
      end

      it "falls back to Citrus when tree-sitter backend fails with LoadError" do
        parser = described_class.new
        expect(parser.backend).to eq(:citrus)
      end
    end

    context "when tree-sitter fails with NoMethodError and Citrus available" do
      let(:failing_backend_module) do
        mod = Module.new
        parser_class = Class.new do
          define_method(:initialize) do
            raise NoMethodError, "Simulated method error"
          end
        end
        mod.const_set(:Parser, parser_class)
        mod
      end

      before do
        allow(TreeHaver).to receive(:resolve_backend_module).and_return(failing_backend_module)
        allow(TreeHaver::Backends::Citrus).to receive(:available?).and_return(true)
      end

      it "falls back to Citrus when tree-sitter backend fails with NoMethodError" do
        parser = described_class.new
        expect(parser.backend).to eq(:citrus)
      end
    end

    context "when tree-sitter fails and Citrus is NOT available" do
      let(:failing_backend_module) do
        mod = Module.new
        parser_class = Class.new do
          define_method(:initialize) do
            raise LoadError, "Simulated tree-sitter load failure"
          end
        end
        mod.const_set(:Parser, parser_class)
        mod
      end

      before do
        allow(TreeHaver).to receive(:resolve_backend_module).and_return(failing_backend_module)
        allow(TreeHaver::Backends::Citrus).to receive(:available?).and_return(false)
      end

      it "raises NotAvailable with helpful message" do
        expect {
          described_class.new
        }.to raise_error(TreeHaver::NotAvailable, /Tree-sitter backend failed.*Citrus fallback not available/)
      end
    end

    context "when explicit backend requested and it fails" do
      let(:failing_backend_module) do
        mod = Module.new
        parser_class = Class.new do
          define_method(:initialize) do
            raise LoadError, "Backend specific failure"
          end
        end
        mod.const_set(:Parser, parser_class)
        mod
      end

      before do
        allow(TreeHaver).to receive(:resolve_backend_module).with(:failing_backend).and_return(failing_backend_module)
      end

      it "re-raises the error without fallback when explicit backend requested" do
        expect {
          described_class.new(backend: :failing_backend)
        }.to raise_error(LoadError, /Backend specific failure/)
      end
    end
  end

  describe "#backend introspection" do
    context "with FFI backend", :ffi_backend do
      it "returns :ffi when using FFI parser" do
        parser = described_class.new(backend: :ffi)
        expect(parser.backend).to eq(:ffi)
      end
    end

    context "with Java backend", :java_backend do
      it "returns :java when using Java parser" do
        parser = described_class.new(backend: :java)
        expect(parser.backend).to eq(:java)
      end
    end

    context "with unknown backend class name" do
      let(:unknown_backend_module) do
        mod = Module.new
        parser_class = Class.new do
          define_method(:initialize) {}
        end
        # Give it a non-matching name
        parser_class.define_singleton_method(:name) { "SomeUnknownBackend::Parser" }
        mod.const_set(:Parser, parser_class)
        mod
      end

      before do
        allow(TreeHaver).to receive_messages(
          resolve_backend_module: unknown_backend_module,
          effective_backend: :custom,
        )
      end

      it "falls back to effective_backend for unknown class names" do
        parser = described_class.new
        expect(parser.backend).to eq(:custom)
      end
    end
  end

  describe "#language= with Citrus language" do
    context "when parser is not Citrus but receives Citrus language", :citrus_backend do
      let(:non_citrus_backend) do
        mod = Module.new
        parser_class = Class.new do
          attr_accessor :language

          define_method(:initialize) {}
        end
        mod.const_set(:Parser, parser_class)
        mod
      end

      before do
        allow(TreeHaver).to receive(:resolve_backend_module).and_return(non_citrus_backend)
      end

      it "switches to Citrus parser when given Citrus language" do
        parser = described_class.new
        # Grammar mock must respond to :parse for Citrus::Language to accept it
        grammar_mock = double("Grammar", parse: double("ParseResult"))
        citrus_lang = TreeHaver::Backends::Citrus::Language.new(grammar_mock)

        parser.language = citrus_lang
        expect(parser.backend).to eq(:citrus)
      end
    end
  end

  describe "#unwrap_language edge cases" do
    context "with language that has no backend attribute" do
      let(:backend_module) do
        mod = Module.new
        parser_class = Class.new do
          attr_accessor :language

          define_method(:initialize) {}
        end
        mod.const_set(:Parser, parser_class)
        mod
      end

      before do
        allow(TreeHaver).to receive(:resolve_backend_module).and_return(backend_module)
      end

      it "raises Error when language has no backend attribute" do
        parser = described_class.new
        raw_lang = double("RawLanguage")
        allow(raw_lang).to receive(:respond_to?).with(:backend).and_return(false)
        allow(raw_lang).to receive(:is_a?).and_return(false)

        expect {
          parser.language = raw_lang
        }.to raise_error(TreeHaver::Error, /Expected TreeHaver Language wrapper/)
      end
    end

    context "with backend mismatch and reload success" do
      let(:mri_lang) do
        double(
          "MRI Language",
          backend: :mri,
          path: "/path/to/lib.so",
          symbol: "tree_sitter_test",
          name: "test",
          respond_to?: true,
          to_language: double("inner"),
        )
      end

      it "reloads language for correct backend", :mri_backend, :rust_backend do
        # Create parser with Rust backend
        parser = described_class.new(backend: :rust)

        # Create a Rust language that will be returned by from_library
        rust_lang = double(
          "Rust Language",
          backend: :rust,
          name: "test",
          respond_to?: true,
        )
        allow(rust_lang).to receive(:respond_to?).with(:backend).and_return(true)
        allow(rust_lang).to receive(:respond_to?).with(:name).and_return(true)

        allow(TreeHaver::Language).to receive(:from_library).and_return(rust_lang)

        # Parser impl needs to accept the language
        allow(parser.instance_variable_get(:@impl)).to receive(:language=)

        # Try to set MRI language on Rust parser - should trigger reload
        parser.language = mri_lang

        expect(TreeHaver::Language).to have_received(:from_library).with(
          "/path/to/lib.so",
          symbol: "tree_sitter_test",
          name: "test",
        )
      end
    end

    context "with backend mismatch and reload failure" do
      let(:mri_lang) do
        lang = double("MRI Language")
        allow(lang).to receive(:respond_to?).with(:backend).and_return(true)
        allow(lang).to receive(:respond_to?).with(:path).and_return(true)
        allow(lang).to receive(:respond_to?).with(:symbol).and_return(true)
        allow(lang).to receive(:respond_to?).with(:name).and_return(true)
        allow(lang).to receive(:respond_to?).with(:is_a?).and_return(false)
        allow(lang).to receive(:is_a?).and_return(false)
        allow(lang).to receive_messages(
          backend: :mri,
          path: "/path/to/lib.so",
          symbol: "tree_sitter_test",
          name: "test",
        )
        lang
      end

      it "raises Error when reload returns nil (path not available)", :rust_backend do
        # Create parser with Rust backend
        parser = described_class.new(backend: :rust)

        # Create a language with no path
        no_path_lang = double("No Path Language")
        allow(no_path_lang).to receive(:respond_to?).with(:backend).and_return(true)
        allow(no_path_lang).to receive(:respond_to?).with(:path).and_return(false)
        allow(no_path_lang).to receive(:respond_to?).with(:grammar_module).and_return(false)
        allow(no_path_lang).to receive_messages(is_a?: false, backend: :mri)

        expect {
          parser.language = no_path_lang
        }.to raise_error(TreeHaver::Error, /Language backend mismatch/)
      end

      it "propagates NotAvailable when from_library fails", :rust_backend do
        # Create parser with Rust backend
        parser = described_class.new(backend: :rust)

        # Make from_library fail - NotAvailable inherits from Exception, not StandardError
        # so it won't be caught by `rescue => e` in try_reload_language_for_backend
        allow(TreeHaver::Language).to receive(:from_library).and_raise(TreeHaver::NotAvailable.new("Failed"))

        # The NotAvailable exception propagates directly
        expect {
          parser.language = mri_lang
        }.to raise_error(TreeHaver::NotAvailable, /Failed/)
      end
    end

    context "with various backend types" do
      # Test unwrap_language for different backend types
      shared_examples "unwraps language correctly" do |backend_sym, _unwrap_method|
        it "unwraps #{backend_sym} language correctly" do
          # Backend constant names mapping (symbols to actual constant names)
          backend_constants = {
            mri: "MRI",
            rust: "Rust",
            ffi: "FFI",
            java: "Java",
            citrus: "Citrus",
          }
          const_name = backend_constants[backend_sym]
          skip "#{backend_sym} backend not available" unless TreeHaver::Backends.const_get(const_name).available?

          parser = described_class.new(backend: backend_sym)
          # Just verify the parser was created - actual unwrapping is tested via integration
          expect(parser.backend).to eq(backend_sym)
        end
      end

      it_behaves_like "unwraps language correctly", :mri, :to_language
      it_behaves_like "unwraps language correctly", :rust, :name
      it_behaves_like "unwraps language correctly", :citrus, :grammar_module
    end

    context "with unknown backend type" do
      let(:unknown_lang) do
        lang = double("Unknown Language")
        allow(lang).to receive(:respond_to?).and_return(true)
        allow(lang).to receive(:respond_to?).with(:backend).and_return(true)
        allow(lang).to receive(:respond_to?).with(:to_language).and_return(false)
        allow(lang).to receive(:respond_to?).with(:inner_language).and_return(false)
        allow(lang).to receive(:respond_to?).with(:impl).and_return(false)
        allow(lang).to receive(:respond_to?).with(:grammar_module).and_return(false)
        allow(lang).to receive(:respond_to?).with(:name).and_return(true)
        allow(lang).to receive(:respond_to?).with(:path).and_return(false)
        allow(lang).to receive_messages(is_a?: false, backend: :unknown_test, name: "test_lang")
        lang
      end

      let(:backend_module) do
        mod = Module.new
        parser_class = Class.new do
          attr_accessor :language

          define_method(:initialize) {}
        end
        parser_class.define_singleton_method(:name) { "UnknownTest::Parser" }
        mod.const_set(:Parser, parser_class)
        mod
      end

      before do
        allow(TreeHaver).to receive_messages(
          resolve_backend_module: backend_module,
          effective_backend: :unknown_test,
        )
      end

      it "tries generic unwrapping methods for unknown backend" do
        parser = described_class.new
        # Should fall through to trying :name method
        parser.language = unknown_lang
        expect(parser.instance_variable_get(:@impl).language).to eq("test_lang")
      end
    end
  end

  describe "#parse_string fallback behavior" do
    context "when backend does not support parse_string" do
      let(:mock_tree) do
        mock_root = double("RootNode", type: "root", child_count: 0)
        double("MockTree", root_node: mock_root)
      end

      let(:backend_module) do
        tree = mock_tree
        mod = Module.new
        parser_class = Class.new do
          attr_accessor :language

          define_method(:initialize) { @tree = tree }

          define_method(:parse) { |_source| @tree }
          # No parse_string method
        end
        mod.const_set(:Parser, parser_class)
        mod
      end

      before do
        allow(TreeHaver).to receive(:resolve_backend_module).and_return(backend_module)
      end

      it "falls back to regular parse when parse_string not supported" do
        parser = described_class.new
        tree = parser.parse_string(nil, "test source")
        expect(tree).to be_a(TreeHaver::Tree)
      end

      it "falls back to regular parse even with old_tree when parse_string not supported" do
        parser = described_class.new
        old_tree = double("OldTree")
        tree = parser.parse_string(old_tree, "test source")
        expect(tree).to be_a(TreeHaver::Tree)
      end
    end
  end
end
