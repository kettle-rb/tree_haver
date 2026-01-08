# frozen_string_literal: true

RSpec.describe TreeHaver::BackendAPI do
  describe ".validate" do
    context "with Java backend", :java_backend do
      let(:backend) { TreeHaver::Backends::Java }

      it "validates successfully" do
        results = described_class.validate(backend)
        expect(results[:valid]).to be true
        expect(results[:errors]).to be_empty
      end

      it "reports capabilities" do
        results = described_class.validate(backend)
        expect(results[:capabilities]).to include(:language, :node)
      end
    end

    context "with MRI backend", :mri_backend do
      let(:backend) { TreeHaver::Backends::MRI }

      it "validates successfully" do
        results = described_class.validate(backend)
        expect(results[:valid]).to be true
        expect(results[:errors]).to be_empty
      end

      it "warns about missing Node class (raw backend)" do
        results = described_class.validate(backend)
        expect(results[:warnings]).to include(/No Node class/)
      end
    end

    context "with FFI backend", :ffi_backend do
      let(:backend) { TreeHaver::Backends::FFI }

      it "validates successfully" do
        results = described_class.validate(backend)
        expect(results[:valid]).to be true
        expect(results[:errors]).to be_empty
      end
    end

    context "with Citrus backend", :citrus_backend do
      let(:backend) { TreeHaver::Backends::Citrus }

      it "validates successfully" do
        results = described_class.validate(backend)
        expect(results[:valid]).to be true
        expect(results[:errors]).to be_empty
      end
    end
  end

  describe ".validate!" do
    context "with valid backend", :java_backend do
      it "returns results without raising" do
        expect {
          described_class.validate!(TreeHaver::Backends::Java)
        }.not_to raise_error
      end
    end

    context "with invalid backend" do
      let(:fake_backend) do
        Module.new do
          class << self
            def name
              "FakeBackend"
            end
          end
        end
      end

      it "raises TreeHaver::Error" do
        expect {
          described_class.validate!(fake_backend)
        }.to raise_error(TreeHaver::Error, /API validation failed/)
      end
    end
  end

  describe ".validate_node_instance" do
    context "with Java backend Node", :java_backend, :toml_grammar do
      let(:node) do
        TreeHaver.with_backend(:java) do
          parser = TreeHaver.parser_for(:toml)
          tree = parser.parse("key = 'value'")
          # Get the inner node from the Java backend
          tree.root_node.inner_node
        end
      end

      it "reports required methods as supported" do
        results = described_class.validate_node_instance(node)
        expect(results[:supported_methods]).to include(:type, :child_count, :child)
      end

      it "validates successfully" do
        results = described_class.validate_node_instance(node)
        expect(results[:valid]).to be true
      end
    end

    context "with mock node missing required methods" do
      let(:incomplete_node) do
        obj = Object.new
        # Only define some methods, not all required ones
        def obj.type
          "test"
        end
        obj
      end

      it "reports missing required methods as errors" do
        results = described_class.validate_node_instance(incomplete_node)
        expect(results[:valid]).to be false
        expect(results[:errors]).not_to be_empty
      end
    end

    context "with mock node with aliased methods" do
      let(:aliased_node) do
        obj = Object.new
        # Use kind instead of type (aliased)
        def obj.kind
          "test"
        end

        def obj.child_count
          0
        end

        def obj.child(_index)
          nil
        end

        def obj.start_byte
          0
        end

        def obj.end_byte
          10
        end

        def obj.named?
          true
        end

        def obj.text
          "text"
        end

        def obj.children
          []
        end

        def obj.each
        end
        obj
      end

      it "recognizes aliased methods" do
        results = described_class.validate_node_instance(aliased_node)
        expect(results[:supported_methods]).to include(:type)
      end
    end
  end

  describe ".validate with strict mode" do
    context "with backend missing optional methods", :java_backend do
      it "treats warnings as errors when strict is true" do
        # Create a mock backend missing optional methods
        mock_backend = Module.new do
          class << self
            def available?
              true
            end

            def name
              "MockBackend"
            end
          end
        end

        results = described_class.validate(mock_backend, strict: true)
        # With strict mode, warnings become errors
        expect(results[:valid]).to be false
      end
    end
  end

  describe "validation of backend components" do
    context "when backend has Language class" do
      let(:backend_with_language) do
        mod = Module.new do
          class << self
            def available?
              true
            end

            def capabilities
              {}
            end

            def name
              "TestBackend"
            end
          end
        end

        # Add Language class
        lang_class = Class.new do
          class << self
            def from_library(_path, symbol: nil)
              new
            end
          end
        end
        mod.const_set(:Language, lang_class)
        mod
      end

      it "validates Language class" do
        results = described_class.validate(backend_with_language)
        expect(results[:capabilities]).to have_key(:language)
      end
    end

    context "when backend has Parser class" do
      let(:backend_with_parser) do
        mod = Module.new do
          class << self
            def available?
              true
            end

            def capabilities
              {}
            end

            def name
              "TestBackend"
            end
          end
        end

        # Add Parser class with required methods
        parser_class = Class.new do
          class << self
            def new(*args)
              allocate
            end
          end

          def parse(_source)
            nil
          end

          def language=(_lang)
          end
        end
        mod.const_set(:Parser, parser_class)
        mod
      end

      it "validates Parser class" do
        results = described_class.validate(backend_with_parser)
        expect(results[:errors]).not_to include(/Parser missing/)
      end
    end
  end

  describe "NODE_INSTANCE_METHODS" do
    it "includes essential navigation methods" do
      expect(described_class::NODE_INSTANCE_METHODS).to include(
        :type,
        :child_count,
        :child,
        :start_byte,
        :end_byte,
      )
    end
  end

  describe "NODE_OPTIONAL_METHODS" do
    it "includes parent/sibling navigation" do
      expect(described_class::NODE_OPTIONAL_METHODS).to include(
        :parent,
        :next_sibling,
        :prev_sibling,
      )
    end

    it "includes position methods" do
      expect(described_class::NODE_OPTIONAL_METHODS).to include(
        :start_point,
        :end_point,
      )
    end
  end

  describe "NODE_ALIASES" do
    it "maps type to kind" do
      expect(described_class::NODE_ALIASES[:type]).to include(:kind)
    end

    it "maps named? variants" do
      expect(described_class::NODE_ALIASES[:named?]).to include(:is_named?, :is_named)
    end
  end

  describe "LANGUAGE_CLASS_METHODS" do
    it "includes from_library" do
      expect(described_class::LANGUAGE_CLASS_METHODS).to include(:from_library)
    end
  end

  describe "PARSER_CLASS_METHODS" do
    it "includes new" do
      expect(described_class::PARSER_CLASS_METHODS).to include(:new)
    end
  end

  describe "PARSER_INSTANCE_METHODS" do
    it "includes parse" do
      expect(described_class::PARSER_INSTANCE_METHODS).to include(:parse)
    end
  end

  describe "TREE_INSTANCE_METHODS" do
    it "includes root_node" do
      expect(described_class::TREE_INSTANCE_METHODS).to include(:root_node)
    end
  end
end
