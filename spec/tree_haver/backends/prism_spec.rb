# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Backends::Prism do
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

    context "when prism gem is available" do
      before do
        backend.reset!
        allow(backend).to receive(:require).with("prism").and_return(true)
      end

      it "returns true" do
        expect(backend.available?).to be true
      end
    end

    context "when prism gem is not available" do
      before do
        backend.reset!
        allow(backend).to receive(:require).with("prism").and_raise(LoadError.new("cannot load prism"))
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
        expect(caps[:backend]).to eq(:prism)
        expect(caps[:query]).to be false
        expect(caps[:bytes_field]).to be true
        expect(caps[:incremental]).to be false
        expect(caps[:pure_ruby]).to be false
        expect(caps[:ruby_only]).to be true
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
      it "creates a language with default name :ruby" do
        lang = backend::Language.new
        expect(lang.name).to eq(:ruby)
        expect(lang.backend).to eq(:prism)
        expect(lang.options).to eq({})
      end

      it "accepts custom options" do
        lang = backend::Language.new(:ruby, options: {frozen_string_literal: true})
        expect(lang.name).to eq(:ruby)
        expect(lang.options).to eq({frozen_string_literal: true})
      end

      it "raises NotAvailable for non-ruby languages" do
        expect {
          backend::Language.new(:javascript)
        }.to raise_error(TreeHaver::NotAvailable, /only supports Ruby parsing/)
      end
    end

    describe ".ruby" do
      it "creates a ruby language" do
        lang = backend::Language.ruby
        expect(lang.name).to eq(:ruby)
        expect(lang.backend).to eq(:prism)
      end

      it "accepts options" do
        lang = backend::Language.ruby(frozen_string_literal: true)
        expect(lang.options).to eq({frozen_string_literal: true})
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

    describe "#<=>" do
      it "compares by options when backends match" do
        lang1 = backend::Language.new(:ruby, options: {a: 1})
        lang2 = backend::Language.new(:ruby, options: {b: 2})
        expect(lang1 <=> lang2).to be_a(Integer)
      end

      it "returns nil for non-Language" do
        lang = backend::Language.new
        expect(lang <=> "other").to be_nil
      end

      it "returns nil for different backends" do
        lang = backend::Language.new
        other = double("other_lang", is_a?: true, backend: :other)
        allow(other).to receive(:is_a?).with(backend::Language).and_return(true)
        allow(other).to receive(:backend).and_return(:other)
        expect(lang <=> other).to be_nil
      end
    end

    describe "#hash" do
      it "returns consistent hash for equal languages" do
        lang1 = backend::Language.new(:ruby, options: {a: 1})
        lang2 = backend::Language.new(:ruby, options: {a: 1})
        expect(lang1.hash).to eq(lang2.hash)
      end
    end

    describe "#eql?" do
      it "returns true for equal languages" do
        lang1 = backend::Language.new(:ruby, options: {a: 1})
        lang2 = backend::Language.new(:ruby, options: {a: 1})
        expect(lang1.eql?(lang2)).to be true
      end
    end
  end

  describe "Parser" do
    describe "#initialize", :prism_backend do
      it "creates a parser" do
        expect { backend::Parser.new }.not_to raise_error
      end
    end

    describe "#initialize when prism is not available" do
      before do
        allow(backend).to receive(:available?).and_return(false)
      end

      it "raises NotAvailable" do
        expect {
          backend::Parser.new
        }.to raise_error(TreeHaver::NotAvailable, /prism not available/)
      end
    end

    describe "#language=", :prism_backend do
      let(:parser) { backend::Parser.new }

      it "accepts a Language instance" do
        lang = backend::Language.ruby
        parser.language = lang
        expect(parser.instance_variable_get(:@language)).to eq(lang)
      end

      it "accepts :ruby symbol" do
        parser.language = :ruby
        expect(parser.instance_variable_get(:@language)).to be_a(backend::Language)
      end

      it "accepts 'ruby' string" do
        parser.language = "ruby"
        expect(parser.instance_variable_get(:@language)).to be_a(backend::Language)
      end

      it "raises ArgumentError for non-ruby languages" do
        expect {
          parser.language = :javascript
        }.to raise_error(ArgumentError, /only supports Ruby/)
      end
    end

    describe "#language", :prism_backend do
      let(:parser) { backend::Parser.new }

      it "stores the language internally" do
        lang = backend::Language.ruby
        parser.language = lang
        # Language is stored in @language instance variable
        expect(parser.instance_variable_get(:@language)).to eq(lang)
      end
    end

    describe "#parse", :prism_backend do
      let(:parser) { backend::Parser.new }

      context "when language is not set" do
        it "raises an error" do
          expect { parser.parse("puts 'hi'") }.to raise_error(TreeHaver::NotAvailable, /No language loaded/)
        end
      end

      context "when language is set" do
        let(:ruby_source) do
          <<~RUBY
            # Comment
            def hello(name)
              puts "Hello, \#{name}!"
            end

            class Greeter
              def initialize(greeting)
                @greeting = greeting
              end

              def greet(name)
                puts "\#{@greeting}, \#{name}!"
              end
            end
          RUBY
        end

        before do
          parser.language = backend::Language.ruby
        end

        it "returns a Tree" do
          tree = parser.parse(ruby_source)
          expect(tree).to be_a(backend::Tree)
        end

        it "parses ruby program structure" do
          tree = parser.parse(ruby_source)
          root = tree.root_node
          expect(root.type).to eq("program_node")
        end

        it "handles syntax errors gracefully" do
          tree = parser.parse("def foo; end def")
          expect(tree).to be_a(backend::Tree)
          expect(tree.errors).not_to be_empty
        end
      end
    end

    describe "#parse_string", :prism_backend do
      let(:parser) { backend::Parser.new }

      before do
        parser.language = backend::Language.ruby
      end

      it "ignores old_tree parameter" do
        old_tree = double("old_tree")
        tree = parser.parse_string(old_tree, "puts 'hi'")
        expect(tree).to be_a(backend::Tree)
      end
    end
  end

  describe "Tree", :prism_backend do
    let(:parser) { backend::Parser.new.tap { |p| p.language = backend::Language.ruby } }
    let(:source) { "def hello; puts 'hi'; end" }
    let(:tree) { parser.parse(source) }

    describe "#root_node" do
      it "returns a Node" do
        expect(tree.root_node).to be_a(backend::Node)
      end

      it "returns program_node as root type" do
        expect(tree.root_node.type).to eq("program_node")
      end
    end

    describe "#source" do
      it "returns the original source" do
        expect(tree.source).to eq(source)
      end
    end

    describe "#errors" do
      it "returns array of errors" do
        expect(tree.errors).to be_an(Array)
      end

      context "with syntax error" do
        let(:source) { "def foo(" }
        let(:tree) { parser.parse(source) }

        it "contains error information" do
          expect(tree.errors).not_to be_empty
        end
      end
    end

    describe "#warnings" do
      it "returns array of warnings" do
        expect(tree.warnings).to be_an(Array)
      end
    end

    describe "#comments" do
      let(:source) { "# comment\nputs 'hi'" }
      let(:tree) { parser.parse(source) }

      it "returns array of comments" do
        expect(tree.comments).to be_an(Array)
      end

      it "includes comment nodes" do
        expect(tree.comments.length).to be >= 1
      end
    end

    describe "#inspect" do
      it "returns a descriptive string" do
        expect(tree.inspect).to include("Prism::Tree")
      end
    end
  end

  describe "Node", :prism_backend do
    let(:parser) { backend::Parser.new.tap { |p| p.language = backend::Language.ruby } }

    describe "basic node properties" do
      let(:source) { "def hello(name); puts name; end" }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#type" do
        it "returns node type as string" do
          expect(root.type).to eq("program_node")
        end
      end

      describe "#kind" do
        it "is aliased to type" do
          expect(root.kind).to eq(root.type)
        end
      end

      describe "#text" do
        it "returns node text content" do
          expect(root.text).to eq(source)
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

        it "returns nil for out of bounds" do
          expect(root.child(999)).to be_nil
        end
      end

      describe "#first_child" do
        it "returns first child" do
          if root.child_count > 0
            expect(root.first_child).to be_a(backend::Node)
            expect(root.first_child.type).to eq(root.child(0).type)
          end
        end
      end

      describe "#each" do
        it "yields each child" do
          yielded = []
          root.each { |child| yielded << child }
          # Compare by type since each children call creates new wrapper objects
          expect(yielded.map(&:type)).to eq(root.children.map(&:type))
        end

        it "returns Enumerator when no block given" do
          expect(root.each).to be_an(Enumerator)
        end
      end
    end

    describe "position information" do
      let(:source) { "def foo\n  bar\nend" }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#start_point" do
        it "returns a hash with row and column" do
          point = root.start_point
          expect(point).to be_a(Hash)
          expect(point[:row]).to eq(0)
          expect(point[:column]).to eq(0)
        end
      end

      describe "#end_point" do
        it "returns a hash with row and column" do
          point = root.end_point
          expect(point).to be_a(Hash)
          expect(point[:row]).to be >= 0
          expect(point[:column]).to be >= 0
        end
      end

      describe "#start_byte" do
        it "returns byte offset" do
          expect(root.start_byte).to be_a(Integer)
          expect(root.start_byte).to eq(0)
        end
      end

      describe "#end_byte" do
        it "returns byte offset" do
          expect(root.end_byte).to be_a(Integer)
          expect(root.end_byte).to eq(source.bytesize)
        end
      end

      describe "#start_line" do
        it "returns 1-based line number" do
          expect(root.start_line).to eq(1)
        end
      end

      describe "#end_line" do
        it "returns 1-based line number" do
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
      let(:source) { "def foo; end" }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#named?" do
        it "returns true for named nodes" do
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

        context "with syntax error" do
          let(:source) { "def foo(" }
          let(:tree) { parser.parse(source) }

          it "returns true or tree has errors" do
            # Prism may report errors via tree.errors rather than node.has_error?
            has_any_error = root.has_error? || tree.errors.any?
            expect(has_any_error).to be true
          end
        end
      end

      describe "#missing?" do
        it "returns false for present nodes" do
          expect(root.missing?).to be false
        end
      end
    end

    describe "navigation" do
      let(:source) { "class Foo\n  def bar; end\n  def baz; end\nend" }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#parent" do
        it "raises NotImplementedError" do
          expect { root.parent }.to raise_error(NotImplementedError, /parent navigation/)
        end
      end

      describe "#next_sibling" do
        it "raises NotImplementedError" do
          expect { root.next_sibling }.to raise_error(NotImplementedError, /sibling navigation/)
        end
      end

      describe "#prev_sibling" do
        it "raises NotImplementedError" do
          if root.child_count > 0
            expect { root.child(0).prev_sibling }.to raise_error(NotImplementedError, /sibling navigation/)
          end
        end
      end
    end

    describe "comparison" do
      let(:source) { "a = 1\nb = 2" }
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
          expect(root.inspect).to include("Prism::Node")
          expect(root.inspect).to include("program_node")
        end
      end
    end

    describe "prism-specific methods" do
      describe "#location" do
        let(:source) { "puts 'hi'" }
        let(:tree) { parser.parse(source) }
        let(:root) { tree.root_node }

        it "returns location object" do
          expect(root.location).to respond_to(:start_offset)
          expect(root.location).to respond_to(:end_offset)
        end
      end

      describe "node type specific accessors" do
        context "with def node" do
          let(:source) { "def hello(name)\n  puts name\nend" }
          let(:tree) { parser.parse(source) }

          it "can access def node children" do
            # Prism wraps in program_node -> statements_node -> def_node
            statements = tree.root_node.child(0)
            def_node = statements.child(0)
            expect(def_node.type).to include("def")
          end
        end

        context "with class node" do
          let(:source) { "class Foo < Bar; end" }
          let(:tree) { parser.parse(source) }

          it "can access class node children" do
            # Prism wraps in program_node -> statements_node -> class_node
            statements = tree.root_node.child(0)
            class_node = statements.child(0)
            expect(class_node.type).to include("class")
          end
        end
      end
    end
  end

  describe "Point", :prism_backend do
    let(:parser) { backend::Parser.new.tap { |p| p.language = backend::Language.ruby } }
    let(:source) { "puts 'hi'" }
    let(:tree) { parser.parse(source) }
    let(:root) { tree.root_node }

    describe "point interface" do
      it "start_point returns position info with hash-style access" do
        point = root.start_point
        # Prism returns a hash-like object
        expect(point[:row]).to eq(0)
        expect(point[:column]).to eq(0)
      end

      it "supports to_h" do
        point = root.start_point
        hash = point.to_h
        expect(hash).to have_key(:row)
        expect(hash).to have_key(:column)
      end
    end
  end
end
