#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Java Backend with Bash
# Forces Java backend for Bash parsing (JRuby only).
# Includes row number validation to verify line tracking works correctly.

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

# Multiline source for row number testing
bash_source = <<~BASH
  #!/bin/bash
  MY_VAR="hello"
  echo "Java backend"
  exit 0
BASH

puts "Bash Source:"
puts "-" * 40
puts bash_source
puts "-" * 40
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

# Row number validation
puts
puts "=== Row Number Validation ==="
row_errors = []

i = 0
root.each do |child|
  start_row = child.start_point.row
  end_row = child.end_point.row
  start_col = child.start_point.column
  end_col = child.end_point.column

  puts "Node #{i}: #{child.type}"
  puts "  start_point: row=#{start_row}, col=#{start_col}"
  puts "  end_point: row=#{end_row}, col=#{end_col}"
  puts "  text: #{child.to_s.inspect[0..50]}"

  # Validate row numbers are reasonable
  if i > 0 && start_row == 0 && child.type.to_s != "comment"
    row_errors << "Node #{i} (#{child.type}) has start_row=0, expected row #{i}"
  end

  i += 1
end

puts
if row_errors.empty?
  puts "✓ Row numbers look correct!"
  puts
  puts "✓ Java backend - optimal for JRuby shell script tools"
else
  puts "✗ Row number issues detected:"
  row_errors.each { |err| puts "  - #{err}" }
  exit 1
end
