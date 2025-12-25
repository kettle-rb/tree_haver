#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: FFI Backend with JSON
#
# Forces the FFI backend (Ruby FFI calling libtree-sitter directly).
# Most portable option - works on MRI, JRuby, TruffleRuby.
# Includes row number validation to verify line tracking works correctly.

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ffi"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver FFI Backend - JSON Parsing"
puts "=" * 70
puts

# Multiline source for row number testing
json_source = <<~JSON
  {
    "backend": "FFI",
    "portable": true,
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

# Force FFI backend
TreeHaver.backend = :ffi
puts "Backend: #{TreeHaver.backend_module}"
puts "Capabilities: #{TreeHaver.capabilities.inspect}"
puts "Ruby Engine: #{RUBY_ENGINE}"
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
  puts "FFI Backend:"
  puts "  - Uses Ruby FFI gem"
  puts "  - Calls libtree-sitter directly via FFI"
  puts "  - Works on MRI, JRuby, TruffleRuby"
  puts "  - Most portable option"
  puts "  - Good performance (slightly slower than native)"
  puts "  - Dynamic linking avoids version conflicts"
  puts "=" * 70
else
  puts "✗ Row number issues detected:"
  row_errors.each { |err| puts "  - #{err}" }
  exit 1
end
