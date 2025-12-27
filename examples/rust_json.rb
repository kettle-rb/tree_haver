#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Rust Backend with JSON
#
# Forces the Rust backend (tree_stump gem with precompiled binaries).
# Very fast and includes precompiled binaries for common platforms.
# Includes row number validation to verify line tracking works correctly.
#
# NOTE: The Rust backend may have version compatibility issues with system
# tree-sitter libraries. Unlike FFI which uses dynamic linking, tree_stump
# statically links a specific version of tree-sitter at compile time.
# If your system tree-sitter-json.so was built with a different version,
# you may encounter incompatibility errors. This is insurmountable without
# rebuilding tree_stump or tree-sitter-json for matching versions.

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "tree_stump"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver Rust Backend - JSON Parsing"
puts "=" * 70
puts

# Multiline source for row number testing
json_source = <<~JSON
  {
    "backend": "Rust",
    "speed": "very fast",
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

# Force Rust backend
TreeHaver.backend = :rust
puts "Backend: #{TreeHaver.backend_module}"
puts "Capabilities: #{TreeHaver.capabilities.inspect}"
puts

# Parse
begin
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
    puts "Rust Backend:"
    puts "  - Uses tree_stump gem (Rust extension)"
    puts "  - Very fast performance"
    puts "  - Includes precompiled binaries"
    puts "  - No compilation needed on common platforms"
    puts "=" * 70
  else
    puts "✗ Row number issues detected:"
    row_errors.each { |err| puts "  - #{err}" }
    exit(1)
  end
rescue => e
  puts "✗ Error: #{e.class}: #{e.message}"
  puts
  puts "=" * 70
  puts "Version Compatibility Issue"
  puts "=" * 70
  puts "The Rust backend statically links tree-sitter at compile time."
  puts "Your system tree-sitter-json.so may be a different version."
  puts
  puts "Solutions:"
  puts "  1. Use FFI backend instead (dynamic linking)"
  puts "  2. Rebuild tree_stump for your tree-sitter version"
  puts "  3. Rebuild tree-sitter-json for tree_stump's version"
  puts "=" * 70
  exit(1)
end
