#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Rust Backend with JSONC
# Forces Rust backend for JSONC parsing.
#
# NOTE: May have version compatibility issues (see rust_json.rb for details)

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "tree_stump"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver Rust Backend - JSONC Parsing"
puts "=" * 70
puts

jsonc_source = '{"backend": "Rust", // inline comment\n"precompiled": true}'

puts "JSONC Source: #{jsonc_source}"
puts

finder = TreeHaver::GrammarFinder.new(:json)
finder.register! if finder.available?

TreeHaver.backend = :rust
puts "Backend: #{TreeHaver.backend_module}"
puts

begin
  parser = TreeHaver::Parser.new
  parser.language = TreeHaver::Language.json
  tree = parser.parse(jsonc_source)

  root = tree.root_node
  puts "✓ Parsed: #{root.type} with #{root.child_count} children"
  puts "✓ Rust backend handles JSONC comments correctly"
rescue => e
  puts "✗ Version compatibility error (see rust_json.rb for details)"
  exit 1
end

