#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: FFI Backend with TOML
#
# Forces the FFI backend (Ruby FFI calling libtree-sitter directly).
# Most portable option - works on MRI, JRuby, TruffleRuby.

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ffi"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver FFI Backend - TOML Parsing"
puts "=" * 70
puts

toml_source = <<~TOML
  [package]
  name = "tree_haver"
  version = "3.0.0"
  
  [features]
  ffi_backend = true
  portable = true
TOML

puts "TOML Source:"
puts "-" * 70
puts toml_source
puts

# Register TOML
puts "Registering TOML grammar..."
finder = TreeHaver::GrammarFinder.new(:toml)
if finder.available?
  finder.register!
  puts "✓ Registered from: #{finder.find_library_path}"
else
  puts "✗ tree-sitter-toml not found"
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
parser.language = TreeHaver::Language.toml
tree = parser.parse(toml_source)

root = tree.root_node
puts "✓ Parsed: #{root.type} with #{root.child_count} children"
puts

# Show structure
puts "Top-level nodes:"
root.children.each do |child|
  puts "  • #{child.type}: #{child.text[0..40].gsub("\n", "\\n")}..."
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
