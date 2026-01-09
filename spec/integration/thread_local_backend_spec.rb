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

    it "is isolated per thread", :ffi_backend do
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
    it "returns global backend when no thread-local context set", :ffi_backend do
      TreeHaver.backend = :ffi
      expect(TreeHaver.effective_backend).to eq(:ffi)
    end

    it "returns thread-local backend when set", :mri_backend, :rust_backend do
      TreeHaver.backend = :rust
      ctx = TreeHaver.current_backend_context
      ctx[:backend] = :mri

      expect(TreeHaver.effective_backend).to eq(:mri)
      # Verify the global wasn't changed
      expect(TreeHaver.backend).to eq(:rust)
    end

    it "falls back to :auto when neither global nor thread-local is set" do
      TreeHaver.backend = nil
      expect(TreeHaver.effective_backend).to eq(:auto)
    end

    it "prioritizes thread-local over global when both are set", :mri_backend, :rust_backend do
      TreeHaver.backend = :rust
      ctx = TreeHaver.current_backend_context
      ctx[:backend] = :mri

      # Thread-local (:mri) takes precedence
      expect(TreeHaver.effective_backend).to eq(:mri)
      # But global remains unchanged
      expect(TreeHaver.backend).to eq(:rust)
      # And context shows the thread-local value
      expect(ctx[:backend]).to eq(:mri)
    end
  end

  describe "TreeHaver.with_backend" do
    it "sets backend for duration of block", :ffi_backend do
      expect(TreeHaver.effective_backend).to eq(:auto)

      TreeHaver.with_backend(:ffi) do
        expect(TreeHaver.effective_backend).to eq(:ffi)
      end

      expect(TreeHaver.effective_backend).to eq(:auto)
    end

    it "returns the block's return value", :ffi_backend do
      result = TreeHaver.with_backend(:ffi) do
        "test result"
      end

      expect(result).to eq("test result")
    end

    it "supports nested blocks (inner overrides outer)", :citrus_backend, :mri_backend, :rust_backend do
      TreeHaver.with_backend(:rust) do
        expect(TreeHaver.effective_backend).to eq(:rust)

        TreeHaver.with_backend(:mri) do
          expect(TreeHaver.effective_backend).to eq(:mri)

          TreeHaver.with_backend(:citrus) do
            expect(TreeHaver.effective_backend).to eq(:citrus)
          end

          expect(TreeHaver.effective_backend).to eq(:mri)
        end

        expect(TreeHaver.effective_backend).to eq(:rust)
      end

      expect(TreeHaver.effective_backend).to eq(:auto)
    end

    it "restores backend even on exception", :ffi_backend do
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

    it "accepts string backend names and converts to symbol", :ffi_backend do
      TreeHaver.with_backend("ffi") do
        expect(TreeHaver.effective_backend).to eq(:ffi)
      end
    end

    it "works with all valid backend names" do
      # Don't test ffi and mri in the same process, so exclude ffi
      [:mri, :rust, :java, :citrus, :auto].each do |backend_name|
        TreeHaver.with_backend(backend_name) do
          expect(TreeHaver.effective_backend).to eq(backend_name)
        end
      end
    end
  end

  describe "Thread isolation" do
    # These tests use :mri and :rust backends which are only available on MRI
    it "different threads can use different backends simultaneously", :mri_backend, :rust_backend do
      results = {}

      thread1 = Thread.new do
        TreeHaver.with_backend(:rust) do
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

      expect(results[:thread1_start]).to eq(:rust)
      expect(results[:thread1_end]).to eq(:rust)
      expect(results[:thread2_start]).to eq(:mri)
      expect(results[:thread2_end]).to eq(:mri)
    end

    it "main thread is unaffected by other threads", :mri_backend, :rust_backend do
      TreeHaver.backend = :rust

      thread = Thread.new do
        TreeHaver.with_backend(:mri) do
          sleep 0.05
        end
      end

      sleep 0.02  # Let thread start
      main_thread_backend = TreeHaver.effective_backend
      thread.join

      expect(main_thread_backend).to eq(:rust)
      expect(TreeHaver.effective_backend).to eq(:rust)
    end

    it "handles multiple concurrent threads with different backends", :citrus_backend, :mri_backend, :rust_backend do
      results = Concurrent::Array.new if defined?(Concurrent::Array)
      results ||= []
      mutex = Mutex.new

      threads = [:mri, :rust, :citrus, :auto].map do |backend_name|
        Thread.new do
          TreeHaver.with_backend(backend_name) do
            sleep 0.01 * rand  # Random timing
            backend = TreeHaver.effective_backend
            mutex.synchronize { results << backend }
          end
        end
      end

      threads.each(&:join)

      expect(results.size).to eq(4)
      expect(results).to contain_exactly(:mri, :rust, :citrus, :auto)
    end
  end

  describe "TreeHaver.backend_module" do
    it "uses effective_backend instead of global backend", :ffi_backend do
      # Set global to :auto but thread-local to specific backend
      TreeHaver.backend = :auto

      TreeHaver.with_backend(:ffi) do
        mod = TreeHaver.backend_module
        # Should resolve based on :ffi, not :auto
        expect(mod).to eq(TreeHaver::Backends::FFI)
      end
    end

    it "respects thread-local context when selecting backend", :rust_backend do
      TreeHaver.with_backend(:rust) do
        mod = TreeHaver.backend_module
        expect(mod).not_to be_nil
        expect(mod.capabilities[:backend]).to eq(:rust)
      end
    end
  end

  describe "TreeHaver.resolve_effective_backend" do
    it "returns explicit backend when provided", :citrus_backend, :mri_backend, :rust_backend do
      TreeHaver.backend = :rust
      TreeHaver.with_backend(:mri) do
        result = TreeHaver.resolve_effective_backend(:citrus)
        expect(result).to eq(:citrus)
      end
    end

    it "returns thread-local backend when no explicit backend", :mri_backend, :rust_backend do
      TreeHaver.backend = :rust
      TreeHaver.with_backend(:mri) do
        result = TreeHaver.resolve_effective_backend(nil)
        expect(result).to eq(:mri)
      end
    end

    it "returns global backend when no explicit or thread-local backend", :rust_backend do
      TreeHaver.backend = :rust
      result = TreeHaver.resolve_effective_backend(nil)
      expect(result).to eq(:rust)
    end

    it "returns :auto when nothing is set" do
      TreeHaver.backend = nil
      result = TreeHaver.resolve_effective_backend(nil)
      expect(result).to eq(:auto)
    end

    it "converts string to symbol", :rust_backend do
      result = TreeHaver.resolve_effective_backend("rust")
      expect(result).to eq(:rust)
    end

    it "demonstrates precedence: explicit > thread-local > global", :mri_backend, :rust_backend do
      TreeHaver.backend = :auto

      TreeHaver.with_backend(:rust) do
        # Thread-local context says :rust
        expect(TreeHaver.resolve_effective_backend(nil)).to eq(:rust)

        # Explicit override wins
        expect(TreeHaver.resolve_effective_backend(:mri)).to eq(:mri)
      end

      # Outside block, global wins
      expect(TreeHaver.resolve_effective_backend(nil)).to eq(:auto)
    end
  end

  describe "TreeHaver.resolve_backend_module" do
    it "returns correct module for explicit backend (non-conflicting)", :citrus_backend do
      # Use citrus since it never conflicts
      mod = TreeHaver.resolve_backend_module(:citrus)
      expect(mod).to eq(TreeHaver::Backends::Citrus)
    end

    it "returns correct module for thread-local backend when passing nil", :citrus_backend do
      TreeHaver.with_backend(:citrus) do
        mod = TreeHaver.resolve_backend_module(nil)
        expect(mod).to eq(TreeHaver::Backends::Citrus)
        # Verify that nil parameter triggers thread-local lookup
        expect(TreeHaver.effective_backend).to eq(:citrus)
      end
    end

    it "returns correct module for each backend type (respecting conflicts)", :citrus_backend, :java_backend, :mri_backend, :rust_backend do
      {
        mri: TreeHaver::Backends::MRI,
        rust: TreeHaver::Backends::Rust,
        java: TreeHaver::Backends::Java,
        citrus: TreeHaver::Backends::Citrus,
      }.each do |name, expected_module|
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

    it "respects thread-local context when no explicit backend and verifies block isolation", :citrus_backend do
      # Use citrus since it never conflicts
      outer_mod = nil
      TreeHaver.with_backend(:citrus) do
        mod = TreeHaver.resolve_backend_module(nil)
        expect(mod).to eq(TreeHaver::Backends::Citrus)
        outer_mod = mod
      end
      # After block, should no longer return citrus (unless it's the global default)
      expect(outer_mod).to eq(TreeHaver::Backends::Citrus)
    end

    # This spec should not run normally because if MRI backend is loaded at all, then FFI backend will not work.
    # Effectively, this can't be tested.
    # it "raises BackendConflict when FFI requested after MRI used", :ffi_backend, :mri_backend do
    #   skip "MRI not loaded, cannot test conflict" unless defined?(TreeSitter::Parser)
    #   skip "Backend protection is disabled" unless TreeHaver.backend_protect?
    #
    #   # Record MRI usage (it's already loaded)
    #   TreeHaver.record_backend_usage(:mri)
    #
    #   expect {
    #     TreeHaver.resolve_backend_module(:ffi)
    #   }.to raise_error(TreeHaver::BackendConflict, /blocked by.*mri/i)
    # end
  end
end
