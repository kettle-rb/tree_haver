#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Rust Backend with JSON
#
# Forces the Rust backend (tree_stump gem with precompiled binaries).
# Very fast and includes precompiled binaries for common platforms.
#
# NOTE: The Rust backend may have version compatibility issues with system
# tree-sitter libraries. Unlike FFI which uses dynamic linking, tree_stump
# statically links a specific version of tree-sitter at compile time.
# If your system tree-sitter-json.so was built with a different version,
# you may encounter incompatibility errors. This is insurmountable without
# rebuilding tree_stump or tree-sitter-json for matching versions.

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "tree_stump"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver Rust Backend - JSON Parsing"
puts "=" * 70
puts

json_source = '{"backend": "Rust", "speed": "very fast", "precompiled": true}'

puts "JSON Source: #{json_source}"
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

  # Show structure
  root.children.each_with_index do |child, i|
    puts "Child #{i}: #{child.type}"
  end
  puts

  puts "=" * 70
  puts "Rust Backend:"
  puts "  - Uses tree_stump gem (Rust extension)"
  puts "  - Very fast performance"
  puts "  - Includes precompiled binaries"
  puts "  - No compilation needed on common platforms"
  puts "=" * 70
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
