# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver do
  after do
    TreeHaver.reset_backend!(to: :auto)
  end

  it "has a version number" do
    expect(TreeHaver::VERSION).not_to be_nil
  end

  describe ".backend" do
    it "defaults to :auto" do
      TreeHaver.reset_backend!(to: nil)
      stub_env("TREE_HAVER_BACKEND" => nil)
      # Force re-evaluation by clearing memoization
      TreeHaver.instance_variable_set(:@backend, nil)
      expect(TreeHaver.backend).to eq(:auto)
    end

    it "reads :mri from ENV" do
      TreeHaver.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "mri")
      expect(TreeHaver.backend).to eq(:mri)
    end

    it "reads :rust from ENV" do
      TreeHaver.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "rust")
      expect(TreeHaver.backend).to eq(:rust)
    end

    it "reads :ffi from ENV" do
      TreeHaver.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "ffi")
      expect(TreeHaver.backend).to eq(:ffi)
    end

    it "reads :java from ENV" do
      TreeHaver.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "java")
      expect(TreeHaver.backend).to eq(:java)
    end

    it "defaults to :auto for unknown ENV value" do
      TreeHaver.instance_variable_set(:@backend, nil)
      stub_env("TREE_HAVER_BACKEND" => "unknown")
      expect(TreeHaver.backend).to eq(:auto)
    end
  end

  describe ".backend=" do
    it "sets the backend" do
      TreeHaver.backend = :ffi
      expect(TreeHaver.backend).to eq(:ffi)
    end

    it "accepts string and converts to symbol" do
      TreeHaver.backend = "mri"
      expect(TreeHaver.backend).to eq(:mri)
    end

    it "accepts nil" do
      TreeHaver.backend = nil
      # When @backend is nil, the getter re-evaluates and defaults to :auto
      expect(TreeHaver.instance_variable_get(:@backend)).to be_nil
    end
  end

  describe ".reset_backend!" do
    it "resets to :auto by default" do
      TreeHaver.backend = :ffi
      TreeHaver.reset_backend!
      expect(TreeHaver.backend).to eq(:auto)
    end

    it "resets to specified value" do
      TreeHaver.backend = :ffi
      TreeHaver.reset_backend!(to: :mri)
      expect(TreeHaver.backend).to eq(:mri)
    end

    it "resets to nil when to: nil" do
      TreeHaver.backend = :ffi
      TreeHaver.reset_backend!(to: nil)
      # When to: nil, @backend is set to nil, but getter re-evaluates to :auto
      expect(TreeHaver.instance_variable_get(:@backend)).to be_nil
    end
  end

  describe ".backend_module" do
    context "with explicit backend selection" do
      it "returns MRI backend when backend is :mri" do
        TreeHaver.backend = :mri
        expect(TreeHaver.backend_module).to eq(TreeHaver::Backends::MRI)
      end

      it "returns Rust backend when backend is :rust" do
        TreeHaver.backend = :rust
        expect(TreeHaver.backend_module).to eq(TreeHaver::Backends::Rust)
      end

      it "returns FFI backend when backend is :ffi" do
        TreeHaver.backend = :ffi
        expect(TreeHaver.backend_module).to eq(TreeHaver::Backends::FFI)
      end

      it "returns Java backend when backend is :java" do
        TreeHaver.backend = :java
        expect(TreeHaver.backend_module).to eq(TreeHaver::Backends::Java)
      end
    end

    context "with auto-selection" do
      before do
        TreeHaver.backend = :auto
      end

      it "prefers Java on JRuby when available" do
        allow(TreeHaver::Backends::Java).to receive(:available?).and_return(true)
        stub_const("RUBY_ENGINE", "jruby")
        expect(TreeHaver.backend_module).to eq(TreeHaver::Backends::Java)
      end

      it "prefers MRI on MRI when available" do
        allow(TreeHaver::Backends::MRI).to receive(:available?).and_return(true)
        stub_const("RUBY_ENGINE", "ruby")
        expect(TreeHaver.backend_module).to eq(TreeHaver::Backends::MRI)
      end

      it "falls back to Rust on MRI when MRI backend unavailable" do
        allow(TreeHaver::Backends::MRI).to receive(:available?).and_return(false)
        allow(TreeHaver::Backends::Rust).to receive(:available?).and_return(true)
        stub_const("RUBY_ENGINE", "ruby")
        expect(TreeHaver.backend_module).to eq(TreeHaver::Backends::Rust)
      end

      it "falls back to FFI when others unavailable" do
        allow(TreeHaver::Backends::MRI).to receive(:available?).and_return(false)
        allow(TreeHaver::Backends::Rust).to receive(:available?).and_return(false)
        allow(TreeHaver::Backends::FFI).to receive(:available?).and_return(true)
        stub_const("RUBY_ENGINE", "ruby")
        expect(TreeHaver.backend_module).to eq(TreeHaver::Backends::FFI)
      end

      it "returns nil when no backend available" do
        allow(TreeHaver::Backends::MRI).to receive(:available?).and_return(false)
        allow(TreeHaver::Backends::Rust).to receive(:available?).and_return(false)
        allow(TreeHaver::Backends::FFI).to receive(:available?).and_return(false)
        allow(TreeHaver::Backends::Java).to receive(:available?).and_return(false)
        allow(TreeHaver::Backends::Citrus).to receive(:available?).and_return(false)
        stub_const("RUBY_ENGINE", "ruby")
        expect(TreeHaver.backend_module).to be_nil
      end
    end
  end

  describe ".capabilities" do
    it "returns backend capabilities when available" do
      allow(TreeHaver).to receive(:backend_module).and_return(TreeHaver::Backends::FFI)
      allow(TreeHaver::Backends::FFI).to receive(:capabilities).and_return({backend: :ffi, parse: true})
      expect(TreeHaver.capabilities).to eq({backend: :ffi, parse: true})
    end

    it "returns empty hash when no backend available" do
      allow(TreeHaver).to receive(:backend_module).and_return(nil)
      expect(TreeHaver.capabilities).to eq({})
    end
  end

  describe ".register_language" do
    it "delegates to LanguageRegistry" do
      expect(TreeHaver::LanguageRegistry).to receive(:register).with(:toml, :tree_sitter, path: "/path.so", symbol: "ts_toml")
      TreeHaver.register_language(:toml, path: "/path.so", symbol: "ts_toml")
    end
  end

  describe ".registered_language" do
    it "delegates to LanguageRegistry" do
      TreeHaver.register_language(:toml, path: "/lib.so")
      result = TreeHaver.registered_language(:toml)
      expect(result).to be_a(Hash)
      expect(result[:tree_sitter]).to be_a(Hash)
      expect(result[:tree_sitter][:path]).to eq("/lib.so")
    end
  end

  describe TreeHaver::Language do
    describe ".load" do
      it "calls from_library with derived symbol" do
        expect(TreeHaver::Language).to receive(:from_library).with(
          "/path/to/lib.so",
          symbol: "tree_sitter_toml",
          name: "toml",
          validate: true,
        )
        TreeHaver::Language.load("toml", "/path/to/lib.so")
      end

      it "passes validate option" do
        expect(TreeHaver::Language).to receive(:from_library).with(
          "/path/to/lib.so",
          symbol: "tree_sitter_json",
          name: "json",
          validate: false,
        )
        TreeHaver::Language.load("json", "/path/to/lib.so", validate: false)
      end
    end

    describe ".from_library" do
      context "path validation" do
        it "raises ArgumentError for unsafe path" do
          expect {
            TreeHaver::Language.from_library("../../../etc/passwd.so")
          }.to raise_error(ArgumentError, /Unsafe library path/)
        end

        it "raises ArgumentError for unsafe symbol" do
          expect {
            TreeHaver::Language.from_library("/usr/lib/libtest.so", symbol: "evil; rm -rf /")
          }.to raise_error(ArgumentError, /Unsafe symbol name/)
        end

        it "skips validation when validate: false" do
          allow(TreeHaver).to receive(:backend_module).and_return(nil)
          # Should not raise ArgumentError for path, but will raise NotAvailable
          expect {
            TreeHaver::Language.from_library("../bad/path.so", validate: false)
          }.to raise_error(TreeHaver::NotAvailable, /No TreeHaver backend/)
        end
      end

      context "when no backend available" do
        before do
          allow(TreeHaver).to receive(:backend_module).and_return(nil)
        end

        it "raises NotAvailable" do
          expect {
            TreeHaver::Language.from_library("/usr/lib/libtest.so")
          }.to raise_error(TreeHaver::NotAvailable, /No TreeHaver backend/)
        end
      end

      context "when backend available" do
        let(:fake_backend_module) do
          mod = Module.new
          lang_class = Class.new do
            define_singleton_method(:from_library) { |*args, **kwargs| "loaded_language" }
          end
          mod.const_set(:Language, lang_class)
          mod
        end

        before do
          allow(TreeHaver).to receive(:backend_module).and_return(fake_backend_module)
          TreeHaver::LanguageRegistry.clear_cache!
        end

        it "delegates to backend Language.from_library" do
          result = TreeHaver::Language.from_library("/usr/lib/libtest.so", symbol: "test_sym")
          expect(result).to eq("loaded_language")
        end

        it "caches the result" do
          call_count = 0
          allow(fake_backend_module::Language).to receive(:from_library).and_wrap_original do |method, *args, **kwargs|
            call_count += 1
            method.call(*args, **kwargs)
          end

          TreeHaver::Language.from_library("/usr/lib/libtest.so", symbol: "test_sym")
          TreeHaver::Language.from_library("/usr/lib/libtest.so", symbol: "test_sym")
          expect(call_count).to eq(1)
        end
      end

      context "when backend only has from_path (legacy)" do
        let(:legacy_backend_module) do
          mod = Module.new
          lang_class = Class.new do
            # Only from_path, not from_library
            define_singleton_method(:from_path) { |path| "loaded_via_from_path" }
          end
          mod.const_set(:Language, lang_class)
          mod
        end

        before do
          allow(TreeHaver).to receive(:backend_module).and_return(legacy_backend_module)
          TreeHaver::LanguageRegistry.clear_cache!
        end

        it "falls back to from_path when from_library not available" do
          result = TreeHaver::Language.from_library("/usr/lib/libtest.so", symbol: "test_sym")
          expect(result).to eq("loaded_via_from_path")
        end
      end
    end
  end

  describe TreeHaver::Parser do
    describe "#initialize" do
      context "when no backend available" do
        before do
          allow(TreeHaver).to receive(:backend_module).and_return(nil)
        end

        it "raises NotAvailable" do
          expect {
            TreeHaver::Parser.new
          }.to raise_error(TreeHaver::NotAvailable, /No TreeHaver backend/)
        end
      end

      context "when backend available" do
        let(:fake_parser) { double("Parser") }
        let(:fake_backend_module) do
          mod = Module.new
          parser_class = Class.new do
            define_method(:initialize) {}
          end
          mod.const_set(:Parser, parser_class)
          mod
        end

        before do
          allow(TreeHaver).to receive(:backend_module).and_return(fake_backend_module)
        end

        it "creates a parser" do
          expect { TreeHaver::Parser.new }.not_to raise_error
        end
      end
    end

    describe "#language=" do
      let(:fake_impl) { double("ImplParser", :language= => nil) }
      let(:fake_backend_module) do
        mod = Module.new
        impl = fake_impl
        parser_class = Class.new do
          define_method(:initialize) { @fake = impl }
          define_method(:language=) { |lang| @fake.language = lang }
        end
        mod.const_set(:Parser, parser_class)
        mod
      end

      # Create a proper test Language class that follows the Language pattern
      let(:test_language_class) do
        Class.new do
          include Comparable

          attr_reader :backend, :path, :symbol

          def initialize(backend: :test, path: "/test/grammar.so", symbol: "tree_sitter_test")
            @backend = backend
            @path = path
            @symbol = symbol
          end

          # Unwrapping method for test backend
          def to_test_language
            "test_language_pointer"
          end

          # Comparable implementation
          def <=>(other)
            return unless other.is_a?(self.class)
            return unless other.backend == @backend

            cmp = (@path || "") <=> (other.path || "")
            return cmp unless cmp.zero?

            (@symbol || "") <=> (other.symbol || "")
          end

          def hash
            [@backend, @path, @symbol].hash
          end

          alias_method :eql?, :==
        end
      end

      before do
        allow(TreeHaver).to receive(:backend_module).and_return(fake_backend_module)
      end

      it "sets language on underlying implementation" do
        parser = TreeHaver::Parser.new
        lang = test_language_class.new
        expect { parser.language = lang }.not_to raise_error
      end
    end

    describe "#parse" do
      let(:fake_tree_impl) { double("TreeImpl", root_node: double("Node")) }
      let(:fake_impl) { double("ImplParser", parse: fake_tree_impl) }
      let(:fake_backend_module) do
        impl = fake_impl
        mod = Module.new
        parser_class = Class.new do
          define_method(:initialize) { @impl = impl }
          attr_reader :impl
          define_method(:parse) { |src| @impl.parse(src) }
        end
        mod.const_set(:Parser, parser_class)
        mod
      end

      before do
        allow(TreeHaver).to receive(:backend_module).and_return(fake_backend_module)
      end

      it "returns a Tree wrapper" do
        parser = TreeHaver::Parser.new
        tree = parser.parse("test")
        expect(tree).to be_a(TreeHaver::Tree)
      end
    end

    describe "#parse_string" do
      let(:fake_tree_impl) { double("TreeImpl", root_node: double("Node")) }
      let(:fake_impl) { double("ImplParser") }
      let(:fake_backend_module) do
        impl = fake_impl
        mod = Module.new
        parser_class = Class.new do
          define_method(:initialize) { @impl = impl }
          attr_reader :impl
          define_method(:parse) { |src| @impl.parse(src) }
          define_method(:parse_string) { |old, src| @impl.parse_string(old, src) }
          define_method(:respond_to?) { |m, *| m == :parse_string || super(m) }
        end
        mod.const_set(:Parser, parser_class)
        mod
      end

      before do
        allow(TreeHaver).to receive(:backend_module).and_return(fake_backend_module)
        allow(fake_impl).to receive(:parse).and_return(fake_tree_impl)
        allow(fake_impl).to receive(:parse_string).and_return(fake_tree_impl)
        allow(fake_impl).to receive(:respond_to?).with(:parse_string).and_return(true)
      end

      it "passes old_tree to backend when provided" do
        parser = TreeHaver::Parser.new
        old_tree = TreeHaver::Tree.new(fake_tree_impl)
        expect(fake_impl).to receive(:parse_string).with(fake_tree_impl, "new source")
        parser.parse_string(old_tree, "new source")
      end

      it "extracts impl from raw object when old_tree is not a Tree wrapper" do
        parser = TreeHaver::Parser.new
        # Pass a raw impl object directly (not wrapped in Tree)
        raw_old_tree = fake_tree_impl
        expect(fake_impl).to receive(:parse_string).with(raw_old_tree, "raw source")
        parser.parse_string(raw_old_tree, "raw source")
      end

      it "passes nil when no old_tree" do
        parser = TreeHaver::Parser.new
        expect(fake_impl).to receive(:parse_string).with(nil, "source")
        parser.parse_string(nil, "source")
      end

      context "when backend doesn't support parse_string" do
        let(:no_parse_string_impl) { double("NoParseStringImpl") }
        let(:no_parse_string_backend) do
          impl = no_parse_string_impl
          mod = Module.new
          parser_class = Class.new do
            define_method(:initialize) { @impl = impl }
            attr_reader :impl
            define_method(:parse) { |src| @impl.parse(src) }
          end
          mod.const_set(:Parser, parser_class)
          mod
        end

        before do
          allow(TreeHaver).to receive(:backend_module).and_return(no_parse_string_backend)
          allow(no_parse_string_impl).to receive(:parse).and_return(fake_tree_impl)
          allow(no_parse_string_impl).to receive(:respond_to?).with(:parse_string).and_return(false)
        end

        it "falls back to parse when parse_string not supported and old_tree is nil" do
          parser = TreeHaver::Parser.new
          expect(no_parse_string_impl).to receive(:parse).with("source")
          parser.parse_string(nil, "source")
        end

        it "falls back to parse when parse_string not supported even with old_tree" do
          parser = TreeHaver::Parser.new
          old_tree = TreeHaver::Tree.new(fake_tree_impl)
          # Even though old_tree is provided, should fall back to parse since backend doesn't support parse_string
          expect(no_parse_string_impl).to receive(:parse).with("new source")
          parser.parse_string(old_tree, "new source")
        end
      end
    end
  end

  describe TreeHaver::Tree do
    let(:fake_root_node) { double("ImplNode", type: "document") }
    let(:fake_impl) { double("TreeImpl", root_node: fake_root_node) }

    describe "#root_node" do
      it "returns a Node wrapper" do
        tree = TreeHaver::Tree.new(fake_impl)
        node = tree.root_node
        expect(node).to be_a(TreeHaver::Node)
      end
    end

    describe "#edit" do
      context "when backend supports editing" do
        let(:editable_impl) { double("EditableTree", root_node: fake_root_node, edit: nil) }

        it "calls edit on underlying implementation" do
          tree = TreeHaver::Tree.new(editable_impl)
          expect(editable_impl).to receive(:edit).with(
            start_byte: 0,
            old_end_byte: 1,
            new_end_byte: 2,
            start_point: {row: 0, column: 0},
            old_end_point: {row: 0, column: 1},
            new_end_point: {row: 0, column: 2},
          )
          tree.edit(
            start_byte: 0,
            old_end_byte: 1,
            new_end_byte: 2,
            start_point: {row: 0, column: 0},
            old_end_point: {row: 0, column: 1},
            new_end_point: {row: 0, column: 2},
          )
        end
      end

      context "when backend doesn't support editing" do
        let(:non_editable_impl) { double("NonEditableTree", root_node: fake_root_node) }

        before do
          # Stub edit to raise NoMethodError as it would if the method doesn't exist
          allow(non_editable_impl).to receive(:edit).and_raise(NoMethodError.new("undefined method `edit'", :edit))
        end

        it "raises NotAvailable" do
          tree = TreeHaver::Tree.new(non_editable_impl)
          expect {
            tree.edit(
              start_byte: 0,
              old_end_byte: 1,
              new_end_byte: 2,
              start_point: {row: 0, column: 0},
              old_end_point: {row: 0, column: 1},
              new_end_point: {row: 0, column: 2},
            )
          }.to raise_error(TreeHaver::NotAvailable, /Incremental parsing not supported/)
        end
      end
    end

    describe "#supports_editing?" do
      it "returns true when impl has edit method" do
        editable_impl = double("EditableTree", root_node: fake_root_node)
        edit_method = double("Method")
        allow(editable_impl).to receive(:method).with(:edit).and_return(edit_method)
        tree = TreeHaver::Tree.new(editable_impl)
        expect(tree.supports_editing?).to be true
      end

      it "returns false when impl doesn't have edit method" do
        non_editable_impl = double("NonEditableTree", root_node: fake_root_node)
        allow(non_editable_impl).to receive(:method).with(:edit).and_raise(NameError.new("undefined method `edit'", :edit))
        tree = TreeHaver::Tree.new(non_editable_impl)
        expect(tree.supports_editing?).to be false
      end
    end
  end

  describe TreeHaver::Node do
    let(:fake_impl) do
      double(
        "ImplNode",
        type: "document",
        start_point: double(row: 0, column: 0),
        end_point: double(row: 5, column: 10),
        start_byte: 0,
        end_byte: 50,
        to_s: "Node(document)",
      )
    end

    describe "#type" do
      it "returns the node type" do
        node = TreeHaver::Node.new(fake_impl)
        expect(node.type).to eq("document")
      end
    end

    describe "#each" do
      let(:child_impl) { double("ChildNode", type: "child") }
      let(:iterable_impl) do
        double("IterableNode", type: "parent", child_count: 1).tap do |impl|
          allow(impl).to receive(:child).with(0).and_return(child_impl)
        end
      end

      it "yields wrapped child nodes" do
        node = TreeHaver::Node.new(iterable_impl)
        children = []
        node.each { |child| children << child }
        expect(children.size).to eq(1)
        expect(children.first).to be_a(TreeHaver::Node)
        expect(children.first.type).to eq("child")
      end

      it "returns Enumerator when no block given" do
        node = TreeHaver::Node.new(iterable_impl)
        enum = node.each
        expect(enum).to be_an(Enumerator)
      end
    end

    describe "#start_point" do
      it "returns start point from impl" do
        node = TreeHaver::Node.new(fake_impl)
        expect(node.start_point.row).to eq(0)
        expect(node.start_point.column).to eq(0)
      end
    end

    describe "#end_point" do
      it "returns end point from impl" do
        node = TreeHaver::Node.new(fake_impl)
        expect(node.end_point.row).to eq(5)
        expect(node.end_point.column).to eq(10)
      end
    end

    describe "#start_byte" do
      it "returns start byte from impl" do
        node = TreeHaver::Node.new(fake_impl)
        expect(node.start_byte).to eq(0)
      end
    end

    describe "#end_byte" do
      it "returns end byte from impl" do
        node = TreeHaver::Node.new(fake_impl)
        expect(node.end_byte).to eq(50)
      end
    end

    describe "#has_error?" do
      it "returns true when impl has error" do
        error_impl = double("ErrorNode", has_error?: true)
        node = TreeHaver::Node.new(error_impl)
        expect(node.has_error?).to be true
      end

      it "returns false when impl has no error" do
        ok_impl = double("OkNode", has_error?: false)
        node = TreeHaver::Node.new(ok_impl)
        expect(node.has_error?).to be false
      end

      it "returns false when impl doesn't respond to has_error?" do
        basic_impl = double("BasicNode", type: "test")
        allow(basic_impl).to receive(:respond_to?).with(:has_error?).and_return(false)
        allow(basic_impl).to receive(:has_error?).and_return(false)
        node = TreeHaver::Node.new(basic_impl)
        expect(node.has_error?).to be false
      end
    end

    describe "#missing?" do
      it "returns true when impl is missing" do
        missing_impl = double("MissingNode", missing?: true)
        node = TreeHaver::Node.new(missing_impl)
        expect(node.missing?).to be true
      end

      it "returns false when impl is not missing" do
        present_impl = double("PresentNode", missing?: false)
        node = TreeHaver::Node.new(present_impl)
        expect(node.missing?).to be false
      end

      it "returns false when impl doesn't respond to missing?" do
        basic_impl = double("BasicNode")
        allow(basic_impl).to receive(:respond_to?).with(:missing?).and_return(false)
        node = TreeHaver::Node.new(basic_impl)
        expect(node.missing?).to be false
      end
    end

    describe "#to_s" do
      it "returns the node text" do
        impl_with_text = double("ImplWithText", text: "sample text", type: "test")
        node = TreeHaver::Node.new(impl_with_text)
        expect(node.to_s).to eq("sample text")
      end
    end

    describe "#respond_to_missing?" do
      it "returns true for methods the impl responds to" do
        impl_with_method = double("ImplWithMethod")
        allow(impl_with_method).to receive(:respond_to?).with(:custom_method, false).and_return(true)
        node = TreeHaver::Node.new(impl_with_method)
        expect(node.respond_to?(:custom_method)).to be true
      end

      it "returns false for methods the impl doesn't respond to" do
        basic_impl = double("BasicImpl")
        allow(basic_impl).to receive(:respond_to?).with(:unknown_method, false).and_return(false)
        node = TreeHaver::Node.new(basic_impl)
        expect(node.respond_to?(:unknown_method)).to be false
      end
    end

    describe "#method_missing" do
      it "delegates unknown methods to impl" do
        impl_with_custom = double("CustomImpl", custom_data: "test_value")
        node = TreeHaver::Node.new(impl_with_custom)
        expect(node.custom_data).to eq("test_value")
      end

      it "raises NoMethodError for undefined methods" do
        basic_impl = double("BasicImpl")
        allow(basic_impl).to receive(:respond_to?).with(:undefined_method).and_return(false)
        node = TreeHaver::Node.new(basic_impl)
        expect {
          node.undefined_method
        }.to raise_error(NoMethodError)
      end
    end
  end

  describe ".backend_module" do
    context "when backend is :citrus", :citrus_backend do
      before { TreeHaver.backend = :citrus }
      after { TreeHaver.backend = :auto }

      it "returns Citrus backend module" do
        expect(TreeHaver.backend_module).to eq(TreeHaver::Backends::Citrus)
      end
    end

    context "when no backend is available" do
      before do
        allow(TreeHaver::Backends::Java).to receive(:available?).and_return(false)
        allow(TreeHaver::Backends::MRI).to receive(:available?).and_return(false)
        allow(TreeHaver::Backends::Rust).to receive(:available?).and_return(false)
        allow(TreeHaver::Backends::FFI).to receive(:available?).and_return(false)
        allow(TreeHaver::Backends::Citrus).to receive(:available?).and_return(false)
        TreeHaver.backend = :auto
      end

      after do
        TreeHaver.backend = :auto
      end

      it "returns nil" do
        expect(TreeHaver.backend_module).to be_nil
      end
    end
  end

  describe ".register_language" do
    # NOTE: Don't clear registrations - use unique names per test

    context "with grammar_module that doesn't respond to :parse" do
      it "raises ArgumentError" do
        bad_module = Module.new

        expect {
          TreeHaver.register_language(:bad_module_test, grammar_module: bad_module)
        }.to raise_error(ArgumentError, /must respond to :parse/)
      end
    end

    context "with neither path nor grammar_module" do
      it "raises ArgumentError" do
        expect {
          TreeHaver.register_language(:empty_test)
        }.to raise_error(ArgumentError, /Must provide at least one/)
      end
    end

    context "with both path and grammar_module" do
      it "registers both backends" do
        mock_grammar = Module.new
        def mock_grammar.parse(source)
        end

        TreeHaver.register_language(
          :test_lang,
          path: "/fake/path.so",
          symbol: "ts_test",
          grammar_module: mock_grammar,
          gem_name: "test-gem",
        )

        registration = TreeHaver.registered_language(:test_lang)
        expect(registration).to have_key(:tree_sitter)
        expect(registration).to have_key(:citrus)
        expect(registration[:tree_sitter][:path]).to eq("/fake/path.so")
        expect(registration[:citrus][:grammar_module]).to eq(mock_grammar)
      end
    end
  end

  describe ".resolve_effective_backend" do
    after do
      Thread.current[:tree_haver_backend_context] = nil
      TreeHaver.backend = :auto
    end

    it "returns explicit backend when provided" do
      expect(TreeHaver.send(:resolve_effective_backend, :ffi)).to eq(:ffi)
    end

    it "returns thread context backend when no explicit backend" do
      Thread.current[:tree_haver_backend_context] = {backend: :mri, depth: 1}
      expect(TreeHaver.send(:resolve_effective_backend, nil)).to eq(:mri)
    end

    it "returns global backend when no thread context" do
      TreeHaver.backend = :rust
      expect(TreeHaver.send(:resolve_effective_backend, nil)).to eq(:rust)
    end

    it "returns :auto when nothing is set" do
      Thread.current[:tree_haver_backend_context] = nil
      TreeHaver.backend = :auto
      expect(TreeHaver.send(:resolve_effective_backend, nil)).to eq(:auto)
    end
  end

  describe "backend resolution edge cases" do
    describe "::resolve_backend_module" do
      context "when no backends are available" do
        before do
          # Stub all backends as unavailable
          allow(TreeHaver::Backends::MRI).to receive(:available?).and_return(false)
          allow(TreeHaver::Backends::Rust).to receive(:available?).and_return(false)
          allow(TreeHaver::Backends::FFI).to receive(:available?).and_return(false)
          allow(TreeHaver::Backends::Java).to receive(:available?).and_return(false)
          allow(TreeHaver::Backends::Citrus).to receive(:available?).and_return(false)
        end

        it "returns nil when auto-detecting with no available backends" do
          result = described_class.resolve_backend_module(:auto)
          expect(result).to be_nil
        end
      end

      context "when only Citrus is available" do
        before do
          allow(TreeHaver::Backends::MRI).to receive(:available?).and_return(false)
          allow(TreeHaver::Backends::Rust).to receive(:available?).and_return(false)
          allow(TreeHaver::Backends::FFI).to receive(:available?).and_return(false)
          allow(TreeHaver::Backends::Java).to receive(:available?).and_return(false)
          allow(TreeHaver::Backends::Citrus).to receive(:available?).and_return(true)
        end

        it "falls back to Citrus when auto-detecting" do
          result = described_class.resolve_backend_module(:auto)
          expect(result).to eq(TreeHaver::Backends::Citrus)
        end
      end
    end
  end

  describe TreeHaver::Language do
    describe "::method_missing edge cases" do
      context "with Citrus backend" do
        before do
          TreeHaver.backend = :citrus
        end

        after do
          TreeHaver.backend = :auto
        end

        it "raises NoMethodError when no registration found" do
          expect {
            TreeHaver::Language.unregistered_lang_citrus_test
          }.to raise_error(NoMethodError)
        end
      end

      context "with Citrus-only registration and tree-sitter backend" do
        before do
          TreeHaver.backend = :mri
          # Register only for Citrus, not tree-sitter - use unique name
          TreeHaver::LanguageRegistry.register(
            :test_lang_citrus_only,
            :citrus,
            grammar_module: double("Grammar", parse: true),
          )
        end

        after do
          TreeHaver.backend = :auto
        end

        it "falls back to Citrus when tree-sitter registration not available" do
          # With our new fallback behavior, when only Citrus is registered
          # and tree-sitter backend is active, we fall back to Citrus
          language = TreeHaver::Language.test_lang_citrus_only
          expect(language).to be_a(TreeHaver::Backends::Citrus::Language)
        end
      end
    end
  end

  describe TreeHaver::Parser do
    describe "#parse_string edge cases" do
      context "with old_tree parameter" do
        let(:old_tree_impl) { double("OldTreeImpl") }
        let(:new_tree_impl) { double("NewTreeImpl", root_node: double(type: "root", child_count: 0)) }
        let(:impl) { double("ParserImpl", parse_string: new_tree_impl, "language=": nil) }

        let(:fake_backend_module) do
          mod = Module.new
          impl_inst = impl
          parser_class = Class.new do
            define_method(:initialize) do
              @impl = impl_inst
            end
            attr_reader :impl
            define_method(:language=) { |lang| @impl.language = lang }
            define_method(:parse_string) { |old, src| @impl.parse_string(old, src) }
          end
          mod.const_set(:Parser, parser_class)
          mod
        end

        before do
          allow(TreeHaver).to receive(:resolve_backend_module).and_return(fake_backend_module)
        end

        it "extracts impl from Tree wrapper when old_tree has @inner_tree" do
          parser = TreeHaver::Parser.new

          old_tree_wrapper = double("TreeWrapper")
          allow(old_tree_wrapper).to receive(:respond_to?).and_return(false)
          allow(old_tree_wrapper).to receive(:respond_to?).with(:inner_tree).and_return(true)
          allow(old_tree_wrapper).to receive(:inner_tree).and_return(old_tree_impl)

          expect(impl).to receive(:parse_string).with(old_tree_impl, "new source").and_return(new_tree_impl)

          parser.parse_string(old_tree_wrapper, "new source")
        end

        it "extracts impl from legacy wrapper when old_tree has @impl" do
          parser = TreeHaver::Parser.new

          old_tree_wrapper = double("TreeWrapper")
          allow(old_tree_wrapper).to receive(:respond_to?).and_return(true)
          allow(old_tree_wrapper).to receive(:respond_to?).with(:inner_tree).and_return(false)
          allow(old_tree_wrapper).to receive(:instance_variable_get).with(:@inner_tree).and_return(nil)
          allow(old_tree_wrapper).to receive(:instance_variable_get).with(:@impl).and_return(old_tree_impl)

          expect(impl).to receive(:parse_string).with(old_tree_impl, "new source").and_return(new_tree_impl)

          parser.parse_string(old_tree_wrapper, "new source")
        end

        it "uses old_tree directly when it's not a wrapper" do
          parser = TreeHaver::Parser.new

          allow(old_tree_impl).to receive(:respond_to?).and_return(false)

          expect(impl).to receive(:parse_string).with(old_tree_impl, "new source").and_return(new_tree_impl)

          parser.parse_string(old_tree_impl, "new source")
        end
      end
    end
  end
end
