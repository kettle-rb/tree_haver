# frozen_string_literal: true

require "spec_helper"

# Integration tests verifying all backends conform to the TreeHaver API
#
# This spec uses shared examples to ensure consistent behavior across all backends.
# Each backend is tested for:
# - Backend module API (available?, capabilities, reset!)
# - Language API (backend, comparison)
# - Parser API (parse, parse_string)
# - Tree API (root_node, source, errors)
# - Node API (type, start_byte, end_byte, children, positions)

RSpec.describe "Backend API Compliance" do
  describe "Citrus Backend", :citrus_backend do
    let(:backend) { TreeHaver::Backends::Citrus }

    before do
      TreeHaver.backend = :citrus
    end

    it_behaves_like "backend module api"

    describe "with TOML language", :toml_rb_gem do
      let(:language_class) { backend::Language }
      let(:language) { language_class.new(TomlRB::Document) }
      let(:same_language) { language_class.new(TomlRB::Document) }
      let(:different_language) do
        # Create a mock different grammar
        mock_grammar = Module.new do
          class << self
            def parse(_)
            end
          end
        end
        language_class.new(mock_grammar)
      end

      it_behaves_like "language api compliance"
      it_behaves_like "language comparison"

      describe "Parser" do
        let(:parser) do
          p = backend::Parser.new
          p.language = language  # Use Language wrapper (normalized pattern)
          p
        end
        let(:simple_source) { "key = \"value\"" }
        let(:modified_source) { 'key = "new_value"' }
        let(:invalid_source) { "[unclosed" }

        it_behaves_like "parser api compliance"
      end

      describe "Tree" do
        let(:parser) do
          p = backend::Parser.new
          p.language = language  # Use Language wrapper (normalized pattern)
          p
        end
        let(:source) { "[section]\nkey = \"value\"\nother = 123" }
        let(:tree) { parser.parse(source) }
        let(:valid_tree) { tree }

        it_behaves_like "tree api compliance"
        it_behaves_like "tree traversal"
      end

      describe "Node" do
        let(:parser) do
          p = backend::Parser.new
          p.language = language  # Use Language wrapper (normalized pattern)
          p
        end
        let(:source) { "[section]\nkey = \"value\"\nother = 123" }
        let(:tree) { parser.parse(source) }
        let(:node) { tree.root_node }
        let(:node_with_children) { tree.root_node }

        it_behaves_like "node api compliance"
        it_behaves_like "node position api"
        it_behaves_like "node children api"
        it_behaves_like "node enumerable behavior"
        it_behaves_like "node text extraction"
        it_behaves_like "node inspection"
      end

      describe "Backend Integration" do
        let(:create_parser) do
          -> {
            p = backend::Parser.new
            p.language = language  # Use Language wrapper (normalized pattern)
            p
          }
        end
        let(:simple_source) { 'key = "value"' }
        let(:expected_root_type) { /document|root/i }

        it_behaves_like "backend integration"
      end
    end
  end

  describe "Parslet Backend", :parslet_backend do
    let(:backend) { TreeHaver::Backends::Parslet }

    it_behaves_like "backend module api"

    describe "with TOML language", :toml_gem do
      let(:language_class) { backend::Language }
      let(:language) { language_class.new(TOML::Parslet) }
      let(:same_language) { language_class.new(TOML::Parslet) }
      let(:different_language) do
        mock_grammar = Class.new do
          def initialize
          end

          def parse(_)
            {}
          end
        end
        language_class.new(mock_grammar)
      end

      it_behaves_like "language api compliance"
      it_behaves_like "language comparison"

      describe "Parser" do
        let(:parser) do
          p = backend::Parser.new
          p.language = language  # Use Language wrapper (normalized pattern)
          p
        end
        # toml gem requires trailing newline
        let(:simple_source) { "[section]\nkey = \"value\"\n" }
        let(:modified_source) { "[section]\nkey = \"new_value\"\n" }

        it_behaves_like "parser api compliance"
      end

      describe "Tree" do
        let(:parser) do
          p = backend::Parser.new
          p.language = language  # Use Language wrapper (normalized pattern)
          p
        end
        # toml gem requires trailing newline
        let(:source) { "[database]\nhost = \"localhost\"\nport = 5432\n" }
        let(:tree) { parser.parse(source) }
        let(:valid_tree) { tree }

        it_behaves_like "tree api compliance"
        it_behaves_like "tree traversal"
      end

      describe "Node" do
        let(:parser) do
          p = backend::Parser.new
          p.language = language  # Use Language wrapper (normalized pattern)
          p
        end
        # toml gem requires trailing newline
        let(:source) { "[database]\nhost = \"localhost\"\nport = 5432\n" }
        let(:tree) { parser.parse(source) }
        let(:node) { tree.root_node }
        let(:node_with_children) { tree.root_node }

        it_behaves_like "node api compliance"
        it_behaves_like "node position api"
        it_behaves_like "node children api"
        it_behaves_like "node enumerable behavior"
        it_behaves_like "node inspection"
      end
    end
  end

  describe "Prism Backend", :prism_backend do
    let(:backend) { TreeHaver::Backends::Prism }

    it_behaves_like "backend module api"

    describe "with Ruby language" do
      let(:language_class) { backend::Language }
      let(:language) { language_class.ruby }
      let(:same_language) { language_class.ruby }
      let(:different_language) { language_class.ruby(frozen_string_literal: true) }

      it_behaves_like "language api compliance"

      describe "Parser" do
        let(:parser) do
          p = backend::Parser.new
          p.language = language
          p
        end
        let(:simple_source) { "puts 'hello'" }
        let(:modified_source) { "puts 'world'" }
        let(:invalid_source) { "def foo(" }

        it_behaves_like "parser api compliance"
        it_behaves_like "parser error handling"
      end

      describe "Tree" do
        let(:parser) do
          p = backend::Parser.new
          p.language = language
          p
        end
        let(:source) { "def hello; puts 'hi'; end" }
        let(:tree) { parser.parse(source) }
        let(:valid_tree) { tree }
        let(:invalid_tree) { parser.parse("def foo(") }

        it_behaves_like "tree api compliance"
        it_behaves_like "tree error handling"
        it_behaves_like "tree traversal"
      end

      describe "Node" do
        let(:parser) do
          p = backend::Parser.new
          p.language = language
          p
        end
        let(:source) { "def hello(name); puts name; end" }
        let(:tree) { parser.parse(source) }
        let(:node) { tree.root_node }
        let(:node_with_children) { tree.root_node }

        it_behaves_like "node api compliance"
        it_behaves_like "node position api"
        it_behaves_like "node children api"
        it_behaves_like "node enumerable behavior"
        it_behaves_like "node text extraction"
        it_behaves_like "node inspection"
      end

      describe "Backend Integration" do
        let(:create_parser) do
          -> {
            p = backend::Parser.new
            p.language = language
            p
          }
        end
        let(:simple_source) { "puts 'hello'" }
        let(:expected_root_type) { "program_node" }

        it_behaves_like "backend integration"
      end
    end
  end

  describe "Psych Backend", :psych_backend do
    let(:backend) { TreeHaver::Backends::Psych }

    it_behaves_like "backend module api"

    describe "with YAML language" do
      let(:language_class) { backend::Language }
      let(:language) { language_class.yaml }
      let(:same_language) { language_class.yaml }
      let(:different_language) { language_class.yaml(symbolize_names: true) }

      it_behaves_like "language api compliance"

      describe "Parser" do
        let(:parser) do
          p = backend::Parser.new
          p.language = language
          p
        end
        let(:simple_source) { "key: value" }
        let(:modified_source) { "key: new_value" }

        it_behaves_like "parser api compliance"
      end

      describe "Tree" do
        let(:parser) do
          p = backend::Parser.new
          p.language = language
          p
        end
        let(:source) { "section:\n  key: value\n  other: 123" }
        let(:tree) { parser.parse(source) }
        let(:valid_tree) { tree }

        it_behaves_like "tree api compliance"
        it_behaves_like "tree traversal"
      end

      describe "Node" do
        let(:parser) do
          p = backend::Parser.new
          p.language = language
          p
        end
        let(:source) { "section:\n  key: value\n  other: 123" }
        let(:tree) { parser.parse(source) }
        let(:node) { tree.root_node }
        let(:node_with_children) { tree.root_node }

        it_behaves_like "node api compliance"
        it_behaves_like "node position api"
        it_behaves_like "node children api"
        it_behaves_like "node enumerable behavior"
        it_behaves_like "node inspection"
      end

      describe "Backend Integration" do
        let(:create_parser) do
          -> {
            p = backend::Parser.new
            p.language = language
            p
          }
        end
        let(:simple_source) { "key: value" }
        let(:expected_root_type) { /document|stream|mapping/i }

        it_behaves_like "backend integration"
      end
    end
  end

  describe "MRI Backend", :mri_backend, :toml_grammar do
    let(:backend) { TreeHaver::Backends::MRI }

    it_behaves_like "backend module api"

    describe "with TOML language" do
      let(:language_class) { backend::Language }
      let(:toml_path) { TreeHaverDependencies.find_toml_grammar_path }
      let(:language) { language_class.from_library(toml_path) }
      let(:same_language) { language_class.from_library(toml_path) }
      # MRI languages are compared by path, so same path = same language
      # Create different by using a mock (can't easily get different grammar)
      let(:different_language) { language } # Same for now

      it_behaves_like "language api compliance"

      describe "Parser (via TreeHaver::Parser wrapper)" do
        let(:parser) do
          TreeHaver.backend = :mri
          p = TreeHaver::Parser.new
          p.language = TreeHaver::Language.from_path(toml_path)
          p
        end
        let(:simple_source) { "key = \"value\"\n" }
        let(:modified_source) { "key = \"new_value\"\n" }
        let(:invalid_source) { "[unclosed\n" }

        it_behaves_like "parser api compliance"
        it_behaves_like "parser incremental parsing"
        it_behaves_like "parser error handling"
      end

      describe "Tree (via TreeHaver::Tree wrapper)" do
        let(:parser) do
          TreeHaver.backend = :mri
          p = TreeHaver::Parser.new
          p.language = TreeHaver::Language.from_path(toml_path)
          p
        end
        let(:source) { "[section]\nkey = \"value\"\nother = 123\n" }
        let(:tree) { parser.parse(source) }
        let(:valid_tree) { tree }
        let(:invalid_tree) { parser.parse("[unclosed\n") }

        it_behaves_like "tree api compliance"
        it_behaves_like "tree error handling"
        it_behaves_like "tree traversal"
      end

      describe "Node (via TreeHaver::Node wrapper)" do
        let(:parser) do
          TreeHaver.backend = :mri
          p = TreeHaver::Parser.new
          p.language = TreeHaver::Language.from_path(toml_path)
          p
        end
        let(:source) { "[section]\nkey = \"value\"\nother = 123\n" }
        let(:tree) { parser.parse(source) }
        let(:node) { tree.root_node }
        let(:node_with_children) { tree.root_node }

        it_behaves_like "node api compliance"
        it_behaves_like "node position api"
        it_behaves_like "node children api"
        it_behaves_like "node enumerable behavior"
        it_behaves_like "node text extraction"
        it_behaves_like "node inspection"
      end
    end
  end

  describe "FFI Backend", :ffi_backend, :toml_grammar do
    let(:backend) { TreeHaver::Backends::FFI }

    it_behaves_like "backend module api"

    describe "with TOML language" do
      let(:language_class) { backend::Language }
      let(:toml_path) { TreeHaverDependencies.find_toml_grammar_path }
      let(:language) { language_class.from_library(toml_path) }
      let(:same_language) { language_class.from_library(toml_path) }
      let(:different_language) { language }

      it_behaves_like "language api compliance"

      describe "Parser (via TreeHaver::Parser wrapper)" do
        let(:parser) do
          TreeHaver.backend = :ffi
          p = TreeHaver::Parser.new
          p.language = TreeHaver::Language.from_path(toml_path)
          p
        end
        let(:simple_source) { "key = \"value\"\n" }
        let(:modified_source) { "key = \"new_value\"\n" }
        let(:invalid_source) { "[unclosed\n" }

        it_behaves_like "parser api compliance"
        it_behaves_like "parser incremental parsing"
        it_behaves_like "parser error handling"
      end

      describe "Tree (via TreeHaver::Tree wrapper)" do
        let(:parser) do
          TreeHaver.backend = :ffi
          p = TreeHaver::Parser.new
          p.language = TreeHaver::Language.from_path(toml_path)
          p
        end
        let(:source) { "[section]\nkey = \"value\"\nother = 123\n" }
        let(:tree) { parser.parse(source) }
        let(:valid_tree) { tree }
        let(:invalid_tree) { parser.parse("[unclosed\n") }

        it_behaves_like "tree api compliance"
        it_behaves_like "tree error handling"
        it_behaves_like "tree traversal"
      end

      describe "Node (via TreeHaver::Node wrapper)" do
        let(:parser) do
          TreeHaver.backend = :ffi
          p = TreeHaver::Parser.new
          p.language = TreeHaver::Language.from_path(toml_path)
          p
        end
        let(:source) { "[section]\nkey = \"value\"\nother = 123\n" }
        let(:tree) { parser.parse(source) }
        let(:node) { tree.root_node }
        let(:node_with_children) { tree.root_node }

        it_behaves_like "node api compliance"
        it_behaves_like "node position api"
        it_behaves_like "node children api"
        it_behaves_like "node enumerable behavior"
        it_behaves_like "node text extraction"
        it_behaves_like "node inspection"
      end
    end
  end
end
