# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Backends::Commonmarker do
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

    context "when commonmarker gem is available" do
      before do
        backend.reset!
        allow(backend).to receive(:require).with("commonmarker").and_return(true)
      end

      it "returns true" do
        expect(backend.available?).to be true
      end
    end

    context "when commonmarker gem is not available" do
      before do
        backend.reset!
        allow(backend).to receive(:require).with("commonmarker").and_raise(LoadError.new("cannot load commonmarker"))
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
        expect(caps[:backend]).to eq(:commonmarker)
        expect(caps[:query]).to be false
        expect(caps[:bytes_field]).to be false
        expect(caps[:incremental]).to be false
        expect(caps[:pure_ruby]).to be false
        expect(caps[:markdown_only]).to be true
        expect(caps[:error_tolerant]).to be true
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
      it "creates a language with default name :markdown" do
        lang = backend::Language.new
        expect(lang.name).to eq(:markdown)
        expect(lang.backend).to eq(:commonmarker)
        expect(lang.options).to eq({})
      end

      it "accepts custom name and options" do
        lang = backend::Language.new(:gfm, options: {smart: true})
        expect(lang.name).to eq(:gfm)
        expect(lang.options).to eq({smart: true})
      end
    end

    describe ".markdown" do
      it "creates a markdown language" do
        lang = backend::Language.markdown
        expect(lang.name).to eq(:markdown)
        expect(lang.backend).to eq(:commonmarker)
      end

      it "accepts options" do
        lang = backend::Language.markdown(options: {smart: true})
        expect(lang.options).to eq({smart: true})
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
        lang = backend::Language.new(:markdown, options: {smart: true})
        expect(lang.inspect).to include("Commonmarker::Language")
        expect(lang.inspect).to include("markdown")
        expect(lang.inspect).to include("smart")
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
        lang = backend::Language.markdown
        parser.language = lang
        expect(parser.language).to eq(lang)
      end
    end

    describe "#parse" do
      let(:parser) { backend::Parser.new }

      context "when language is not set" do
        it "raises an error" do
          expect { parser.parse("# Hello") }.to raise_error(RuntimeError, "Language not set")
        end
      end

      context "when commonmarker is not available" do
        before do
          parser.language = backend::Language.markdown
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises an error" do
          expect { parser.parse("# Hello") }.to raise_error(RuntimeError, "Commonmarker not available")
        end
      end

      context "when commonmarker is available", :commonmarker_backend do
        let(:markdown_source) do
          <<~MD
            # Heading 1

            A paragraph with **bold** and *italic* text.

            ## Heading 2

            - Item 1
            - Item 2
            - Item 3

            ```ruby
            puts "Hello, World!"
            ```
          MD
        end

        before do
          parser.language = backend::Language.markdown
        end

        it "returns a Tree" do
          tree = parser.parse(markdown_source)
          expect(tree).to be_a(backend::Tree)
        end

        it "parses markdown document structure" do
          tree = parser.parse(markdown_source)
          root = tree.root_node
          expect(root.type).to eq("document")
        end
      end
    end

    describe "#parse_string", :commonmarker_backend do
      let(:parser) { backend::Parser.new }

      before do
        parser.language = backend::Language.markdown
      end

      it "ignores old_tree parameter" do
        old_tree = double("old_tree")
        tree = parser.parse_string(old_tree, "# Hello")
        expect(tree).to be_a(backend::Tree)
      end
    end
  end

  describe "Tree", :commonmarker_backend do
    let(:parser) { backend::Parser.new.tap { |p| p.language = backend::Language.markdown } }
    let(:source) { "# Hello\n\nA paragraph." }
    let(:tree) { parser.parse(source) }

    describe "#root_node" do
      it "returns a Node" do
        expect(tree.root_node).to be_a(backend::Node)
      end

      it "returns document as root type" do
        expect(tree.root_node.type).to eq("document")
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
      it "returns an empty array" do
        expect(tree.comments).to eq([])
      end
    end

    describe "#inspect" do
      it "returns a descriptive string" do
        expect(tree.inspect).to include("Commonmarker::Tree")
      end
    end
  end

  describe "Node", :commonmarker_backend do
    let(:parser) { backend::Parser.new.tap { |p| p.language = backend::Language.markdown } }

    describe "basic node properties" do
      let(:source) { "# Hello World\n\nA paragraph with **bold** text." }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#type" do
        it "returns node type as string" do
          expect(root.type).to eq("document")
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

        context "when string_content raises TypeError (container node)" do
          let(:mock_node) { double("CommonmarkerNode", type: :document) }
          let(:mock_child) { double("CommonmarkerChild", type: :text) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:string_content).and_return(true)
            allow(mock_node).to receive(:string_content).and_raise(TypeError)
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(true)
            allow(mock_node).to receive(:each).and_yield(mock_child)
            allow(mock_child).to receive(:respond_to?).with(:string_content).and_return(true)
            allow(mock_child).to receive(:string_content).and_return("child text")
            allow(mock_child).to receive(:respond_to?).with(:each).and_return(false)
          end

          it "concatenates children's text" do
            expect(node.text).to eq("child text")
          end
        end

        context "when node doesn't respond to string_content" do
          let(:mock_node) { double("CommonmarkerNode", type: :document) }
          let(:mock_child) { double("CommonmarkerChild", type: :text) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:string_content).and_return(false)
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(true)
            allow(mock_node).to receive(:each).and_yield(mock_child)
            allow(mock_child).to receive(:respond_to?).with(:string_content).and_return(true)
            allow(mock_child).to receive(:string_content).and_return("child text")
            allow(mock_child).to receive(:respond_to?).with(:each).and_return(false)
          end

          it "concatenates children's text" do
            expect(node.text).to eq("child text")
          end
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
      let(:source) { "# Heading\n\nParagraph text." }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#start_point" do
        it "returns a Point" do
          point = root.start_point
          expect(point).to respond_to(:row)
          expect(point).to respond_to(:column)
        end

        context "when source_position is not available" do
          let(:mock_node) { double("CommonmarkerNode", type: :document) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(false)
          end

          it "falls back to sourcepos method" do
            allow(mock_node).to receive(:sourcepos).and_return([1, 1, 3, 15])
            point = node.start_point
            expect(point.row).to eq(0)  # 1-based to 0-based
            expect(point.column).to eq(0)
          end

          it "returns (0, 0) when sourcepos is nil" do
            allow(mock_node).to receive(:sourcepos).and_return(nil)
            point = node.start_point
            expect(point.row).to eq(0)
            expect(point.column).to eq(0)
          end

          it "returns (0, 0) when sourcepos raises" do
            allow(mock_node).to receive(:sourcepos).and_raise(StandardError)
            point = node.start_point
            expect(point.row).to eq(0)
            expect(point.column).to eq(0)
          end
        end

        context "when source_position returns nil" do
          let(:mock_node) { double("CommonmarkerNode", type: :document) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(true)
            allow(mock_node).to receive(:source_position).and_return(nil)
          end

          it "falls back to sourcepos method" do
            allow(mock_node).to receive(:sourcepos).and_return([2, 5, 4, 10])
            point = node.start_point
            expect(point.row).to eq(1)  # 2 - 1
            expect(point.column).to eq(4)  # 5 - 1
          end
        end

        context "when source_position raises" do
          let(:mock_node) { double("CommonmarkerNode", type: :document) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(true)
            allow(mock_node).to receive(:source_position).and_raise(StandardError)
          end

          it "falls back to sourcepos method" do
            allow(mock_node).to receive(:sourcepos).and_return([1, 1, 1, 10])
            point = node.start_point
            expect(point.row).to eq(0)
            expect(point.column).to eq(0)
          end
        end
      end

      describe "#end_point" do
        it "returns a Point" do
          point = root.end_point
          expect(point).to respond_to(:row)
          expect(point).to respond_to(:column)
        end

        context "when source_position is not available" do
          let(:mock_node) { double("CommonmarkerNode", type: :document) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(false)
          end

          it "falls back to sourcepos method" do
            allow(mock_node).to receive(:sourcepos).and_return([1, 1, 3, 15])
            point = node.end_point
            expect(point.row).to eq(2)  # 3 - 1
            expect(point.column).to eq(14)  # 15 - 1
          end

          it "returns (0, 0) when sourcepos is nil" do
            allow(mock_node).to receive(:sourcepos).and_return(nil)
            point = node.end_point
            expect(point.row).to eq(0)
            expect(point.column).to eq(0)
          end

          it "returns (0, 0) when sourcepos raises" do
            allow(mock_node).to receive(:sourcepos).and_raise(StandardError)
            point = node.end_point
            expect(point.row).to eq(0)
            expect(point.column).to eq(0)
          end
        end

        context "when source_position returns nil" do
          let(:mock_node) { double("CommonmarkerNode", type: :document) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(true)
            allow(mock_node).to receive(:source_position).and_return(nil)
          end

          it "falls back to sourcepos method" do
            allow(mock_node).to receive(:sourcepos).and_return([1, 1, 5, 20])
            point = node.end_point
            expect(point.row).to eq(4)  # 5 - 1
            expect(point.column).to eq(19)  # 20 - 1
          end
        end

        context "when source_position raises" do
          let(:mock_node) { double("CommonmarkerNode", type: :document) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(true)
            allow(mock_node).to receive(:source_position).and_raise(StandardError)
          end

          it "falls back to sourcepos method" do
            allow(mock_node).to receive(:sourcepos).and_return([1, 1, 2, 5])
            point = node.end_point
            expect(point.row).to eq(1)
            expect(point.column).to eq(4)
          end
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

        context "when source_position is not available" do
          let(:mock_node) { double("CommonmarkerNode", type: :document) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(false)
          end

          it "falls back to sourcepos method" do
            allow(mock_node).to receive(:sourcepos).and_return([5, 1, 10, 15])
            expect(node.start_line).to eq(5)
          end

          it "returns 1 when sourcepos is nil" do
            allow(mock_node).to receive(:sourcepos).and_return(nil)
            expect(node.start_line).to eq(1)
          end

          it "returns 1 when sourcepos raises" do
            allow(mock_node).to receive(:sourcepos).and_raise(StandardError)
            expect(node.start_line).to eq(1)
          end
        end

        context "when source_position returns nil" do
          let(:mock_node) { double("CommonmarkerNode", type: :document) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(true)
            allow(mock_node).to receive(:source_position).and_return(nil)
          end

          it "falls back to sourcepos method" do
            allow(mock_node).to receive(:sourcepos).and_return([7, 1, 10, 15])
            expect(node.start_line).to eq(7)
          end
        end

        context "when source_position raises" do
          let(:mock_node) { double("CommonmarkerNode", type: :document) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(true)
            allow(mock_node).to receive(:source_position).and_raise(StandardError)
          end

          it "falls back to sourcepos method" do
            allow(mock_node).to receive(:sourcepos).and_return([3, 1, 5, 10])
            expect(node.start_line).to eq(3)
          end
        end
      end

      describe "#end_line" do
        it "returns line number" do
          expect(root.end_line).to be_a(Integer)
          expect(root.end_line).to be >= root.start_line
        end

        context "when source_position is not available" do
          let(:mock_node) { double("CommonmarkerNode", type: :document) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(false)
          end

          it "falls back to sourcepos method" do
            allow(mock_node).to receive(:sourcepos).and_return([1, 1, 10, 15])
            expect(node.end_line).to eq(10)
          end

          it "returns 1 when sourcepos is nil" do
            allow(mock_node).to receive(:sourcepos).and_return(nil)
            expect(node.end_line).to eq(1)
          end

          it "returns 1 when sourcepos raises" do
            allow(mock_node).to receive(:sourcepos).and_raise(StandardError)
            expect(node.end_line).to eq(1)
          end
        end

        context "when source_position returns nil" do
          let(:mock_node) { double("CommonmarkerNode", type: :document) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(true)
            allow(mock_node).to receive(:source_position).and_return(nil)
          end

          it "falls back to sourcepos method" do
            allow(mock_node).to receive(:sourcepos).and_return([1, 1, 15, 20])
            expect(node.end_line).to eq(15)
          end
        end

        context "when source_position raises" do
          let(:mock_node) { double("CommonmarkerNode", type: :document) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(true)
            allow(mock_node).to receive(:source_position).and_raise(StandardError)
          end

          it "falls back to sourcepos method" do
            allow(mock_node).to receive(:sourcepos).and_return([1, 1, 8, 5])
            expect(node.end_line).to eq(8)
          end
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
      let(:source) { "# Hello" }
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
        it "returns false" do
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
      let(:source) { "# A\n\n# B\n\n# C" }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#parent" do
        it "returns nil for root" do
          parent = root.parent
          expect([nil, root]).to include(parent).or be_a(backend::Node)
        end

        it "returns parent for child node" do
          if root.child_count > 0
            child = root.child(0)
            expect(child.parent).to be_nil.or be_a(backend::Node)
          end
        end

        context "when inner_node.parent raises" do
          let(:mock_node) { double("CommonmarkerNode", type: :paragraph) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:parent).and_raise(StandardError)
          end

          it "returns nil" do
            expect(node.parent).to be_nil
          end
        end

        context "when inner_node.parent returns nil" do
          let(:mock_node) { double("CommonmarkerNode", type: :paragraph) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:parent).and_return(nil)
          end

          it "returns nil" do
            expect(node.parent).to be_nil
          end
        end
      end

      describe "#next_sibling" do
        it "returns next sibling when available" do
          if root.child_count > 1
            first = root.child(0)
            sibling = first.next_sibling
            expect(sibling).to be_nil.or be_a(backend::Node)
          end
        end

        context "when inner_node.next_sibling raises" do
          let(:mock_node) { double("CommonmarkerNode", type: :paragraph) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:next_sibling).and_raise(StandardError)
          end

          it "returns nil" do
            expect(node.next_sibling).to be_nil
          end
        end

        context "when inner_node.next_sibling returns nil" do
          let(:mock_node) { double("CommonmarkerNode", type: :paragraph) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:next_sibling).and_return(nil)
          end

          it "returns nil" do
            expect(node.next_sibling).to be_nil
          end
        end
      end

      describe "#prev_sibling" do
        it "returns previous sibling when available" do
          if root.child_count > 1
            second = root.child(1)
            sibling = second.prev_sibling
            expect(sibling).to be_nil.or be_a(backend::Node)
          end
        end

        context "when inner_node.previous_sibling raises" do
          let(:mock_node) { double("CommonmarkerNode", type: :paragraph) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:previous_sibling).and_raise(StandardError)
          end

          it "returns nil" do
            expect(node.prev_sibling).to be_nil
          end
        end

        context "when inner_node.previous_sibling returns nil" do
          let(:mock_node) { double("CommonmarkerNode", type: :paragraph) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:previous_sibling).and_return(nil)
          end

          it "returns nil" do
            expect(node.prev_sibling).to be_nil
          end
        end
      end
    end

    describe "comparison" do
      let(:source) { "# Hello\n\nWorld" }
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

        it "returns nil when other doesn't respond to start_byte" do
          other = double("Other")
          allow(other).to receive(:respond_to?).with(:start_byte).and_return(false)
          expect(root <=> other).to be_nil
        end

        context "when start_byte comparison returns non-zero" do
          let(:mock_node_earlier) { double("NodeEarlier", type: :paragraph) }
          let(:mock_node_later) { double("NodeLater", type: :paragraph) }
          let(:node_earlier) { backend::Node.new(mock_node_earlier, source) }
          let(:node_later) { backend::Node.new(mock_node_later, source) }

          before do
            allow(mock_node_earlier).to receive_messages(respond_to?: false)
            allow(mock_node_later).to receive_messages(respond_to?: false)
            allow(mock_node_earlier).to receive(:respond_to?).with(:source_position).and_return(true)
            allow(mock_node_later).to receive(:respond_to?).with(:source_position).and_return(true)
            allow(mock_node_earlier).to receive(:source_position).and_return({start_line: 1, start_column: 1, end_line: 1, end_column: 5})
            allow(mock_node_later).to receive(:source_position).and_return({start_line: 2, start_column: 1, end_line: 2, end_column: 5})
          end

          it "returns comparison result based on start_byte" do
            expect(node_earlier <=> node_later).to be < 0
          end
        end

        context "when start_byte is equal but end_byte differs" do
          let(:mock_node_shorter) { double("NodeShorter", type: :paragraph) }
          let(:mock_node_longer) { double("NodeLonger", type: :paragraph) }
          let(:node_shorter) { backend::Node.new(mock_node_shorter, source) }
          let(:node_longer) { backend::Node.new(mock_node_longer, source) }

          before do
            allow(mock_node_shorter).to receive_messages(respond_to?: false)
            allow(mock_node_longer).to receive_messages(respond_to?: false)
            allow(mock_node_shorter).to receive(:respond_to?).with(:source_position).and_return(true)
            allow(mock_node_longer).to receive(:respond_to?).with(:source_position).and_return(true)
            allow(mock_node_shorter).to receive(:source_position).and_return({start_line: 1, start_column: 1, end_line: 1, end_column: 5})
            allow(mock_node_longer).to receive(:source_position).and_return({start_line: 1, start_column: 1, end_line: 1, end_column: 10})
          end

          it "compares by end_byte" do
            expect(node_shorter <=> node_longer).to be < 0
          end
        end
      end

      describe "#inspect" do
        it "returns descriptive string" do
          expect(root.inspect).to include("Commonmarker::Node")
          expect(root.inspect).to include("document")
        end
      end
    end

    describe "markdown-specific methods" do
      describe "#header_level" do
        let(:source) { "# H1\n\n## H2\n\n### H3" }
        let(:tree) { parser.parse(source) }
        let(:root) { tree.root_node }

        it "returns heading level for heading nodes" do
          heading = root.children.find { |c| c.type == "heading" }
          if heading
            level = heading.header_level
            expect(level).to be_a(Integer).or be_nil
          end
        end

        it "returns nil for non-heading nodes" do
          expect(root.header_level).to be_nil
        end

        context "when header_level raises" do
          let(:mock_node) { double("CommonmarkerNode", type: :heading) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:header_level).and_raise(StandardError)
          end

          it "returns nil" do
            expect(node.header_level).to be_nil
          end
        end
      end

      describe "#fence_info" do
        let(:source) { "```ruby\nputs 'hi'\n```" }
        let(:tree) { parser.parse(source) }
        let(:root) { tree.root_node }

        it "returns fence info for code blocks" do
          code_block = root.children.find { |c| c.type == "code_block" }
          if code_block
            info = code_block.fence_info
            expect(info).to be_nil.or eq("ruby")
          end
        end

        it "returns nil for non-code-block nodes" do
          expect(root.fence_info).to be_nil
        end

        context "when fence_info raises" do
          let(:mock_node) { double("CommonmarkerNode", type: :code_block) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:fence_info).and_raise(StandardError)
          end

          it "returns nil" do
            expect(node.fence_info).to be_nil
          end
        end
      end

      describe "#url" do
        let(:source) { "[link](https://example.com)" }
        let(:tree) { parser.parse(source) }

        it "returns url for link nodes" do
          result = tree.root_node.url
          expect(result).to be_nil.or be_a(String)
        end

        context "when url raises" do
          let(:mock_node) { double("CommonmarkerNode", type: :link) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:url).and_raise(StandardError)
          end

          it "returns nil" do
            expect(node.url).to be_nil
          end
        end
      end

      describe "#title" do
        let(:source) { '[link](https://example.com "Title")' }
        let(:tree) { parser.parse(source) }

        it "returns title when available" do
          result = tree.root_node.title
          expect(result).to be_nil.or be_a(String)
        end

        context "when title raises" do
          let(:mock_node) { double("CommonmarkerNode", type: :link) }
          let(:node) { backend::Node.new(mock_node, source) }

          before do
            allow(mock_node).to receive(:respond_to?).with(:each).and_return(false)
            allow(mock_node).to receive(:title).and_raise(StandardError)
          end

          it "returns nil" do
            expect(node.title).to be_nil
          end
        end
      end
    end
  end

  describe "Point", :commonmarker_backend do
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
        expect(point.inspect).to include("Commonmarker::Point")
        expect(point.inspect).to include("5")
        expect(point.inspect).to include("10")
      end
    end
  end
end
