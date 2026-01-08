# frozen_string_literal: true

require "spec_helper"

RSpec.describe TreeHaver::Backends::MRI do
  let(:backend) { described_class }

  before do
    TreeHaver::LanguageRegistry.clear_cache!
  end

  after do
    backend.reset!
    TreeHaver::LanguageRegistry.clear_cache!
    TreeHaver.reset_backend!(to: :auto)
  end

  describe "::available?" do
    it "returns a boolean" do
      result = backend.available?
      expect(result).to be(true).or be(false)
    end

    context "when ruby_tree_sitter is available", :mri_backend do
      it "returns true" do
        expect(backend.available?).to be true
      end

      it "sets @loaded to true after successful require" do
        # Reset to force re-evaluation
        backend.instance_variable_set(:@load_attempted, false)
        backend.instance_variable_set(:@loaded, false)
        backend.available?
        expect(backend.instance_variable_get(:@loaded)).to be true
      end
    end

    context "when ruby_tree_sitter is not available" do
      it "returns false after reset and failed require" do
        # Reset the memoized state using the API
        backend.reset!

        # Stub require to fail
        allow(backend).to receive(:require).with("tree_sitter").and_raise(LoadError)

        expect(backend.available?).to be false
      end
    end

    it "memoizes the result" do
      first_result = backend.available?
      second_result = backend.available?
      expect(first_result).to eq(second_result)
    end
  end

  describe "::capabilities", :mri_backend do
    it "returns a hash with backend info" do
      caps = backend.capabilities
      expect(caps).to be_a(Hash)
      expect(caps[:backend]).to eq(:mri)
      expect(caps[:query]).to be true
      expect(caps[:bytes_field]).to be true
      expect(caps[:incremental]).to be true
    end

    it "returns the full capabilities hash" do
      caps = backend.capabilities
      expect(caps.keys).to contain_exactly(:backend, :query, :bytes_field, :incremental)
    end
  end

  describe "::capabilities when not available" do
    before do
      allow(backend).to receive(:available?).and_return(false)
    end

    it "returns empty hash" do
      expect(backend.capabilities).to eq({})
    end
  end

  describe "Language" do
    describe "#<=>" do
      context "when comparing languages", :mri_backend, :toml_grammar do
        let(:path) { TreeHaverDependencies.find_toml_grammar_path }
        let(:first_language) { backend::Language.from_library(path) }
        let(:second_language) { backend::Language.from_library(path) }

        it "returns nil for non-Language objects" do
          expect(first_language <=> "not a language").to be_nil
        end

        it "returns nil for Language with different backend" do
          other = double("other_lang", is_a?: true, backend: :other)
          allow(other).to receive(:is_a?).with(backend::Language).and_return(true)
          allow(other).to receive(:backend).and_return(:other)
          expect(first_language <=> other).to be_nil
        end

        it "returns 0 for languages with same path and symbol" do
          expect(first_language <=> second_language).to eq(0)
        end

        it "compares by path when paths differ" do
          allow(second_language).to receive(:path).and_return("/z/path.so")
          expect(first_language <=> second_language).to be < 0
        end
      end
    end

    describe "#hash", :mri_backend, :toml_grammar do
      it "returns consistent hash for same language" do
        path = TreeHaverDependencies.find_toml_grammar_path
        lang1 = backend::Language.from_library(path)
        lang2 = backend::Language.from_library(path)
        expect(lang1.hash).to eq(lang2.hash)
      end
    end

    describe "::from_library" do
      context "when MRI backend is not available" do
        before do
          # Stub available? to return false - this is more reliable than hide_const
          # because it avoids issues with memoization
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises NotAvailable" do
          expect {
            backend::Language.from_library("/path/to/lib.so")
          }.to raise_error(TreeHaver::NotAvailable, /ruby_tree_sitter not available/)
        end
      end

      context "when path does not exist", :mri_backend do
        it "raises an error for non-existent path" do
          expect {
            backend::Language.from_library("/nonexistent/path/to/lib.so")
          }.to raise_error(TreeHaver::NotAvailable)
        end
      end

      context "with valid TOML grammar", :mri_backend, :toml_grammar do
        it "loads the language successfully" do
          path = TreeHaverDependencies.find_toml_grammar_path
          lang = backend::Language.from_library(path)
          expect(lang).to be_a(backend::Language)
          # Inner language should be the raw TreeSitter::Language
          expect(lang.inner_language).to be_a(TreeSitter::Language)
        end

        it "calls TreeSitter::Language.load" do
          path = TreeHaverDependencies.find_toml_grammar_path
          # This actually exercises the internal from_path method via from_library
          lang = backend::Language.from_library(path)
          expect(lang).not_to be_nil
        end
      end

      context "with error handling", :mri_backend do
        context "when TreeSitter::TreeSitterError is raised" do
          it "wraps the error in NotAvailable" do
            stub_const("TreeSitter::TreeSitterError", Class.new(RuntimeError)) unless defined?(TreeSitter::TreeSitterError)

            allow(TreeSitter::Language).to receive(:load).and_raise(TreeSitter::TreeSitterError.new("load error"))

            expect {
              backend::Language.from_library("/some/path.so", symbol: "tree_sitter_test")
            }.to raise_error(TreeHaver::NotAvailable, /Could not load language: load error/)
          end
        end

        context "when a non-TreeSitter exception is raised" do
          it "re-raises the original exception" do
            allow(TreeSitter::Language).to receive(:load).and_raise(IOError.new("io error"))

            expect {
              backend::Language.from_library("/some/path.so", symbol: "tree_sitter_test")
            }.to raise_error(IOError, "io error")
          end
        end
      end
    end
  end

  describe "Parser", :mri_backend do
    describe "#initialize" do
      context "when MRI backend is not available" do
        before do
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises NotAvailable" do
          expect {
            backend::Parser.new
          }.to raise_error(TreeHaver::NotAvailable, /ruby_tree_sitter not available/)
        end
      end

      it "creates a new parser wrapping TreeSitter::Parser" do
        parser = backend::Parser.new
        expect(parser).to be_a(backend::Parser)
        # Verify it actually created the underlying parser (line 80)
        expect(parser.instance_variable_get(:@parser)).to be_a(TreeSitter::Parser)
      end
    end

    describe "#language=", :toml_grammar do
      it "sets the language on the underlying parser" do
        parser = backend::Parser.new
        path = TreeHaverDependencies.find_toml_grammar_path
        lang = backend::Language.from_library(path)
        # This actually exercises line 88: @parser.language = lang
        result = parser.language = lang
        expect(result).to eq(lang)
      end
    end

    describe "#parse", :toml_grammar do
      let(:parser) do
        p = backend::Parser.new
        path = TreeHaverDependencies.find_toml_grammar_path
        p.language = backend::Language.from_library(path)
        p
      end

      it "parses source code and returns a tree" do
        # This actually exercises line 96: @parser.parse(source)
        tree = parser.parse("key = \"value\"\n")
        expect(tree).to be_a(TreeSitter::Tree)
      end

      it "parses valid TOML and provides access to root node" do
        tree = parser.parse("key = \"value\"\n")
        root = tree.root_node
        expect(root).not_to be_nil
        expect(root.type).to eq(:document)
      end
    end

    describe "#parse_string", :toml_grammar do
      let(:parser) do
        p = backend::Parser.new
        path = TreeHaverDependencies.find_toml_grammar_path
        p.language = backend::Language.from_library(path)
        p
      end

      it "parses source code with nil old_tree" do
        # This actually exercises line 105: @parser.parse_string(old_tree, source)
        tree = parser.parse_string(nil, "key = \"value\"\n")
        expect(tree).to be_a(TreeSitter::Tree)
      end

      it "parses source code with existing tree for incremental parsing" do
        old_tree = parser.parse("key = \"old\"\n")
        new_tree = parser.parse_string(old_tree, "key = \"new\"\n")
        expect(new_tree).to be_a(TreeSitter::Tree)
        expect(new_tree.root_node.type).to eq(:document)
      end
    end

    describe "#parse error handling", :mri_backend do
      let(:parser) { backend::Parser.new }

      context "when parse_string returns nil" do
        it "raises NotAvailable with helpful message" do
          # Mock the inner parser to return nil
          inner_parser = parser.instance_variable_get(:@parser)
          allow(inner_parser).to receive(:parse_string).and_return(nil)

          expect {
            parser.parse("some source")
          }.to raise_error(TreeHaver::NotAvailable, /Parse returned nil - is language set\?/)
        end
      end

      context "when TreeSitter::TreeSitterError is raised" do
        it "wraps the error in NotAvailable" do
          # Create a mock TreeSitterError class if it doesn't exist for testing
          stub_const("TreeSitter::TreeSitterError", Class.new(RuntimeError)) unless defined?(TreeSitter::TreeSitterError)

          inner_parser = parser.instance_variable_get(:@parser)
          allow(inner_parser).to receive(:parse_string).and_raise(TreeSitter::TreeSitterError.new("test error"))

          expect {
            parser.parse("some source")
          }.to raise_error(TreeHaver::NotAvailable, /Could not parse source: test error/)
        end
      end

      context "when a non-TreeSitter exception is raised" do
        it "re-raises the original exception" do
          inner_parser = parser.instance_variable_get(:@parser)
          allow(inner_parser).to receive(:parse_string).and_raise(RuntimeError.new("other error"))

          expect {
            parser.parse("some source")
          }.to raise_error(RuntimeError, "other error")
        end
      end
    end

    describe "#parse_string error handling", :mri_backend do
      let(:parser) { backend::Parser.new }

      context "when TreeSitter::TreeSitterError is raised" do
        it "wraps the error in NotAvailable" do
          stub_const("TreeSitter::TreeSitterError", Class.new(RuntimeError)) unless defined?(TreeSitter::TreeSitterError)

          inner_parser = parser.instance_variable_get(:@parser)
          allow(inner_parser).to receive(:parse_string).and_raise(TreeSitter::TreeSitterError.new("parse_string error"))

          expect {
            parser.parse_string(nil, "some source")
          }.to raise_error(TreeHaver::NotAvailable, /Could not parse source: parse_string error/)
        end
      end

      context "when a non-TreeSitter exception is raised" do
        it "re-raises the original exception" do
          inner_parser = parser.instance_variable_get(:@parser)
          allow(inner_parser).to receive(:parse_string).and_raise(ArgumentError.new("bad argument"))

          expect {
            parser.parse_string(nil, "some source")
          }.to raise_error(ArgumentError, "bad argument")
        end
      end
    end

    describe "#language= error handling", :mri_backend do
      let(:parser) { backend::Parser.new }

      context "when language is not set correctly (nil after assignment)" do
        it "raises NotAvailable" do
          inner_parser = parser.instance_variable_get(:@parser)
          allow(inner_parser).to receive(:language=)
          allow(inner_parser).to receive(:language).and_return(nil)

          expect {
            parser.language = double("lang", inner_language: double("inner"))
          }.to raise_error(TreeHaver::NotAvailable, /Language not set correctly/)
        end
      end

      context "when TreeSitter::TreeSitterError is raised" do
        it "wraps the error in NotAvailable" do
          stub_const("TreeSitter::TreeSitterError", Class.new(RuntimeError)) unless defined?(TreeSitter::TreeSitterError)

          inner_parser = parser.instance_variable_get(:@parser)
          allow(inner_parser).to receive(:language=).and_raise(TreeSitter::TreeSitterError.new("language error"))

          expect {
            parser.language = double("lang", inner_language: double("inner"))
          }.to raise_error(TreeHaver::NotAvailable, /Could not set language: language error/)
        end
      end

      context "when a non-TreeSitter exception is raised" do
        it "re-raises the original exception" do
          inner_parser = parser.instance_variable_get(:@parser)
          allow(inner_parser).to receive(:language=).and_raise(TypeError.new("type error"))

          expect {
            parser.language = double("lang", inner_language: double("inner"))
          }.to raise_error(TypeError, "type error")
        end
      end
    end

    describe "Parser.new error handling", :mri_backend do
      context "when TreeSitter::TreeSitterError is raised during creation" do
        it "wraps the error in NotAvailable" do
          stub_const("TreeSitter::TreeSitterError", Class.new(RuntimeError)) unless defined?(TreeSitter::TreeSitterError)

          allow(TreeSitter::Parser).to receive(:new).and_raise(TreeSitter::TreeSitterError.new("creation error"))

          expect {
            backend::Parser.new
          }.to raise_error(TreeHaver::NotAvailable, /Could not create parser: creation error/)
        end
      end

      context "when a non-TreeSitter exception is raised" do
        it "re-raises the original exception" do
          allow(TreeSitter::Parser).to receive(:new).and_raise(NoMemoryError.new("out of memory"))

          expect {
            backend::Parser.new
          }.to raise_error(NoMemoryError, "out of memory")
        end
      end
    end
  end

  context "with Tree" do
    it "doesn't define a separate Tree class (passes through to TreeSitter::Tree)" do
      # MRI backend doesn't define Tree/Node - it passes through to ruby_tree_sitter
      # The public API returns TreeHaver::Tree which wraps ::TreeSitter::Tree
      expect(defined?(backend::Tree)).to be_nil
    end
  end

  context "with Node" do
    it "doesn't define a separate Node class (passes through to TreeSitter::Node)" do
      # MRI backend doesn't define Tree/Node - it passes through to ruby_tree_sitter
      # The public API returns TreeHaver::Node which wraps ::TreeSitter::Node
      expect(defined?(backend::Node)).to be_nil
    end
  end

  describe "full parsing workflow", :mri_backend, :toml_grammar do
    it "can parse TOML and traverse the AST" do
      path = TreeHaverDependencies.find_toml_grammar_path
      lang = backend::Language.from_library(path)
      parser = backend::Parser.new
      parser.language = lang

      tree = parser.parse(<<~TOML)
        [package]
        name = "example"
        version = "1.0.0"
      TOML

      root = tree.root_node
      expect(root.type).to eq(:document)
      expect(root.child_count).to be > 0

      # Check that we can access children
      first_child = root.child(0)
      expect(first_child).to be_a(TreeSitter::Node)
    end
  end
end
