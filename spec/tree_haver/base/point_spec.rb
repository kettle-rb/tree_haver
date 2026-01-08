# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Base::Point do
  let(:point) { described_class.new(5, 10) }

  describe "#initialize" do
    it "sets row and column" do
      expect(point.row).to eq(5)
      expect(point.column).to eq(10)
    end
  end

  describe "#[]" do
    it "supports symbol access for :row" do
      expect(point[:row]).to eq(5)
    end

    it "supports symbol access for :column" do
      expect(point[:column]).to eq(10)
    end

    it "supports string access for 'row'" do
      expect(point["row"]).to eq(5)
    end

    it "supports string access for 'column'" do
      expect(point["column"]).to eq(10)
    end

    it "supports numeric index 0 for row" do
      expect(point[0]).to eq(5)
    end

    it "supports numeric index 1 for column" do
      expect(point[1]).to eq(10)
    end

    it "returns nil for unknown key" do
      expect(point[:unknown]).to be_nil
    end
  end

  describe "#to_h" do
    it "returns hash with row and column" do
      expect(point.to_h).to eq({row: 5, column: 10})
    end
  end

  describe "#to_s" do
    it "returns coordinate string" do
      expect(point.to_s).to eq("(5, 10)")
    end
  end

  describe "#inspect" do
    it "returns descriptive string" do
      expect(point.inspect).to include("Point")
      expect(point.inspect).to include("row=5")
      expect(point.inspect).to include("column=10")
    end
  end

  describe "equality" do
    it "equals another point with same values" do
      other = described_class.new(5, 10)
      expect(point).to eq(other)
    end

    it "does not equal point with different values" do
      other = described_class.new(5, 11)
      expect(point).not_to eq(other)
    end
  end
end

