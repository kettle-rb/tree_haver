# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::CitrusGrammarFinder do
  let(:finder) do
    described_class.new(
      language: :toml,
      gem_name: "toml-rb",
      grammar_const: "TomlRB::Document",
    )
  end

  after do
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "#initialize" do
    it "creates a finder with required parameters" do
      f = described_class.new(
        language: :json,
        gem_name: "json-rb",
        grammar_const: "JsonRB::Grammar",
      )
      expect(f.language_name).to eq(:json)
      expect(f.gem_name).to eq("json-rb")
      expect(f.grammar_const).to eq("JsonRB::Grammar")
    end

    it "converts language to symbol" do
      f = described_class.new(
        language: "yaml",
        gem_name: "yaml-rb",
        grammar_const: "YamlRB::Grammar",
      )
      expect(f.language_name).to eq(:yaml)
    end

    it "defaults require_path to gem_name as-is" do
      f = described_class.new(
        language: :toml,
        gem_name: "toml-rb",
        grammar_const: "TomlRB::Document",
      )
      expect(f.require_path).to eq("toml-rb")
    end

    it "accepts custom require_path" do
      f = described_class.new(
        language: :toml,
        gem_name: "toml-rb",
        grammar_const: "TomlRB::Document",
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
    end

    # Note: Tests for LoadError, NameError, TypeError, and unexpected errors
    # are not included because they would require mocking `require`, which
    # is fragile and can cause unexpected side effects.
    # The error handling code is marked with # :nocov: in the source.
  end

  describe "#grammar_module" do
    context "with nil require_path" do
      let(:nil_finder) do
        described_class.new(
          language: :test,
          gem_name: nil,
          grammar_const: "Test::Grammar",
        )
      end

      it "returns nil when not available" do
        expect(nil_finder.grammar_module).to be_nil
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
  end

  describe "#search_info" do
    it "returns diagnostic hash" do
      info = finder.search_info
      expect(info).to be_a(Hash)
      expect(info[:language]).to eq(:toml)
      expect(info[:gem_name]).to eq("toml-rb")
      expect(info[:grammar_const]).to eq("TomlRB::Document")
      expect(info[:require_path]).to eq("toml-rb")
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
        expect(info[:grammar_module]).to be_nil
      end
    end
  end

  describe "#not_found_message" do
    it "returns helpful error message" do
      msg = finder.not_found_message
      expect(msg).to include("toml")
      expect(msg).to include("toml-rb")
      expect(msg).to include("gem install")
    end
  end

  describe "#resolve_constant (private)" do
    it "resolves simple constant" do
      result = finder.send(:resolve_constant, "String")
      expect(result).to eq(String)
    end

    it "resolves nested constant" do
      result = finder.send(:resolve_constant, "TreeHaver::Backends")
      expect(result).to eq(TreeHaver::Backends)
    end

    it "resolves deeply nested constant" do
      result = finder.send(:resolve_constant, "TreeHaver::Backends::Citrus")
      expect(result).to eq(TreeHaver::Backends::Citrus)
    end

    it "raises NameError for unknown constant" do
      expect {
        finder.send(:resolve_constant, "NonExistent::Constant")
      }.to raise_error(NameError)
    end
  end

  describe "integration with real toml-rb gem", :toml_rb do
    let(:toml_finder) do
      described_class.new(
        language: :toml,
        gem_name: "toml-rb",
        grammar_const: "TomlRB::Document",
        require_path: "toml-rb",
      )
    end

    it "can find the grammar" do
      expect(toml_finder.available?).to be true
    end

    it "returns the grammar module" do
      expect(toml_finder.grammar_module).to eq(TomlRB::Document)
    end

    it "grammar responds to parse" do
      expect(toml_finder.grammar_module).to respond_to(:parse)
    end

    it "caches the availability result" do
      toml_finder.available?
      # Access internal state to verify caching
      expect(toml_finder.instance_variable_get(:@load_attempted)).to be true
      expect(toml_finder.instance_variable_get(:@available)).to be true
    end

    it "can register the language" do
      allow(TreeHaver).to receive(:register_language)
      expect(toml_finder.register!).to be true
      expect(TreeHaver).to have_received(:register_language).with(
        :toml,
        grammar_module: TomlRB::Document,
        gem_name: "toml-rb",
      )
    end

    it "search_info shows available grammar" do
      info = toml_finder.search_info
      expect(info[:available]).to be true
      expect(info[:grammar_module]).to eq("TomlRB::Document")
    end
  end
end
