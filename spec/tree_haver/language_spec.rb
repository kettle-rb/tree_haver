# frozen_string_literal: true

RSpec.describe TreeHaver::Language do
  before do
    TreeHaver.clear_languages!
  end

  after do
    TreeHaver.clear_languages!
  end

  describe "::respond_to? for dynamic language helpers" do
    it "does not respond before registration, responds after" do
      expect(described_class.respond_to?(:toml)).to be false
      TreeHaver.register_language(:toml, path: "/nonexistent/libtree-sitter-toml.so", symbol: "tree_sitter_toml")
      expect(described_class.respond_to?(:toml)).to be true
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
      expect(described_class.respond_to?(:toml)).to be(false)
      expect { described_class.toml }.to raise_error(NoMethodError)
    end

    it "responds to registered names and uses stored defaults" do
      # Register a fake path just to test dispatch behavior without requiring native libs
      TreeHaver.register_language(:toml, path: "/nonexistent/libtree-sitter-toml.so", symbol: "tree_sitter_toml")

      expect(described_class.respond_to?(:toml)).to be(true)

      # Calling the helper will attempt to dlopen; expect a graceful NotAvailable
      expect {
        described_class.toml
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
      expect(TreeHaver::Language).to receive(:from_library).with(
        "/path.so",
        symbol: "tree_sitter_nosymbol",
        name: "nosymbol",
      )
      described_class.nosymbol
    end

    it "allows name override via kwargs" do
      TreeHaver.register_language(:test, path: "/path.so")
      expect(TreeHaver::Language).to receive(:from_library).with(
        "/path.so",
        symbol: "tree_sitter_test",
        name: "custom_name",
      )
      described_class.test(name: "custom_name")
    end

    it "allows symbol override via kwargs when key exists" do
      TreeHaver.register_language(:test2, path: "/path.so", symbol: "default_sym")
      expect(TreeHaver::Language).to receive(:from_library).with(
        "/path.so",
        symbol: "custom_sym",
        name: "test2",
      )
      described_class.test2(symbol: "custom_sym")
    end
  end

  describe ".from_path alias" do
    it "is an alias for from_library" do
      expect(described_class.method(:from_path)).to eq(described_class.method(:from_library))
    end
  end
end
