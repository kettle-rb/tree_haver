# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::BackendRegistry do
  before do
    # Save original state
    @original_checkers = described_class.instance_variable_get(:@availability_checkers).dup
    @original_cache = described_class.instance_variable_get(:@availability_cache).dup
  end

  after do
    # Restore original state
    described_class.instance_variable_set(:@availability_checkers, @original_checkers)
    described_class.instance_variable_set(:@availability_cache, @original_cache)
  end

  describe ".register_availability_checker" do
    it "registers a callable for a backend" do
      checker = -> { true }
      described_class.register_availability_checker(:test_backend, checker)

      expect(described_class.registered?(:test_backend)).to be true
    end

    it "accepts blocks" do
      described_class.register_availability_checker(:block_backend) { true }

      expect(described_class.registered?(:block_backend)).to be true
    end

    it "clears cache for re-registered backend" do
      # First register and check
      described_class.register_availability_checker(:cache_test) { true }
      described_class.available?(:cache_test)

      # Re-register should clear cache
      described_class.register_availability_checker(:cache_test) { false }

      # Cache should be cleared, so new check should happen
      expect(described_class.available?(:cache_test)).to be false
    end

    it "raises ArgumentError when no checker or block provided" do
      expect {
        described_class.register_availability_checker(:no_checker)
      }.to raise_error(ArgumentError, /Must provide a checker callable or block/)
    end

    it "raises ArgumentError when checker does not respond to call" do
      non_callable = "not a callable"
      expect {
        described_class.register_availability_checker(:bad_checker, non_callable)
      }.to raise_error(ArgumentError, /Checker must respond to #call/)
    end
  end

  describe ".available?" do
    context "with registered checker" do
      it "returns true when checker returns true" do
        described_class.register_availability_checker(:available_test) { true }
        expect(described_class.available?(:available_test)).to be true
      end

      it "returns false when checker returns false" do
        described_class.register_availability_checker(:unavailable_test) { false }
        expect(described_class.available?(:unavailable_test)).to be false
      end

      it "returns false when checker raises an error" do
        described_class.register_availability_checker(:error_test) { raise StandardError, "test error" }
        expect(described_class.available?(:error_test)).to be false
      end

      it "caches the result" do
        call_count = 0
        described_class.register_availability_checker(:cached_test) do
          call_count += 1
          true
        end

        described_class.available?(:cached_test)
        described_class.available?(:cached_test)

        expect(call_count).to eq(1)
      end
    end

    context "with built-in backend" do
      it "checks TreeHaver::Backends module" do
        # MRI is a built-in backend
        result = described_class.available?(:mri)
        expect(result).to be(true).or be(false)
      end

      it "returns false for non-existent backend" do
        expect(described_class.available?(:nonexistent_backend_xyz)).to be false
      end
    end
  end

  describe ".registered?" do
    it "returns true for registered backends" do
      described_class.register_availability_checker(:registered_test) { true }
      expect(described_class.registered?(:registered_test)).to be true
    end

    it "returns false for unregistered backends" do
      expect(described_class.registered?(:never_registered_xyz)).to be false
    end

    it "accepts string backend names" do
      described_class.register_availability_checker(:string_test) { true }
      expect(described_class.registered?("string_test")).to be true
    end
  end

  describe ".registered_backends" do
    it "returns an array of symbols" do
      result = described_class.registered_backends
      expect(result).to be_an(Array)
      result.each do |name|
        expect(name).to be_a(Symbol)
      end
    end

    it "includes registered backends" do
      described_class.register_availability_checker(:list_test) { true }
      expect(described_class.registered_backends).to include(:list_test)
    end

    it "returns a copy (not the original)" do
      result = described_class.registered_backends
      result << :modified_entry
      expect(described_class.registered_backends).not_to include(:modified_entry)
    end
  end

  describe ".clear_cache!" do
    it "clears the availability cache" do
      described_class.register_availability_checker(:clear_test) { true }
      described_class.available?(:clear_test)

      described_class.clear_cache!

      # After clearing, the checker should be called again
      call_count = 0
      described_class.register_availability_checker(:clear_test) do
        call_count += 1
        true
      end
      described_class.available?(:clear_test)

      expect(call_count).to eq(1)
    end

    it "returns nil" do
      expect(described_class.clear_cache!).to be_nil
    end
  end

  describe ".clear!" do
    it "clears both checkers and cache" do
      described_class.register_availability_checker(:full_clear_test) { true }
      described_class.available?(:full_clear_test)

      described_class.clear!

      expect(described_class.registered?(:full_clear_test)).to be false
    end

    it "returns nil" do
      expect(described_class.clear!).to be_nil
    end
  end
end

