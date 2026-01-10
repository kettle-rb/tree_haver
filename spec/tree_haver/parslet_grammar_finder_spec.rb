# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::ParsletGrammarFinder do
  let(:finder) do
    described_class.new(
      language: :toml,
      gem_name: "toml",
      grammar_const: "TOML::Parslet",
    )
  end

  after do
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "#initialize" do
    it "creates a finder with required parameters" do
      f = described_class.new(
        language: :json,
        gem_name: "json-parslet",
        grammar_const: "JsonParslet::Grammar",
      )
      expect(f.language_name).to eq(:json)
      expect(f.gem_name).to eq("json-parslet")
      expect(f.grammar_const).to eq("JsonParslet::Grammar")
    end

    it "converts language to symbol" do
      f = described_class.new(
        language: "yaml",
        gem_name: "yaml-parslet",
        grammar_const: "YamlParslet::Grammar",
      )
      expect(f.language_name).to eq(:yaml)
    end

    it "defaults require_path to gem_name" do
      f = described_class.new(
        language: :toml,
        gem_name: "toml",
        grammar_const: "TOML::Parslet",
      )
      expect(f.require_path).to eq("toml")
    end

    it "accepts custom require_path" do
      f = described_class.new(
        language: :toml,
        gem_name: "toml",
        grammar_const: "TOML::Parslet",
        require_path: "custom/path",
      )
      expect(f.require_path).to eq("custom/path")
    end
  end

  describe "#available?" do
    context "with nil require_path" do
      let(:nil_finder) do
        described_class.new(
          language: :test,
          gem_name: nil,
          grammar_const: "Test::Grammar",
        )
      end

      it "returns false when require_path is nil" do
        expect(nil_finder.available?).to be false
      end

      it "caches the result" do
        nil_finder.available?
        # Second call should return cached value
        expect(nil_finder.available?).to be false
      end

      context "when TREE_HAVER_DEBUG is set" do
        before do
          stub_env("TREE_HAVER_DEBUG" => "1")
        end

        it "outputs warning" do
          fresh_finder = described_class.new(
            language: :debug_test,
            gem_name: nil,
            grammar_const: "Debug::Grammar",
          )
          expect { fresh_finder.available? }.to output(/require_path is nil or empty/).to_stderr
        end
      end
    end

    context "with empty require_path" do
      let(:empty_finder) do
        described_class.new(
          language: :test,
          gem_name: "",
          grammar_const: "Test::Grammar",
        )
      end

      it "returns false when require_path is empty" do
        expect(empty_finder.available?).to be false
      end

      context "when TREE_HAVER_DEBUG is set" do
        before do
          stub_env("TREE_HAVER_DEBUG" => "1")
        end

        it "outputs warning" do
          fresh_finder = described_class.new(
            language: :debug_test,
            gem_name: "",
            grammar_const: "Debug::Grammar",
          )
          expect { fresh_finder.available? }.to output(/require_path is nil or empty/).to_stderr
        end
      end
    end

    # Note: Tests for LoadError, NameError, TypeError, and unexpected errors
    # are not included because they would require mocking `require`, which
    # is fragile and can cause unexpected side effects.
    # The error handling code is marked with # :nocov: in the source.
  end

  describe "#grammar_class" do
    context "with nil require_path" do
      let(:nil_finder) do
        described_class.new(
          language: :test,
          gem_name: nil,
          grammar_const: "Test::Grammar",
        )
      end

      it "returns nil when not available" do
        expect(nil_finder.grammar_class).to be_nil
      end
    end
  end

  describe "#register!" do
    context "with nil require_path (not available)" do
      let(:nil_finder) do
        described_class.new(
          language: :test,
          gem_name: nil,
          grammar_const: "Test::Grammar",
        )
      end

      it "returns false by default" do
        expect(nil_finder.register!).to be false
      end

      it "raises when raise_on_missing is true" do
        expect {
          nil_finder.register!(raise_on_missing: true)
        }.to raise_error(TreeHaver::NotAvailable)
      end
    end

    context "when grammar is available", :parslet_backend do
      before do
        skip "Parslet not available" unless TreeHaver::Backends::Parslet.available?
      end

      # Define a test grammar class
      let(:test_grammar_class) do
        require "parslet"
        Class.new(Parslet::Parser) do
          rule(:test) { str("test") }
          root(:test)
        end
      end

      let(:available_finder) do
        # Create a finder that will find our test grammar
        finder = described_class.new(
          language: :test_parslet_register,
          gem_name: "parslet", # parslet gem is available
          grammar_const: "TestParsletGrammar",
        )
        # Pre-set the grammar class to simulate successful constant resolution
        finder.instance_variable_set(:@grammar_class, test_grammar_class)
        finder.instance_variable_set(:@load_attempted, true)
        finder.instance_variable_set(:@available, true)
        finder
      end

      after do
        TreeHaver::LanguageRegistry.clear
      end

      it "registers the grammar with TreeHaver" do
        expect(available_finder.register!).to be true
      end
    end
  end

  describe "#search_info" do
    it "returns diagnostic hash" do
      info = finder.search_info
      expect(info).to be_a(Hash)
      expect(info[:language]).to eq(:toml)
      expect(info[:gem_name]).to eq("toml")
      expect(info[:grammar_const]).to eq("TOML::Parslet")
      expect(info[:require_path]).to eq("toml")
    end

    context "with nil require_path" do
      let(:nil_finder) do
        described_class.new(
          language: :test,
          gem_name: nil,
          grammar_const: "Test::Grammar",
        )
      end

      it "shows available as false" do
        info = nil_finder.search_info
        expect(info[:available]).to be false
        expect(info[:grammar_class]).to be_nil
      end
    end
  end

  describe "#not_found_message" do
    it "returns helpful error message" do
      msg = finder.not_found_message
      expect(msg).to include("toml")
      expect(msg).to include("gem install")
    end
  end

  describe "integration with real toml gem", :parslet_backend do
    before do
      skip "toml gem not available" unless toml_gem_available?
    end

    let(:real_finder) do
      described_class.new(
        language: :toml_parslet_test,
        gem_name: "toml",
        grammar_const: "TOML::Parslet",
      )
    end

    after do
      TreeHaver::LanguageRegistry.clear
    end

    it "finds and validates the TOML::Parslet grammar" do
      expect(real_finder.available?).to be true
      expect(real_finder.grammar_class).not_to be_nil
    end

    it "registers the grammar successfully" do
      expect(real_finder.register!).to be true
    end

    private

    def toml_gem_available?
      require "toml"
      true
    rescue LoadError
      false
    end
  end
end

