#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Using TreeHaver with TOML-RB Citrus Grammar
#
# This demonstrates how tree_haver's Citrus backend provides a pure Ruby
# fallback for TOML parsing using toml-rb when tree-sitter-toml is unavailable.
#
# toml-rb gem: https://github.com/emancu/toml-rb
# TOML spec: https://toml.io/

require "bundler/inline"

gemfile do
  source "https://gem.coop"

  # Load tree_haver from local path
  gem "tree_haver", path: File.expand_path("..", __dir__)

  # TOML parser with Citrus grammar
  gem "toml-rb", "~> 4.1"

  gem "citrus"
end

require "tree_haver"
require "toml-rb"

puts "=" * 70
puts "TreeHaver + TOML-RB (Citrus Grammar) Example"
puts "=" * 70
puts

# Example TOML configuration
toml_source = <<~TOML
  # Application configuration
  [database]
  host = "localhost"
  port = 5432
  username = "admin"
  
  [server]
  bind = "0.0.0.0"
  port = 8080
  workers = 4
  
  [[services]]
  name = "api"
  enabled = true
  
  [[services]]
  name = "worker"
  enabled = false
TOML

puts "TOML Source:"
puts "-" * 70
puts toml_source
puts

# Register TOML-RB's Citrus grammar with TreeHaver
puts "Registering TOML grammar with TreeHaver..."
TreeHaver.register_language(
  :toml,
  grammar_module: TomlRB::Document,
  gem_name: "toml-rb",
)
puts "✓ Registered"
puts

# Force Citrus backend (pure Ruby parsing)
puts "Setting backend to Citrus (pure Ruby)..."
TreeHaver.backend = :citrus
puts "✓ Backend: #{TreeHaver.backend_module}"
puts "✓ This is 100% pure Ruby - no native extensions!"
puts

# Parse the TOML source
puts "Parsing TOML source with TreeHaver..."
parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.toml
tree = parser.parse(toml_source)
puts "✓ Parsed successfully"
puts

# Explore the AST
root = tree.root_node
puts "Root Node:"
puts "  Type: #{root.type}"
puts "  Structural?: #{root.structural?}"
puts "  Children: #{root.child_count}"
puts

# Helper to display node tree
def show_tree(node, indent = 0, max_depth = 3)
  return if indent > max_depth

  prefix = "  " * indent
  marker = node.structural? ? "📦" : "🔤"

  # Show node info
  text_preview = node.text[0..40].gsub("\n", "\\n")
  puts "#{prefix}#{marker} #{node.type}: #{text_preview.inspect}"

  # Recurse into children (limit to avoid too much output)
  if node.child_count > 0 && node.child_count < 15
    node.children.each { |child| show_tree(child, indent + 1, max_depth) }
  elsif node.child_count > 0
    puts "#{prefix}  ... #{node.child_count} children ..."
  end
end

puts "AST Structure (first 3 levels):"
puts "-" * 70
show_tree(root)
puts

# Row number validation
puts "=== Row Number Validation ==="
row_errors = []

puts "Checking structural nodes for position info:"
i = 0
root.each do |child|
  next unless child.structural?

  if child.respond_to?(:start_point)
    start_row = child.start_point.row
    end_row = child.end_point.row
    puts "  Node #{i}: #{child.type} - rows #{start_row}-#{end_row}"

    # For multiline TOML, tables should have different start rows
    if child.type.to_s == "table" && child.to_s.include?("[server]")
      if start_row == 0
        row_errors << "[server] table has start_row=0, expected row > 0"
      end
    end
  else
    puts "  Node #{i}: #{child.type} - position info not available (Citrus nodes)"
  end

  i += 1
end

puts
if row_errors.empty?
  puts "✓ Row numbers look correct (or not applicable for Citrus backend)"
else
  puts "✗ Row number issues detected:"
  row_errors.each { |err| puts "  - #{err}" }
  exit 1
end
puts

# Find structural nodes (filtering out whitespace)
structural_nodes = []
root.children.each do |child|
  if child.structural? && !["space", "line_break"].include?(child.type)
    structural_nodes << child
  end
end

puts "Structural Nodes (excluding whitespace):"
puts "-" * 70
structural_nodes.each do |node|
  text = node.text.strip.tr("\n", " ")[0..60]
  puts "  • #{node.type}: #{text.inspect}"
end
puts

# Find all tables
puts "TOML Tables:"
puts "-" * 70
def find_nodes_by_type(node, type_name, results = [])
  results << node if node.type == type_name
  node.children.each { |child| find_nodes_by_type(child, type_name, results) }
  results
end

tables = find_nodes_by_type(root, "table")
table_arrays = find_nodes_by_type(root, "table_array")

tables.each do |table|
  puts "  [section] #{table.text[0..40].delete("\n")}"
end

table_arrays.each do |array|
  puts "  [[array]] #{array.text[0..40].delete("\n")}"
end
puts

# Find all key-value pairs
puts "Key-Value Pairs:"
puts "-" * 70
keyvalues = find_nodes_by_type(root, "keyvalue")
keyvalues.each do |kv|
  puts "  • #{kv.text.strip}"
end
puts

# Demonstrate the advantage of Citrus backend
puts "=" * 70
puts "Why Use Citrus Backend?"
puts "=" * 70
puts "1. Pure Ruby - works on any platform without native extensions"
puts "2. No compilation needed - perfect for development"
puts "3. Works on JRuby, TruffleRuby, and other Ruby implementations"
puts "4. Useful when tree-sitter-toml native library isn't available"
puts "5. Same TreeHaver API as tree-sitter backends"
puts
puts "Trade-offs:"
puts "  - Slower than native tree-sitter (but still fast enough for most uses)"
puts "  - Uses more memory (Ruby objects vs C structs)"
puts
puts "Best practice:"
puts "  - Use tree-sitter when available (fast)"
puts "  - Automatic fallback to Citrus when tree-sitter unavailable"
puts "  - tree_haver makes this transparent to your application!"
puts "=" * 70
