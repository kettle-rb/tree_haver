# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Base::Language do
  let(:concrete_language_class) do
    Class.new(described_class) do
      class << self
        def from_library(path = nil, symbol: nil, name: nil)
          new(name || :test, backend: :test_backend)
        end
      end
    end
  end

  let(:language) { concrete_language_class.new(:ruby, backend: :test_backend) }

  describe "#initialize" do
    it "sets name as symbol" do
      expect(language.name).to eq(:ruby)
    end

    it "accepts string name and converts to symbol" do
      lang = concrete_language_class.new("ruby", backend: :test_backend)
      expect(lang.name).to eq(:ruby)
    end

    it "sets backend as symbol" do
      expect(language.backend).to eq(:test_backend)
    end

    it "accepts options hash" do
      lang = concrete_language_class.new(:ruby, backend: :test, options: {foo: :bar})
      expect(lang.options).to eq({foo: :bar})
    end

    it "defaults options to empty hash" do
      expect(language.options).to eq({})
    end
  end

  describe "#language_name" do
    it "is an alias for name" do
      expect(language.language_name).to eq(language.name)
    end
  end

  describe "#<=>" do
    it "compares languages by name when same backend" do
      lang1 = concrete_language_class.new(:ruby, backend: :test_backend)
      lang2 = concrete_language_class.new(:python, backend: :test_backend)

      expect(lang1 <=> lang2).to be > 0  # ruby > python alphabetically
      expect(lang2 <=> lang1).to be < 0
    end

    it "returns nil for different backends" do
      lang1 = concrete_language_class.new(:ruby, backend: :backend_a)
      lang2 = concrete_language_class.new(:ruby, backend: :backend_b)

      expect(lang1 <=> lang2).to be_nil
    end

    it "returns nil for non-Language objects" do
      expect(language <=> "not a language").to be_nil
    end

    it "returns 0 for same name and backend" do
      lang1 = concrete_language_class.new(:ruby, backend: :test_backend)
      lang2 = concrete_language_class.new(:ruby, backend: :test_backend)

      expect(lang1 <=> lang2).to eq(0)
    end
  end

  describe "#hash" do
    it "returns same hash for equivalent languages" do
      lang1 = concrete_language_class.new(:ruby, backend: :test_backend, options: {a: 1})
      lang2 = concrete_language_class.new(:ruby, backend: :test_backend, options: {a: 1})

      expect(lang1.hash).to eq(lang2.hash)
    end

    it "returns different hash for different options" do
      lang1 = concrete_language_class.new(:ruby, backend: :test_backend, options: {a: 1})
      lang2 = concrete_language_class.new(:ruby, backend: :test_backend, options: {a: 2})

      expect(lang1.hash).not_to eq(lang2.hash)
    end
  end

  describe "#eql?" do
    it "returns true for equivalent languages" do
      lang1 = concrete_language_class.new(:ruby, backend: :test_backend, options: {a: 1})
      lang2 = concrete_language_class.new(:ruby, backend: :test_backend, options: {a: 1})

      expect(lang1.eql?(lang2)).to be true
    end

    it "returns false for different name" do
      lang1 = concrete_language_class.new(:ruby, backend: :test_backend)
      lang2 = concrete_language_class.new(:python, backend: :test_backend)

      expect(lang1.eql?(lang2)).to be false
    end

    it "returns false for different backend" do
      lang1 = concrete_language_class.new(:ruby, backend: :backend_a)
      lang2 = concrete_language_class.new(:ruby, backend: :backend_b)

      expect(lang1.eql?(lang2)).to be false
    end

    it "returns false for different options" do
      lang1 = concrete_language_class.new(:ruby, backend: :test_backend, options: {a: 1})
      lang2 = concrete_language_class.new(:ruby, backend: :test_backend, options: {a: 2})

      expect(lang1.eql?(lang2)).to be false
    end

    it "returns false for non-Language objects" do
      expect(language.eql?("not a language")).to be false
    end
  end

  describe "#inspect" do
    it "includes class name" do
      expect(language.inspect).to match(/#<.*Language/)
    end

    it "includes name" do
      expect(language.inspect).to include("name=ruby")
    end

    it "includes backend" do
      expect(language.inspect).to include("backend=test_backend")
    end

    it "includes options when present" do
      lang = concrete_language_class.new(:ruby, backend: :test, options: {foo: :bar})
      expect(lang.inspect).to include("options=")
    end

    it "omits options when empty" do
      expect(language.inspect).not_to include("options=")
    end
  end

  describe ".from_library" do
    it "raises NotImplementedError in base class" do
      expect {
        described_class.from_library("/path/to/lib.so")
      }.to raise_error(NotImplementedError)
    end

    it "works in concrete subclass" do
      lang = concrete_language_class.from_library("/path", name: :ruby)
      expect(lang.name).to eq(:ruby)
    end
  end
end
