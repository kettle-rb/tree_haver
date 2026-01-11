# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Backends::Parslet do
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

    context "when parslet gem is available" do
      before do
        backend.reset!
        allow(backend).to receive(:require).with("parslet").and_return(true)
      end

      it "returns true" do
        expect(backend.available?).to be true
      end
    end

    context "when parslet gem is not available" do
      before do
        backend.reset!
        allow(backend).to receive(:require).with("parslet").and_raise(LoadError.new("cannot load parslet"))
      end

      it "returns false" do
        expect(backend.available?).to be false
      end
    end

    context "when parslet gem raises StandardError" do
      before do
        backend.reset!
        allow(backend).to receive(:require).with("parslet").and_raise(StandardError.new("unexpected error"))
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
        expect(caps[:backend]).to eq(:parslet)
        expect(caps[:query]).to be false
        expect(caps[:bytes_field]).to be true
        expect(caps[:incremental]).to be false
        expect(caps[:pure_ruby]).to be true
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
    # Create a mock Parslet grammar class
    let(:mock_grammar_class) do
      Class.new do
        class << self
          def name
            "MockParsletGrammar"
          end
        end

        def initialize
        end

        def parse(_source)
          {}
        end
      end
    end

    describe "#initialize" do
      it "accepts a grammar class with new and parse methods" do
        expect {
          backend::Language.new(mock_grammar_class)
        }.not_to raise_error
      end

      it "sets backend to :parslet" do
        lang = backend::Language.new(mock_grammar_class)
        expect(lang.backend).to eq(:parslet)
      end

      it "stores the grammar class" do
        lang = backend::Language.new(mock_grammar_class)
        expect(lang.grammar_class).to eq(mock_grammar_class)
      end

      context "when grammar class doesn't respond to new" do
        let(:bad_grammar) { Module.new }

        it "raises NotAvailable" do
          expect {
            backend::Language.new(bad_grammar)
          }.to raise_error(TreeHaver::NotAvailable, /must be a Parslet::Parser subclass/)
        end
      end

      context "when grammar instance doesn't respond to parse" do
        let(:bad_grammar_class) do
          Class.new do
            def initialize
            end
            # No parse method
          end
        end

        it "raises NotAvailable" do
          expect {
            backend::Language.new(bad_grammar_class)
          }.to raise_error(TreeHaver::NotAvailable, /must be a Parslet::Parser subclass/)
        end
      end
    end

    describe ".from_library" do
      context "when no name can be derived" do
        it "raises NotAvailable" do
          expect {
            backend::Language.from_library(nil, symbol: nil, name: nil)
          }.to raise_error(TreeHaver::NotAvailable, /requires a language name/)
        end
      end

      context "when no grammar is registered" do
        before do
          TreeHaver::LanguageRegistry.clear
        end

        it "raises NotAvailable with helpful message" do
          expect {
            backend::Language.from_library("/path/to/lib.so", name: :test_unregistered_parslet_lang)
          }.to raise_error(TreeHaver::NotAvailable, /No Parslet grammar registered/)
        end
      end

      context "when grammar is registered" do
        before do
          TreeHaver::LanguageRegistry.clear
          TreeHaver::LanguageRegistry.register(:test_parslet_lang, :parslet, grammar_class: mock_grammar_class)
        end

        after do
          TreeHaver::LanguageRegistry.clear
        end

        it "returns Language wrapping the registered grammar" do
          lang = backend::Language.from_library(nil, name: :test_parslet_lang)
          expect(lang).to be_a(backend::Language)
          expect(lang.grammar_class).to eq(mock_grammar_class)
        end
      end
    end

    describe ".from_path" do
      it "is aliased to from_library" do
        expect(backend::Language.method(:from_path)).to eq(backend::Language.method(:from_library))
      end
    end

    describe "#<=>" do
      let(:first_grammar_class) do
        Class.new do
          class << self
            def name
              "Grammar1"
            end
          end

          def initialize
          end

          def parse(_s)
            {}
          end
        end
      end

      let(:second_grammar_class) do
        Class.new do
          class << self
            def name
              "Grammar2"
            end
          end

          def initialize
          end

          def parse(_s)
            {}
          end
        end
      end

      it "returns nil for non-Language objects" do
        lang = backend::Language.new(first_grammar_class)
        expect(lang <=> "not a language").to be_nil
      end

      it "returns nil for Language with different backend" do
        lang = backend::Language.new(first_grammar_class)
        other = double("other_lang", is_a?: true, backend: :other)
        allow(other).to receive(:is_a?).with(backend::Language).and_return(true)
        allow(other).to receive(:backend).and_return(:other)
        expect(lang <=> other).to be_nil
      end

      it "compares by grammar_class name when backends match" do
        lang_a = backend::Language.new(first_grammar_class)
        lang_b = backend::Language.new(second_grammar_class)
        # Grammar1 < Grammar2 alphabetically
        expect(lang_a <=> lang_b).to be < 0
      end

      it "returns 0 for languages with same grammar_class" do
        lang_a = backend::Language.new(first_grammar_class)
        lang_b = backend::Language.new(first_grammar_class)
        expect(lang_a <=> lang_b).to eq(0)
      end
    end

    describe "#hash" do
      it "returns consistent hash for same grammar" do
        lang_a = backend::Language.new(mock_grammar_class)
        lang_b = backend::Language.new(mock_grammar_class)
        expect(lang_a.hash).to eq(lang_b.hash)
      end
    end

    describe "#eql?" do
      it "returns true for equal languages" do
        lang_a = backend::Language.new(mock_grammar_class)
        lang_b = backend::Language.new(mock_grammar_class)
        expect(lang_a.eql?(lang_b)).to be true
      end
    end
  end

  describe "Parser" do
    describe "#initialize" do
      context "when parslet is available" do
        before do
          allow(backend).to receive(:available?).and_return(true)
        end

        it "creates a parser instance" do
          expect {
            backend::Parser.new
          }.not_to raise_error
        end
      end

      context "when parslet is not available" do
        before do
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises NotAvailable" do
          expect {
            backend::Parser.new
          }.to raise_error(TreeHaver::NotAvailable, /parslet gem not available/)
        end
      end
    end

    describe "#language=" do
      let(:parser) do
        allow(backend).to receive(:available?).and_return(true)
        backend::Parser.new
      end

      let(:mock_grammar_class) do
        Class.new do
          def initialize
          end

          def parse(_s)
            {}
          end
        end
      end

      it "accepts a grammar class directly" do
        expect {
          parser.language = mock_grammar_class
        }.not_to raise_error
      end

      context "when given an invalid object" do
        it "raises ArgumentError" do
          expect {
            parser.language = "not a grammar"
          }.to raise_error(ArgumentError, /Expected Parslet grammar class/)
        end
      end
    end

    describe "#parse" do
      let(:parser) do
        allow(backend).to receive(:available?).and_return(true)
        backend::Parser.new
      end

      let(:source) { 'key = "value"' }

      let(:mock_grammar_class) do
        Class.new do
          def initialize
          end

          def parse(source)
            # Return a simple parsed result structure
            {key: source[0..2], value: source[7..13]}
          end
        end
      end

      before do
        parser.language = mock_grammar_class
      end

      it "parses source and returns wrapped tree" do
        result = parser.parse(source)
        expect(result).to be_a(TreeHaver::Backends::Parslet::Tree)
        expect(result.source).to eq(source)
      end

      it "returns tree with parslet_result" do
        result = parser.parse(source)
        expect(result.parslet_result).to be_a(Hash)
      end

      context "when no grammar is set" do
        let(:parser_no_grammar) do
          allow(backend).to receive(:available?).and_return(true)
          backend::Parser.new
        end

        it "raises NotAvailable" do
          expect {
            parser_no_grammar.parse(source)
          }.to raise_error(TreeHaver::NotAvailable, /No grammar loaded/)
        end
      end
    end

    describe "#parse_string" do
      let(:parser) do
        allow(backend).to receive(:available?).and_return(true)
        backend::Parser.new
      end

      let(:mock_grammar_class) do
        Class.new do
          def initialize
          end

          def parse(_s)
            {}
          end
        end
      end

      before do
        parser.language = mock_grammar_class
      end

      it "ignores old_tree and parses source" do
        old_tree = double("old_tree")
        result = parser.parse_string(old_tree, "test")
        expect(result).to be_a(TreeHaver::Backends::Parslet::Tree)
      end
    end
  end

  describe "Tree" do
    let(:source) { 'key = "value"' }
    let(:parslet_result) { {key: "key", value: "value"} }
    let(:tree) { backend::Tree.new(parslet_result, source) }

    describe "#parslet_result" do
      it "returns the parslet result" do
        expect(tree.parslet_result).to eq(parslet_result)
      end
    end

    describe "#source" do
      it "returns the source string" do
        expect(tree.source).to eq(source)
      end
    end

    describe "#root_node" do
      it "returns a Node wrapping the result" do
        node = tree.root_node
        expect(node).to be_a(backend::Node)
      end

      it "returns node with type 'document'" do
        node = tree.root_node
        expect(node.type).to eq("document")
      end
    end
  end

  describe "Node" do
    let(:source) { 'key = "value"' }

    describe "with Hash value" do
      let(:hash_value) { {key: "key", value: "value"} }
      let(:node) { backend::Node.new(hash_value, source, type: "document") }

      describe "#type" do
        it "returns the specified type" do
          expect(node.type).to eq("document")
        end
      end

      describe "#child_count" do
        it "returns number of hash keys" do
          expect(node.child_count).to eq(2)
        end
      end

      describe "#child" do
        it "returns child node at index" do
          child = node.child(0)
          expect(child).to be_a(backend::Node)
        end

        it "returns nil for out of bounds index" do
          expect(node.child(10)).to be_nil
        end

        it "returns nil for negative index" do
          expect(node.child(-1)).to be_nil
        end
      end

      describe "#children" do
        it "returns all child nodes" do
          children = node.children
          expect(children).to all(be_a(backend::Node))
          expect(children.length).to eq(2)
        end
      end

      describe "#first_child" do
        it "returns the first child" do
          expect(node.first_child).to be_a(backend::Node)
        end
      end

      describe "#text" do
        it "returns the source slice for the node" do
          expect(node.text).to be_a(String)
        end
      end

      describe "#structural?" do
        it "returns true for Hash nodes" do
          expect(node.structural?).to be true
        end
      end

      describe "#named?" do
        it "returns true for Hash nodes" do
          expect(node.named?).to be true
        end
      end

      describe "#has_error?" do
        it "returns false" do
          expect(node.has_error?).to be false
        end
      end

      describe "#missing?" do
        it "returns false" do
          expect(node.missing?).to be false
        end
      end

      describe "#each" do
        it "yields each child" do
          children = []
          node.each { |c| children << c }
          expect(children.length).to eq(2)
        end

        it "returns enumerator when no block given" do
          expect(node.each).to be_an(Enumerator)
        end
      end
    end

    describe "with Array value" do
      let(:array_value) { ["a", "b", "c"] }
      let(:node) { backend::Node.new(array_value, source, type: "array") }

      describe "#child_count" do
        it "returns array length" do
          expect(node.child_count).to eq(3)
        end
      end

      describe "#structural?" do
        it "returns true for Array nodes" do
          expect(node.structural?).to be true
        end
      end
    end

    describe "with Parslet::Slice value", :parslet_backend do
      let(:slice) do
        # Create a real Parslet::Slice if available
        require "parslet"
        position = Parslet::Position.new(source, 0)
        Parslet::Slice.new(position, "key", nil)
      end

      let(:node) { backend::Node.new(slice, source) }

      describe "#start_byte" do
        it "returns the slice offset" do
          expect(node.start_byte).to eq(0)
        end
      end

      describe "#end_byte" do
        it "returns offset plus length" do
          expect(node.end_byte).to eq(3) # "key".length
        end
      end

      describe "#text" do
        it "returns the slice string" do
          expect(node.text).to eq("key")
        end
      end

      describe "#structural?" do
        it "returns false for Slice nodes" do
          expect(node.structural?).to be false
        end
      end
    end

    describe "with Hash containing Parslet::Slice values", :parslet_backend do
      let(:key_slice) do
        require "parslet"
        position = Parslet::Position.new(source, 0)
        Parslet::Slice.new(position, "key", nil)
      end

      let(:value_slice) do
        require "parslet"
        position = Parslet::Position.new(source, 6)
        Parslet::Slice.new(position, "value", nil)
      end

      let(:hash_with_slices) { {key: key_slice, value: value_slice} }
      let(:node) { backend::Node.new(hash_with_slices, source, type: "pair") }

      describe "#start_byte" do
        it "returns the first slice offset" do
          expect(node.start_byte).to eq(0)
        end
      end

      describe "#end_byte" do
        it "returns the last slice end position" do
          # value_slice starts at 6, is 5 chars long ("value")
          expect(node.end_byte).to eq(11)
        end
      end
    end

    describe "with Array containing Parslet::Slice values", :parslet_backend do
      let(:first_slice) do
        require "parslet"
        position = Parslet::Position.new(source, 0)
        Parslet::Slice.new(position, "key", nil)
      end

      let(:second_slice) do
        require "parslet"
        position = Parslet::Position.new(source, 6)
        Parslet::Slice.new(position, "value", nil)
      end

      let(:array_with_slices) { [first_slice, second_slice] }
      let(:node) { backend::Node.new(array_with_slices, source, type: "array") }

      describe "#start_byte" do
        it "returns the first slice offset" do
          expect(node.start_byte).to eq(0)
        end
      end

      describe "#end_byte" do
        it "returns the last slice end position" do
          expect(node.end_byte).to eq(11)
        end
      end
    end

    describe "with Hash containing no slices" do
      let(:hash_without_slices) { {key: "plain_string", value: 123} }
      let(:node) { backend::Node.new(hash_without_slices, source, type: "pair") }

      describe "#start_byte" do
        it "returns 0 when no slices found" do
          expect(node.start_byte).to eq(0)
        end
      end

      describe "#end_byte" do
        it "returns source length when no slices found" do
          expect(node.end_byte).to eq(source.length)
        end
      end
    end

    describe "with Array containing no slices" do
      let(:array_without_slices) { ["plain", "strings"] }
      let(:node) { backend::Node.new(array_without_slices, source, type: "array") }

      describe "#start_byte" do
        it "returns 0 when no slices found" do
          expect(node.start_byte).to eq(0)
        end
      end

      describe "#end_byte" do
        it "returns source length when no slices found" do
          expect(node.end_byte).to eq(source.length)
        end
      end
    end

    describe "position methods" do
      let(:multiline_source) { "line1\nline2\nline3" }
      let(:node) { backend::Node.new({}, multiline_source, type: "document") }

      describe "#start_point" do
        it "returns hash with row and column" do
          point = node.start_point
          expect(point).to be_a(Hash)
          expect(point).to have_key(:row)
          expect(point).to have_key(:column)
        end
      end

      describe "#end_point" do
        it "returns hash with row and column" do
          point = node.end_point
          expect(point).to be_a(Hash)
          expect(point).to have_key(:row)
          expect(point).to have_key(:column)
        end
      end

      describe "#start_line" do
        it "returns 1-based line number" do
          expect(node.start_line).to be >= 1
        end
      end

      describe "#end_line" do
        it "returns 1-based line number" do
          expect(node.end_line).to be >= 1
        end
      end

      describe "#source_position" do
        it "returns position hash" do
          pos = node.source_position
          expect(pos).to have_key(:start_line)
          expect(pos).to have_key(:end_line)
          expect(pos).to have_key(:start_column)
          expect(pos).to have_key(:end_column)
        end
      end
    end

    describe "#type inference" do
      let(:source) { "test" }

      context "with String value" do
        let(:node) { backend::Node.new("string_value", source) }

        it "infers type as 'string'" do
          expect(node.type).to eq("string")
        end
      end

      context "with Integer value (unknown type)" do
        let(:node) { backend::Node.new(42, source) }

        it "infers type as 'unknown'" do
          expect(node.type).to eq("unknown")
        end
      end

      context "with nil value (unknown type)" do
        let(:node) { backend::Node.new(nil, source) }

        it "infers type as 'unknown'" do
          expect(node.type).to eq("unknown")
        end
      end
    end
  end

  describe "integration", :parslet_backend do
    context "with real Parslet grammar" do
      # Define a simple test grammar
      let(:simple_grammar_class) do
        require "parslet"
        Class.new(Parslet::Parser) do
          rule(:key) { match["a-z"].repeat(1).as(:key) }
          rule(:value) { str('"') >> match['^\\"'].repeat.as(:value) >> str('"') }
          rule(:pair) { key >> str(" = ") >> value }
          root(:pair)
        end
      end

      let(:source) { 'test = "hello"' }

      it "can parse using the grammar" do
        allow(backend).to receive(:available?).and_return(true)
        parser = backend::Parser.new
        parser.language = simple_grammar_class

        tree = parser.parse(source)
        expect(tree).to be_a(backend::Tree)

        root = tree.root_node
        expect(root).to be_a(backend::Node)
        expect(root.child_count).to be > 0
      end
    end
  end

  describe "BackendRegistry integration" do
    it "registers availability checker" do
      # The backend should have registered its checker
      expect(TreeHaver::BackendRegistry.registered?(:parslet)).to be true
    end

    it "reports availability through registry" do
      # Should match direct availability check
      direct = backend.available?
      via_registry = TreeHaver::BackendRegistry.available?(:parslet)
      expect(via_registry).to eq(direct)
    end
  end
end
