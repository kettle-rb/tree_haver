# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Language do
  # NOTE: Do NOT clear languages between tests - can cause issues with backend tracking
  # Use unique language names in each test to avoid conflicts

  describe "::respond_to? for dynamic language helpers" do
    it "does not respond before registration, responds after" do
      # Use a unique name to avoid pollution from other tests
      unique_name = :"respond_to_test_#{SecureRandom.hex(4)}"
      expect(described_class.respond_to?(unique_name)).to be false
      TreeHaver.register_language(unique_name, path: "/nonexistent/libtree-sitter-test.so", symbol: "tree_sitter_test")
      expect(described_class.respond_to?(unique_name)).to be true
    end
  end

  describe "::method_missing dynamic helpers" do
    it "uses registered defaults when invoked without per-call overrides" do
      # Use unique name to avoid pollution from other tests that may register Citrus fallback for :toml
      unique_name = :"toml_defaults_test_#{SecureRandom.hex(4)}"
      TreeHaver.register_language(unique_name, path: "/nonexistent/libtree-sitter-toml.so", symbol: "tree_sitter_toml")
      expect {
        described_class.public_send(unique_name)
      }.to raise_error(TreeHaver::NotAvailable)
    end

    it "allows per-call overrides when registered" do
      # Use unique name to avoid pollution from other tests that may register Citrus fallback for :toml
      unique_name = :"toml_override_test_#{SecureRandom.hex(4)}"
      TreeHaver.register_language(unique_name, path: "/nonexistent/libtree-sitter-toml.so")
      expect {
        described_class.public_send(unique_name, path: "/also/missing/libtree-sitter-toml.so", symbol: "tree_sitter_toml")
      }.to raise_error(TreeHaver::NotAvailable)
    end

    it "raises NoMethodError when trying to call unregistered language" do
      # Without any registration, calling an undefined method should raise NoMethodError
      expect {
        described_class.no_path_lang
      }.to raise_error(NoMethodError)
    end

    it "accepts path as first positional argument" do
      # Register with a tree-sitter path so the language is registered for tree-sitter backends
      TreeHaver.register_language(:pos_arg_lang, path: "/default/path.so")
      # First positional arg should override the registered path
      # This will fail because the path doesn't exist, but it tests the API
      expect {
        described_class.pos_arg_lang("/nonexistent/override.so")
      }.to raise_error(TreeHaver::NotAvailable)
    end
  end

  describe "registration-driven dynamic helpers" do
    it "does not claim to respond to unregistered names" do
      # Use a unique name that will never be registered
      unregistered_name = :"totally_fake_lang_#{SecureRandom.hex(8)}"
      expect(described_class.respond_to?(unregistered_name)).to be(false)
      expect { described_class.public_send(unregistered_name) }.to raise_error(NoMethodError)
    end

    it "responds to registered names and uses stored defaults" do
      # Register with a unique name to avoid collision with other tests
      unique_name = :"toml_respond_test_#{SecureRandom.hex(4)}"
      TreeHaver.register_language(unique_name, path: "/nonexistent/libtree-sitter-toml.so", symbol: "tree_sitter_toml")

      expect(described_class.respond_to?(unique_name)).to be(true)

      # Calling the helper will attempt to dlopen; expect a graceful NotAvailable
      expect {
        described_class.public_send(unique_name)
      }.to raise_error(TreeHaver::NotAvailable)
    end

    it "allows per-call overrides to the registered defaults" do
      # Use unique name to avoid pollution from other tests that may register Citrus fallback for :toml
      unique_name = :"toml_percall_test_#{SecureRandom.hex(4)}"
      TreeHaver.register_language(unique_name, path: "/nonexistent/libtree-sitter-toml.so")

      expect(described_class.respond_to?(unique_name)).to be(true)

      # Provide a different fake path per-call; still results in NotAvailable, but exercises override path
      expect {
        described_class.public_send(unique_name, path: "/also/missing/libtree-sitter-toml.so", symbol: "tree_sitter_toml")
      }.to raise_error(TreeHaver::NotAvailable)
    end
  end

  # These tests mock from_library which only works with native tree-sitter backends.
  # Each backend has its own test block with the appropriate availability tag.
  describe "additional method_missing edge cases" do
    shared_examples "method_missing derives symbol from name" do
      it "derives symbol from name when registration has no symbol" do
        TreeHaver.register_language(:nosymbol, path: "/path.so", symbol: nil)
        expect(described_class).to receive(:from_library).with(
          "/path.so",
          symbol: "tree_sitter_nosymbol",
          name: "nosymbol",
        )
        described_class.nosymbol
      end
    end

    shared_examples "method_missing allows name override" do
      it "allows name override via kwargs" do
        TreeHaver.register_language(:test, path: "/path.so")
        expect(described_class).to receive(:from_library).with(
          "/path.so",
          symbol: "tree_sitter_test",
          name: "custom_name",
        )
        described_class.test(name: "custom_name")
      end
    end

    shared_examples "method_missing allows symbol override" do
      it "allows symbol override via kwargs when key exists" do
        TreeHaver.register_language(:test2, path: "/path.so", symbol: "default_sym")
        expect(described_class).to receive(:from_library).with(
          "/path.so",
          symbol: "custom_sym",
          name: "custom_sym",
        )
        described_class.test2(symbol: "custom_sym")
      end
    end

    context "with MRI backend", :mri_backend do
      it_behaves_like "method_missing derives symbol from name"
      it_behaves_like "method_missing allows name override"
      it_behaves_like "method_missing allows symbol override"
    end

    context "with Rust backend", :rust_backend do
      it_behaves_like "method_missing derives symbol from name"
      it_behaves_like "method_missing allows name override"
      it_behaves_like "method_missing allows symbol override"
    end

    context "with FFI backend", :ffi_backend do
      it_behaves_like "method_missing derives symbol from name"
      it_behaves_like "method_missing allows name override"
      it_behaves_like "method_missing allows symbol override"
    end

    context "with Java backend", :java_backend do
      it_behaves_like "method_missing derives symbol from name"
      it_behaves_like "method_missing allows name override"
      it_behaves_like "method_missing allows symbol override"
    end
  end

  describe "::from_path alias" do
    it "is an alias for from_library" do
      expect(described_class.method(:from_path)).to eq(described_class.method(:from_library))
    end
  end

  describe "::load" do
    it "calls from_library with derived symbol" do
      expect(described_class).to receive(:from_library).with(
        "/path/to/lib.so",
        symbol: "tree_sitter_toml",
        name: "toml",
        validate: true,
      )
      described_class.load("toml", "/path/to/lib.so")
    end

    it "passes validate option" do
      expect(described_class).to receive(:from_library).with(
        "/path/to/lib.so",
        symbol: "tree_sitter_json",
        name: "json",
        validate: false,
      )
      described_class.load("json", "/path/to/lib.so", validate: false)
    end
  end

  describe "::from_library" do
    context "with path validation" do
      it "raises ArgumentError for unsafe path" do
        expect {
          described_class.from_library("../../../etc/passwd.so")
        }.to raise_error(ArgumentError, /Unsafe library path/)
      end

      it "raises ArgumentError for unsafe symbol" do
        expect {
          described_class.from_library("/usr/lib/libtest.so", symbol: "evil; rm -rf /")
        }.to raise_error(ArgumentError, /Unsafe symbol name/)
      end

      it "skips validation when validate: false" do
        allow(TreeHaver).to receive(:resolve_native_backend_module).and_return(nil)
        # Should not raise ArgumentError for path, but will raise NotAvailable
        expect {
          described_class.from_library("../bad/path.so", validate: false)
        }.to raise_error(TreeHaver::NotAvailable, /No TreeHaver backend|No native tree-sitter backend/)
      end
    end

    context "when no backend available" do
      before do
        allow(TreeHaver).to receive(:resolve_native_backend_module).and_return(nil)
      end

      it "raises NotAvailable" do
        expect {
          described_class.from_library("/usr/lib/libtest.so")
        }.to raise_error(TreeHaver::NotAvailable, /No TreeHaver backend|No native tree-sitter backend/)
      end
    end

    context "when backend available" do
      let(:fake_backend_module) do
        mod = Module.new
        lang_class = Class.new do
          define_singleton_method(:from_library) { |*_args, **_kwargs| "loaded_language" }
        end
        mod.const_set(:Language, lang_class)
        mod
      end

      before do
        allow(TreeHaver).to receive(:resolve_native_backend_module).and_return(fake_backend_module)
        TreeHaver::LanguageRegistry.clear_cache!
      end

      it "delegates to backend Language.from_library" do
        result = described_class.from_library("/usr/lib/libtest.so", symbol: "test_sym")
        expect(result).to eq("loaded_language")
      end

      it "caches the result" do
        call_count = 0
        allow(fake_backend_module::Language).to receive(:from_library).and_wrap_original do |method, *args, **kwargs|
          call_count += 1
          method.call(*args, **kwargs)
        end

        described_class.from_library("/usr/lib/libtest.so", symbol: "test_sym")
        described_class.from_library("/usr/lib/libtest.so", symbol: "test_sym")
        expect(call_count).to eq(1)
      end
    end

    context "when backend only has from_path (legacy)" do
      let(:legacy_backend_module) do
        mod = Module.new
        lang_class = Class.new do
          # Only from_path, not from_library
          define_singleton_method(:from_path) { |_path| "loaded_via_from_path" }
        end
        mod.const_set(:Language, lang_class)
        mod
      end

      before do
        allow(TreeHaver).to receive(:resolve_native_backend_module).and_return(legacy_backend_module)
        TreeHaver::LanguageRegistry.clear_cache!
      end

      it "falls back to from_path when from_library not available" do
        result = described_class.from_library("/usr/lib/libtest.so", symbol: "test_sym")
        expect(result).to eq("loaded_via_from_path")
      end
    end
  end

  describe "method_missing edge cases" do
    context "with Citrus backend" do
      before do
        TreeHaver.backend = :citrus
      end

      after do
        TreeHaver.backend = :auto
      end

      it "raises NoMethodError when no registration found" do
        expect {
          described_class.unregistered_lang_citrus_test
        }.to raise_error(NoMethodError)
      end
    end

    context "with Citrus-only registration and tree-sitter backend" do
      before do
        TreeHaver.backend = :mri
        # Register only for Citrus, not tree-sitter - use unique name
        TreeHaver::LanguageRegistry.register(
          :test_lang_citrus_only,
          :citrus,
          grammar_module: double("Grammar", parse: true),
        )
      end

      after do
        TreeHaver.backend = :auto
      end

      it "falls back to Citrus when tree-sitter registration not available" do
        # With our new fallback behavior, when only Citrus is registered
        # and tree-sitter backend is active, we fall back to Citrus
        language = described_class.test_lang_citrus_only
        expect(language).to be_a(TreeHaver::Backends::Citrus::Language)
      end
    end
  end

  context "with backend parameter and caching" do
    after do
      # Clean up thread-local state
      Thread.current[:tree_haver_backend_context] = nil
      TreeHaver.reset_backend!(to: :auto)
      # Doing this might make the specs brittle since the state of the ruby process
      # can be polluted by certain backends that conflict with other backends, and they can't be unloaded.
      # TreeHaver::LanguageRegistry.clear_cache!
    end

    describe "::from_library" do
      let(:mock_path) { "/fake/path/to/grammar.so" }
      let(:mock_symbol) { "tree_sitter_test" }

      before do
        # Allow path validation to pass
        allow(TreeHaver::PathValidator).to receive_messages(
          safe_library_path?: true,
          safe_symbol_name?: true,
        )
      end

      context "with no backend parameter" do
        # These tests use MRI backend which is available when ruby_tree_sitter is loaded
        it "uses effective backend from context", :mri_backend do
          mock_language = double("Language")
          allow(TreeHaver::Backends::MRI::Language).to receive(:from_library)
            .and_return(mock_language)

          TreeHaver.with_backend(:mri) do
            language = described_class.from_library(mock_path, symbol: mock_symbol)
            expect(language).to eq(mock_language)
          end
        end

        it "uses global backend when no context set", :mri_backend do
          mock_language = double("Language")
          allow(TreeHaver::Backends::MRI::Language).to receive(:from_library)
            .and_return(mock_language)

          TreeHaver.backend = :mri
          language = described_class.from_library(mock_path, symbol: mock_symbol)
          expect(language).to eq(mock_language)
        end
      end

      context "with explicit backend parameter" do
        # Test using Rust backend explicitly while MRI is the context backend
        # (Rust and MRI can coexist, unlike FFI and MRI)
        it "uses specified backend regardless of context", :mri_backend, :rust_backend do
          mock_language = double("Language")
          allow(TreeHaver::Backends::Rust::Language).to receive(:from_library)
            .and_return(mock_language)

          TreeHaver.with_backend(:mri) do
            language = described_class.from_library(
              mock_path,
              symbol: mock_symbol,
              backend: :rust,
            )
            expect(language).to eq(mock_language)
          end

          expect(TreeHaver::Backends::Rust::Language).to have_received(:from_library)
        end

        it "overrides global backend setting", :mri_backend, :rust_backend do
          mock_language = double("Language")
          allow(TreeHaver::Backends::Rust::Language).to receive(:from_library)
            .and_return(mock_language)

          TreeHaver.backend = :mri
          language = described_class.from_library(
            mock_path,
            symbol: mock_symbol,
            backend: :rust,
          )
          expect(language).to eq(mock_language)
        end

        it "raises NotAvailable when requested backend is not available" do
          # Try to use a backend that definitely won't be available
          unavailable_backend = if defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
            :mri  # MRI backend won't work on JRuby
          else
            :java  # Java backend won't work on MRI
          end

          expect do
            described_class.from_library(
              mock_path,
              symbol: mock_symbol,
              backend: unavailable_backend,
            )
          end.to raise_error(TreeHaver::NotAvailable, /Requested backend .* is not available/)
        end
      end
    end

    describe "Backend-aware language caching" do
      let(:mock_path) { "/fake/path/to/grammar.so" }
      let(:mock_symbol) { "tree_sitter_test" }

      before do
        allow(TreeHaver::PathValidator).to receive_messages(
          safe_library_path?: true,
          safe_symbol_name?: true,
        )
      end

      # Tests use Rust + MRI which can coexist (unlike FFI + MRI)
      it "caches language separately per backend", :mri_backend, :rust_backend do
        rust_language = double("Rust Language")
        mri_language = double("MRI Language")

        allow(TreeHaver::Backends::Rust::Language).to receive(:from_library)
          .and_return(rust_language)
        allow(TreeHaver::Backends::MRI::Language).to receive(:from_library)
          .and_return(mri_language)

        # Load with Rust backend
        lang1 = described_class.from_library(
          mock_path,
          symbol: mock_symbol,
          backend: :rust,
        )

        # Load same path with MRI backend - should be different cached object
        lang2 = described_class.from_library(
          mock_path,
          symbol: mock_symbol,
          backend: :mri,
        )

        expect(lang1).to eq(rust_language)
        expect(lang2).to eq(mri_language)
        expect(lang1).not_to eq(lang2)
      end

      it "returns cached language for same backend and path", :mri_backend do
        mock_language = double("Language")
        allow(TreeHaver::Backends::MRI::Language).to receive(:from_library)
          .and_return(mock_language)

        lang1 = described_class.from_library(
          mock_path,
          symbol: mock_symbol,
          backend: :mri,
        )
        lang2 = described_class.from_library(
          mock_path,
          symbol: mock_symbol,
          backend: :mri,
        )

        expect(lang1).to eq(lang2)
        expect(lang1.object_id).to eq(lang2.object_id)  # Same object from cache
        expect(TreeHaver::Backends::MRI::Language).to have_received(:from_library).once
      end

      it "uses thread-local context in cache key", :mri_backend, :rust_backend do
        rust_language = double("Rust Language")
        mri_language = double("MRI Language")

        allow(TreeHaver::Backends::Rust::Language).to receive(:from_library)
          .and_return(rust_language)
        allow(TreeHaver::Backends::MRI::Language).to receive(:from_library)
          .and_return(mri_language)

        # Load with Rust context
        lang1 = nil
        TreeHaver.with_backend(:rust) do
          lang1 = described_class.from_library(mock_path, symbol: mock_symbol)
        end

        # Load with MRI context - should be different
        lang2 = nil
        TreeHaver.with_backend(:mri) do
          lang2 = described_class.from_library(mock_path, symbol: mock_symbol)
        end

        expect(lang1).to eq(rust_language)
        expect(lang2).to eq(mri_language)
        expect(lang1).not_to eq(lang2)
      end

      it "prevents cache pollution between backends", :mri_backend, :rust_backend do
        rust_language = double("Rust Language")
        mri_language = double("MRI Language")

        allow(TreeHaver::Backends::Rust::Language).to receive(:from_library)
          .and_return(rust_language)
        allow(TreeHaver::Backends::MRI::Language).to receive(:from_library)
          .and_return(mri_language)

        # Load with different backends - should call backend-specific loader each time
        lang1 = described_class.from_library(
          mock_path,
          symbol: mock_symbol,
          backend: :rust,
        )
        lang2 = described_class.from_library(
          mock_path,
          symbol: mock_symbol,
          backend: :mri,
        )

        # Load again with Rust - should use cache
        lang3 = described_class.from_library(
          mock_path,
          symbol: mock_symbol,
          backend: :rust,
        )

        expect(lang1).to eq(rust_language)
        expect(lang2).to eq(mri_language)
        expect(lang3).to eq(rust_language)
        expect(lang1.object_id).to eq(lang3.object_id)  # Same cached object

        expect(TreeHaver::Backends::Rust::Language).to have_received(:from_library).once
        expect(TreeHaver::Backends::MRI::Language).to have_received(:from_library).once
      end
    end

    describe "Thread-safe language loading" do
      let(:mock_path) { "/fake/path/to/grammar.so" }
      let(:mock_symbol) { "tree_sitter_test" }

      before do
        allow(TreeHaver::PathValidator).to receive_messages(
          safe_library_path?: true,
          safe_symbol_name?: true,
        )
      end

      # Use Rust + MRI which both support from_library and can coexist
      it "loads languages with different backends in concurrent threads", :mri_backend, :rust_backend do
        rust_language = double("Rust Language")
        mri_language = double("MRI Language")

        allow(TreeHaver::Backends::Rust::Language).to receive(:from_library)
          .and_return(rust_language)
        allow(TreeHaver::Backends::MRI::Language).to receive(:from_library)
          .and_return(mri_language)

        results = Concurrent::Array.new if defined?(Concurrent::Array)
        results ||= []
        mutex = Mutex.new

        thread1 = Thread.new do
          TreeHaver.with_backend(:rust) do
            lang = described_class.from_library(mock_path, symbol: mock_symbol)
            mutex.synchronize { results << {thread: 1, language: lang} }
          end
        end

        thread2 = Thread.new do
          TreeHaver.with_backend(:mri) do
            lang = described_class.from_library(mock_path, symbol: mock_symbol)
            mutex.synchronize { results << {thread: 2, language: lang} }
          end
        end

        thread1.join
        thread2.join

        expect(results.size).to eq(2)
        expect(results.find { |r| r[:thread] == 1 }[:language]).to eq(rust_language)
        expect(results.find { |r| r[:thread] == 2 }[:language]).to eq(mri_language)
      end

      it "loads languages with explicit backends in concurrent threads", :mri_backend, :rust_backend do
        rust_language = double("Rust Language")
        mri_language = double("MRI Language")

        allow(TreeHaver::Backends::Rust::Language).to receive(:from_library)
          .and_return(rust_language)
        allow(TreeHaver::Backends::MRI::Language).to receive(:from_library)
          .and_return(mri_language)

        results = Concurrent::Array.new if defined?(Concurrent::Array)
        results ||= []
        mutex = Mutex.new

        thread1 = Thread.new do
          lang = described_class.from_library(
            mock_path,
            symbol: mock_symbol,
            backend: :rust,
          )
          mutex.synchronize { results << {thread: 1, language: lang} }
        end

        thread2 = Thread.new do
          lang = described_class.from_library(
            mock_path,
            symbol: mock_symbol,
            backend: :mri,
          )
          mutex.synchronize { results << {thread: 2, language: lang} }
        end

        thread1.join
        thread2.join

        expect(results.size).to eq(2)
        expect(results.find { |r| r[:thread] == 1 }[:language]).to eq(rust_language)
        expect(results.find { |r| r[:thread] == 2 }[:language]).to eq(mri_language)
      end
    end

    describe "Backward compatibility" do
      let(:mock_path) { "/fake/path/to/grammar.so" }
      let(:mock_symbol) { "tree_sitter_test" }

      before do
        allow(TreeHaver::PathValidator).to receive_messages(
          safe_library_path?: true,
          safe_symbol_name?: true,
        )
      end

      shared_examples "from_library works without backend parameter" do |backend_sym, backend_mod|
        before do
          TreeHaver.backend = backend_sym
        end

        it "works without backend parameter (existing behavior)" do
          mock_language = double("Language")
          allow(backend_mod::Language).to receive(:from_library).and_return(mock_language)

          language = described_class.from_library(mock_path, symbol: mock_symbol)
          expect(language).to eq(mock_language)
        end
      end

      context "with MRI backend", :mri_backend do
        it_behaves_like "from_library works without backend parameter", :mri, TreeHaver::Backends::MRI
      end

      context "with Rust backend", :rust_backend do
        it_behaves_like "from_library works without backend parameter", :rust, TreeHaver::Backends::Rust
      end

      context "with FFI backend", :ffi_backend do
        it_behaves_like "from_library works without backend parameter", :ffi, TreeHaver::Backends::FFI
      end

      context "with Java backend", :java_backend do
        it_behaves_like "from_library works without backend parameter", :java, TreeHaver::Backends::Java
      end

      it "respects global backend setting (existing behavior)", :mri_backend do
        mock_language = double("Language")
        allow(TreeHaver::Backends::MRI::Language).to receive(:from_library)
          .and_return(mock_language)

        TreeHaver.backend = :mri
        language = described_class.from_library(mock_path, symbol: mock_symbol)
        expect(language).to eq(mock_language)
      end
    end
  end

  describe "method_missing Citrus fallback scenarios" do
    context "when Citrus backend is active but registration has no grammar_module" do
      before do
        TreeHaver.backend = :citrus
        # Register for Citrus but without grammar_module
        TreeHaver::LanguageRegistry.register(
          :citrus_no_grammar_test,
          :citrus,
          grammar_module: nil,
        )
      end

      after do
        TreeHaver.backend = :auto
      end

      it "raises NotAvailable when Citrus registration has no grammar_module" do
        expect {
          described_class.citrus_no_grammar_test
        }.to raise_error(TreeHaver::NotAvailable, /no Citrus grammar registered/)
      end
    end

    context "when tree-sitter backend is active with no tree-sitter registration" do
      before do
        TreeHaver.backend = :mri
      end

      after do
        TreeHaver.backend = :auto
      end

      it "raises ArgumentError when no compatible registration found" do
        # Register only for Citrus, then try to use with MRI backend
        TreeHaver::LanguageRegistry.register(
          :no_ts_path_test,
          :citrus,
          grammar_module: nil,  # No valid Citrus grammar
        )

        expect {
          described_class.no_ts_path_test
        }.to raise_error(ArgumentError, /No grammar registered.*compatible with tree_sitter backend/)
      end
    end

    context "when tree-sitter fails and Citrus fallback is available" do
      before do
        TreeHaver.backend = :mri
        # Register both tree-sitter (with bad path) and Citrus fallback
        TreeHaver::LanguageRegistry.register(
          :ts_fail_citrus_fallback_test,
          :tree_sitter,
          path: "/nonexistent/path.so",
          symbol: "tree_sitter_test",
        )
        TreeHaver::LanguageRegistry.register(
          :ts_fail_citrus_fallback_test,
          :citrus,
          grammar_module: double("Grammar", parse: true),
        )
      end

      after do
        TreeHaver.backend = :auto
      end

      it "falls back to Citrus when tree-sitter loading fails" do
        language = described_class.ts_fail_citrus_fallback_test
        expect(language).to be_a(TreeHaver::Backends::Citrus::Language)
      end
    end

    context "when tree-sitter fails and no Citrus fallback available" do
      before do
        TreeHaver.backend = :mri
        # Register only tree-sitter (with bad path), no Citrus
        TreeHaver::LanguageRegistry.register(
          :ts_fail_no_fallback_test,
          :tree_sitter,
          path: "/nonexistent/path.so",
          symbol: "tree_sitter_test",
        )
      end

      after do
        TreeHaver.backend = :auto
      end

      it "re-raises the original error when no Citrus fallback" do
        expect {
          described_class.ts_fail_no_fallback_test
        }.to raise_error(TreeHaver::NotAvailable)
      end
    end
  end

  describe "respond_to_missing?" do
    it "returns true for registered language names" do
      TreeHaver::LanguageRegistry.register(
        :respond_test_lang,
        :tree_sitter,
        path: "/path.so",
      )
      expect(described_class.respond_to?(:respond_test_lang)).to be true
    end

    it "returns false for unregistered language names" do
      expect(described_class.respond_to?(:definitely_not_registered_xyz)).to be false
    end

    it "delegates to super for non-language methods" do
      # Standard Object methods should still work
      expect(described_class.respond_to?(:to_s)).to be true
      expect(described_class.respond_to?(:class)).to be true
    end
  end
end
