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
  end
end
