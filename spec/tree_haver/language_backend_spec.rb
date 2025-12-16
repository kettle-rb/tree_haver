# frozen_string_literal: true

RSpec.describe "TreeHaver::Language with backend parameter and caching" do
  after do
    # Clean up thread-local state
    Thread.current[:tree_haver_backend_context] = nil
    TreeHaver.reset_backend!(to: :auto)
    TreeHaver::LanguageRegistry.clear_cache!
  end

  describe "Language.from_library with backend parameter" do
    let(:mock_path) { "/fake/path/to/grammar.so" }
    let(:mock_symbol) { "tree_sitter_test" }

    before do
      # Allow path validation to pass
      allow(TreeHaver::PathValidator).to receive(:safe_library_path?).and_return(true)
      allow(TreeHaver::PathValidator).to receive(:safe_symbol_name?).and_return(true)
    end

    context "with no backend parameter" do
      it "uses effective backend from context" do
        skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?

        mock_language = double("Language")
        allow(TreeHaver::Backends::FFI::Language).to receive(:from_library)
          .and_return(mock_language)

        TreeHaver.with_backend(:ffi) do
          language = TreeHaver::Language.from_library(mock_path, symbol: mock_symbol)
          expect(language).to eq(mock_language)
        end
      end

      it "uses global backend when no context set" do
        skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?

        mock_language = double("Language")
        allow(TreeHaver::Backends::FFI::Language).to receive(:from_library)
          .and_return(mock_language)

        TreeHaver.backend = :ffi
        language = TreeHaver::Language.from_library(mock_path, symbol: mock_symbol)
        expect(language).to eq(mock_language)
      end
    end

    context "with explicit backend parameter" do
      it "uses specified backend regardless of context" do
        skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?

        mock_language = double("Language")
        allow(TreeHaver::Backends::FFI::Language).to receive(:from_library)
          .and_return(mock_language)

        TreeHaver.with_backend(:mri) do
          language = TreeHaver::Language.from_library(mock_path,
            symbol: mock_symbol,
            backend: :ffi)
          expect(language).to eq(mock_language)
        end

        expect(TreeHaver::Backends::FFI::Language).to have_received(:from_library)
      end

      it "overrides global backend setting" do
        skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?

        mock_language = double("Language")
        allow(TreeHaver::Backends::FFI::Language).to receive(:from_library)
          .and_return(mock_language)

        TreeHaver.backend = :mri
        language = TreeHaver::Language.from_library(mock_path,
          symbol: mock_symbol,
          backend: :ffi)
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
          TreeHaver::Language.from_library(mock_path,
            symbol: mock_symbol,
            backend: unavailable_backend)
        end.to raise_error(TreeHaver::NotAvailable, /Requested backend .* is not available/)
      end
    end
  end

  describe "Backend-aware language caching" do
    let(:mock_path) { "/fake/path/to/grammar.so" }
    let(:mock_symbol) { "tree_sitter_test" }

    before do
      allow(TreeHaver::PathValidator).to receive(:safe_library_path?).and_return(true)
      allow(TreeHaver::PathValidator).to receive(:safe_symbol_name?).and_return(true)
    end

    it "caches language separately per backend" do
      skip "FFI and MRI backends not available" unless
        TreeHaver::Backends::FFI.available? && TreeHaver::Backends::MRI.available?

      ffi_language = double("FFI Language")
      mri_language = double("MRI Language")

      allow(TreeHaver::Backends::FFI::Language).to receive(:from_library)
        .and_return(ffi_language)
      allow(TreeHaver::Backends::MRI::Language).to receive(:from_library)
        .and_return(mri_language)

      # Load with FFI backend
      lang1 = TreeHaver::Language.from_library(mock_path,
        symbol: mock_symbol,
        backend: :ffi)

      # Load same path with MRI backend - should be different cached object
      lang2 = TreeHaver::Language.from_library(mock_path,
        symbol: mock_symbol,
        backend: :mri)

      expect(lang1).to eq(ffi_language)
      expect(lang2).to eq(mri_language)
      expect(lang1).not_to eq(lang2)
    end

    it "returns cached language for same backend and path" do
      skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?

      mock_language = double("Language")
      allow(TreeHaver::Backends::FFI::Language).to receive(:from_library)
        .and_return(mock_language)

      lang1 = TreeHaver::Language.from_library(mock_path,
        symbol: mock_symbol,
        backend: :ffi)
      lang2 = TreeHaver::Language.from_library(mock_path,
        symbol: mock_symbol,
        backend: :ffi)

      expect(lang1).to eq(lang2)
      expect(lang1.object_id).to eq(lang2.object_id)  # Same object from cache
      expect(TreeHaver::Backends::FFI::Language).to have_received(:from_library).once
    end

    it "uses thread-local context in cache key" do
      skip "FFI and MRI backends not available" unless
        TreeHaver::Backends::FFI.available? && TreeHaver::Backends::MRI.available?

      ffi_language = double("FFI Language")
      mri_language = double("MRI Language")

      allow(TreeHaver::Backends::FFI::Language).to receive(:from_library)
        .and_return(ffi_language)
      allow(TreeHaver::Backends::MRI::Language).to receive(:from_library)
        .and_return(mri_language)

      # Load with FFI context
      lang1 = nil
      TreeHaver.with_backend(:ffi) do
        lang1 = TreeHaver::Language.from_library(mock_path, symbol: mock_symbol)
      end

      # Load with MRI context - should be different
      lang2 = nil
      TreeHaver.with_backend(:mri) do
        lang2 = TreeHaver::Language.from_library(mock_path, symbol: mock_symbol)
      end

      expect(lang1).to eq(ffi_language)
      expect(lang2).to eq(mri_language)
      expect(lang1).not_to eq(lang2)
    end

    it "prevents cache pollution between backends" do
      skip "FFI and Citrus backends not available" unless
        TreeHaver::Backends::FFI.available? && TreeHaver::Backends::Citrus.available?

      ffi_language = double("FFI Language")
      citrus_language = double("Citrus Language")

      allow(TreeHaver::Backends::FFI::Language).to receive(:from_library)
        .and_return(ffi_language)
      allow(TreeHaver::Backends::Citrus::Language).to receive(:from_library)
        .and_return(citrus_language)

      # Load with different backends - should call backend-specific loader each time
      lang1 = TreeHaver::Language.from_library(mock_path,
        symbol: mock_symbol,
        backend: :ffi)
      lang2 = TreeHaver::Language.from_library(mock_path,
        symbol: mock_symbol,
        backend: :citrus)

      # Load again with FFI - should use cache
      lang3 = TreeHaver::Language.from_library(mock_path,
        symbol: mock_symbol,
        backend: :ffi)

      expect(lang1).to eq(ffi_language)
      expect(lang2).to eq(citrus_language)
      expect(lang3).to eq(ffi_language)
      expect(lang1.object_id).to eq(lang3.object_id)  # Same cached object

      expect(TreeHaver::Backends::FFI::Language).to have_received(:from_library).once
      expect(TreeHaver::Backends::Citrus::Language).to have_received(:from_library).once
    end
  end

  describe "Thread-safe language loading" do
    let(:mock_path) { "/fake/path/to/grammar.so" }
    let(:mock_symbol) { "tree_sitter_test" }

    before do
      allow(TreeHaver::PathValidator).to receive(:safe_library_path?).and_return(true)
      allow(TreeHaver::PathValidator).to receive(:safe_symbol_name?).and_return(true)
    end

    it "loads languages with different backends in concurrent threads" do
      skip "FFI and Citrus backends not available" unless
        TreeHaver::Backends::FFI.available? && TreeHaver::Backends::Citrus.available?

      ffi_language = double("FFI Language")
      citrus_language = double("Citrus Language")

      allow(TreeHaver::Backends::FFI::Language).to receive(:from_library)
        .and_return(ffi_language)
      allow(TreeHaver::Backends::Citrus::Language).to receive(:from_library)
        .and_return(citrus_language)

      results = Concurrent::Array.new if defined?(Concurrent::Array)
      results ||= []
      mutex = Mutex.new

      thread1 = Thread.new do
        TreeHaver.with_backend(:ffi) do
          lang = TreeHaver::Language.from_library(mock_path, symbol: mock_symbol)
          mutex.synchronize { results << { thread: 1, language: lang } }
        end
      end

      thread2 = Thread.new do
        TreeHaver.with_backend(:citrus) do
          lang = TreeHaver::Language.from_library(mock_path, symbol: mock_symbol)
          mutex.synchronize { results << { thread: 2, language: lang } }
        end
      end

      thread1.join
      thread2.join

      expect(results.size).to eq(2)
      expect(results.find { |r| r[:thread] == 1 }[:language]).to eq(ffi_language)
      expect(results.find { |r| r[:thread] == 2 }[:language]).to eq(citrus_language)
    end

    it "loads languages with explicit backends in concurrent threads" do
      skip "FFI and Citrus backends not available" unless
        TreeHaver::Backends::FFI.available? && TreeHaver::Backends::Citrus.available?

      ffi_language = double("FFI Language")
      citrus_language = double("Citrus Language")

      allow(TreeHaver::Backends::FFI::Language).to receive(:from_library)
        .and_return(ffi_language)
      allow(TreeHaver::Backends::Citrus::Language).to receive(:from_library)
        .and_return(citrus_language)

      results = Concurrent::Array.new if defined?(Concurrent::Array)
      results ||= []
      mutex = Mutex.new

      thread1 = Thread.new do
        lang = TreeHaver::Language.from_library(mock_path,
          symbol: mock_symbol,
          backend: :ffi)
        mutex.synchronize { results << { thread: 1, language: lang } }
      end

      thread2 = Thread.new do
        lang = TreeHaver::Language.from_library(mock_path,
          symbol: mock_symbol,
          backend: :citrus)
        mutex.synchronize { results << { thread: 2, language: lang } }
      end

      thread1.join
      thread2.join

      expect(results.size).to eq(2)
      expect(results.find { |r| r[:thread] == 1 }[:language]).to eq(ffi_language)
      expect(results.find { |r| r[:thread] == 2 }[:language]).to eq(citrus_language)
    end
  end

  describe "Backward compatibility" do
    let(:mock_path) { "/fake/path/to/grammar.so" }
    let(:mock_symbol) { "tree_sitter_test" }

    before do
      allow(TreeHaver::PathValidator).to receive(:safe_library_path?).and_return(true)
      allow(TreeHaver::PathValidator).to receive(:safe_symbol_name?).and_return(true)
    end

    it "works without backend parameter (existing behavior)" do
      skip "No backend available" unless TreeHaver.backend_module

      mock_language = double("Language")
      backend_mod = TreeHaver.backend_module
      allow(backend_mod::Language).to receive(:from_library).and_return(mock_language)

      language = TreeHaver::Language.from_library(mock_path, symbol: mock_symbol)
      expect(language).to eq(mock_language)
    end

    it "respects global backend setting (existing behavior)" do
      skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?

      mock_language = double("Language")
      allow(TreeHaver::Backends::FFI::Language).to receive(:from_library)
        .and_return(mock_language)

      TreeHaver.backend = :ffi
      language = TreeHaver::Language.from_library(mock_path, symbol: mock_symbol)
      expect(language).to eq(mock_language)
    end
  end
end

