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
      TreeHaver.register_language(:toml, path: "/nonexistent/libtree-sitter-toml.so", symbol: "tree_sitter_toml")
      expect {
        described_class.toml
      }.to raise_error(TreeHaver::NotAvailable)
    end

    it "allows per-call overrides when registered" do
      TreeHaver.register_language(:toml, path: "/nonexistent/libtree-sitter-toml.so")
      expect {
        described_class.toml(path: "/also/missing/libtree-sitter-toml.so", symbol: "tree_sitter_toml")
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
      TreeHaver.register_language(:toml, path: "/nonexistent/libtree-sitter-toml.so")

      expect(described_class.respond_to?(:toml)).to be(true)

      # Provide a different fake path per-call; still results in NotAvailable, but exercises override path
      expect {
        described_class.toml(path: "/also/missing/libtree-sitter-toml.so", symbol: "tree_sitter_toml")
      }.to raise_error(TreeHaver::NotAvailable)
    end
  end

  describe "additional method_missing edge cases" do
    it "derives symbol from name when registration has no symbol" do
      TreeHaver.register_language(:nosymbol, path: "/path.so", symbol: nil)
      # When no symbol is registered, it derives "tree_sitter_#{method_name}"
      # and name is derived from symbol by stripping "tree_sitter_" prefix
      expect(described_class).to receive(:from_library).with(
        "/path.so",
        symbol: "tree_sitter_nosymbol",
        name: "nosymbol",
      )
      described_class.nosymbol
    end

    it "allows name override via kwargs" do
      TreeHaver.register_language(:test, path: "/path.so")
      # Symbol is derived as "tree_sitter_test", but name is explicitly overridden
      expect(described_class).to receive(:from_library).with(
        "/path.so",
        symbol: "tree_sitter_test",
        name: "custom_name",
      )
      described_class.test(name: "custom_name")
    end

    it "allows symbol override via kwargs when key exists" do
      TreeHaver.register_language(:test2, path: "/path.so", symbol: "default_sym")
      # Symbol is overridden via kwargs, name is derived from the overridden symbol
      expect(described_class).to receive(:from_library).with(
        "/path.so",
        symbol: "custom_sym",
        name: "custom_sym",  # Derived from symbol (no tree_sitter_ prefix to strip)
      )
      described_class.test2(symbol: "custom_sym")
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
        allow(TreeHaver).to receive(:backend_module).and_return(nil)
        # Should not raise ArgumentError for path, but will raise NotAvailable
        expect {
          described_class.from_library("../bad/path.so", validate: false)
        }.to raise_error(TreeHaver::NotAvailable, /No TreeHaver backend/)
      end
    end

    context "when no backend available" do
      before do
        allow(TreeHaver).to receive(:backend_module).and_return(nil)
      end

      it "raises NotAvailable" do
        expect {
          described_class.from_library("/usr/lib/libtest.so")
        }.to raise_error(TreeHaver::NotAvailable, /No TreeHaver backend/)
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
        allow(TreeHaver).to receive(:backend_module).and_return(fake_backend_module)
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
        allow(TreeHaver).to receive(:backend_module).and_return(legacy_backend_module)
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
end
