#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Commonmarker Markdown Parsing
#
# This demonstrates Markdown parsing using the commonmarker gem
# (Rust comrak parser) directly. Note that commonmarker is NOT a TreeHaver
# backend - it's a standalone parser. For markdown merging, see the
# markdown-merge and commonmarker-merge gems.
#
# commonmarker gem: https://github.com/gjtorikian/commonmarker
# CommonMark spec: https://commonmark.org/

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "commonmarker", ">= 0.23"
end

require "commonmarker"

puts "=" * 70
puts "Commonmarker - Markdown Parsing"
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

# Parse the Markdown source with commonmarker
puts "Parsing Markdown source with Commonmarker..."
doc = Commonmarker.parse(markdown_source)
puts "✓ Parsed successfully"
puts "✓ Uses comrak (Rust) parser"
puts

# Explore the AST
puts "Document Info:"
puts "  Type: #{doc.type}"
puts

# Helper to display node tree
def show_tree(node, indent = 0, max_depth = 3)
  return if indent > max_depth

  prefix = "  " * indent
  marker = case node.type
  when :document then "📄"
  when :heading then "📌"
  when :paragraph then "📝"
  when :code_block then "💻"
  when :list then "📋"
  when :text then "📖"
  else "•"
  end

  # Get node source range if available
  sr = node.source_position
  pos_info = "(L#{sr[:start_line]}-#{sr[:end_line]})" if sr
  puts "#{prefix}#{marker} #{node.type} #{pos_info}"

  # Recurse into children
  node.each { |child| show_tree(child, indent + 1, max_depth) }
end

puts "AST Structure (first 3 levels):"
puts "-" * 70
show_tree(doc)
puts

# Find all headings
puts "Headings with Position Info:"
puts "-" * 70
def find_nodes_by_type(node, type_sym, results = [])
  results << node if node.type == type_sym
  node.each { |child| find_nodes_by_type(child, type_sym, results) }
  results
end

headings = find_nodes_by_type(doc, :heading)
headings.each do |heading|
  sr = heading.source_position
  text = heading.first_child&.string_content || ""
  puts "  H#{heading.header_level} (lines #{sr[:start_line]}-#{sr[:end_line]}): #{text}"
end
puts

# Find all code blocks
puts "Code Blocks:"
puts "-" * 70
code_blocks = find_nodes_by_type(doc, :code_block)
code_blocks.each do |block|
  sr = block.source_position
  info = block.fence_info || "plain"
  content = block.string_content || ""
  puts "  Language: #{info} (lines #{sr[:start_line]}-#{sr[:end_line]})"
  puts "    #{content.lines.first&.strip}"
end
puts

# Demonstrate position API
puts "Position API Demo:"
puts "-" * 70
first_heading = headings.first
if first_heading
  sr = first_heading.source_position
  puts "First heading analysis:"
  puts "  Type: #{first_heading.type}"
  puts "  Level: H#{first_heading.header_level}"
  puts "  source_position: #{sr.inspect}"
end
puts

# Demonstrate the advantages
puts "=" * 70
puts "Why Use Commonmarker?"
puts "=" * 70
puts "1. Fast Rust-based parser (comrak)"
puts "2. Fully CommonMark compliant"
puts "3. GitHub Flavored Markdown (GFM) support"
puts "4. Excellent error tolerance"
puts
puts "Note: Commonmarker is NOT a TreeHaver backend."
puts "For TreeHaver-style parsing, see the markly-merge and commonmarker-merge gems"
puts "which provide tree_haver integration for markdown merging."
puts
puts "Perfect for:"
puts "  - Documentation processing"
puts "  - Markdown linting and formatting"
puts "  - Content management systems"
puts "  - Static site generators"
puts "=" * 70
