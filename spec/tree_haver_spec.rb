# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver do
  after do
    described_class.reset_backend!(to: :auto)
  end

  it "has a version number" do
    expect(described_class::VERSION).not_to be_nil
  end

  describe "::backend" do
    it "defaults to :auto" do
      described_class.reset_backend!(to: nil)
      stub_env("TREE_HAVER_BACKEND" => nil)
      # Force re-evaluation by clearing memoization
      described_class.instance_variable_set(:@backend, nil)
      expect(described_class.backend).to eq(:auto)
    end

    it "reads :mri from ENV" do
      described_class.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "mri")
      expect(described_class.backend).to eq(:mri)
    end

    it "reads :rust from ENV" do
      described_class.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "rust")
      expect(described_class.backend).to eq(:rust)
    end

    it "reads :ffi from ENV" do
      described_class.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "ffi")
      expect(described_class.backend).to eq(:ffi)
    end

    it "reads :java from ENV" do
      described_class.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "java")
      expect(described_class.backend).to eq(:java)
    end

    it "reads :citrus from ENV" do
      described_class.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "citrus")
      expect(described_class.backend).to eq(:citrus)
    end

    it "reads :prism from ENV" do
      described_class.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "prism")
      expect(described_class.backend).to eq(:prism)
    end

    it "reads :psych from ENV" do
      described_class.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "psych")
      expect(described_class.backend).to eq(:psych)
    end

    it "reads :commonmarker from ENV" do
      described_class.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "commonmarker")
      expect(described_class.backend).to eq(:commonmarker)
    end

    it "reads :markly from ENV" do
      described_class.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "markly")
      expect(described_class.backend).to eq(:markly)
    end

    it "defaults to :auto for unknown ENV value" do
      described_class.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "unknown")
      expect(described_class.backend).to eq(:auto)
    end
  end

  describe "::backend=" do
    it "sets the backend" do
      described_class.backend = :ffi
      expect(described_class.backend).to eq(:ffi)
    end

    it "accepts string and converts to symbol" do
      described_class.backend = "mri"
      expect(described_class.backend).to eq(:mri)
    end

    it "accepts nil" do
      described_class.backend = nil
      # When @backend is nil, the getter re-evaluates and defaults to :auto
      expect(described_class.instance_variable_get(:@backend)).to be_nil
    end
  end

  describe "::reset_backend!" do
    it "resets to :auto by default" do
      described_class.backend = :ffi
      described_class.reset_backend!
      expect(described_class.backend).to eq(:auto)
    end

    it "resets to specified value" do
      described_class.backend = :ffi
      described_class.reset_backend!(to: :mri)
      expect(described_class.backend).to eq(:mri)
    end

    it "resets to nil when to: nil" do
      described_class.backend = :ffi
      described_class.reset_backend!(to: nil)
      # When to: nil, @backend is set to nil, but getter re-evaluates to :auto
      expect(described_class.instance_variable_get(:@backend)).to be_nil
    end
  end

  describe "::backend_module" do
    context "with explicit backend selection" do
      it "returns MRI backend when backend is :mri" do
        described_class.backend = :mri
        expect(described_class.backend_module).to eq(described_class::Backends::MRI)
      end

      it "returns Rust backend when backend is :rust" do
        described_class.backend = :rust
        expect(described_class.backend_module).to eq(described_class::Backends::Rust)
      end

      it "returns FFI backend when backend is :ffi" do
        described_class.backend = :ffi
        expect(described_class.backend_module).to eq(described_class::Backends::FFI)
      end

      it "returns Java backend when backend is :java" do
        described_class.backend = :java
        expect(described_class.backend_module).to eq(described_class::Backends::Java)
      end

      it "returns Prism backend when backend is :prism" do
        described_class.backend = :prism
        expect(described_class.backend_module).to eq(described_class::Backends::Prism)
      end

      it "returns Psych backend when backend is :psych" do
        described_class.backend = :psych
        expect(described_class.backend_module).to eq(described_class::Backends::Psych)
      end

      it "returns Commonmarker backend when backend is :commonmarker" do
        described_class.backend = :commonmarker
        expect(described_class.backend_module).to eq(described_class::Backends::Commonmarker)
      end

      it "returns Markly backend when backend is :markly" do
        described_class.backend = :markly
        expect(described_class.backend_module).to eq(described_class::Backends::Markly)
      end
    end

    context "with auto-selection" do
      before do
        described_class.backend = :auto
      end

      it "prefers Java on JRuby when available" do
        allow(described_class::Backends::Java).to receive(:available?).and_return(true)
        stub_const("RUBY_ENGINE", "jruby")
        expect(described_class.backend_module).to eq(described_class::Backends::Java)
      end

      it "prefers MRI on MRI when available" do
        allow(described_class::Backends::MRI).to receive(:available?).and_return(true)
        stub_const("RUBY_ENGINE", "ruby")
        expect(described_class.backend_module).to eq(described_class::Backends::MRI)
      end

      it "falls back to Rust on MRI when MRI backend unavailable" do
        allow(described_class::Backends::MRI).to receive(:available?).and_return(false)
        allow(described_class::Backends::Rust).to receive(:available?).and_return(true)
        stub_const("RUBY_ENGINE", "ruby")
        expect(described_class.backend_module).to eq(described_class::Backends::Rust)
      end

      it "falls back to FFI when others unavailable" do
        allow(described_class::Backends::MRI).to receive(:available?).and_return(false)
        allow(described_class::Backends::Rust).to receive(:available?).and_return(false)
        allow(described_class::Backends::FFI).to receive(:available?).and_return(true)
        stub_const("RUBY_ENGINE", "ruby")
        expect(described_class.backend_module).to eq(described_class::Backends::FFI)
      end

      it "returns nil when no backend available" do
        allow(described_class::Backends::MRI).to receive(:available?).and_return(false)
        allow(described_class::Backends::Rust).to receive(:available?).and_return(false)
        allow(described_class::Backends::FFI).to receive(:available?).and_return(false)
        allow(described_class::Backends::Java).to receive(:available?).and_return(false)
        allow(described_class::Backends::Citrus).to receive(:available?).and_return(false)
        stub_const("RUBY_ENGINE", "ruby")
        expect(described_class.backend_module).to be_nil
      end
    end
  end

  describe "::capabilities" do
    it "returns backend capabilities when available" do
      allow(described_class).to receive(:backend_module).and_return(described_class::Backends::FFI)
      allow(described_class::Backends::FFI).to receive(:capabilities).and_return({backend: :ffi, parse: true})
      expect(described_class.capabilities).to eq({backend: :ffi, parse: true})
    end

    it "returns empty hash when no backend available" do
      allow(described_class).to receive(:backend_module).and_return(nil)
      expect(described_class.capabilities).to eq({})
    end
  end

  describe "::register_language" do
    it "delegates to LanguageRegistry" do
      expect(described_class::LanguageRegistry).to receive(:register).with(:toml, :tree_sitter, path: "/path.so", symbol: "ts_toml")
      described_class.register_language(:toml, path: "/path.so", symbol: "ts_toml")
    end
  end

  describe "::registered_language" do
    it "delegates to LanguageRegistry" do
      described_class.register_language(:toml, path: "/lib.so")
      result = described_class.registered_language(:toml)
      expect(result).to be_a(Hash)
      expect(result[:tree_sitter]).to be_a(Hash)
      expect(result[:tree_sitter][:path]).to eq("/lib.so")
    end
  end

  describe "::backend_module with Citrus backend" do
    context "when backend is :citrus", :citrus_backend do
      before { described_class.backend = :citrus }
      after { described_class.backend = :auto }

      it "returns Citrus backend module" do
        expect(described_class.backend_module).to eq(described_class::Backends::Citrus)
      end
    end

    context "when no backend is available" do
      before do
        allow(described_class::Backends::Java).to receive(:available?).and_return(false)
        allow(described_class::Backends::MRI).to receive(:available?).and_return(false)
        allow(described_class::Backends::Rust).to receive(:available?).and_return(false)
        allow(described_class::Backends::FFI).to receive(:available?).and_return(false)
        allow(described_class::Backends::Citrus).to receive(:available?).and_return(false)
        described_class.backend = :auto
      end

      after do
        described_class.backend = :auto
      end

      it "returns nil" do
        expect(described_class.backend_module).to be_nil
      end
    end
  end

  describe "::register_language validation" do
    # NOTE: Don't clear registrations - use unique names per test

    context "with grammar_module that doesn't respond to :parse" do
      it "raises ArgumentError" do
        bad_module = Module.new

        expect {
          described_class.register_language(:bad_module_test, grammar_module: bad_module)
        }.to raise_error(ArgumentError, /must respond to :parse/)
      end
    end

    context "with neither path nor grammar_module" do
      it "raises ArgumentError" do
        expect {
          described_class.register_language(:empty_test)
        }.to raise_error(ArgumentError, /Must provide at least one/)
      end
    end

    context "with both path and grammar_module" do
      it "registers both backends" do
        mock_grammar = Module.new
        def mock_grammar.parse(source)
        end

        described_class.register_language(
          :test_lang,
          path: "/fake/path.so",
          symbol: "ts_test",
          grammar_module: mock_grammar,
          gem_name: "test-gem",
        )

        registration = described_class.registered_language(:test_lang)
        expect(registration).to have_key(:tree_sitter)
        expect(registration).to have_key(:citrus)
        expect(registration[:tree_sitter][:path]).to eq("/fake/path.so")
        expect(registration[:citrus][:grammar_module]).to eq(mock_grammar)
      end
    end
  end

  describe "::resolve_effective_backend" do
    after do
      Thread.current[:tree_haver_backend_context] = nil
      described_class.backend = :auto
    end

    it "returns explicit backend when provided" do
      expect(described_class.send(:resolve_effective_backend, :ffi)).to eq(:ffi)
    end

    it "returns thread context backend when no explicit backend" do
      Thread.current[:tree_haver_backend_context] = {backend: :mri, depth: 1}
      expect(described_class.send(:resolve_effective_backend, nil)).to eq(:mri)
    end

    it "returns global backend when no thread context" do
      described_class.backend = :rust
      expect(described_class.send(:resolve_effective_backend, nil)).to eq(:rust)
    end

    it "returns :auto when nothing is set" do
      Thread.current[:tree_haver_backend_context] = nil
      described_class.backend = :auto
      expect(described_class.send(:resolve_effective_backend, nil)).to eq(:auto)
    end
  end

  describe "::resolve_backend_module" do
    context "when no backends are available" do
      before do
        # Stub all backends as unavailable
        allow(described_class::Backends::MRI).to receive(:available?).and_return(false)
        allow(described_class::Backends::Rust).to receive(:available?).and_return(false)
        allow(described_class::Backends::FFI).to receive(:available?).and_return(false)
        allow(described_class::Backends::Java).to receive(:available?).and_return(false)
        allow(described_class::Backends::Citrus).to receive(:available?).and_return(false)
      end

      it "returns nil when auto-detecting with no available backends" do
        result = described_class.resolve_backend_module(:auto)
        expect(result).to be_nil
      end
    end

    context "when only Citrus is available" do
      before do
        allow(described_class::Backends::MRI).to receive(:available?).and_return(false)
        allow(described_class::Backends::Rust).to receive(:available?).and_return(false)
        allow(described_class::Backends::FFI).to receive(:available?).and_return(false)
        allow(described_class::Backends::Java).to receive(:available?).and_return(false)
        allow(described_class::Backends::Citrus).to receive(:available?).and_return(true)
      end

      it "falls back to Citrus when auto-detecting" do
        result = described_class.resolve_backend_module(:auto)
        expect(result).to eq(described_class::Backends::Citrus)
      end
    end

    context "with explicit backend selection" do
      it "returns Prism backend for :prism" do
        result = described_class.resolve_backend_module(:prism)
        expect(result).to eq(described_class::Backends::Prism)
      end

      it "returns Psych backend for :psych" do
        result = described_class.resolve_backend_module(:psych)
        expect(result).to eq(described_class::Backends::Psych)
      end

      it "returns Commonmarker backend for :commonmarker", :commonmarker_backend do
        result = described_class.resolve_backend_module(:commonmarker)
        expect(result).to eq(described_class::Backends::Commonmarker)
      end

      it "returns Markly backend for :markly", :markly_backend do
        result = described_class.resolve_backend_module(:markly)
        expect(result).to eq(described_class::Backends::Markly)
      end

      it "returns nil for unknown backend" do
        result = described_class.resolve_backend_module(:nonexistent)
        expect(result).to be_nil
      end
    end
  end

  describe "::backend_protect" do
    after do
      # Reset to default
      described_class.instance_variable_set(:@backend_protect, nil)
    end

    describe "::backend_protect=" do
      it "sets the protection flag" do
        described_class.backend_protect = false
        expect(described_class.backend_protect?).to be false
      end

      it "sets the protection flag to true" do
        described_class.backend_protect = true
        expect(described_class.backend_protect?).to be true
      end
    end

    describe "::backend_protect?" do
      it "defaults to true when not set" do
        described_class.instance_variable_set(:@backend_protect, nil)
        described_class.remove_instance_variable(:@backend_protect) if described_class.instance_variable_defined?(:@backend_protect)
        expect(described_class.backend_protect?).to be true
      end

      it "returns the set value" do
        described_class.backend_protect = false
        expect(described_class.backend_protect?).to be false
      end
    end

    describe "::backend_protect alias" do
      it "is an alias for backend_protect?" do
        described_class.backend_protect = false
        expect(described_class.backend_protect).to be false
      end
    end
  end

  describe "::backends_used" do
    after do
      described_class.instance_variable_set(:@backends_used, nil)
    end

    it "returns a Set" do
      expect(described_class.backends_used).to be_a(Set)
    end

    it "starts empty" do
      described_class.instance_variable_set(:@backends_used, nil)
      expect(described_class.backends_used).to be_empty
    end
  end

  describe "::record_backend_usage" do
    after do
      described_class.instance_variable_set(:@backends_used, nil)
    end

    it "adds the backend to backends_used" do
      described_class.instance_variable_set(:@backends_used, nil)
      described_class.record_backend_usage(:ffi)
      expect(described_class.backends_used).to include(:ffi)
    end
  end

  describe "::conflicting_backends_for" do
    it "returns empty array when no conflicts" do
      described_class.instance_variable_set(:@backends_used, Set.new)
      expect(described_class.conflicting_backends_for(:ffi)).to eq([])
    end
  end

  describe "::check_backend_conflict!" do
    after do
      described_class.instance_variable_set(:@backend_protect, nil)
      described_class.instance_variable_set(:@backends_used, nil)
    end

    context "when protection is disabled" do
      before do
        described_class.backend_protect = false
      end

      it "does not raise even with conflicts" do
        described_class.instance_variable_set(:@backends_used, Set.new([:ffi]))
        expect { described_class.check_backend_conflict!(:mri) }.not_to raise_error
      end
    end

    context "when protection is enabled" do
      before do
        described_class.backend_protect = true
      end

      it "does not raise when no conflicts" do
        described_class.instance_variable_set(:@backends_used, Set.new)
        expect { described_class.check_backend_conflict!(:ffi) }.not_to raise_error
      end
    end
  end

  describe "::parser_for" do
    after do
      described_class.reset_backend!(to: :auto)
    end

    context "when library_path is provided but does not exist" do
      it "raises NotAvailable" do
        expect {
          described_class.parser_for(:nonexistent_lang, library_path: "/nonexistent/path.so")
        }.to raise_error(described_class::NotAvailable, /does not exist/)
      end
    end

    context "when no parser is available" do
      before do
        # rubocop:disable RSpec/AnyInstance
        # Stub GrammarFinder to not find anything
        allow_any_instance_of(described_class::GrammarFinder).to receive(:available?).and_return(false)
        allow_any_instance_of(described_class::CitrusGrammarFinder).to receive(:available?).and_return(false)
        # rubocop:enable RSpec/AnyInstance
      end

      it "raises NotAvailable" do
        expect {
          described_class.parser_for(:totally_unknown_language_xyz)
        }.to raise_error(described_class::NotAvailable, /No parser available/)
      end
    end
  end

  describe "::Language" do
    describe ".method_missing for language loading" do
      context "when tree-sitter path exists but Citrus fallback is available" do
        before do
          # Register both tree-sitter and Citrus for same language
          mock_grammar = Module.new do
            class << self
              def parse(source)
                # Mock parse
              end
            end
          end
          described_class.register_language(
            :dual_backend_test,
            path: "/nonexistent/fake.so",
            symbol: "tree_sitter_test",
            grammar_module: mock_grammar,
          )
        end

        after do
          described_class::LanguageRegistry.clear_cache!
        end

        it "falls back to Citrus when tree-sitter loading fails", :citrus_backend do
          described_class.backend = :citrus
          lang = described_class::Language.dual_backend_test
          expect(lang).to be_a(described_class::Backends::Citrus::Language)
        end
      end

      context "when no grammar is registered" do
        it "raises NoMethodError" do
          expect {
            described_class::Language.totally_nonexistent_language_xyz
          }.to raise_error(NoMethodError)
        end
      end
    end

    describe ".respond_to_missing?" do
      it "returns true for registered languages" do
        described_class.register_language(:respond_test, path: "/fake.so")
        expect(described_class::Language.respond_to?(:respond_test)).to be true
      end

      it "returns false for unregistered languages" do
        expect(described_class::Language.respond_to?(:totally_fake_unregistered)).to be false
      end
    end
  end

  describe "::Parser" do
    describe "#backend detection" do
      context "when explicit backend is set" do
        it "returns the explicit backend", :citrus_backend do
          parser = described_class::Parser.new(backend: :citrus)
          expect(parser.backend).to eq(:citrus)
        end
      end

      context "when backend is auto and implementation class name is checked" do
        it "detects Citrus backend from class name", :citrus_backend do
          described_class.backend = :citrus
          parser = described_class::Parser.new
          expect(parser.backend).to eq(:citrus)
        end
      end
    end

    describe "#initialize with backend fallback" do
      context "when tree-sitter backend fails and Citrus is available" do
        before do
          # Force tree-sitter backends to fail
          allow(described_class::Backends::MRI).to receive(:available?).and_return(false)
          allow(described_class::Backends::Rust).to receive(:available?).and_return(false)
          allow(described_class::Backends::FFI).to receive(:available?).and_return(false)
          allow(described_class::Backends::Java).to receive(:available?).and_return(false)
          allow(described_class::Backends::Citrus).to receive(:available?).and_return(true)
        end

        it "falls back to Citrus parser" do
          parser = described_class::Parser.new
          expect(parser.backend).to eq(:citrus)
        end
      end

      context "when explicit backend is requested but not available" do
        before do
          allow(described_class::Backends::FFI).to receive(:available?).and_return(false)
        end

        it "raises NotAvailable or BackendConflict for explicit backend" do
          # FFI can fail with NotAvailable (gem not available) or BackendConflict
          # (MRI already loaded, blocking FFI). Both indicate the backend is unusable.
          expect {
            described_class::Parser.new(backend: :ffi)
          }.to raise_error(described_class::Error, /not available|blocked by/)
        end
      end
    end

    describe "#language= with Citrus language", :citrus_backend, :toml_rb do
      it "switches to Citrus parser when given Citrus language" do
        # Start with a Citrus parser
        parser = described_class::Parser.new(backend: :citrus)

        # Create a Citrus language
        citrus_lang = described_class::Backends::Citrus::Language.new(TomlRB::Document)

        # Set the Citrus language
        parser.language = citrus_lang
        expect(parser.backend).to eq(:citrus)
      end
    end
  end
end
