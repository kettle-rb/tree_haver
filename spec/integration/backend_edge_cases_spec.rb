# frozen_string_literal: true

# Integration tests for backend-specific edge cases
RSpec.describe "Backend-specific behaviors", :ffi do
  describe "FFI backend edge cases", :toml_grammar do
    before do
      skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?
    end

    it "handles language loading with symbol parameter" do
      path = TreeHaverDependencies.find_toml_grammar_path

      # Load with explicit symbol
      language = TreeHaver::Backends::FFI::Language.from_library(
        path,
        symbol: "tree_sitter_toml"
      )

      expect(language).not_to be_nil
      expect(language).to be_a(TreeHaver::Backends::FFI::Language)
    end

    it "creates and uses parser" do
      TreeHaver.backend = :ffi
      parser = TreeHaver::Parser.new

      path = TreeHaverDependencies.find_toml_grammar_path
      language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
      parser.language = language

      tree = parser.parse("x = 42")
      expect(tree).to be_a(TreeHaver::Tree)
      expect(tree.root_node).not_to be_nil
    end

    describe "Tree finalizer behavior" do
      it "creates finalizer for tree objects" do
        TreeHaver.backend = :ffi
        parser = TreeHaver::Parser.new

        path = TreeHaverDependencies.find_toml_grammar_path
        language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
        parser.language = language

        tree = parser.parse("x = 42")

        # The tree should have a finalizer registered
        # This is internal behavior - we can't directly test the finalizer
        # but we can verify the tree works correctly
        expect(tree.root_node.type).to be_a(String)

        # Force tree to go out of scope (finalizer will run eventually)
        tree = nil
        GC.start
      end
    end
  end

  describe "MRI backend edge cases", :toml_grammar, :not_ffi do
    before do
      skip "MRI backend not available" unless TreeHaver::Backends::MRI.available?
    end

    it "handles language loading" do
      TreeHaver.backend = :mri
      path = TreeHaverDependencies.find_toml_grammar_path

      language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
      expect(language).not_to be_nil
    end

    it "creates parser successfully" do
      TreeHaver.backend = :mri
      parser = TreeHaver::Parser.new
      expect(parser).to be_a(TreeHaver::Parser)
    end
  end

  describe "Citrus backend edge cases" do
    before do
      begin
        require "toml-rb"
      rescue LoadError
        skip "toml-rb gem not available"
      end
    end

    it "handles grammar module registration" do
      TreeHaver.register_language(
        :toml,
        grammar_module: TomlRB::Document,
        gem_name: "toml-rb"
      )

      TreeHaver.backend = :citrus
      lang = TreeHaver::Language.toml
      expect(lang).to be_a(TreeHaver::Backends::Citrus::Language)
    end

    it "parses source using Citrus grammar" do
      TreeHaver.register_language(
        :toml,
        grammar_module: TomlRB::Document,
        gem_name: "toml-rb"
      )

      TreeHaver.backend = :citrus
      parser = TreeHaver::Parser.new
      lang = TreeHaver::Language.toml
      parser.language = lang

      tree = parser.parse("x = 42")
      expect(tree).to be_a(TreeHaver::Tree)
      expect(tree.root_node).not_to be_nil
    end

    describe "Node#structural? edge cases" do
      it "identifies structural nodes correctly" do

        TreeHaver.register_language(
          :toml,
          grammar_module: TomlRB::Document,
          gem_name: "toml-rb"
        )

        TreeHaver.backend = :citrus
        parser = TreeHaver::Parser.new
        lang = TreeHaver::Language.toml
        parser.language = lang

        tree = parser.parse("name = \"value\"")
        root = tree.root_node

        # Root should be structural
        expect(root.structural?).to be true
      end
    end
  end

  describe "Backend availability checks" do
    it "checks Java backend availability" do
      available = TreeHaver::Backends::Java.available?
      expect([true, false]).to include(available)
    end

    it "checks MRI backend availability" do
      available = TreeHaver::Backends::MRI.available?
      expect([true, false]).to include(available)
    end

    it "checks Rust backend availability" do
      available = TreeHaver::Backends::Rust.available?
      expect([true, false]).to include(available)
    end

    it "checks FFI backend availability" do
      available = TreeHaver::Backends::FFI.available?
      expect([true, false]).to include(available)
    end

    it "checks Citrus backend availability" do
      available = TreeHaver::Backends::Citrus.available?
      # Citrus is always available (built-in)
      expect(available).to be true
    end
  end
end

