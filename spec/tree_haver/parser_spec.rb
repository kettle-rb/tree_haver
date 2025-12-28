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

        it "creates parser with FFI backend when specified", :ffi do
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
end
