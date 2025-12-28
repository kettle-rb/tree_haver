# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Thread-local backend selection" do
  # NOTE: Do NOT reset backends_used! The tracking is essential for backend_protect

  after do
    # Clean up thread-local state after each test
    Thread.current[:tree_haver_backend_context] = nil
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "TreeHaver.current_backend_context" do
    it "returns a hash with backend and depth keys" do
      ctx = TreeHaver.current_backend_context

      expect(ctx).to be_a(Hash)
      expect(ctx).to have_key(:backend)
      expect(ctx).to have_key(:depth)
    end

    it "initializes with nil backend and 0 depth" do
      ctx = TreeHaver.current_backend_context

      expect(ctx[:backend]).to be_nil
      expect(ctx[:depth]).to eq(0)
    end

    it "is isolated per thread" do
      Thread.current[:tree_haver_backend_context] = {backend: :ffi, depth: 1}

      other_context = nil
      thread = Thread.new do
        other_context = TreeHaver.current_backend_context
      end
      thread.join

      expect(other_context[:backend]).to be_nil
      expect(other_context[:depth]).to eq(0)
      expect(Thread.current[:tree_haver_backend_context][:backend]).to eq(:ffi)
    end
  end

  describe "TreeHaver.effective_backend" do
    it "returns global backend when no thread-local context set" do
      TreeHaver.backend = :ffi
      expect(TreeHaver.effective_backend).to eq(:ffi)
    end

    it "returns thread-local backend when set" do
      TreeHaver.backend = :ffi
      ctx = TreeHaver.current_backend_context
      ctx[:backend] = :mri

      expect(TreeHaver.effective_backend).to eq(:mri)
    end

    it "falls back to :auto when neither global nor thread-local is set" do
      TreeHaver.backend = nil
      expect(TreeHaver.effective_backend).to eq(:auto)
    end

    it "prioritizes thread-local over global" do
      TreeHaver.backend = :ffi
      ctx = TreeHaver.current_backend_context
      ctx[:backend] = :mri

      expect(TreeHaver.effective_backend).to eq(:mri)
    end
  end

  describe "TreeHaver.with_backend" do
    it "sets backend for duration of block" do
      expect(TreeHaver.effective_backend).to eq(:auto)

      TreeHaver.with_backend(:ffi) do
        expect(TreeHaver.effective_backend).to eq(:ffi)
      end

      expect(TreeHaver.effective_backend).to eq(:auto)
    end

    it "returns the block's return value" do
      result = TreeHaver.with_backend(:ffi) do
        "test result"
      end

      expect(result).to eq("test result")
    end

    it "supports nested blocks (inner overrides outer)" do
      TreeHaver.with_backend(:ffi) do
        expect(TreeHaver.effective_backend).to eq(:ffi)

        TreeHaver.with_backend(:mri) do
          expect(TreeHaver.effective_backend).to eq(:mri)

          TreeHaver.with_backend(:citrus) do
            expect(TreeHaver.effective_backend).to eq(:citrus)
          end

          expect(TreeHaver.effective_backend).to eq(:mri)
        end

        expect(TreeHaver.effective_backend).to eq(:ffi)
      end

      expect(TreeHaver.effective_backend).to eq(:auto)
    end

    it "restores backend even on exception" do
      expect do
        TreeHaver.with_backend(:ffi) do
          raise StandardError, "test error"
        end
      end.to raise_error(StandardError, "test error")

      expect(TreeHaver.effective_backend).to eq(:auto)
    end

    it "increments and decrements depth correctly" do
      ctx = TreeHaver.current_backend_context
      expect(ctx[:depth]).to eq(0)

      TreeHaver.with_backend(:ffi) do
        expect(ctx[:depth]).to eq(1)

        TreeHaver.with_backend(:mri) do
          expect(ctx[:depth]).to eq(2)
        end

        expect(ctx[:depth]).to eq(1)
      end

      expect(ctx[:depth]).to eq(0)
    end

    it "raises ArgumentError when backend name is nil" do
      expect do
        TreeHaver.with_backend(nil) do
          # Should not execute
        end
      end.to raise_error(ArgumentError, "Backend name required")
    end

    it "accepts string backend names and converts to symbol" do
      TreeHaver.with_backend("ffi") do
        expect(TreeHaver.effective_backend).to eq(:ffi)
      end
    end

    it "works with all valid backend names" do
      [:mri, :rust, :ffi, :java, :citrus, :auto].each do |backend_name|
        TreeHaver.with_backend(backend_name) do
          expect(TreeHaver.effective_backend).to eq(backend_name)
        end
      end
    end
  end

  describe "Thread isolation" do
    it "different threads can use different backends simultaneously" do
      results = {}

      thread1 = Thread.new do
        TreeHaver.with_backend(:ffi) do
          results[:thread1_start] = TreeHaver.effective_backend
          sleep 0.05  # Ensure overlap
          results[:thread1_end] = TreeHaver.effective_backend
        end
      end

      thread2 = Thread.new do
        TreeHaver.with_backend(:mri) do
          results[:thread2_start] = TreeHaver.effective_backend
          sleep 0.05  # Ensure overlap
          results[:thread2_end] = TreeHaver.effective_backend
        end
      end

      thread1.join
      thread2.join

      expect(results[:thread1_start]).to eq(:ffi)
      expect(results[:thread1_end]).to eq(:ffi)
      expect(results[:thread2_start]).to eq(:mri)
      expect(results[:thread2_end]).to eq(:mri)
    end

    it "main thread is unaffected by other threads" do
      TreeHaver.backend = :ffi

      thread = Thread.new do
        TreeHaver.with_backend(:mri) do
          sleep 0.05
        end
      end

      sleep 0.02  # Let thread start
      main_thread_backend = TreeHaver.effective_backend
      thread.join

      expect(main_thread_backend).to eq(:ffi)
      expect(TreeHaver.effective_backend).to eq(:ffi)
    end

    it "handles multiple concurrent threads with different backends" do
      results = Concurrent::Array.new if defined?(Concurrent::Array)
      results ||= []
      mutex = Mutex.new

      threads = [:ffi, :mri, :rust, :citrus, :auto].map do |backend_name|
        Thread.new do
          TreeHaver.with_backend(backend_name) do
            sleep 0.01 * rand  # Random timing
            backend = TreeHaver.effective_backend
            mutex.synchronize { results << backend }
          end
        end
      end

      threads.each(&:join)

      expect(results.size).to eq(5)
      expect(results).to contain_exactly(:ffi, :mri, :rust, :citrus, :auto)
    end
  end

  describe "TreeHaver.backend_module" do
    it "uses effective_backend instead of global backend" do
      # Set global to :auto but thread-local to specific backend
      TreeHaver.backend = :auto

      TreeHaver.with_backend(:ffi) do
        mod = TreeHaver.backend_module
        # Should resolve based on :ffi, not :auto
        expect(mod).to eq(TreeHaver::Backends::FFI) if TreeHaver::Backends::FFI.available?
      end
    end

    it "respects thread-local context when selecting backend" do
      available_backends = []
      available_backends << :mri if TreeHaver::Backends::MRI.available?
      available_backends << :ffi if TreeHaver::Backends::FFI.available?
      available_backends << :citrus if TreeHaver::Backends::Citrus.available?

      skip "No backends available for testing" if available_backends.empty?

      backend_name = available_backends.first

      TreeHaver.with_backend(backend_name) do
        mod = TreeHaver.backend_module
        expect(mod).not_to be_nil
        expect(mod.capabilities[:backend]).to eq(backend_name)
      end
    end
  end

  describe "TreeHaver.resolve_effective_backend" do
    it "returns explicit backend when provided" do
      TreeHaver.backend = :ffi
      TreeHaver.with_backend(:mri) do
        result = TreeHaver.resolve_effective_backend(:citrus)
        expect(result).to eq(:citrus)
      end
    end

    it "returns thread-local backend when no explicit backend" do
      TreeHaver.backend = :ffi
      TreeHaver.with_backend(:mri) do
        result = TreeHaver.resolve_effective_backend(nil)
        expect(result).to eq(:mri)
      end
    end

    it "returns global backend when no explicit or thread-local backend" do
      TreeHaver.backend = :ffi
      result = TreeHaver.resolve_effective_backend(nil)
      expect(result).to eq(:ffi)
    end

    it "returns :auto when nothing is set" do
      TreeHaver.backend = nil
      result = TreeHaver.resolve_effective_backend(nil)
      expect(result).to eq(:auto)
    end

    it "converts string to symbol" do
      result = TreeHaver.resolve_effective_backend("ffi")
      expect(result).to eq(:ffi)
    end

    it "demonstrates precedence: explicit > thread-local > global" do
      TreeHaver.backend = :auto

      TreeHaver.with_backend(:ffi) do
        # Thread-local context says :ffi
        expect(TreeHaver.resolve_effective_backend(nil)).to eq(:ffi)

        # Explicit override wins
        expect(TreeHaver.resolve_effective_backend(:mri)).to eq(:mri)
      end

      # Outside block, global wins
      expect(TreeHaver.resolve_effective_backend(nil)).to eq(:auto)
    end
  end

  describe "TreeHaver.resolve_backend_module" do
    it "returns correct module for explicit backend (non-conflicting)" do
      # Use citrus since it never conflicts
      mod = TreeHaver.resolve_backend_module(:citrus)
      expect(mod).to eq(TreeHaver::Backends::Citrus)
    end

    it "returns correct module for thread-local backend" do
      TreeHaver.with_backend(:citrus) do
        mod = TreeHaver.resolve_backend_module(nil)
        expect(mod).to eq(TreeHaver::Backends::Citrus)
      end
    end

    it "returns correct module for each backend type (respecting conflicts)" do
      {
        mri: TreeHaver::Backends::MRI,
        rust: TreeHaver::Backends::Rust,
        ffi: TreeHaver::Backends::FFI,
        java: TreeHaver::Backends::Java,
        citrus: TreeHaver::Backends::Citrus,
      }.each do |name, expected_module|
        # Check FFI conflict: MRI loaded (native lib present) AND recorded in backends_used AND protection enabled
        # Note: mri_recorded must be checked here, not at test start, because it may have been
        # recorded during dependency detection (TreeHaver::RSpec::DependencyTags.mri_backend_available?)
        if name == :ffi && defined?(TreeSitter::Parser) && TreeHaver.backends_used.include?(:mri) && TreeHaver.backend_protect?
          expect {
            TreeHaver.resolve_backend_module(name)
          }.to raise_error(TreeHaver::BackendConflict)
          next
        end

        mod = TreeHaver.resolve_backend_module(name)
        # resolve_backend_module returns nil if backend is not available
        if expected_module.respond_to?(:available?) && !expected_module.available?
          expect(mod).to be_nil
        else
          expect(mod).to eq(expected_module)
        end
      end
    end

    it "falls back to normal resolution for :auto" do
      mod = TreeHaver.resolve_backend_module(:auto)
      expect(mod).to eq(TreeHaver.backend_module)
    end

    it "respects thread-local context when no explicit backend (non-conflicting)" do
      # Use citrus since it never conflicts
      TreeHaver.with_backend(:citrus) do
        mod = TreeHaver.resolve_backend_module(nil)
        expect(mod).to eq(TreeHaver::Backends::Citrus)
      end
    end

    it "raises BackendConflict when FFI requested after MRI used", :backend_conflict do
      skip "MRI not loaded, cannot test conflict" unless defined?(TreeSitter::Parser)
      skip "Backend protection is disabled" unless TreeHaver.backend_protect?

      # Record MRI usage (it's already loaded)
      TreeHaver.record_backend_usage(:mri)

      expect {
        TreeHaver.resolve_backend_module(:ffi)
      }.to raise_error(TreeHaver::BackendConflict, /blocked by.*mri/i)
    end
  end
end
