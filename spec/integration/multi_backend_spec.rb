# frozen_string_literal: true

# Integration tests for multi-backend scenarios and backend switching
RSpec.describe "Multi-backend integration", :toml_grammar do
  after do
    TreeHaver.reset_backend!(to: :auto)
    TreeHaver::LanguageRegistry.clear_all!
    Thread.current[:tree_haver_backend_context] = nil
  end

  describe "backend switching during parsing" do
    it "allows parsing with different backends sequentially" do
      path = TreeHaverDependencies.find_toml_grammar_path
      source = "x = 42"

      # Parse with FFI backend
      TreeHaver.backend = :ffi
      if TreeHaver::Backends::FFI.available?
        parser1 = TreeHaver::Parser.new
        lang1 = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
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

    it "caches languages per backend correctly" do
      path = TreeHaverDependencies.find_toml_grammar_path

      # Load with FFI
      TreeHaver.backend = :ffi
      if TreeHaver::Backends::FFI.available?
        lang_ffi = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
        expect(lang_ffi).to be_a(TreeHaver::Backends::FFI::Language)
      end

      # Load with MRI - should get different cached object
      TreeHaver.backend = :mri
      if TreeHaver::Backends::MRI.available?
        lang_mri = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
        expect(lang_mri).to be_a(TreeHaver::Backends::MRI::Language)

        # Should be different objects due to backend-aware caching
        if defined?(lang_ffi)
          expect(lang_mri.class).not_to eq(lang_ffi.class)
        end
      end
    end
  end

  describe "thread-local backend with language loading" do
    it "loads correct backend language in thread context" do
      path = TreeHaverDependencies.find_toml_grammar_path

      results = []
      mutex = Mutex.new

      thread1 = Thread.new do
        TreeHaver.with_backend(:ffi) do
          if TreeHaver::Backends::FFI.available?
            lang = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
            mutex.synchronize { results << { thread: 1, class: lang.class } }
          end
        end
      end

      thread2 = Thread.new do
        TreeHaver.with_backend(:mri) do
          if TreeHaver::Backends::MRI.available?
            lang = TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
            mutex.synchronize { results << { thread: 2, class: lang.class } }
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

      # Set global to FFI
      TreeHaver.backend = :ffi

      # But request MRI explicitly
      if TreeHaver::Backends::MRI.available?
        lang = TreeHaver::Language.from_library(
          path,
          symbol: "tree_sitter_toml",
          backend: :mri
        )
        expect(lang).to be_a(TreeHaver::Backends::MRI::Language)
      end
    end

    it "creates parser with explicit backend" do
      # Set global to FFI
      TreeHaver.backend = :ffi

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
          gem_name: "toml-rb"
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
          gem_name: "toml-rb"
        )

        # Load with tree-sitter backend (FFI/MRI/Rust)
        TreeHaver.backend = :ffi
        if TreeHaver::Backends::FFI.available?
          lang_ts = TreeHaver::Language.toml_both
          expect(lang_ts).to be_a(TreeHaver::Backends::FFI::Language)
        end

        # Load with Citrus backend
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
      }.to raise_error(TreeHaver::Error, /No grammar_module registered/)
    end

    it "raises appropriate error when tree-sitter config missing for tree-sitter backend" do
      begin
        require "toml-rb"

        # Only register Citrus, not tree-sitter
        TreeHaver.register_language(
          :citrus_only,
          grammar_module: TomlRB::Document,
          gem_name: "toml-rb"
        )

        # Try to load with FFI (which has no configuration)
        TreeHaver.backend = :ffi
        expect {
          TreeHaver::Language.citrus_only
        }.to raise_error(TreeHaver::Error, /No path registered/)
      rescue LoadError
        skip "toml-rb gem not available"
      end
    end
  end
end

