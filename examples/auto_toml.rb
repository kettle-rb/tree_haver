#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Auto Backend Selection with TOML
#
# This example demonstrates that TreeHaver with backend: :auto will:
# 1. Try tree-sitter-toml first (if available and working)
# 2. Automatically fall back to Citrus/toml-rb if tree-sitter fails
#
# This fallback is transparent - you just use TreeHaver::Language.toml
# and it picks the best available backend.

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ffi" # FFI backend - most portable
  gem "citrus"
  gem "toml-rb"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver Auto Backend - TOML Parsing"
puts "=" * 70
puts

# TOML example
toml_source = <<~TOML
  # Application configuration
  [package]
  name = "tree_haver"
  version = "3.0.0"
  
  [features]
  comments = true
  citrus_fallback = true
  
  [config]
  debug = true
  log_level = "info"
TOML

puts "TOML Source:"
puts "-" * 70
puts toml_source
puts

# Debug: Check current backend
puts "Current backend setting: #{TreeHaver.backend.inspect}"
puts "Backend module: #{TreeHaver.backend_module}"
puts

# Debug: Check tree-sitter availability
puts "Checking tree-sitter-toml availability..."
tree_sitter_finder = TreeHaver::GrammarFinder.new(:toml)
tree_sitter_available = tree_sitter_finder.available?
puts "  tree-sitter-toml available?: #{tree_sitter_available}"
if tree_sitter_available
  puts "  path: #{tree_sitter_finder.find_library_path}"
else
  puts "  #{tree_sitter_finder.not_found_message}"
end
puts

# Debug: Check Citrus/toml-rb availability
puts "Checking toml-rb (Citrus) availability..."
citrus_finder = TreeHaver::CitrusGrammarFinder.new(
  language: :toml,
  gem_name: "toml-rb",
  grammar_const: "TomlRB::Document",
  require_path: "toml-rb",
)
citrus_available = citrus_finder.available?
puts "  toml-rb available?: #{citrus_available}"
if citrus_available
  puts "  grammar_module: #{citrus_finder.grammar_module}"
end
puts

# Register both grammars (like toml-merge does)
# The auto backend will try tree-sitter first, fall back to Citrus if needed
puts "Registering grammars..."
tree_sitter_finder.register! if tree_sitter_available
citrus_finder.register! if citrus_available
puts "  tree-sitter registered: #{tree_sitter_available}"
puts "  citrus registered: #{citrus_available}"
puts

# Debug: Check what's registered
puts "Registered language info for :toml:"
registered = TreeHaver.registered_language(:toml)
puts "  #{registered.inspect}"
puts

# Debug: Check if Language.toml responds
puts "TreeHaver::Language.respond_to?(:toml): #{TreeHaver::Language.respond_to?(:toml)}"
puts

# Try to get the language
puts "Attempting TreeHaver::Language.toml..."
begin
  language = TreeHaver::Language.toml
  puts "✓ Got language: #{language.class}"
  puts "  language details: #{language.inspect[0..100]}..."
rescue => e
  puts "✗ Error: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit(1)
end
puts

# Parse TOML
puts "Parsing TOML..."
parser = TreeHaver::Parser.new
parser.language = language
tree = parser.parse(toml_source)
puts "✓ Parsed TOML successfully"
puts "  root node type: #{tree.root_node.type}"
puts

# Show some structure
puts "Top-level nodes:"
tree.root_node.children.each do |child|
  puts "  • #{child.type}: #{child.text[0..50].gsub("\n", "\\n")}..."
end
puts

puts "=" * 70
puts "Summary:"
puts "  Default backend module: #{TreeHaver.backend_module}"
puts "  Actual parser backend: #{parser.backend}"
puts "  Language type: #{language.class}"
puts "  tree-sitter-toml grammar file: #{tree_sitter_available ? "✓ exists" : "✗ not found"}"
puts "  tree-sitter actually used: #{language.is_a?(TreeHaver::Backends::Citrus::Language) ? "✗ no (fell back to Citrus)" : "✓ yes"}"
puts "  toml-rb (Citrus): #{citrus_available ? "✓ available" : "✗ not available"}"
puts "  Parsing: ✓ successful"
puts "=" * 70
