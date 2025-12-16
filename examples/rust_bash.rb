#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Rust Backend with Bash
# Forces Rust backend for Bash parsing.
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
puts "TreeHaver Rust Backend - Bash Parsing"
puts "=" * 70
puts

bash_source = '#!/bin/bash\necho "Rust backend"\nexit 0'

puts "Bash Source:\n#{bash_source}"
puts

finder = TreeHaver::GrammarFinder.new(:bash)
finder.register! if finder.available?

TreeHaver.backend = :rust
puts "Backend: #{TreeHaver.backend_module}"
puts

begin
  parser = TreeHaver::Parser.new
  parser.language = TreeHaver::Language.bash
  tree = parser.parse(bash_source)

  root = tree.root_node
  puts "✓ Parsed: #{root.type} with #{root.child_count} children"
  puts "✓ Rust backend - very fast with precompiled binaries"
rescue
  puts "✗ Version compatibility error"
  puts "The Rust backend statically links tree-sitter at compile time."
  puts "See rust_json.rb for detailed explanation and solutions."
  exit(1)
end
