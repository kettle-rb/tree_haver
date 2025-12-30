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
    context "when gem is available and grammar responds to :parse" do
      let(:mock_grammar) { double("grammar", parse: nil) }

      before do
        allow(finder).to receive(:require).with("toml-rb").and_return(true)
        allow(finder).to receive(:resolve_constant).with("TomlRB::Document").and_return(mock_grammar)
      end

      it "returns true" do
        expect(finder.available?).to be true
      end

      it "caches the result" do
        expect(finder).to receive(:require).once
        finder.available?
        finder.available?
      end
    end

    context "when gem is not available" do
      before do
        allow(finder).to receive(:require).with("toml-rb").and_raise(LoadError.new("cannot load toml-rb"))
      end

      it "returns false" do
        expect(finder.available?).to be false
      end
    end

    context "when constant is not found" do
      before do
        allow(finder).to receive(:require).with("toml-rb").and_return(true)
        allow(finder).to receive(:resolve_constant).with("TomlRB::Document").and_raise(NameError.new("uninitialized constant"))
      end

      it "returns false" do
        expect(finder.available?).to be false
      end
    end

    context "when grammar doesn't respond to :parse" do
      let(:mock_grammar) { double("grammar") }

      before do
        allow(finder).to receive(:require).with("toml-rb").and_return(true)
        allow(finder).to receive(:resolve_constant).with("TomlRB::Document").and_return(mock_grammar)
      end

      it "returns false" do
        expect(finder.available?).to be false
      end
    end

    context "when unexpected error occurs" do
      before do
        allow(finder).to receive(:require).with("toml-rb").and_raise(StandardError.new("unexpected"))
      end

      it "returns false" do
        expect(finder.available?).to be false
      end
    end
  end

  describe "#grammar_module" do
    context "when available" do
      let(:mock_grammar) { double("grammar", parse: nil) }

      before do
        allow(finder).to receive(:require).with("toml-rb").and_return(true)
        allow(finder).to receive(:resolve_constant).with("TomlRB::Document").and_return(mock_grammar)
      end

      it "returns the grammar module" do
        expect(finder.grammar_module).to eq(mock_grammar)
      end
    end

    context "when not available" do
      before do
        allow(finder).to receive(:require).with("toml-rb").and_raise(LoadError.new("cannot load"))
      end

      it "returns nil" do
        expect(finder.grammar_module).to be_nil
      end
    end
  end

  describe "#register!" do
    context "when grammar is available" do
      let(:mock_grammar) { double("grammar", parse: nil, name: "TomlRB::Document") }

      before do
        allow(finder).to receive(:require).with("toml-rb").and_return(true)
        allow(finder).to receive(:resolve_constant).with("TomlRB::Document").and_return(mock_grammar)
        allow(TreeHaver).to receive(:register_language)
      end

      it "registers the language" do
        expect(TreeHaver).to receive(:register_language).with(
          :toml,
          grammar_module: mock_grammar,
          gem_name: "toml-rb",
        )
        finder.register!
      end

      it "returns true" do
        expect(finder.register!).to be true
      end
    end

    context "when grammar is not available" do
      before do
        allow(finder).to receive(:require).with("toml-rb").and_raise(LoadError.new("cannot load"))
      end

      it "returns false by default" do
        expect(finder.register!).to be false
      end

      it "raises when raise_on_missing is true" do
        expect {
          finder.register!(raise_on_missing: true)
        }.to raise_error(TreeHaver::NotAvailable)
      end
    end
  end

  describe "#search_info" do
    before do
      allow(finder).to receive(:require).with("toml-rb").and_raise(LoadError.new("cannot load"))
    end

    it "returns diagnostic hash" do
      info = finder.search_info
      expect(info).to be_a(Hash)
      expect(info[:language]).to eq(:toml)
      expect(info[:gem_name]).to eq("toml-rb")
      expect(info[:grammar_const]).to eq("TomlRB::Document")
      expect(info[:require_path]).to eq("toml-rb")
      expect(info[:available]).to be false
    end

    context "when grammar is available" do
      let(:mock_grammar) { double("grammar", parse: nil, name: "TomlRB::Document") }

      before do
        allow(finder).to receive(:require).with("toml-rb").and_return(true)
        allow(finder).to receive(:resolve_constant).with("TomlRB::Document").and_return(mock_grammar)
      end

      it "includes grammar_module name" do
        info = finder.search_info
        expect(info[:available]).to be true
        expect(info[:grammar_module]).to eq("TomlRB::Document")
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

  describe "integration with real toml-rb gem" do
    let(:toml_finder) do
      described_class.new(
        language: :toml,
        gem_name: "toml-rb",
        grammar_const: "TomlRB::Document",
        require_path: "toml-rb",
      )
    end

    context "when toml-rb is installed and findable", :toml_rb do
      it "can find the grammar" do
        expect(toml_finder.available?).to be true
      end

      it "returns the grammar module" do
        expect(toml_finder.grammar_module).to eq(TomlRB::Document)
      end

      it "grammar responds to parse" do
        expect(toml_finder.grammar_module).to respond_to(:parse)
      end
    end
  end
end
