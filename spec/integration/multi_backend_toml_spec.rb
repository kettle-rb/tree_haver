# frozen_string_literal: true

require "spec_helper"

# Multi-backend TOML parsing tests
#
# This spec runs the same tests against all available TOML backends
# to ensure consistent behavior across tree-sitter and Citrus implementations.
RSpec.describe "TOML parsing across backends" do
  # Tree-sitter backend tests - requires native backend and toml grammar
  context "with tree-sitter-toml backend", :native_parsing do
    # Let TreeHaver pick the best available native backend
    let(:parser) { TreeHaver.parser_for(:toml) }

    it_behaves_like "toml parsing basics"
    it_behaves_like "toml node navigation"
  end

  # Citrus backend tests - requires citrus gem and toml-rb
  context "with Citrus/toml-rb backend", :citrus_backend, :toml_rb do
    around do |example|
      TreeHaver.with_backend(:citrus) do
        example.run
      end
    end

    let(:parser) { TreeHaver.parser_for(:toml) }

    it_behaves_like "toml parsing basics"
    it_behaves_like "toml node navigation"
  end

  # Test that both backends produce equivalent results for the same input
  # Only runs when BOTH native tree-sitter AND citrus backends are available
  describe "backend equivalence", :citrus_backend, :native_parsing, :toml_rb do
    let(:source) { "[section]\nkey = \"value\"" }

    # Use auto backend for tree-sitter (will pick best available native backend)
    let(:tree_sitter_parser) { TreeHaver.parser_for(:toml) }

    let(:citrus_parser) do
      TreeHaver.with_backend(:citrus) do
        TreeHaver.parser_for(:toml)
      end
    end

    it "both backends parse successfully" do
      ts_tree = tree_sitter_parser.parse(source)
      citrus_tree = citrus_parser.parse(source)

      expect(ts_tree).not_to be_nil
      expect(citrus_tree).not_to be_nil
      expect(ts_tree.root_node).not_to be_nil
      expect(citrus_tree.root_node).not_to be_nil
    end

    it "both backends report valid byte positions" do
      ts_root = tree_sitter_parser.parse(source).root_node
      citrus_root = citrus_parser.parse(source).root_node

      # Both should have valid byte ranges
      expect(ts_root.start_byte).to be >= 0
      expect(citrus_root.start_byte).to be >= 0
      expect(ts_root.end_byte).to be > ts_root.start_byte
      expect(citrus_root.end_byte).to be > citrus_root.start_byte
    end

    it "both backends report valid line positions" do
      ts_root = tree_sitter_parser.parse(source).root_node
      citrus_root = citrus_parser.parse(source).root_node

      ts_pos = ts_root.source_position
      citrus_pos = citrus_root.source_position

      # Both should have valid positions
      expect(ts_pos[:start_line]).to be >= 1
      expect(citrus_pos[:start_line]).to be >= 1
      expect(ts_pos[:start_column]).to be >= 0
      expect(citrus_pos[:start_column]).to be >= 0
    end
  end
end
