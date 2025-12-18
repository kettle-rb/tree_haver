# frozen_string_literal: true

require "spec_helper"

# Integration tests for multi-backend scenarios and backend switching
# NOTE: These tests use Citrus and MRI backends which can coexist.
# FFI backend tests must run in isolation - see bin/rspec-ffi
RSpec.describe "Multi-backend integration", :toml_grammar do
  after do
    TreeHaver.reset_backend!(to: :auto)
    Thread.current[:tree_haver_backend_context] = nil
  end

  describe "backend switching during parsing" do
    it "caches languages per backend correctly" do
      path = TreeHaverDependencies.find_toml_grammar_path

      # Register language for Citrus backend
      TreeHaver.register_language(
        :toml_test,
        path: path,
        symbol: "tree_sitter_toml",
        grammar_module: TomlRB::Document,
        gem_name: "toml-rb",
      )

      # Load with Citrus
      TreeHaver.backend = :citrus
      if TreeHaver::Backends::Citrus.available?
        lang_citrus = TreeHaver::Language.toml_test
        expect(lang_citrus).to be_a(TreeHaver::Backends::Citrus::Language)
      end

      # Load with MRI - should get different cached object
      TreeHaver.backend = :mri
      if TreeHaver::Backends::MRI.available?
        lang_mri = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
        expect(lang_mri).to be_a(TreeHaver::Backends::MRI::Language)

        # Should be different objects due to backend-aware caching
        if defined?(lang_citrus)
          expect(lang_mri.class).not_to eq(lang_citrus.class)
        end
      end
    end

    it "allows parsing with different backends sequentially" do
      path = TreeHaverDependencies.find_toml_grammar_path
      source = "x = 42"

      # Register language for Citrus backend
      TreeHaver.register_language(
        :toml_parse,
        path: path,
        symbol: "tree_sitter_toml",
        grammar_module: TomlRB::Document,
        gem_name: "toml-rb",
      )

      # Parse with Citrus backend
      TreeHaver.backend = :citrus
      if TreeHaver::Backends::Citrus.available?
        parser1 = TreeHaver::Parser.new
        lang1 = TreeHaver::Language.toml_parse
        parser1.language = lang1
        tree1 = parser1.parse(source)
        expect(tree1.root_node).not_to be_nil
      end

      # Parse with MRI backend
      TreeHaver.backend = :mri
      if TreeHaver::Backends::MRI.available?
        parser2 = TreeHaver::Parser.new
        lang2 = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
        parser2.language = lang2
        tree2 = parser2.parse(source)
        expect(tree2.root_node).not_to be_nil
      end
    end
  end

  describe "thread-local backend with language loading" do
    it "loads correct backend language in thread context" do
      path = TreeHaverDependencies.find_toml_grammar_path

      results = []
      mutex = Mutex.new

      # Use MRI and Rust which can coexist (not FFI which conflicts with MRI)
      thread1 = Thread.new do
        TreeHaver.with_backend(:rust) do
          if TreeHaver::Backends::Rust.available?
            lang = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
            mutex.synchronize { results << {thread: 1, class: lang.class} }
          end
        end
      end

      thread2 = Thread.new do
        TreeHaver.with_backend(:mri) do
          if TreeHaver::Backends::MRI.available?
            lang = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
            mutex.synchronize { results << {thread: 2, class: lang.class} }
          end
        end
      end

      thread1.join
      thread2.join

      # Should have loaded appropriate backend languages
      if results.size == 2
        expect(results[0][:class]).not_to eq(results[1][:class])
      end
    end
  end

  describe "explicit backend parameter with language loading" do
    it "uses explicit backend regardless of global setting" do
      path = TreeHaverDependencies.find_toml_grammar_path

      # Set global to Citrus
      TreeHaver.backend = :citrus

      # But request MRI explicitly
      if TreeHaver::Backends::MRI.available?
        lang = TreeHaver::Language.from_library(
          path,
          symbol: "tree_sitter_toml",
          backend: :mri,
        )
        expect(lang).to be_a(TreeHaver::Backends::MRI::Language)
      end
    end

    it "creates parser with explicit backend" do
      # Set global to Citrus
      TreeHaver.backend = :citrus

      # But create MRI parser explicitly
      if TreeHaver::Backends::MRI.available?
        parser = TreeHaver::Parser.new(backend: :mri)
        expect(parser.backend).to eq(:mri)
      end
    end
  end

  describe "fallback behavior when preferred backend unavailable" do
    it "falls back gracefully when explicitly requested backend unavailable" do
      # Request a backend that's definitely not available
      expect {
        TreeHaver::Parser.new(backend: :nonexistent)
      }.to raise_error(TreeHaver::NotAvailable)
    end

    it "auto-selects available backend when set to :auto" do
      TreeHaver.backend = :auto

      # Should successfully create a parser with some available backend
      parser = TreeHaver::Parser.new
      expect(parser).to be_a(TreeHaver::Parser)

      # Should have selected an available backend
      expect(parser.backend).not_to be_nil
      expect(parser.backend).not_to eq(:auto)
    end
  end

  describe "language registration with multiple backends" do
    it "registers same language for multiple backends", :toml_grammar do
      path = TreeHaverDependencies.find_toml_grammar_path

      begin
        require "toml-rb"

        # Register for both tree-sitter and Citrus
        TreeHaver.register_language(
          :toml_multi,
          path: path,
          symbol: "tree_sitter_toml",
          grammar_module: TomlRB::Document,
          gem_name: "toml-rb",
        )

        reg = TreeHaver.registered_language(:toml_multi)
        expect(reg).to have_key(:tree_sitter)
        expect(reg).to have_key(:citrus)
      rescue LoadError
        skip "toml-rb gem not available"
      end
    end

    it "loads correct language implementation based on active backend", :toml_grammar do
      path = TreeHaverDependencies.find_toml_grammar_path

      begin
        require "toml-rb"

        TreeHaver.register_language(
          :toml_both,
          path: path,
          symbol: "tree_sitter_toml",
          grammar_module: TomlRB::Document,
          gem_name: "toml-rb",
        )

        # Load with tree-sitter backend (MRI - not FFI since it conflicts with MRI)
        # Note: FFI cannot be used after MRI has been loaded in the test suite
        TreeHaver.backend = :mri
        if TreeHaver::Backends::MRI.available?
          lang_ts = TreeHaver::Language.toml_both
          expect(lang_ts).to be_a(TreeHaver::Backends::MRI::Language)
        end

        # Load with Citrus backend (Citrus can coexist with MRI)
        TreeHaver.backend = :citrus
        lang_citrus = TreeHaver::Language.toml_both
        expect(lang_citrus).to be_a(TreeHaver::Backends::Citrus::Language)
      rescue LoadError
        skip "toml-rb gem not available"
      end
    end
  end

  describe "error handling across backends" do
    it "raises appropriate error when no backend configuration exists" do
      TreeHaver.register_language(:incomplete, path: "/fake/path.so")

      # Try to load with Citrus (which has no configuration)
      TreeHaver.backend = :citrus
      expect {
        TreeHaver::Language.incomplete
      }.to raise_error(TreeHaver::NotAvailable, /no Citrus grammar registered/)
    end

    it "falls back to Citrus when tree-sitter config missing for tree-sitter backend" do
      require "toml-rb"

      # Only register Citrus, not tree-sitter
      TreeHaver.register_language(
        :citrus_only,
        grammar_module: TomlRB::Document,
        gem_name: "toml-rb",
      )

      # Try to load with MRI backend - should fall back to Citrus
      TreeHaver.backend = :mri
      language = TreeHaver::Language.citrus_only
      expect(language).to be_a(TreeHaver::Backends::Citrus::Language)
    rescue LoadError
      skip "toml-rb gem not available"
    end
  end
end
