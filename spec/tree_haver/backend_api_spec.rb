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
end
