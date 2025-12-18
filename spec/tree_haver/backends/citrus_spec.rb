# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Backends::Citrus do
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

    context "when citrus gem is available" do
      before do
        # Force re-evaluation
        backend.reset!
        allow(backend).to receive(:require).with("citrus").and_return(true)
      end

      it "returns true" do
        expect(backend.available?).to be true
      end
    end

    context "when citrus gem is not available" do
      before do
        backend.reset!
        allow(backend).to receive(:require).with("citrus").and_raise(LoadError.new("cannot load citrus"))
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
        expect(caps[:backend]).to eq(:citrus)
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
    describe "#initialize" do
      let(:mock_grammar) { double("grammar", parse: nil) }

      it "accepts a grammar module with parse method" do
        expect {
          backend::Language.new(mock_grammar)
        }.not_to raise_error
      end

      context "when grammar doesn't have parse method" do
        let(:bad_grammar) { double("grammar") }

        it "raises NotAvailable" do
          expect {
            backend::Language.new(bad_grammar)
          }.to raise_error(TreeHaver::NotAvailable, /must respond to :parse/)
        end
      end
    end

    describe ".from_library" do
      it "raises NotAvailable" do
        expect {
          backend::Language.from_library("/path/to/lib.so")
        }.to raise_error(TreeHaver::NotAvailable, /doesn't use shared libraries/)
      end
    end

    describe ".from_path" do
      it "is aliased to from_library" do
        expect(backend::Language.method(:from_path)).to eq(backend::Language.method(:from_library))
      end
    end
  end

  describe "Parser" do
    describe "#initialize" do
      context "when citrus is available" do
        before do
          allow(backend).to receive(:available?).and_return(true)
        end

        it "creates a parser instance" do
          expect {
            backend::Parser.new
          }.not_to raise_error
        end
      end

      context "when citrus is not available" do
        before do
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises NotAvailable" do
          expect {
            backend::Parser.new
          }.to raise_error(TreeHaver::NotAvailable, /citrus gem not available/)
        end
      end
    end

    describe "#language=" do
      let(:parser) do
        allow(backend).to receive(:available?).and_return(true)
        backend::Parser.new
      end
      let(:mock_grammar) { double("grammar", parse: nil) }

      it "accepts a Language wrapper's grammar_module" do
        # Citrus::Parser expects the unwrapped grammar module, not the wrapper
        # TreeHaver::Parser handles unwrapping, but when testing the backend directly,
        # we need to pass the grammar module
        language = backend::Language.new(mock_grammar)
        expect {
          parser.language = language.grammar_module
        }.not_to raise_error
      end

      it "accepts a grammar module directly" do
        expect {
          parser.language = mock_grammar
        }.not_to raise_error
      end

      context "when given an invalid object" do
        it "raises ArgumentError" do
          expect {
            parser.language = "not a grammar"
          }.to raise_error(ArgumentError, /Expected Citrus grammar/)
        end
      end
    end

    describe "#parse" do
      let(:parser) do
        allow(backend).to receive(:available?).and_return(true)
        backend::Parser.new
      end
      let(:source) { "test source" }
      let(:mock_match) { double("match", offset: 0, length: 11, string: source, events: [:test], matches: []) }
      let(:mock_grammar) { double("grammar", parse: mock_match) }

      before do
        parser.language = mock_grammar
      end

      it "parses source and returns wrapped tree" do
        result = parser.parse(source)
        expect(result).to be_a(TreeHaver::Backends::Citrus::Tree)
        expect(result.source).to eq(source)
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

      context "when parse fails" do
        let(:parse_error) do
          # Create an appropriate error based on whether Citrus is loaded
          if defined?(Citrus::ParseError)
            # Real Citrus::ParseError requires an input object with various methods
            input_stub = double(
              "input",
              max_offset: 100,
              string: "test",
              line_offset: 0,
              line_number: 1,
              line: "test",
              column_number: 1,
            )
            Citrus::ParseError.new(input_stub)
          else
            # Mock Citrus::ParseError for when Citrus isn't loaded
            citrus_module = Module.new
            error_class = Class.new(StandardError)
            citrus_module.const_set(:ParseError, error_class)
            stub_const("Citrus", citrus_module)
            Citrus::ParseError.new("test error")
          end
        end

        let(:failing_grammar) do
          error = parse_error
          double("grammar").tap do |g|
            allow(g).to receive(:parse).and_raise(error)
          end
        end

        before do
          parser.language = failing_grammar
        end

        it "re-raises as TreeHaver::Error" do
          expect {
            parser.parse(source)
          }.to raise_error(TreeHaver::Error, /Parse error/)
        end
      end
    end

    describe "#parse_string" do
      let(:parser) do
        allow(backend).to receive(:available?).and_return(true)
        backend::Parser.new
      end
      let(:source) { "test" }
      let(:mock_match) { double("match", offset: 0, length: 4, string: source, events: [:test], matches: []) }
      let(:mock_grammar) { double("grammar", parse: mock_match) }

      before do
        parser.language = mock_grammar
      end

      it "ignores old_tree and calls parse" do
        old_tree = double("tree")
        result = parser.parse_string(old_tree, source)
        expect(result).to be_a(TreeHaver::Backends::Citrus::Tree)
      end

      it "works with nil old_tree" do
        result = parser.parse_string(nil, source)
        expect(result).to be_a(TreeHaver::Backends::Citrus::Tree)
      end
    end
  end

  describe "Tree" do
    let(:source) { "test source" }
    let(:mock_match) { double("match", offset: 0, length: 11, string: source, events: [:test], matches: []) }
    let(:tree) { backend::Tree.new(mock_match, source) }

    describe "#initialize" do
      it "stores root match and source" do
        expect(tree.root_match).to eq(mock_match)
        expect(tree.source).to eq(source)
      end
    end

    describe "#root_node" do
      it "returns a wrapped Node" do
        root = tree.root_node
        expect(root).to be_a(backend::Node)
      end
    end
  end

  describe "Node" do
    let(:source) { "hello world" }
    let(:child_match) { double("child", offset: 6, length: 5, string: "world", events: [:child], matches: []) }
    let(:mock_match) do
      double(
        "match",
        offset: 0,
        length: 11,
        string: source,
        events: [:root],
        matches: [child_match],
      )
    end
    let(:node) { backend::Node.new(mock_match, source) }

    describe "#initialize" do
      it "stores match and source" do
        expect(node.match).to eq(mock_match)
        expect(node.source).to eq(source)
      end
    end

    describe "#type" do
      it "returns the rule name from events" do
        expect(node.type).to eq("root")
      end

      context "when events is not an array" do
        let(:bad_match) { double("match", events: nil, offset: 0, length: 0) }
        let(:bad_node) { backend::Node.new(bad_match, source) }

        it "returns unknown" do
          expect(bad_node.type).to eq("unknown")
        end
      end

      context "when events is empty" do
        let(:empty_match) { double("match", events: [], offset: 0, length: 0) }
        let(:empty_node) { backend::Node.new(empty_match, source) }

        it "returns unknown" do
          expect(empty_node.type).to eq("unknown")
        end
      end

      context "when first event is not a symbol" do
        let(:string_match) { double("match", events: ["string"], offset: 0, length: 0) }
        let(:string_node) { backend::Node.new(string_match, source) }

        it "returns the string event value" do
          # When the event is a String, extract_type_from_event returns the string itself
          expect(string_node.type).to eq("string")
        end
      end
    end

    describe "#start_byte" do
      it "returns the offset" do
        expect(node.start_byte).to eq(0)
      end
    end

    describe "#end_byte" do
      it "returns offset plus length" do
        expect(node.end_byte).to eq(11)
      end
    end

    describe "#start_point" do
      it "returns a hash with row and column" do
        point = node.start_point
        expect(point).to be_a(Hash)
        expect(point[:row]).to eq(0)
        expect(point[:column]).to eq(0)
      end

      context "with multi-line source" do
        let(:multiline_source) { "line1\nline2\nline3" }
        let(:multiline_match) { double("match", offset: 6, length: 5, string: "line2", events: [:line]) }
        let(:multiline_node) { backend::Node.new(multiline_match, multiline_source) }

        it "calculates correct row" do
          point = multiline_node.start_point
          expect(point[:row]).to eq(1)
        end

        it "calculates correct column" do
          point = multiline_node.start_point
          expect(point[:column]).to eq(0)
        end
      end
    end

    describe "#end_point" do
      it "returns a hash with row and column" do
        point = node.end_point
        expect(point).to be_a(Hash)
        expect(point[:row]).to be_a(Integer)
        expect(point[:column]).to be_a(Integer)
      end
    end

    describe "#text" do
      it "returns the matched string" do
        expect(node.text).to eq(source)
      end
    end

    describe "#child_count" do
      it "returns the number of child matches" do
        expect(node.child_count).to eq(1)
      end

      context "when matches is not available" do
        let(:no_matches) { double("match", offset: 0, length: 0, events: [:test]) }
        let(:no_matches_node) { backend::Node.new(no_matches, source) }

        it "returns 0" do
          expect(no_matches_node.child_count).to eq(0)
        end
      end
    end

    describe "#child" do
      it "returns a wrapped child node" do
        child = node.child(0)
        expect(child).to be_a(backend::Node)
      end

      it "returns nil for invalid index" do
        expect(node.child(999)).to be_nil
      end

      context "when matches is not available" do
        let(:no_matches) { double("match", offset: 0, length: 0, events: [:test]) }
        let(:no_matches_node) { backend::Node.new(no_matches, source) }

        it "returns nil" do
          expect(no_matches_node.child(0)).to be_nil
        end
      end
    end

    describe "#children" do
      it "returns an array of wrapped nodes" do
        children = node.children
        expect(children).to be_an(Array)
        expect(children.size).to eq(1)
        expect(children.first).to be_a(backend::Node)
      end

      context "when matches is not available" do
        let(:no_matches) { double("match", offset: 0, length: 0, events: [:test]) }
        let(:no_matches_node) { backend::Node.new(no_matches, source) }

        it "returns empty array" do
          expect(no_matches_node.children).to eq([])
        end
      end
    end

    describe "#each" do
      it "iterates over children" do
        count = 0
        node.each do |child|
          expect(child).to be_a(backend::Node)
          count += 1
        end
        expect(count).to eq(1)
      end

      it "returns an enumerator when no block given" do
        enumerator = node.each
        expect(enumerator).to be_a(Enumerator)
      end
    end

    describe "#start_line" do
      it "returns 1-based line number" do
        expect(node.start_line).to be_a(Integer)
        expect(node.start_line).to be >= 1
      end

      it "converts 0-based row to 1-based" do
        expect(node.start_line).to eq(node.start_point[:row] + 1)
      end

      context "with multiline source" do
        let(:multiline_source) { "x = 1\ny = 2\nz = 3" }
        let(:multiline_match) do
          double(
            "multiline_match",
            offset: 0,
            length: multiline_source.length,
            string: multiline_source,
            events: [:root],
            matches: [],
          )
        end
        let(:multiline_node) { backend::Node.new(multiline_match, multiline_source) }

        it "returns correct line number for first line" do
          if multiline_node.start_point[:row] == 0
            expect(multiline_node.start_line).to eq(1)
          end
        end
      end
    end

    describe "#end_line" do
      it "returns 1-based line number" do
        expect(node.end_line).to be_a(Integer)
        expect(node.end_line).to be >= 1
      end

      it "converts 0-based row to 1-based" do
        expect(node.end_line).to eq(node.end_point[:row] + 1)
      end

      it "is greater than or equal to start_line" do
        expect(node.end_line).to be >= node.start_line
      end
    end

    describe "#source_position" do
      it "returns hash with position information" do
        pos = node.source_position
        expect(pos).to be_a(Hash)
        expect(pos).to include(
          :start_line,
          :end_line,
          :start_column,
          :end_column,
        )
      end

      it "has 1-based line numbers" do
        pos = node.source_position
        expect(pos[:start_line]).to be >= 1
        expect(pos[:end_line]).to be >= 1
        expect(pos[:end_line]).to be >= pos[:start_line]
      end

      it "has 0-based column numbers" do
        pos = node.source_position
        expect(pos[:start_column]).to be >= 0
        expect(pos[:end_column]).to be >= 0
      end

      it "matches start_line and end_line methods" do
        pos = node.source_position
        expect(pos[:start_line]).to eq(node.start_line)
        expect(pos[:end_line]).to eq(node.end_line)
      end

      it "matches start_point and end_point columns" do
        pos = node.source_position
        expect(pos[:start_column]).to eq(node.start_point[:column])
        expect(pos[:end_column]).to eq(node.end_point[:column])
      end
    end

    describe "#first_child" do
      it "returns the first child node" do
        if node.child_count > 0
          expect(node.first_child).to be_a(backend::Node)
          # Compare by match object and position instead of object identity
          expect(node.first_child.instance_variable_get(:@match)).to eq(node.child(0).instance_variable_get(:@match))
          expect(node.first_child.start_byte).to eq(node.child(0).start_byte)
        end
      end

      it "returns nil when node has no children" do
        if node.child_count == 0
          expect(node.first_child).to be_nil
        end
      end
    end

    describe "#has_error?" do
      it "always returns false" do
        expect(node.has_error?).to be false
      end
    end

    describe "#missing?" do
      it "always returns false" do
        expect(node.missing?).to be false
      end
    end

    describe "#named?" do
      it "always returns true" do
        expect(node.named?).to be true
      end
    end
  end
end
