#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Commonmarker Backend with Markdown
#
# This demonstrates how tree_haver's Commonmarker backend provides fast
# Markdown parsing using the commonmarker gem (Rust comrak parser).
#
# commonmarker gem: https://github.com/gjtorikian/commonmarker
# CommonMark spec: https://commonmark.org/

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "commonmarker", ">= 0.23"
end

require "tree_haver"
require "commonmarker" # Explicitly require commonmarker

puts "=" * 70
puts "TreeHaver Commonmarker Backend - Markdown Parsing"
puts "=" * 70
puts

markdown_source = <<~MARKDOWN
  # TreeHaver Position API

  The position API provides consistent access to node locations.

  ## Features

  - `start_line` - 1-based line number
  - `end_line` - 1-based line number
  - `source_position` - Hash with all position info
  - `first_child` - Convenience method

  ## Example

  ```ruby
  node = tree.root_node
  puts node.start_line  # => 1
  ```

  Works with all backends!
MARKDOWN

puts "Markdown Source:"
puts "-" * 70
puts markdown_source
puts

# Force Commonmarker backend
puts "Setting backend to Commonmarker..."
TreeHaver.backend = :commonmarker
puts "✓ Backend: #{TreeHaver.backend_module}"
puts "✓ Uses comrak (Rust) via FFI"
puts

# Check availability
if TreeHaver::Backends::Commonmarker.available?
  puts "✓ Commonmarker gem is available"
else
  puts "✗ Commonmarker gem not found"
  exit 1
end
puts

# Parse the Markdown source
puts "Parsing Markdown source with TreeHaver..."
parser = TreeHaver::Parser.new
parser.language = TreeHaver::Backends::Commonmarker::Language.markdown
tree = parser.parse(markdown_source)
puts "✓ Parsed successfully"
puts

# Explore the AST
root = tree.root_node
puts "Root Node:"
puts "  Type: #{root.type}"
puts "  Children: #{root.child_count}"
puts "  Start Line: #{root.start_line}"
puts "  End Line: #{root.end_line}"
puts "  Position: #{root.source_position.inspect}"
puts

# Helper to display node tree
def show_tree(node, indent = 0, max_depth = 3)
  return if indent > max_depth

  prefix = "  " * indent
  marker = case node.type
  when "document" then "📄"
  when "heading" then "📌"
  when "paragraph" then "📝"
  when "code_block" then "💻"
  when "list" then "📋"
  when "text" then "📖"
  else "•"
  end

  # Show node info with position
  text_preview = node.text[0..40].gsub("\n", "\\n")
  pos_info = "(L#{node.start_line}:#{node.end_line})"
  puts "#{prefix}#{marker} #{node.type} #{pos_info}: #{text_preview.inspect}"

  # Recurse into children
  if node.child_count > 0 && node.child_count < 20
    node.children.each { |child| show_tree(child, indent + 1, max_depth) }
  elsif node.child_count > 0
    puts "#{prefix}  ... #{node.child_count} children ..."
  end
end

puts "AST Structure (first 3 levels):"
puts "-" * 70
show_tree(root)
puts

# Row number validation
puts "=== Row Number Validation ==="
row_errors = []

puts "Checking nodes for position info:"
i = 0
root.each do |child|
  start_row = child.start_point.row
  end_row = child.end_point.row
  start_col = child.start_point.column
  end_col = child.end_point.column

  puts "  Node #{i}: #{child.type} - rows #{start_row}-#{end_row}, cols #{start_col}-#{end_col}"

  # The "## Features" heading should NOT be on row 0
  if child.type.to_s == "heading" && child.text.include?("Features") && start_row == 0
    row_errors << "Features heading has start_row=0, expected > 0"
  end

  i += 1
  break if i > 5  # Only check first few
end

puts
if row_errors.empty?
  puts "✓ Row numbers look correct!"
else
  puts "✗ Row number issues detected:"
  row_errors.each { |err| puts "  - #{err}" }
  exit 1
end
puts

# Find all headings
puts "Headings with Position Info:"
puts "-" * 70
def find_nodes_by_type(node, type_name, results = [])
  results << node if node.type == type_name
  node.children.each { |child| find_nodes_by_type(child, type_name, results) }
  results
end

headings = find_nodes_by_type(root, "heading")
headings.each do |heading|
  level = heading.header_level || "?"
  text = heading.children.map(&:text).join.strip
  pos = heading.source_position
  puts "  H#{level} (lines #{pos[:start_line]}-#{pos[:end_line]}): #{text}"
end
puts

# Find all code blocks
puts "Code Blocks:"
puts "-" * 70
code_blocks = find_nodes_by_type(root, "code_block")
code_blocks.each do |block|
  info = block.fence_info || "plain"
  pos = block.source_position
  puts "  Language: #{info} (lines #{pos[:start_line]}-#{pos[:end_line]})"
  puts "    #{block.text.lines.first.strip}"
end
puts

# Demonstrate position API consistency
puts "Position API Demo:"
puts "-" * 70
first_heading = headings.first
if first_heading
  puts "First heading analysis:"
  puts "  Text: #{first_heading.children.map(&:text).join.strip}"
  puts "  Type: #{first_heading.type}"
  puts "  start_line: #{first_heading.start_line} (1-based)"
  puts "  end_line: #{first_heading.end_line} (1-based)"
  puts "  start_point: row=#{first_heading.start_point.row}, col=#{first_heading.start_point.column} (0-based)"
  puts "  end_point: row=#{first_heading.end_point.row}, col=#{first_heading.end_point.column} (0-based)"
  puts "  source_position: #{first_heading.source_position.inspect}"
  puts "  first_child: #{first_heading.first_child&.type || "none"}"
end
puts

# Demonstrate the advantages
puts "=" * 70
puts "Why Use Commonmarker Backend?"
puts "=" * 70
puts "1. Fast Rust-based parser (comrak) via FFI"
puts "2. Fully CommonMark compliant"
puts "3. GitHub Flavored Markdown (GFM) support"
puts "4. Excellent error tolerance"
puts "5. Same TreeHaver API as other backends"
puts
puts "Position API Features:"
puts "  - start_line/end_line: 1-based line numbers (human-readable)"
puts "  - source_position: Complete position hash"
puts "  - start_point/end_point: 0-based rows and columns"
puts "  - first_child: Convenient child access"
puts
puts "Perfect for:"
puts "  - Documentation processing"
puts "  - Markdown linting and formatting"
puts "  - Content management systems"
puts "  - Static site generators"
puts "=" * 70
