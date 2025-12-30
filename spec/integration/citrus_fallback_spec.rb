# frozen_string_literal: true

require "spec_helper"

# Regression tests for Citrus fallback when tree-sitter backends are unavailable.
#
# These tests verify that parser_for correctly falls back to Citrus backends
# when native tree-sitter backends fail or are unavailable (e.g., on TruffleRuby).
#
# The bug: When no explicit citrus_config was provided to parser_for, and
# tree-sitter backends failed, the Citrus fallback was attempted with
# gem_name: nil and grammar_const: nil, causing require to receive nil
# instead of a valid require path.
#
# See: https://github.com/pboling/tree_haver/issues/XXX
RSpec.describe "Citrus fallback", :citrus_backend do
  before do
    TreeHaver::LanguageRegistry.clear_cache!
  end

  after do
    TreeHaver::LanguageRegistry.clear_cache!
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "TreeHaver::CITRUS_DEFAULTS" do
    it "includes configuration for :toml" do
      expect(TreeHaver::CITRUS_DEFAULTS).to have_key(:toml)
    end

    it "has gem_name for :toml" do
      expect(TreeHaver::CITRUS_DEFAULTS[:toml][:gem_name]).to eq("toml-rb")
    end

    it "has grammar_const for :toml" do
      expect(TreeHaver::CITRUS_DEFAULTS[:toml][:grammar_const]).to eq("TomlRB::Document")
    end

    it "has require_path for :toml" do
      expect(TreeHaver::CITRUS_DEFAULTS[:toml][:require_path]).to eq("toml-rb")
    end
  end

  describe "TreeHaver.parser_for with Citrus fallback" do
    context "when tree-sitter backends are unavailable (simulating TruffleRuby)" do
      before do
        # Stub all native tree-sitter backends as unavailable
        # This simulates the TruffleRuby environment where native extensions don't work
        allow(TreeHaver::Backends::MRI).to receive(:available?).and_return(false)
        allow(TreeHaver::Backends::Rust).to receive(:available?).and_return(false)
        allow(TreeHaver::Backends::FFI).to receive(:available?).and_return(false)
        allow(TreeHaver::Backends::Java).to receive(:available?).and_return(false)

        # Stub GrammarFinder to return unavailable (no tree-sitter grammar found)
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(TreeHaver::GrammarFinder).to receive(:available?).and_return(false)
        # rubocop:enable RSpec/AnyInstance
      end

      context "with :toml (has CITRUS_DEFAULTS entry)" do
        it "successfully creates a parser using Citrus backend" do
          parser = TreeHaver.parser_for(:toml)
          expect(parser).to be_a(TreeHaver::Parser)
          expect(parser.backend).to eq(:citrus)
        end

        it "can parse TOML content" do
          parser = TreeHaver.parser_for(:toml)
          tree = parser.parse('key = "value"')
          expect(tree).not_to be_nil
          expect(tree.root_node).not_to be_nil
        end

        it "does not require explicit citrus_config" do
          # This is the key regression test - previously this would fail with:
          # TypeError: no implicit conversion of nil into String
          # because citrus_config[:gem_name] was nil
          expect {
            TreeHaver.parser_for(:toml)
          }.not_to raise_error
        end
      end

      context "with unknown language (no CITRUS_DEFAULTS entry)" do
        it "raises NotAvailable" do
          expect {
            TreeHaver.parser_for(:totally_unknown_language_xyz)
          }.to raise_error(TreeHaver::NotAvailable, /No parser available/)
        end
      end

      context "when explicit citrus_config is provided" do
        it "uses the explicit config instead of defaults" do
          custom_config = {
            gem_name: "toml-rb",
            grammar_const: "TomlRB::Document",
            require_path: "toml-rb",
          }

          parser = TreeHaver.parser_for(:toml, citrus_config: custom_config)
          expect(parser).to be_a(TreeHaver::Parser)
          expect(parser.backend).to eq(:citrus)
        end
      end
    end

    context "when tree-sitter is available but citrus_config with nil values is passed" do
      # This tests that we don't try to create CitrusGrammarFinder with nil values
      # which would cause TypeError from require(nil)
      it "does not raise TypeError when citrus_config has nil gem_name" do
        # This should either succeed with tree-sitter or raise NotAvailable
        # but NOT raise TypeError about nil conversion
        error = nil
        begin
          TreeHaver.parser_for(:toml, citrus_config: {gem_name: nil, grammar_const: nil})
        rescue Exception => e  # rubocop:disable Lint/RescueException
          # Must rescue Exception because NotAvailable inherits from Exception, not StandardError
          error = e
        end

        # TypeError would indicate the bug we're testing for
        expect(error).not_to be_a(TypeError)
        # NotAvailable is acceptable (means tree-sitter-toml not installed)
        expect(error).to be_nil.or be_a(TreeHaver::NotAvailable)
      end
    end
  end

  describe "TreeHaver::CitrusGrammarFinder" do
    describe "#initialize" do
      it "sets require_path from gem_name when require_path is nil" do
        finder = TreeHaver::CitrusGrammarFinder.new(
          language: :toml,
          gem_name: "toml-rb",
          grammar_const: "TomlRB::Document",
        )
        expect(finder.require_path).to eq("toml-rb")
      end

      it "uses explicit require_path when provided" do
        finder = TreeHaver::CitrusGrammarFinder.new(
          language: :toml,
          gem_name: "toml-rb",
          grammar_const: "TomlRB::Document",
          require_path: "custom/path",
        )
        expect(finder.require_path).to eq("custom/path")
      end
    end

    describe "#available?" do
      context "when gem_name is nil" do
        it "returns false without raising TypeError" do
          finder = TreeHaver::CitrusGrammarFinder.new(
            language: :test,
            gem_name: nil,
            grammar_const: "Test::Grammar",
          )
          # This should not raise TypeError, just return false
          expect(finder.available?).to be false
        end
      end

      context "when require_path is explicitly set to nil" do
        it "returns false without raising TypeError" do
          finder = TreeHaver::CitrusGrammarFinder.new(
            language: :test,
            gem_name: nil,
            grammar_const: "Test::Grammar",
            require_path: nil,
          )
          # This should not raise TypeError, just return false
          expect(finder.available?).to be false
        end
      end

      context "with valid toml-rb configuration" do
        it "returns true" do
          finder = TreeHaver::CitrusGrammarFinder.new(
            language: :toml,
            gem_name: "toml-rb",
            grammar_const: "TomlRB::Document",
            require_path: "toml-rb",
          )
          expect(finder.available?).to be true
        end
      end
    end
  end

  describe "Explicit Citrus backend usage on MRI" do
    # This test explicitly uses Citrus backend even on MRI where tree-sitter works
    # This ensures we test the Citrus code path regardless of native backend availability
    it "can use Citrus backend explicitly via with_backend" do
      TreeHaver.with_backend(:citrus) do
        parser = TreeHaver::Parser.new
        require "toml-rb"
        citrus_lang = TreeHaver::Backends::Citrus::Language.new(TomlRB::Document)
        parser.language = citrus_lang

        tree = parser.parse('key = "value"')
        expect(tree).not_to be_nil
        expect(tree.root_node).not_to be_nil
      end
    end

    it "can parse complex TOML via Citrus backend" do
      TreeHaver.with_backend(:citrus) do
        parser = TreeHaver::Parser.new
        require "toml-rb"
        citrus_lang = TreeHaver::Backends::Citrus::Language.new(TomlRB::Document)
        parser.language = citrus_lang

        toml_content = <<~TOML
          [package]
          name = "my-app"
          version = "1.0.0"

          [dependencies]
          foo = "1.0"
        TOML

        tree = parser.parse(toml_content)
        expect(tree).not_to be_nil
        expect(tree.root_node).not_to be_nil
      end
    end
  end
end
