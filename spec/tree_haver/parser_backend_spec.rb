# frozen_string_literal: true

RSpec.describe "TreeHaver::Parser with backend parameter" do
  after do
    # Clean up thread-local state
    Thread.current[:tree_haver_backend_context] = nil
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "Parser.new" do
    context "with no backend parameter" do
      it "uses effective backend from context/global" do
        skip "No backend available" unless TreeHaver.backend_module

        TreeHaver.with_backend(:ffi) do
          parser = TreeHaver::Parser.new
          expect(parser.backend).to eq(:ffi)
        end
      end

      it "uses global backend when no context set" do
        skip "No backend available" unless TreeHaver.backend_module

        TreeHaver.backend = :auto
        parser = TreeHaver::Parser.new
        expect(parser.backend).to eq(:auto)
      end
    end

    context "with explicit backend parameter" do
      it "uses specified backend regardless of context" do
        skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?

        TreeHaver.with_backend(:mri) do
          parser = TreeHaver::Parser.new(backend: :ffi)
          expect(parser.backend).to eq(:ffi)
        end
      end

      it "overrides global backend setting" do
        skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?

        TreeHaver.backend = :mri
        parser = TreeHaver::Parser.new(backend: :ffi)
        expect(parser.backend).to eq(:ffi)
      end

      it "creates parser with MRI backend when specified" do
        skip "MRI backend not available" unless TreeHaver::Backends::MRI.available?

        parser = TreeHaver::Parser.new(backend: :mri)
        expect(parser.backend).to eq(:mri)
      end

      it "creates parser with Rust backend when specified" do
        skip "Rust backend not available" unless TreeHaver::Backends::Rust.available?

        parser = TreeHaver::Parser.new(backend: :rust)
        expect(parser.backend).to eq(:rust)
      end

      it "creates parser with FFI backend when specified" do
        skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?

        parser = TreeHaver::Parser.new(backend: :ffi)
        expect(parser.backend).to eq(:ffi)
      end

      it "creates parser with Citrus backend when specified" do
        skip "Citrus backend not available" unless TreeHaver::Backends::Citrus.available?

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

      it "accepts string backend names" do
        skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?

        parser = TreeHaver::Parser.new(backend: "ffi")
        expect(parser.backend).to eq(:ffi)
      end
    end

    context "backend introspection" do
      it "returns thread-local backend when no explicit backend set" do
        skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?

        TreeHaver.with_backend(:ffi) do
          parser = TreeHaver::Parser.new
          expect(parser.backend).to eq(:ffi)
        end
      end

      it "returns explicit backend when set" do
        skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?

        TreeHaver.with_backend(:mri) do
          parser = TreeHaver::Parser.new(backend: :ffi)
          expect(parser.backend).to eq(:ffi)
        end
      end

      it "returns consistent backend throughout parser lifecycle" do
        skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?

        parser = TreeHaver::Parser.new(backend: :ffi)

        # Change context after parser creation
        TreeHaver.with_backend(:mri) do
          # Parser should still report :ffi
          expect(parser.backend).to eq(:ffi)
        end
      end
    end
  end

  describe "Thread-safe parser creation" do
    it "creates parsers with different backends in concurrent threads" do
      ffi_available = TreeHaver::Backends::FFI.available?
      citrus_available = TreeHaver::Backends::Citrus.available?

      skip "Need at least FFI and Citrus backends" unless ffi_available && citrus_available

      results = Concurrent::Array.new if defined?(Concurrent::Array)
      results ||= []
      mutex = Mutex.new

      thread1 = Thread.new do
        TreeHaver.with_backend(:ffi) do
          parser = TreeHaver::Parser.new
          mutex.synchronize { results << { thread: 1, backend: parser.backend } }
        end
      end

      thread2 = Thread.new do
        TreeHaver.with_backend(:citrus) do
          parser = TreeHaver::Parser.new
          mutex.synchronize { results << { thread: 2, backend: parser.backend } }
        end
      end

      thread1.join
      thread2.join

      expect(results.size).to eq(2)
      expect(results.find { |r| r[:thread] == 1 }[:backend]).to eq(:ffi)
      expect(results.find { |r| r[:thread] == 2 }[:backend]).to eq(:citrus)
    end

    it "creates parsers with explicit backends in concurrent threads" do
      ffi_available = TreeHaver::Backends::FFI.available?
      citrus_available = TreeHaver::Backends::Citrus.available?

      skip "Need at least FFI and Citrus backends" unless ffi_available && citrus_available

      results = Concurrent::Array.new if defined?(Concurrent::Array)
      results ||= []
      mutex = Mutex.new

      thread1 = Thread.new do
        parser = TreeHaver::Parser.new(backend: :ffi)
        mutex.synchronize { results << { thread: 1, backend: parser.backend } }
      end

      thread2 = Thread.new do
        parser = TreeHaver::Parser.new(backend: :citrus)
        mutex.synchronize { results << { thread: 2, backend: parser.backend } }
      end

      thread1.join
      thread2.join

      expect(results.size).to eq(2)
      expect(results.find { |r| r[:thread] == 1 }[:backend]).to eq(:ffi)
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
      skip "FFI backend not available" unless TreeHaver::Backends::FFI.available?

      TreeHaver.backend = :ffi
      parser = TreeHaver::Parser.new
      expect(parser.backend).to eq(:ffi)
    end
  end
end

