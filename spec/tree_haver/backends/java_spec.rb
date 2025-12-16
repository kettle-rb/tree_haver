# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Backends::Java do
  let(:backend) { described_class }

  # Store original state
  before do
    @original_load_attempted = backend.instance_variable_get(:@load_attempted)
    @original_loaded = backend.instance_variable_get(:@loaded)
    @original_load_error = backend.instance_variable_get(:@load_error)
    @original_java_classes = backend.instance_variable_get(:@java_classes).dup
    @original_runtime_lookup = backend.runtime_lookup
  end

  after do
    # Restore original state
    backend.instance_variable_set(:@load_attempted, @original_load_attempted)
    backend.instance_variable_set(:@loaded, @original_loaded)
    backend.instance_variable_set(:@load_error, @original_load_error)
    backend.instance_variable_set(:@java_classes, @original_java_classes)
    backend.runtime_lookup = @original_runtime_lookup
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "::available?" do
    it "returns a boolean" do
      result = backend.available?
      expect(result).to be(true).or be(false)
    end

    context "when on JRuby", :jruby do
      it "returns true when java-tree-sitter classes are available", :java_backend do
        expect(backend.available?).to be true
      end
    end

    context "when not on JRuby", :not_jruby do
      before do
        backend.reset!
      end

      it "returns false on MRI" do
        expect(backend.available?).to be false
      end
    end
  end

  describe "::reset!" do
    before do
      backend.instance_variable_set(:@load_attempted, true)
      backend.instance_variable_set(:@loaded, true)
      backend.instance_variable_set(:@load_error, "some error")
      backend.instance_variable_set(:@java_classes, {Parser: "fake"})
    end

    it "resets load_attempted flag" do
      backend.reset!
      expect(backend.instance_variable_get(:@load_attempted)).to be false
    end

    it "resets loaded flag" do
      backend.reset!
      expect(backend.instance_variable_get(:@loaded)).to be false
    end

    it "resets load_error" do
      backend.reset!
      expect(backend.instance_variable_get(:@load_error)).to be_nil
    end

    it "clears java_classes" do
      backend.reset!
      expect(backend.java_classes).to eq({})
    end
  end

  describe "::load_error" do
    it "returns nil when no error" do
      backend.instance_variable_set(:@load_error, nil)
      expect(backend.load_error).to be_nil
    end

    it "returns the error message when set" do
      backend.instance_variable_set(:@load_error, "test error")
      expect(backend.load_error).to eq("test error")
    end
  end

  describe "::java_classes" do
    it "returns the java_classes hash" do
      backend.instance_variable_set(:@java_classes, {Parser: "test"})
      expect(backend.java_classes).to eq({Parser: "test"})
    end
  end

  describe "::runtime_lookup" do
    it "can be get and set" do
      fake_lookup = double("SymbolLookup")
      backend.runtime_lookup = fake_lookup
      expect(backend.runtime_lookup).to eq(fake_lookup)
    end
  end

  describe "::capabilities" do
    context "when available", :java_backend do
      it "returns a hash with backend info" do
        caps = backend.capabilities
        expect(caps).to include(:backend)
        expect(caps[:backend]).to eq(:java)
        expect(caps[:parse]).to be true
        expect(caps[:query]).to be true
        expect(caps[:bytes_field]).to be true
        expect(caps[:incremental]).to be true
      end
    end

    context "when unavailable" do
      before do
        allow(backend).to receive(:available?).and_return(false)
      end

      it "returns empty hash" do
        expect(backend.capabilities).to eq({})
      end
    end
  end

  describe "forcing :java backend selection" do
    it "raises NotAvailable from facade when Java backend cannot be used" do
      stub_env("TREE_HAVER_BACKEND" => "java")
      TreeHaver.reset_backend!(to: :java)
      if backend.available?
        expect {
          TreeHaver::Language.from_path("/nonexistent/path/to/libtree-sitter-toml.so")
        }.to raise_error(TreeHaver::NotAvailable)
      else
        expect(TreeHaver.backend).to eq(:java)
        expect(TreeHaver.backend_module).to eq(TreeHaver::Backends::Java)
        expect {
          TreeHaver::Language.from_path("/nonexistent/path/to/libtree-sitter-toml.so")
        }.to raise_error(TreeHaver::NotAvailable)
      end
    end
  end

  describe "Language" do
    describe "::from_library" do
      context "when Java backend is not available" do
        before do
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises NotAvailable" do
          expect {
            backend::Language.from_library("/path/to/lib.so")
          }.to raise_error(TreeHaver::NotAvailable, /Java backend not available/)
        end
      end

      context "when Java backend is available", :java_backend do
        it "loads a language from a path" do
          # Will fail because path doesn't exist, but tests the code path
          expect {
            backend::Language.from_library("/nonexistent/lib.so", name: "toml")
          }.to raise_error(TreeHaver::NotAvailable)
        end
      end
    end

    describe "::load_by_name" do
      context "when Java backend is not available" do
        before do
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises NotAvailable" do
          expect {
            backend::Language.load_by_name("toml")
          }.to raise_error(TreeHaver::NotAvailable, /Java backend not available/)
        end
      end

      context "when Java backend is available", :java_backend do
        it "attempts to load language by name" do
          expect {
            backend::Language.load_by_name("nonexistent_language")
          }.to raise_error(TreeHaver::NotAvailable)
        end
      end
    end

    describe "::from_path alias" do
      it "is an alias for from_library" do
        expect(backend::Language.method(:from_path)).to eq(backend::Language.method(:from_library))
      end
    end
  end

  describe "Parser" do
    describe "#initialize" do
      context "when Java backend is not available" do
        before do
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises NotAvailable" do
          expect {
            backend::Parser.new
          }.to raise_error(TreeHaver::NotAvailable, /Java backend not available/)
        end
      end

      context "when Java backend is available", :java_backend do
        it "creates a new parser" do
          parser = backend::Parser.new
          expect(parser).to be_a(backend::Parser)
        end
      end
    end
  end

  describe "Tree" do
    describe "#root_node" do
      it "exists as a method" do
        expect(backend::Tree.instance_methods).to include(:root_node)
      end
    end

    describe "#edit" do
      it "exists as a method" do
        expect(backend::Tree.instance_methods).to include(:edit)
      end
    end
  end

  describe "Node" do
    describe "instance methods" do
      it "defines type method" do
        expect(backend::Node.instance_methods).to include(:type)
      end

      it "defines child_count method" do
        expect(backend::Node.instance_methods).to include(:child_count)
      end

      it "defines child method" do
        expect(backend::Node.instance_methods).to include(:child)
      end

      it "defines each method" do
        expect(backend::Node.instance_methods).to include(:each)
      end

      it "defines start_byte method" do
        expect(backend::Node.instance_methods).to include(:start_byte)
      end

      it "defines end_byte method" do
        expect(backend::Node.instance_methods).to include(:end_byte)
      end

      it "defines start_point method" do
        expect(backend::Node.instance_methods).to include(:start_point)
      end

      it "defines end_point method" do
        expect(backend::Node.instance_methods).to include(:end_point)
      end

      it "defines has_error? method" do
        expect(backend::Node.instance_methods).to include(:has_error?)
      end

      it "defines missing? method" do
        expect(backend::Node.instance_methods).to include(:missing?)
      end

      it "defines text method" do
        expect(backend::Node.instance_methods).to include(:text)
      end
    end
  end

  describe "::add_jars_from_env!" do
    it "does not raise when called" do
      expect { backend.add_jars_from_env! }.not_to raise_error
    end
  end

  describe "::configure_native_library_path!" do
    it "is a private method that can be called" do
      expect { backend.send(:configure_native_library_path!) }.not_to raise_error
    end

    context "when TREE_SITTER_RUNTIME_LIB is not set" do
      before do
        stub_env("TREE_SITTER_RUNTIME_LIB" => nil)
      end

      it "does nothing" do
        expect { backend.send(:configure_native_library_path!) }.not_to raise_error
      end
    end

    context "when TREE_SITTER_RUNTIME_LIB points to nonexistent file" do
      before do
        stub_env("TREE_SITTER_RUNTIME_LIB" => "/nonexistent/lib.so")
      end

      it "does nothing" do
        expect { backend.send(:configure_native_library_path!) }.not_to raise_error
      end
    end
  end
end
