# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Point do
  let(:point) { described_class.new(5, 10) }

  describe "#initialize" do
    it "sets row and column" do
      expect(point.row).to eq(5)
      expect(point.column).to eq(10)
    end
  end

  describe "#[]" do
    it "provides hash-like access with symbol keys" do
      expect(point[:row]).to eq(5)
      expect(point[:column]).to eq(10)
    end

    it "provides hash-like access with string keys" do
      expect(point["row"]).to eq(5)
      expect(point["column"]).to eq(10)
    end

    it "returns nil for invalid keys" do
      expect(point[:invalid]).to be_nil
      expect(point["invalid"]).to be_nil
    end
  end

  describe "#to_h" do
    it "converts to a hash" do
      expect(point.to_h).to eq({row: 5, column: 10})
    end
  end

  describe "#to_s" do
    it "returns a readable string representation" do
      expect(point.to_s).to eq("(5, 10)")
    end
  end

  describe "#inspect" do
    it "returns a debug-friendly string" do
      result = point.inspect
      # TreeHaver::Point is an alias for TreeHaver::Base::Point
      expect(result).to match(/TreeHaver::(Base::)?Point/)
      expect(result).to include("row=5")
      expect(result).to include("column=10")
    end
  end
end
