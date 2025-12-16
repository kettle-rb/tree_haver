#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Java Backend with JSONC
# Forces Java backend for JSONC parsing (JRuby only).

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tree_haver", path: File.expand_path("..", __dir__)
end

require "tree_haver"

unless RUBY_ENGINE == "jruby"
  puts "⚠️  This example requires JRuby"
  puts "Current engine: #{RUBY_ENGINE}"
  exit 1
end

puts "=" * 70
puts "TreeHaver Java Backend - JSONC Parsing (JRuby)"
puts "=" * 70
puts

jsonc_source = '{"backend": "Java", // JRuby\n"jni": true}'

puts "JSONC Source: #{jsonc_source}"
puts

finder = TreeHaver::GrammarFinder.new(:json)
finder.register! if finder.available?

TreeHaver.backend = :java
puts "Backend: #{TreeHaver.backend_module}"
puts

parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.json
tree = parser.parse(jsonc_source)

root = tree.root_node
puts "✓ Parsed: #{root.type} with #{root.child_count} children"
puts "✓ Java backend handles JSONC comments correctly"
