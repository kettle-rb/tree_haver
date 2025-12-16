#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Auto Backend Selection with Bash
#
# Demonstrates parsing Bash shell scripts with tree-sitter-bash.

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "ffi" # FFI backend - most portable
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver Auto Backend - Bash Parsing"
puts "=" * 70
puts

# Bash script example
bash_source = <<~BASH
  #!/bin/bash
  
  # Function to greet user
  greet() {
    local name="$1"
    echo "Hello, $name!"
  }
  
  # Main script
  if [ -n "$USER" ]; then
    greet "$USER"
  else
    echo "User not found"
    exit 1
  fi
  
  # Loop example
  for i in {1..3}; do
    echo "Iteration $i"
  done
BASH

puts "Bash Source:"
puts "-" * 70
puts bash_source
puts

# Register Bash grammar
puts "Registering Bash grammar..."
finder = TreeHaver::GrammarFinder.new(:bash)
if finder.available?
  finder.register!
  puts "✓ Registered from: #{finder.find_library_path}"
else
  puts "✗ tree-sitter-bash not found"
  puts finder.not_found_message
  exit 1
end
puts

backend = TreeHaver.backend_module
puts "Backend: #{backend}"
puts

# Parse Bash
parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.bash
tree = parser.parse(bash_source)
puts "✓ Parsed successfully"
puts

# Explore AST
root = tree.root_node
puts "Root: #{root.type} with #{root.child_count} children"
puts

# Find functions
def find_functions(node, results = [])
  results << node if node.type == "function_definition"
  node.children.each { |child| find_functions(child, results) }
  results
end

functions = find_functions(root)
puts "Functions Found: #{functions.count}"
functions.each do |func|
  puts "  • #{func.text.lines.first.strip}"
end
puts

# Find if statements
def find_if_statements(node, results = [])
  results << node if node.type == "if_statement"
  node.children.each { |child| find_if_statements(child, results) }
  results
end

ifs = find_if_statements(root)
puts "If Statements: #{ifs.count}"
puts

# Find loops
def find_loops(node, results = [])
  results << node if ["for_statement", "while_statement"].include?(node.type)
  node.children.each { |child| find_loops(child, results) }
  results
end

loops = find_loops(root)
puts "Loops Found: #{loops.count}"
puts

puts "=" * 70
puts "Bash Parsing Use Cases:"
puts "  • Shell script analysis"
puts "  • CI/CD script validation"
puts "  • Documentation generation"
puts "  • Security auditing"
puts "  • Code refactoring tools"
puts "=" * 70

