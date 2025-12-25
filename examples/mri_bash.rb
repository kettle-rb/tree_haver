#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: MRI Backend with Bash
# Forces MRI backend for Bash parsing.
#
# KNOWN ISSUE: MRI backend has ABI incompatibility with some bash grammar versions.
# Use the FFI backend (ffi_bash.rb) if you encounter parsing errors.
# Includes row number validation to verify line tracking works correctly.

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ruby_tree_sitter"
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver MRI Backend - Bash Parsing"
puts "=" * 70
puts

# Multiline source for row number testing
bash_source = <<~BASH
  #!/bin/bash
  MY_VAR="hello"
  echo "MRI backend"
  exit 0
BASH

puts "Bash Source:"
puts "-" * 40
puts bash_source
puts "-" * 40
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
  # For multiline source, nodes should NOT all be on row 0
  if i > 0 && start_row == 0 && child.type.to_s != "comment"
    row_errors << "Node #{i} (#{child.type}) has start_row=0, expected row #{i}"
  end

  i += 1
end

puts
if row_errors.empty?
  puts "✓ Row numbers look correct!"
  puts
  puts "MRI Backend notes:"
  puts "  - Uses ruby_tree_sitter gem (C extension)"
  puts "  - KNOWN ISSUE: ABI incompatibility with some bash grammar versions"
  puts "  - Recommended: Use FFI backend for bash (see ffi_bash.rb)"
else
  puts "✗ Row number issues detected:"
  row_errors.each { |err| puts "  - #{err}" }
  exit 1
end
