# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Base::Parser do
  let(:concrete_parser_class) do
    Class.new(described_class) do
      def parse(source)
        # Mock parse implementation
        "parsed: #{source}"
      end
    end
  end

  let(:parser) { concrete_parser_class.new }

  describe "#initialize" do
    it "sets language to nil" do
      expect(parser.language).to be_nil
    end
  end

  describe "#language=" do
    it "sets the language" do
      parser.language = :toml
      expect(parser.language).to eq(:toml)
    end
  end

  describe "#parse" do
    it "raises NotImplementedError in base class" do
      base_parser = described_class.new
      expect { base_parser.parse("test") }.to raise_error(NotImplementedError)
    end

    it "calls implementation in concrete class" do
      result = parser.parse("test content")
      expect(result).to eq("parsed: test content")
    end
  end

  describe "#parse_string" do
    it "delegates to parse by default" do
      result = parser.parse_string(nil, "test content")
      expect(result).to eq("parsed: test content")
    end

    it "ignores old_tree parameter in default implementation" do
      old_tree = double("old_tree")
      result = parser.parse_string(old_tree, "test content")
      expect(result).to eq("parsed: test content")
    end
  end
end

