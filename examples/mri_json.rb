#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: MRI Backend with JSON
#
# Forces the MRI backend (ruby_tree_sitter C extension).
# This is the fastest backend for MRI Ruby.

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ruby_tree_sitter"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver MRI Backend - JSON Parsing"
puts "=" * 70
puts

json_source = '{"backend": "MRI", "speed": "fastest", "type": "C extension"}'

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
puts "Parsed: #{root.type} with #{root.child_count} children"
puts

# Show structure
root.children.each_with_index do |child, i|
  puts "Child #{i}: #{child.type}"
end
puts

puts "=" * 70
puts "MRI Backend:"
puts "  - Uses ruby_tree_sitter gem (C extension)"
puts "  - Fastest option for MRI Ruby"
puts "  - Direct bindings to libtree-sitter"
puts "  - Best for performance-critical applications"
puts "=" * 70

