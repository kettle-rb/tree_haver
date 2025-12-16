#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Auto Backend Selection with JSON
#
# This demonstrates tree_haver's automatic backend selection.
# tree_haver will choose the best available backend for your Ruby implementation.

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ffi" # FFI backend - most portable, works on MRI/JRuby/TruffleRuby
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver Auto Backend - JSON Parsing"
puts "=" * 70
puts

# Example JSON
json_source = <<~JSON
  {
    "name": "TreeHaver",
    "version": "2.0.0",
    "description": "Cross-Ruby tree-sitter adapter",
    "features": ["MRI", "Rust", "FFI", "Java", "Citrus"],
    "config": {
      "auto_select": true,
      "backends_available": 5
    }
  }
JSON

puts "JSON Source:"
puts "-" * 70
puts json_source
puts

# Register JSON grammar
puts "Registering JSON grammar..."
finder = TreeHaver::GrammarFinder.new(:json)
if finder.available?
  finder.register!
  puts "✓ Registered from: #{finder.find_library_path}"
else
  puts "✗ tree-sitter-json not found"
  puts finder.not_found_message
  exit 1
end
puts

# Auto backend selection
puts "Backend Selection:"
puts "-" * 70
puts "Mode: auto (best backend for your platform)"
backend = TreeHaver.backend_module
if backend
  puts "Selected: #{backend}"
  puts "Capabilities: #{TreeHaver.capabilities.inspect}"
else
  puts "✗ No backend available"
  exit 1
end
puts

# Parse JSON
puts "Parsing JSON..."
parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.json
tree = parser.parse(json_source)
puts "✓ Parsed successfully"
puts

# Explore AST
root = tree.root_node
puts "Root Node:"
puts "  Type: #{root.type}"
puts "  Children: #{root.child_count}"
puts

# Show tree structure
def show_tree(node, indent = 0, max_depth = 3)
  return if indent > max_depth
  prefix = "  " * indent
  text = node.text[0..40].gsub("\n", "\\n")
  puts "#{prefix}#{node.type}: #{text.inspect}"

  if node.child_count > 0 && node.child_count < 10
    node.children.each { |child| show_tree(child, indent + 1, max_depth) }
  end
end

puts "AST Structure:"
puts "-" * 70
show_tree(root)
puts

# Find all object members
def find_objects(node, results = [])
  results << node if node.type == "object"
  node.children.each { |child| find_objects(child, results) }
  results
end

objects = find_objects(root)
puts "JSON Objects Found: #{objects.count}"
objects.each_with_index do |obj, i|
  puts "  #{i + 1}. #{obj.text[0..50].gsub("\n", " ")}"
end
puts

puts "=" * 70
puts "Auto Backend Benefits:"
puts "=" * 70
puts "✓ Automatically selects fastest available backend"
puts "✓ No manual configuration needed"
puts "✓ Works across MRI, JRuby, TruffleRuby"
puts "✓ Priority: MRI > Rust > FFI > Java > Citrus"
puts "=" * 70

