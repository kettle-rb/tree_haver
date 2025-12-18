#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: FFI Backend with JSON
#
# Forces the FFI backend (Ruby FFI calling libtree-sitter directly).
# Most portable option - works on MRI, JRuby, TruffleRuby.

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

json_source = '{"backend": "FFI", "portable": true, "ruby_impls": ["MRI", "JRuby", "TruffleRuby"]}'

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

# Show structure
root.children.each_with_index do |child, i|
  puts "Child #{i}: #{child.type}"
end
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
