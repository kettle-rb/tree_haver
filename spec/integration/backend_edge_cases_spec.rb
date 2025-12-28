# frozen_string_literal: true

require "spec_helper"

# Integration tests for backend-specific edge cases
# Tests are tagged per-backend rather than at the top level
RSpec.describe "Backend-specific behaviors" do
  before do
    TreeHaver::LanguageRegistry.clear_cache!
  end

  after do
    TreeHaver::LanguageRegistry.clear_cache!
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "with_backend block isolation tests" do
    it "runs simple code in FFI backend block", :ffi do
      result = nil
      TreeHaver.with_backend(:ffi) do
        result = 1 + 1
      end
      expect(result).to eq(2)
    end

    it "runs simple code in MRI backend block", :mri_backend do
      result = nil
      TreeHaver.with_backend(:mri) do
        result = 1 + 1
      end
      expect(result).to eq(2)
    end

    it "creates FFI parser without language", :ffi do
      TreeHaver.with_backend(:ffi) do
        parser = TreeHaver::Parser.new
        expect(parser).to be_a(TreeHaver::Parser)
      end
    end

    it "creates MRI parser without language", :mri_backend do
      TreeHaver.with_backend(:mri) do
        parser = TreeHaver::Parser.new
        expect(parser).to be_a(TreeHaver::Parser)
      end
    end

    it "loads FFI language without setting on parser", :ffi, :toml_grammar do
      TreeHaver.with_backend(:ffi) do
        path = TreeHaverDependencies.find_toml_grammar_path
        language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
        expect(language).to be_a(TreeHaver::Backends::FFI::Language)
      end
    end

    it "loads MRI language without setting on parser", :mri_backend, :toml_grammar do
      TreeHaver.with_backend(:mri) do
        path = TreeHaverDependencies.find_toml_grammar_path
        language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
        expect(language).to be_a(TreeHaver::Backends::MRI::Language)
      end
    end

    it "sets FFI language on parser", :ffi, :toml_grammar do
      TreeHaver.with_backend(:ffi) do
        path = TreeHaverDependencies.find_toml_grammar_path
        language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
        parser = TreeHaver::Parser.new
        parser.language = language
        expect(parser).to be_a(TreeHaver::Parser)
      end
    end

    it "sets MRI language on parser", :mri_backend, :toml_grammar do
      TreeHaver.with_backend(:mri) do
        path = TreeHaverDependencies.find_toml_grammar_path
        language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
        parser = TreeHaver::Parser.new
        parser.language = language
        expect(parser).to be_a(TreeHaver::Parser)
      end
    end
  end

  describe "FFI backend edge cases", :ffi, :toml_grammar do
    before do
      TreeHaver::LanguageRegistry.clear_cache!
      TreeHaver.backend = :ffi
    end

    after do
      TreeHaver::LanguageRegistry.clear_cache!
      TreeHaver.reset_backend!(to: :auto)
    end

    it "handles language loading with symbol parameter" do
      path = TreeHaverDependencies.find_toml_grammar_path

      # Load with explicit symbol
      language = TreeHaver::Backends::FFI::Language.from_library(
        path,
        symbol: "tree_sitter_toml",
      )

      expect(language).not_to be_nil
      expect(language).to be_a(TreeHaver::Backends::FFI::Language)
    end

    it "creates and uses parser" do
      TreeHaver.with_backend(:ffi) do
        parser = TreeHaver::Parser.new

        path = TreeHaverDependencies.find_toml_grammar_path
        language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
        parser.language = language

        tree = parser.parse("x = 42")
        expect(tree).to be_a(TreeHaver::Tree)
        expect(tree.root_node).not_to be_nil
      end
    end

    describe "Tree finalizer behavior" do
      it "creates finalizer for tree objects" do
        TreeHaver.with_backend(:ffi) do
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
          GC.start
        end
      end
    end
  end

  describe "MRI backend edge cases", :mri_backend, :toml_grammar do
    before do
      skip "MRI backend not available" unless TreeHaver::Backends::MRI.available?
      TreeHaver::LanguageRegistry.clear_cache!
    end

    after do
      TreeHaver::LanguageRegistry.clear_cache!
    end

    it "handles language loading" do
      TreeHaver.with_backend(:mri) do
        path = TreeHaverDependencies.find_toml_grammar_path

        language = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
        expect(language).not_to be_nil
      end
    end

    it "creates parser successfully" do
      TreeHaver.with_backend(:mri) do
        parser = TreeHaver::Parser.new
        expect(parser).to be_a(TreeHaver::Parser)
      end
    end
  end

  describe "Citrus backend edge cases", :citrus_backend do
    before do
      require "toml-rb"
    rescue LoadError
      skip "toml-rb gem not available"
    end

    it "handles grammar module registration" do
      TreeHaver.register_language(
        :toml_citrus_test,
        grammar_module: TomlRB::Document,
        gem_name: "toml-rb",
      )

      TreeHaver.backend = :citrus
      lang = TreeHaver::Language.toml_citrus_test
      expect(lang).to be_a(TreeHaver::Backends::Citrus::Language)
    end

    it "parses source using Citrus grammar" do
      TreeHaver.register_language(
        :toml_citrus_parse,
        grammar_module: TomlRB::Document,
        gem_name: "toml-rb",
      )

      TreeHaver.backend = :citrus
      parser = TreeHaver::Parser.new
      lang = TreeHaver::Language.toml_citrus_parse
      parser.language = lang

      tree = parser.parse("x = 42")
      expect(tree).to be_a(TreeHaver::Tree)
      expect(tree.root_node).not_to be_nil
    end

    describe "Node#structural? edge cases" do
      it "identifies structural nodes correctly" do
        TreeHaver.register_language(
          :toml_structural,
          grammar_module: TomlRB::Document,
          gem_name: "toml-rb",
        )

        TreeHaver.backend = :citrus
        parser = TreeHaver::Parser.new
        lang = TreeHaver::Language.toml_structural
        parser.language = lang

        tree = parser.parse("name = \"value\"")
        root = tree.root_node

        # Root should be structural
        expect(root.structural?).to be true
      end
    end
  end

  # These tests check availability and don't require any specific backend to be active
  describe "Backend availability checks" do
    it "checks Java backend availability" do
      available = TreeHaver::Backends::Java.available?
      expect(available).to be(true).or be(false)
    end

    it "checks MRI backend availability" do
      available = TreeHaver::Backends::MRI.available?
      expect(available).to be(true).or be(false)
    end

    it "checks Rust backend availability" do
      available = TreeHaver::Backends::Rust.available?
      expect(available).to be(true).or be(false)
    end

    it "checks FFI backend availability" do
      available = TreeHaver::Backends::FFI.available?
      expect(available).to be(true).or be(false)
    end

    it "checks Citrus backend availability" do
      available = TreeHaver::Backends::Citrus.available?
      # Citrus is always available (built-in)
      expect(available).to be true
    end
  end
end
