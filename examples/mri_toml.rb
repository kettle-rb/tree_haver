#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: MRI Backend with TOML
# Forces MRI backend for TOML parsing.
#
# TOML spec: https://toml.io/

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ruby_tree_sitter"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver MRI Backend - TOML Parsing"
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

# Register JSON
puts "Registering JSON grammar..."
finder = TreeHaver::GrammarFinder.new(:toml)
if finder.available?
  finder.register!
  puts "✓ Registered from: #{finder.find_library_path}"
else
  puts "✗ tree-sitter-toml not found"
  puts finder.not_found_message
  exit 1
end
puts "✓ Registered"
puts

# Force MRI backend (C Extensions)
puts "Setting backend to MRI (C Extensions)..."
TreeHaver.backend = :mri
puts "✓ Backend: #{TreeHaver.backend_module}"
puts "✓ Capabilities: #{TreeHaver.capabilities.inspect}"
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

puts "✓ Parsed: #{root.type} with #{root.child_count} children"
puts "✓ MRI backend handles TOML comments correctly"
