#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: MRI Backend with TOML
#
# Forces the MRI backend (ruby_tree_sitter gem).
# Requires MRI Ruby with native C extension support.

# Check Ruby implementation
unless RUBY_ENGINE == "ruby"
  puts "⚠️  MRI backend requires MRI Ruby (CRuby)"
  puts "Current Ruby: #{RUBY_ENGINE} #{RUBY_VERSION}"
  puts "Run with MRI Ruby"
  exit 1
end

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ruby_tree_sitter"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver MRI Backend - TOML Parsing"
puts "=" * 70
puts

toml_source = <<~TOML
  [package]
  name = "tree_haver"
  version = "3.0.0"
  
  [features]
  mri_backend = true
  native = true
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

# Force MRI backend
TreeHaver.backend = :mri
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
puts "MRI Backend:"
puts "  - Uses ruby_tree_sitter gem (C extension)"
puts "  - Fastest performance (native)"
puts "  - MRI only (C extension)"
puts "  - Requires tree-sitter development headers"
puts "=" * 70
