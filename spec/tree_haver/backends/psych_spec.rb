# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Backends::Psych do
  let(:backend) { described_class }

  # Store original state to restore after tests
  before do
    @original_load_attempted = backend.instance_variable_get(:@load_attempted)
    @original_loaded = backend.instance_variable_get(:@loaded)
  end

  after do
    # Restore original state
    backend.instance_variable_set(:@load_attempted, @original_load_attempted)
    backend.instance_variable_set(:@loaded, @original_loaded)
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "::available?" do
    it "returns a boolean" do
      result = backend.available?
      expect(result).to be(true).or be(false)
    end

    it "memoizes the result" do
      first_result = backend.available?
      second_result = backend.available?
      expect(first_result).to eq(second_result)
    end

    context "when psych is available" do
      before do
        backend.reset!
        allow(backend).to receive(:require).with("psych").and_return(true)
      end

      it "returns true" do
        expect(backend.available?).to be true
      end
    end

    context "when psych is not available" do
      before do
        backend.reset!
        allow(backend).to receive(:require).with("psych").and_raise(LoadError.new("cannot load psych"))
      end

      it "returns false" do
        expect(backend.available?).to be false
      end
    end
  end

  describe "::reset!" do
    it "resets load state" do
      backend.available? # Trigger load
      backend.reset!
      expect(backend.instance_variable_get(:@load_attempted)).to be false
      expect(backend.instance_variable_get(:@loaded)).to be false
    end
  end

  describe "::capabilities" do
    context "when available" do
      before do
        allow(backend).to receive(:available?).and_return(true)
      end

      it "returns a hash with backend info" do
        caps = backend.capabilities
        expect(caps).to be_a(Hash)
        expect(caps[:backend]).to eq(:psych)
        expect(caps[:query]).to be false
        expect(caps[:bytes_field]).to be false
        expect(caps[:incremental]).to be false
        expect(caps[:pure_ruby]).to be false
        expect(caps[:yaml_only]).to be true
        expect(caps[:error_tolerant]).to be false
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

  describe "Language" do
    describe "#initialize" do
      it "creates a language with default name :yaml" do
        lang = backend::Language.new
        expect(lang.name).to eq(:yaml)
        expect(lang.backend).to eq(:psych)
      end

      it "accepts custom name" do
        lang = backend::Language.new(:yml)
        expect(lang.name).to eq(:yml)
      end
    end

    describe ".yaml" do
      it "creates a yaml language" do
        lang = backend::Language.yaml
        expect(lang.name).to eq(:yaml)
        expect(lang.backend).to eq(:psych)
      end
    end

    describe ".from_library" do
      it "returns yaml language when called without arguments" do
        lang = backend::Language.from_library
        expect(lang.name).to eq(:yaml)
        expect(lang.backend).to eq(:psych)
      end

      it "returns yaml language when name is :yaml" do
        lang = backend::Language.from_library("/some/path.so", name: :yaml)
        expect(lang.name).to eq(:yaml)
      end

      it "ignores the path parameter" do
        lang = backend::Language.from_library("/nonexistent/path.so")
        expect(lang.name).to eq(:yaml)
      end

      it "ignores the symbol parameter" do
        lang = backend::Language.from_library(symbol: "tree_sitter_json")
        expect(lang.name).to eq(:yaml)
      end

      it "raises NotAvailable for non-yaml language name" do
        expect {
          backend::Language.from_library(name: :json)
        }.to raise_error(TreeHaver::NotAvailable, /only supports YAML/)
      end

      it "raises NotAvailable for ruby language name" do
        expect {
          backend::Language.from_library(name: :ruby)
        }.to raise_error(TreeHaver::NotAvailable, /only supports YAML, not ruby/)
      end
    end

    describe "#<=>" do
      it "compares by name" do
        lang1 = backend::Language.new(:a)
        lang2 = backend::Language.new(:b)
        expect(lang1 <=> lang2).to eq(-1)
      end

      it "returns nil for non-Language" do
        lang = backend::Language.new
        expect(lang <=> "other").to be_nil
      end
    end

    describe "#inspect" do
      it "returns a descriptive string" do
        lang = backend::Language.new(:yaml)
        expect(lang.inspect).to include("Psych::Language")
        expect(lang.inspect).to include("yaml")
      end
    end
  end

  describe "Parser" do
    describe "#initialize" do
      it "creates a parser with nil language" do
        parser = backend::Parser.new
        expect(parser.language).to be_nil
      end
    end

    describe "#language=" do
      let(:parser) { backend::Parser.new }

      it "accepts a Language instance" do
        lang = backend::Language.yaml
        parser.language = lang
        expect(parser.language).to eq(lang)
      end
    end

    describe "#parse" do
      let(:parser) { backend::Parser.new }

      context "when language is not set" do
        it "raises an error" do
          expect { parser.parse("key: value") }.to raise_error(RuntimeError, "Language not set")
        end
      end

      context "when psych is not available" do
        before do
          parser.language = backend::Language.yaml
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises an error" do
          expect { parser.parse("key: value") }.to raise_error(RuntimeError, "Psych not available")
        end
      end

      context "when psych is available", :psych_backend do
        let(:yaml_source) do
          <<~YAML
            # Configuration file
            name: test-app
            version: "1.0.0"

            database:
              host: localhost
              port: 5432
              name: testdb

            features:
              - logging
              - caching
              - auth
          YAML
        end

        before do
          parser.language = backend::Language.yaml
        end

        it "returns a Tree" do
          tree = parser.parse(yaml_source)
          expect(tree).to be_a(backend::Tree)
        end

        it "parses yaml document structure" do
          tree = parser.parse(yaml_source)
          root = tree.root_node
          expect(root.type).to eq("stream")
        end
      end
    end

    describe "#parse_string", :psych_backend do
      let(:parser) { backend::Parser.new }

      before do
        parser.language = backend::Language.yaml
      end

      it "ignores old_tree parameter" do
        old_tree = double("old_tree")
        tree = parser.parse_string(old_tree, "key: value")
        expect(tree).to be_a(backend::Tree)
      end
    end
  end

  describe "Tree", :psych_backend do
    let(:parser) { backend::Parser.new.tap { |p| p.language = backend::Language.yaml } }
    let(:source) { "key: value\nother: 123" }
    let(:tree) { parser.parse(source) }

    describe "#root_node" do
      it "returns a Node" do
        expect(tree.root_node).to be_a(backend::Node)
      end

      it "returns stream as root type" do
        expect(tree.root_node.type).to eq("stream")
      end
    end

    describe "#errors" do
      it "returns an empty array" do
        expect(tree.errors).to eq([])
      end
    end

    describe "#warnings" do
      it "returns an empty array" do
        expect(tree.warnings).to eq([])
      end
    end

    describe "#comments" do
      let(:source) { "# comment\nkey: value" }
      let(:tree) { parser.parse(source) }

      it "returns an array" do
        expect(tree.comments).to be_an(Array)
      end
    end

    describe "#inspect" do
      it "returns a descriptive string" do
        expect(tree.inspect).to include("Psych::Tree")
      end
    end
  end

  describe "Node", :psych_backend do
    let(:parser) { backend::Parser.new.tap { |p| p.language = backend::Language.yaml } }

    describe "basic node properties" do
      let(:source) { "name: value\ncount: 42" }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#type" do
        it "returns node type as string" do
          expect(root.type).to eq("stream")
        end
      end

      describe "#kind" do
        it "is aliased to type" do
          expect(root.kind).to eq(root.type)
        end
      end

      describe "#text" do
        it "returns node text content" do
          expect(root.text).to be_a(String)
        end
      end

      describe "#children" do
        it "returns array of child nodes" do
          children = root.children
          expect(children).to be_an(Array)
          expect(children).to all(be_a(backend::Node))
        end
      end

      describe "#child_count" do
        it "returns number of children" do
          expect(root.child_count).to be_a(Integer)
          expect(root.child_count).to be >= 0
        end
      end

      describe "#child" do
        it "returns child at index" do
          if root.child_count > 0
            expect(root.child(0)).to be_a(backend::Node)
          end
        end
      end

      describe "#first_child" do
        it "returns first child" do
          if root.child_count > 0
            expect(root.first_child).to be_a(backend::Node)
            expect(root.first_child).to eq(root.child(0))
          end
        end
      end

      describe "#each" do
        it "yields each child" do
          yielded = []
          root.each { |child| yielded << child }
          expect(yielded).to eq(root.children)
        end

        it "returns Enumerator when no block given" do
          expect(root.each).to be_an(Enumerator)
        end
      end
    end

    describe "position information" do
      let(:source) { "key: value\nother: data" }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#start_point" do
        it "returns a Point" do
          point = root.start_point
          expect(point).to respond_to(:row)
          expect(point).to respond_to(:column)
        end
      end

      describe "#end_point" do
        it "returns a Point" do
          point = root.end_point
          expect(point).to respond_to(:row)
          expect(point).to respond_to(:column)
        end
      end

      describe "#start_byte" do
        it "returns byte offset" do
          expect(root.start_byte).to be_a(Integer)
          expect(root.start_byte).to be >= 0
        end
      end

      describe "#end_byte" do
        it "returns byte offset" do
          expect(root.end_byte).to be_a(Integer)
          expect(root.end_byte).to be >= root.start_byte
        end
      end

      describe "#start_line" do
        it "returns line number" do
          expect(root.start_line).to be_a(Integer)
          expect(root.start_line).to be >= 1
        end
      end

      describe "#end_line" do
        it "returns line number" do
          expect(root.end_line).to be_a(Integer)
          expect(root.end_line).to be >= root.start_line
        end
      end

      describe "#source_position" do
        it "returns position hash" do
          pos = root.source_position
          expect(pos).to be_a(Hash)
          expect(pos).to have_key(:start_line)
          expect(pos).to have_key(:end_line)
          expect(pos).to have_key(:start_column)
          expect(pos).to have_key(:end_column)
        end
      end
    end

    describe "node flags" do
      let(:source) { "key: value" }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#named?" do
        it "returns true" do
          expect(root.named?).to be true
        end
      end

      describe "#structural?" do
        it "is aliased to named?" do
          expect(root.structural?).to eq(root.named?)
        end
      end

      describe "#has_error?" do
        it "returns false for valid syntax" do
          expect(root.has_error?).to be false
        end
      end

      describe "#missing?" do
        it "returns false" do
          expect(root.missing?).to be false
        end
      end
    end

    describe "navigation" do
      let(:source) { "a: 1\nb: 2\nc: 3" }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#parent" do
        it "returns nil (not implemented for Psych)" do
          expect(root.parent).to be_nil
        end
      end

      describe "#next_sibling" do
        it "returns nil (not implemented for Psych)" do
          expect(root.next_sibling).to be_nil
        end
      end

      describe "#prev_sibling" do
        it "returns nil (not implemented for Psych)" do
          expect(root.prev_sibling).to be_nil
        end
      end
    end

    describe "comparison" do
      let(:source) { "key1: value1\nkey2: value2" }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#<=>" do
        it "compares by byte position" do
          if root.child_count >= 2
            child1 = root.child(0)
            child2 = root.child(1)
            expect(child1 <=> child2).to be < 0
          end
        end

        it "returns nil for non-comparable" do
          expect(root <=> "string").to be_nil
        end
      end

      describe "#inspect" do
        it "returns descriptive string" do
          expect(root.inspect).to include("Psych::Node")
          expect(root.inspect).to include("stream")
        end
      end
    end

    describe "yaml-specific methods" do
      describe "#text with different node types" do
        context "with scalar node" do
          let(:source) { "name: hello" }
          let(:tree) { parser.parse(source) }

          it "returns scalar value" do
            # Navigate to the scalar value node
            # In YAML mapping, children alternate: key, value, key, value...
            doc = tree.root_node.child(0)  # document
            mapping = doc.child(0)         # mapping
            scalars = mapping.children.select(&:scalar?)
            # First scalar is "name" (key), second is "hello" (value)
            expect(scalars.length).to be >= 2
            expect(scalars[0].text).to eq("name")
            expect(scalars[1].text).to eq("hello")
          end
        end

        context "with alias node" do
          let(:source) { "first: &myanchor value\nsecond: *myanchor" }
          let(:tree) { parser.parse(source) }

          it "returns *anchor format for alias nodes" do
            # Find the alias node
            doc = tree.root_node.child(0)
            mapping = doc.child(0)
            alias_node = mapping.children.find(&:alias?)
            expect(alias_node).not_to be_nil
            expect(alias_node.text).to include("*")
            expect(alias_node.text).to include("myanchor")
          end
        end

        context "with container node" do
          let(:source) { "key: value" }
          let(:tree) { parser.parse(source) }

          it "extracts text from location for container nodes" do
            doc = tree.root_node.child(0)
            mapping = doc.child(0)
            expect(mapping.mapping?).to be true
            # Container nodes use extract_text_from_location
            expect(mapping.text).to be_a(String)
          end
        end
      end

      describe "#anchor" do
        let(:source) { "key: &anchor value\nother: *anchor" }
        let(:tree) { parser.parse(source) }
        let(:root) { tree.root_node }

        it "returns nil when no anchor" do
          expect(root.anchor).to be_nil
        end

        it "returns anchor name for anchored node" do
          doc = tree.root_node.child(0)
          mapping = doc.child(0)
          # Find the scalar with anchor
          anchored = mapping.children.find { |c| c.respond_to?(:anchor) && c.anchor }
          if anchored
            expect(anchored.anchor).to eq("anchor")
          end
        end
      end

      describe "#tag" do
        let(:source) { "key: value" }
        let(:tree) { parser.parse(source) }
        let(:root) { tree.root_node }

        it "returns nil or string tag" do
          expect(root.tag).to be_nil.or be_a(String)
        end
      end

      describe "#value" do
        let(:source) { "name: hello" }
        let(:tree) { parser.parse(source) }

        it "returns value for scalar nodes" do
          doc = tree.root_node.child(0)
          mapping = doc.child(0)
          value_scalar = mapping.children[1]  # second child is the value
          expect(value_scalar.scalar?).to be true
          expect(value_scalar.value).to eq("hello")
        end

        it "returns nil for non-scalar nodes" do
          doc = tree.root_node.child(0)
          mapping = doc.child(0)
          expect(mapping.value).to be_nil
        end
      end

      describe "#sequence?" do
        let(:source) { "items:\n  - one\n  - two" }
        let(:tree) { parser.parse(source) }

        it "returns true for sequence nodes" do
          doc = tree.root_node.child(0)
          mapping = doc.child(0)
          # Find the sequence node (value of 'items' key)
          sequence_node = mapping.children.find(&:sequence?)
          expect(sequence_node).not_to be_nil
          expect(sequence_node.sequence?).to be true
        end

        it "returns false for non-sequence nodes" do
          doc = tree.root_node.child(0)
          mapping = doc.child(0)
          expect(mapping.sequence?).to be false
        end
      end

      describe "#mapping_entries" do
        let(:source) { "name: hello\nage: 30" }
        let(:tree) { parser.parse(source) }

        it "returns key-value pairs for mapping nodes" do
          doc = tree.root_node.child(0)
          mapping = doc.child(0)
          entries = mapping.mapping_entries
          expect(entries).to be_an(Array)
          expect(entries.length).to eq(2)
          # Each entry should be [key, value] pair
          expect(entries[0].length).to eq(2)
        end

        it "returns empty array for non-mapping nodes" do
          doc = tree.root_node.child(0)
          # The document node is not a mapping
          expect(doc.mapping_entries).to eq([])
        end
      end

      describe "#extract_text_from_location (via #text on container)" do
        context "with single-line content" do
          let(:source) { "key: value" }
          let(:tree) { parser.parse(source) }

          it "extracts text for single-line mapping" do
            doc = tree.root_node.child(0)
            mapping = doc.child(0)
            expect(mapping.text).to be_a(String)
          end
        end

        context "with multi-line content" do
          let(:source) { "key: value\nother: data\nmore: stuff" }
          let(:tree) { parser.parse(source) }

          it "extracts text spanning multiple lines" do
            doc = tree.root_node.child(0)
            mapping = doc.child(0)
            # Multi-line mapping should extract across lines
            text = mapping.text
            expect(text).to be_a(String)
          end
        end
      end
    end
  end

  describe "Point", :psych_backend do
    let(:point) { backend::Point.new(5, 10) }

    describe "#row" do
      it "returns row value" do
        expect(point.row).to eq(5)
      end
    end

    describe "#column" do
      it "returns column value" do
        expect(point.column).to eq(10)
      end
    end

    describe "#[]" do
      it "returns row for :row key" do
        expect(point[:row]).to eq(5)
        expect(point["row"]).to eq(5)
      end

      it "returns column for :column key" do
        expect(point[:column]).to eq(10)
        expect(point["column"]).to eq(10)
      end
    end

    describe "#to_h" do
      it "returns hash representation" do
        expect(point.to_h).to eq({row: 5, column: 10})
      end
    end

    describe "#to_s" do
      it "returns string representation" do
        expect(point.to_s).to eq("(5, 10)")
      end
    end

    describe "#inspect" do
      it "returns descriptive string" do
        expect(point.inspect).to include("Point")
        expect(point.inspect).to include("5")
        expect(point.inspect).to include("10")
      end
    end
  end
end
