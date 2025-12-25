#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Auto Backend Selection with JSONC (JSON with Comments)
#
# JSONC supports comments and trailing commas, commonly used in config files.

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ffi" # FFI backend - most portable
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver Auto Backend - JSONC Parsing"
puts "=" * 70
puts

# JSONC example with comments and trailing comma
jsonc_source = <<~JSONC
  {
    // Application configuration
    "app_name": "TreeHaver",
    "version": "2.0.0",
    
    /* Multi-line comment
       describing features */
    "features": [
      "comments",
      "trailing_commas",
      "relaxed_syntax", // inline comment
    ],
    
    // Nested configuration
    "config": {
      "debug": true,
      "log_level": "info", // trailing comma OK
    }
  }
JSONC

puts "JSONC Source:"
puts "-" * 70
puts jsonc_source
puts

# Register JSON grammar (JSONC uses same grammar)
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

backend = TreeHaver.backend_module
puts "Backend: #{backend}"
puts

# Parse JSONC
parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.json
tree = parser.parse(jsonc_source)
puts "✓ Parsed JSONC successfully"
puts

# Row number validation
puts "=== Row Number Validation ==="
row_errors = []

def validate_jsonc_rows(node, depth, row_errors)
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

  node.each { |child| validate_jsonc_rows(child, depth + 1, row_errors) } if depth < 2
end

validate_jsonc_rows(tree.root_node, 0, row_errors)

puts
if row_errors.empty?
  puts "✓ Row numbers look correct!"
else
  puts "✗ Row number issues detected:"
  row_errors.each { |err| puts "  - #{err}" }
  exit 1
end
puts

# Find comments
def find_comments(node, results = [])
  results << node if node.type == "comment"
  node.children.each { |child| find_comments(child, results) }
  results
end

comments = find_comments(tree.root_node)
puts "Comments Found: #{comments.count}"
comments.each do |comment|
  text = comment.text.strip
  puts "  • #{text[0..60]}"
end
puts

puts "=" * 70
puts "JSONC vs JSON:"
puts "  ✓ Supports // and /* */ comments"
puts "  ✓ Allows trailing commas in arrays/objects"
puts "  ✓ Same tree-sitter grammar handles both"
puts "  ✓ Commonly used in: VSCode settings, tsconfig.json, etc."
puts "=" * 70
