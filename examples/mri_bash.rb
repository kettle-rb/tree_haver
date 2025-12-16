#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: MRI Backend with Bash
# Forces MRI backend for Bash parsing.

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ruby_tree_sitter"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver MRI Backend - Bash Parsing"
puts "=" * 70
puts

bash_source = '#!/bin/bash\necho "MRI backend"\nexit 0'

puts "Bash Source:\n#{bash_source}"
puts

finder = TreeHaver::GrammarFinder.new(:bash)
if finder.available?
  finder.register!
  puts "✓ Registered from: #{finder.find_library_path}"
else
  puts "✗ bash grammar not found"
  puts finder.not_found_message
  exit 1
end

TreeHaver.backend = :mri
puts "Backend: #{TreeHaver.backend_module}"
puts

parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.bash
tree = parser.parse(bash_source)

root = tree.root_node
puts "✓ Parsed: #{root.type} with #{root.child_count} children"
puts "✓ MRI backend - fastest for shell script analysis"
