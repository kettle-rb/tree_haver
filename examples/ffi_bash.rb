#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: FFI Backend with Bash
# Forces FFI backend for Bash parsing.

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ffi"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver FFI Backend - Bash Parsing"
puts "=" * 70
puts

bash_source = '#!/bin/bash\necho "FFI backend - works everywhere"\nexit 0'

puts "Bash Source:\n#{bash_source}"
puts

finder = TreeHaver::GrammarFinder.new(:bash)
finder.register! if finder.available?

TreeHaver.backend = :ffi
puts "Backend: #{TreeHaver.backend_module}"
puts "Ruby Engine: #{RUBY_ENGINE}"
puts

parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.bash
tree = parser.parse(bash_source)

root = tree.root_node
puts "✓ Parsed: #{root.type} with #{root.child_count} children"
puts "✓ FFI backend - portable across MRI, JRuby, TruffleRuby"
