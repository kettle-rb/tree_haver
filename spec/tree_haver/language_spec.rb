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

    it "raises ArgumentError when path is nil and not registered with a path" do
      # Register without a path (path: nil)
      TreeHaver::LanguageRegistry.register(:no_path_lang, path: nil, symbol: "test")
      expect {
        described_class.no_path_lang
      }.to raise_error(ArgumentError, /path is required/)
    end

    it "uses path from positional argument if kwargs path is nil" do
      TreeHaver.register_language(:pos_arg_lang, path: nil)
      expect {
        # First positional arg should be used as path
        described_class.pos_arg_lang("/path/from/arg.so")
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
end
