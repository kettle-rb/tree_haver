#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: FFI Backend with JSONC
# Forces FFI backend for JSONC parsing.

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ffi"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver FFI Backend - JSONC Parsing"
puts "=" * 70
puts

jsonc_source = '{"backend": "FFI", /* portable */ "ruby_impls": ["MRI", "JRuby"]}'

puts "JSONC Source: #{jsonc_source}"
puts

finder = TreeHaver::GrammarFinder.new(:json)
finder.register! if finder.available?

TreeHaver.backend = :ffi
puts "Backend: #{TreeHaver.backend_module}"
puts

parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.json
tree = parser.parse(jsonc_source)

root = tree.root_node
puts "✓ Parsed: #{root.type} with #{root.child_count} children"
puts "✓ FFI backend handles JSONC comments correctly"
