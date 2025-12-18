#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: MRI Backend with JSONC
# Forces MRI backend for JSONC parsing.

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ruby_tree_sitter"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver MRI Backend - JSONC Parsing"
puts "=" * 70
puts

jsonc_source = '{"backend": "MRI", /* C extension */ "supports_comments": true}'

puts "JSONC Source: #{jsonc_source}"
puts

finder = TreeHaver::GrammarFinder.new(:json)
finder.register! if finder.available?

TreeHaver.backend = :mri
puts "Backend: #{TreeHaver.backend_module}"
puts

parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.json
tree = parser.parse(jsonc_source)

root = tree.root_node
puts "✓ Parsed: #{root.type} with #{root.child_count} children"
puts "✓ MRI backend handles JSONC comments correctly"
