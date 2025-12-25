#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: MRI Backend with JSON
#
# Forces the MRI backend (ruby_tree_sitter C extension).
# This is the fastest backend for MRI Ruby. # Includes row number validation to verify line tracking works correctly.

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ruby_tree_sitter"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver MRI Backend - JSON Parsing"
puts "=" * 70
puts

# Multiline source for row number testing
json_source = <<~JSON
  {
    "backend": "MRI",
    "speed": "fastest",
    "line": 4
  }
JSON

puts "JSON Source:"
puts "-" * 40
puts json_source
puts "-" * 40
puts

# Register JSON
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

# Force MRI backend
TreeHaver.backend = :mri
puts "Backend: #{TreeHaver.backend_module}"
puts "Capabilities: #{TreeHaver.capabilities.inspect}"
puts

# Parse
parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.json
tree = parser.parse(json_source)

root = tree.root_node
puts "✓ Parsed: #{root.type} with #{root.child_count} children"
puts

# Row number validation
puts "=== Row Number Validation ==="
row_errors = []

def validate_node_rows(node, depth, row_errors)
  indent = "  " * depth
  start_row = node.start_point.row
  end_row = node.end_point.row
  start_col = node.start_point.column
  end_col = node.end_point.column

  puts "#{indent}#{node.type}: rows #{start_row}-#{end_row}, cols #{start_col}-#{end_col}"

  # For multiline JSON, the root object should span multiple rows
  if node.type.to_s == "object" && depth == 1
    if end_row == start_row && node.to_s.include?("\n")
      row_errors << "Object spans multiple lines but end_row == start_row (#{end_row})"
    end
  end

  node.each { |child| validate_node_rows(child, depth + 1, row_errors) }
end

validate_node_rows(root, 0, row_errors)

puts
if row_errors.empty?
  puts "✓ Row numbers look correct!"
  puts
  puts "=" * 70
  puts "MRI Backend:"
  puts "  - Uses ruby_tree_sitter gem (C extension)"
  puts "  - Fastest option for MRI Ruby"
  puts "  - Direct bindings to libtree-sitter"
  puts "  - Best for performance-critical applications"
  puts "=" * 70
else
  puts "✗ Row number issues detected:"
  row_errors.each { |err| puts "  - #{err}" }
  exit 1
end
puts "=" * 70
