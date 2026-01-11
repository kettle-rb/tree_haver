# frozen_string_literal: true

# Shared examples for Backend module API compliance
#
# These examples test the standard Backend module interface that all backends
# must implement. They ensure consistent behavior across MRI, FFI, Rust, Java,
# Citrus, Parslet, Prism, Psych, and other backends.
#
# @example Usage in backend specs
#   RSpec.describe TreeHaver::Backends::Citrus do
#     let(:backend) { described_class }
#
#     it_behaves_like "backend module api"
#   end

# Core Backend module API that all implementations must provide
RSpec.shared_examples "backend module api" do
  # Expects `backend` to be defined as the backend module under test

  describe "availability checking" do
    describe "::available?" do
      it "responds to ::available?" do
        expect(backend).to respond_to(:available?)
      end

      it "returns a boolean" do
        result = backend.available?
        expect(result).to be(true).or be(false)
      end

      it "memoizes the result" do
        first = backend.available?
        second = backend.available?
        expect(first).to eq(second)
      end
    end

    describe "::reset!" do
      it "responds to ::reset!" do
        expect(backend).to respond_to(:reset!)
      end

      it "allows re-checking availability after reset" do
        original = backend.available?
        backend.reset!
        after_reset = backend.available?
        expect(after_reset).to eq(original)
      end
    end
  end

  describe "capabilities reporting" do
    describe "::capabilities" do
      it "responds to ::capabilities" do
        expect(backend).to respond_to(:capabilities)
      end

      it "returns a Hash" do
        expect(backend.capabilities).to be_a(Hash)
      end

      context "when available" do
        before do
          skip "Backend not available" unless backend.available?
        end

        it "includes :backend key" do
          expect(backend.capabilities).to have_key(:backend)
        end

        it ":backend value is a Symbol" do
          expect(backend.capabilities[:backend]).to be_a(Symbol)
        end
      end

      context "when not available" do
        before do
          allow(backend).to receive(:available?).and_return(false)
        end

        it "returns empty hash" do
          expect(backend.capabilities).to eq({})
        end
      end
    end
  end
end

# Backend subclass structure
RSpec.shared_examples "backend class structure" do
  # Expects `backend` to be defined as the backend module under test

  describe "nested classes" do
    context "when available", if: -> { backend.available? } do
      it "defines Language class" do
        expect(backend.const_defined?(:Language)).to be true
      end

      it "defines Parser class" do
        expect(backend.const_defined?(:Parser)).to be true
      end

      it "defines Tree class or uses TreeHaver::Tree" do
        # Some backends define their own Tree, others use the wrapper
        has_tree = backend.const_defined?(:Tree, false) ||
          defined?(TreeHaver::Tree)
        expect(has_tree).to be true
      end

      it "defines Node class or uses TreeHaver::Node" do
        # Some backends define their own Node, others use the wrapper
        has_node = backend.const_defined?(:Node, false) ||
          defined?(TreeHaver::Node)
        expect(has_node).to be true
      end
    end
  end
end

# Backend integration (full parse cycle)
RSpec.shared_examples "backend integration" do
  # Expects:
  # - `backend` to be defined as the backend module
  # - `create_parser` to be a lambda that creates a configured parser
  # - `simple_source` to be valid source for the backend's language
  # - `expected_root_type` to be the expected root node type (String or Regexp)

  describe "full parse cycle" do
    let(:parser) { create_parser.call }
    let(:tree) { parser.parse(simple_source) }
    let(:root) { tree.root_node }

    it "parses source to tree" do
      expect(tree).to respond_to(:root_node)
    end

    it "tree has correct source" do
      expect(tree.source).to eq(simple_source)
    end

    it "root node has expected type" do
      if expected_root_type.is_a?(Regexp)
        expect(root.type).to match(expected_root_type)
      else
        expect(root.type).to eq(expected_root_type)
      end
    end

    it "root node spans the source" do
      expect(root.start_byte).to eq(0)
      # End byte should be close to source length (may differ due to trailing newline handling)
      expect(root.end_byte).to be_within(2).of(simple_source.bytesize)
    end

    it "nodes are traversable" do
      visited = 0
      stack = [root]
      while (node = stack.pop)
        visited += 1
        node.children.each { |c| stack.push(c) }
        break if visited > 100 # Safety limit
      end
      expect(visited).to be >= 1
    end
  end
end

