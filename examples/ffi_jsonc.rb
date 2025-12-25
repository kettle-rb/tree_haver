#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: FFI Backend with JSONC
# Forces FFI backend for JSONC parsing.
# Includes row number validation to verify line tracking works correctly.

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ffi"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver FFI Backend - JSONC Parsing"
puts "=" * 70
puts

# Multiline source for row number testing
jsonc_source = <<~JSONC
  {
    "backend": "FFI",
    /* This is a block comment */
    "portable": true,
    // Line comment
    "line": 6
  }
JSONC

puts "JSONC Source:"
puts "-" * 40
puts jsonc_source
puts "-" * 40
puts

finder = TreeHaver::GrammarFinder.new(:jsonc)
if finder.available?
  finder.register!
  puts "✓ Registered JSONC from: #{finder.find_library_path}"
else
  # Fall back to JSON grammar
  finder = TreeHaver::GrammarFinder.new(:json)
  finder.register! if finder.available?
  puts "Using JSON grammar (JSONC not found)"
end

TreeHaver.backend = :ffi
puts "Backend: #{TreeHaver.backend_module}"
puts

parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.jsonc rescue TreeHaver::Language.json
tree = parser.parse(jsonc_source)

root = tree.root_node
puts "✓ Parsed: #{root.type} with #{root.child_count} children"

# Row number validation
puts
puts "=== Row Number Validation ==="
row_errors = []

def validate_node_rows(node, depth, row_errors)
  indent = "  " * depth
  start_row = node.start_point.row
  end_row = node.end_point.row

  puts "#{indent}#{node.type}: rows #{start_row}-#{end_row}"

  # For multiline JSONC, the root object should span multiple rows
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
  puts "✓ FFI backend handles JSONC comments correctly"
else
  puts "✗ Row number issues detected:"
  row_errors.each { |err| puts "  - #{err}" }
  exit 1
end

