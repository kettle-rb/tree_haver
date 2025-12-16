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
      expect(TreeHaver::Language).to receive(:from_library).with(
        "/path.so",
        symbol: "tree_sitter_nosymbol",
        name: "nosymbol",
      )
      described_class.nosymbol
    end

    it "allows name override via kwargs" do
      TreeHaver.register_language(:test, path: "/path.so")
      # Symbol is derived as "tree_sitter_test", but name is explicitly overridden
      expect(TreeHaver::Language).to receive(:from_library).with(
        "/path.so",
        symbol: "tree_sitter_test",
        name: "custom_name",
      )
      described_class.test(name: "custom_name")
    end

    it "allows symbol override via kwargs when key exists" do
      TreeHaver.register_language(:test2, path: "/path.so", symbol: "default_sym")
      # Symbol is overridden via kwargs, name is derived from the overridden symbol
      expect(TreeHaver::Language).to receive(:from_library).with(
        "/path.so",
        symbol: "custom_sym",
        name: "custom_sym",  # Derived from symbol (no tree_sitter_ prefix to strip)
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
