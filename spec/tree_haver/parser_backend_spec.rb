# frozen_string_literal: true

require "spec_helper"

RSpec.describe "TreeHaver::Parser with backend parameter" do
  # NOTE: Do NOT reset backends_used! The tracking is essential for backend_protect

  after do
    # Clean up thread-local state
    Thread.current[:tree_haver_backend_context] = nil
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "Parser.new" do
    context "with no backend parameter" do
      it "uses effective backend from context/global (non-conflicting)" do
        skip "No backend available" unless TreeHaver.backend_module

        # Use citrus since it never conflicts
        TreeHaver.with_backend(:citrus) do
          parser = TreeHaver::Parser.new
          expect(parser.backend).to eq(:citrus)
        end
      end

      it "uses global backend when no context set" do
        skip "No backend available" unless TreeHaver.backend_module

        TreeHaver.backend = :auto
        parser = TreeHaver::Parser.new
        # parser.backend returns the actual resolved backend, not :auto
        # It should be one of the available backends
        valid_backends = [:mri, :rust, :ffi, :java, :citrus]
        expect(valid_backends).to include(parser.backend)
      end
    end

    context "with explicit backend parameter" do
      it "uses specified backend regardless of context (non-conflicting)" do
        skip "Citrus backend not available" unless TreeHaver::Backends::Citrus.available?

        TreeHaver.with_backend(:mri) do
          parser = TreeHaver::Parser.new(backend: :citrus)
          expect(parser.backend).to eq(:citrus)
        end
      end

      it "overrides global backend setting (non-conflicting)" do
        skip "Citrus backend not available" unless TreeHaver::Backends::Citrus.available?

        TreeHaver.backend = :mri
        parser = TreeHaver::Parser.new(backend: :citrus)
        expect(parser.backend).to eq(:citrus)
      end

      it "creates parser with MRI backend when specified" do
        skip "MRI backend not available" unless TreeHaver::Backends::MRI.available?

        parser = TreeHaver::Parser.new(backend: :mri)
        expect(parser.backend).to eq(:mri)
      end

      it "creates parser with FFI backend when specified", :ffi do
        parser = TreeHaver::Parser.new(backend: :ffi)
        expect(parser.backend).to eq(:ffi)
      end

      it "creates parser with Rust backend when specified", :rust_backend do
        parser = TreeHaver::Parser.new(backend: :rust)
        expect(parser.backend).to eq(:rust)
      end

      it "creates parser with MRI backend when specified", :mri_backend do
        parser = TreeHaver::Parser.new(backend: :mri)
        expect(parser.backend).to eq(:mri)
      end

      it "creates parser with Citrus backend when specified", :citrus_backend do
        parser = TreeHaver::Parser.new(backend: :citrus)
        expect(parser.backend).to eq(:citrus)
      end

      it "raises NotAvailable when requested backend is not available" do
        # Try to use a backend that definitely won't be available
        unavailable_backend = if defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
          :mri  # MRI backend won't work on JRuby
        else
          :java  # Java backend won't work on MRI
        end

        expect do
          TreeHaver::Parser.new(backend: unavailable_backend)
        end.to raise_error(TreeHaver::NotAvailable, /Requested backend .* is not available/)
      end

      it "accepts string backend names", :mri_backend do
        parser = TreeHaver::Parser.new(backend: "mri")
        expect(parser.backend).to eq(:mri)
      end
    end

    context "with backend introspection" do
      it "returns thread-local backend when no explicit backend set", :mri_backend do
        TreeHaver.with_backend(:mri) do
          parser = TreeHaver::Parser.new
          expect(parser.backend).to eq(:mri)
        end
      end

      it "returns explicit backend when set", :mri_backend, :rust_backend do
        TreeHaver.with_backend(:mri) do
          parser = TreeHaver::Parser.new(backend: :rust)
          expect(parser.backend).to eq(:rust)
        end
      end

      it "returns consistent backend throughout parser lifecycle", :mri_backend do
        parser = TreeHaver::Parser.new(backend: :mri)

        # Change context after parser creation
        TreeHaver.with_backend(:rust) do
          # Parser should still report :mri
          expect(parser.backend).to eq(:mri)
        end
      end
    end
  end

  describe "Thread-safe parser creation" do
    it "creates parsers with different backends in concurrent threads" do
      # Use Rust and Citrus which can coexist (not FFI which conflicts with MRI)
      rust_available = TreeHaver::Backends::Rust.available?
      citrus_available = TreeHaver::Backends::Citrus.available?

      skip "Need at least Rust and Citrus backends" unless rust_available && citrus_available

      results = Concurrent::Array.new if defined?(Concurrent::Array)
      results ||= []
      mutex = Mutex.new

      thread1 = Thread.new do
        TreeHaver.with_backend(:rust) do
          parser = TreeHaver::Parser.new
          mutex.synchronize { results << {thread: 1, backend: parser.backend} }
        end
      end

      thread2 = Thread.new do
        TreeHaver.with_backend(:citrus) do
          parser = TreeHaver::Parser.new
          mutex.synchronize { results << {thread: 2, backend: parser.backend} }
        end
      end

      thread1.join
      thread2.join

      expect(results.size).to eq(2)
      expect(results.find { |r| r[:thread] == 1 }[:backend]).to eq(:rust)
      expect(results.find { |r| r[:thread] == 2 }[:backend]).to eq(:citrus)
    end

    it "creates parsers with explicit backends in concurrent threads" do
      # Use Rust and Citrus which can coexist (not FFI which conflicts with MRI)
      rust_available = TreeHaver::Backends::Rust.available?
      citrus_available = TreeHaver::Backends::Citrus.available?

      skip "Need at least Rust and Citrus backends" unless rust_available && citrus_available

      results = Concurrent::Array.new if defined?(Concurrent::Array)
      results ||= []
      mutex = Mutex.new

      thread1 = Thread.new do
        parser = TreeHaver::Parser.new(backend: :rust)
        mutex.synchronize { results << {thread: 1, backend: parser.backend} }
      end

      thread2 = Thread.new do
        parser = TreeHaver::Parser.new(backend: :citrus)
        mutex.synchronize { results << {thread: 2, backend: parser.backend} }
      end

      thread1.join
      thread2.join

      expect(results.size).to eq(2)
      expect(results.find { |r| r[:thread] == 1 }[:backend]).to eq(:rust)
      expect(results.find { |r| r[:thread] == 2 }[:backend]).to eq(:citrus)
    end
  end

  describe "Backward compatibility" do
    it "works without backend parameter (existing behavior)" do
      skip "No backend available" unless TreeHaver.backend_module

      parser = TreeHaver::Parser.new
      expect(parser).to be_a(TreeHaver::Parser)
    end

    it "respects global backend setting (existing behavior)" do
      # Use Citrus which doesn't conflict with MRI (not FFI)
      skip "Citrus backend not available" unless TreeHaver::Backends::Citrus.available?

      TreeHaver.backend = :citrus
      parser = TreeHaver::Parser.new
      expect(parser.backend).to eq(:citrus)
    end
  end
end
