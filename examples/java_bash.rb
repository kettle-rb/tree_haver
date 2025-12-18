#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Java Backend with Bash
# Forces Java backend for Bash parsing (JRuby only).

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
end

require "tree_haver"

unless RUBY_ENGINE == "jruby"
  puts "⚠️  This example requires JRuby"
  puts "Current engine: #{RUBY_ENGINE}"
  exit 1
end

puts "=" * 70
puts "TreeHaver Java Backend - Bash Parsing (JRuby)"
puts "=" * 70
puts

bash_source = '#!/bin/bash\necho "Java backend on JRuby"\nexit 0'

puts "Bash Source:\n#{bash_source}"
puts

finder = TreeHaver::GrammarFinder.new(:bash)
finder.register! if finder.available?

TreeHaver.backend = :java
puts "Backend: #{TreeHaver.backend_module}"
puts "Ruby Engine: #{RUBY_ENGINE}"
puts

parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.bash
tree = parser.parse(bash_source)

root = tree.root_node
puts "✓ Parsed: #{root.type} with #{root.child_count} children"
puts "✓ Java backend - optimal for JRuby shell script tools"
