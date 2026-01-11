# frozen_string_literal: true

# Shared examples for Language API compliance
#
# These examples test the standard Language interface that all backends must implement.
# They ensure consistent behavior across MRI, FFI, Rust, Java, Citrus, Parslet,
# Prism, Psych, and other backends.
#
# @example Usage in backend specs
#   RSpec.describe TreeHaver::Backends::Citrus::Language do
#     let(:language) { create_language_for_backend }
#     let(:same_language) { create_language_for_backend } # equivalent language
#     let(:different_language) { create_different_language }
#
#     it_behaves_like "language api compliance"
#   end

# Core Language API that all implementations must provide
RSpec.shared_examples "language api compliance" do
  # Expects `language` to be defined as the language under test

  describe "required interface" do
    it "responds to #backend" do
      expect(language).to respond_to(:backend)
    end

    it "#backend returns a Symbol" do
      expect(language.backend).to be_a(Symbol)
    end
  end

  describe "optional interface" do
    it "responds to #name or #language_name" do
      expect(language).to respond_to(:name).or respond_to(:language_name)
    end
  end
end

# Language comparison and equality
RSpec.shared_examples "language comparison" do
  # Expects `language`, `same_language`, and `different_language` to be defined

  describe "#<=>" do
    it "returns 0 for equivalent languages" do
      expect(language <=> same_language).to eq(0)
    end

    it "returns nil for non-Language objects" do
      expect(language <=> "not a language").to be_nil
    end

    it "returns nil for languages with different backends" do
      other = double("other_lang", backend: :different_backend)
      allow(other).to receive(:is_a?).and_return(true)
      expect(language <=> other).to be_nil
    end
  end

  describe "#hash" do
    it "returns the same hash for equivalent languages" do
      expect(language.hash).to eq(same_language.hash)
    end
  end

  describe "#eql?" do
    it "returns true for equivalent languages" do
      expect(language.eql?(same_language)).to be true
    end

    it "returns false for different languages" do
      expect(language.eql?(different_language)).to be false
    end
  end

  describe "#==" do
    it "returns true for equivalent languages" do
      expect(language == same_language).to be true
    end

    it "returns false for different languages" do
      expect(language == different_language).to be false
    end
  end
end

# Language factory methods (class methods)
RSpec.shared_examples "language factory methods" do
  # Expects `language_class` to be the Language class under test
  # Expects `valid_path` to be a valid path/config for creating a language (or nil if not applicable)

  describe ".from_library" do
    it "class responds to .from_library" do
      expect(language_class).to respond_to(:from_library)
    end
  end

  describe ".from_path" do
    it "class responds to .from_path" do
      expect(language_class).to respond_to(:from_path)
    end

    it ".from_path is aliased to .from_library" do
      expect(language_class.method(:from_path)).to eq(language_class.method(:from_library))
    end
  end
end

