#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Markly Markdown Parsing
#
# This demonstrates Markdown parsing using the markly gem
# (cmark-gfm C library) directly. Note that markly is NOT a TreeHaver
# backend - it's a standalone parser. For markdown merging, see the
# markdown-merge and markly-merge gems.
#
# markly gem: https://github.com/ioquatix/markly
# cmark-gfm: https://github.com/github/cmark-gfm

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "markly", "~> 0.12"
end

require "markly"

puts "=" * 70
puts "Markly - Markdown Parsing (GitHub Flavored)"
puts "=" * 70
puts

markdown_source = <<~MARKDOWN
  # TreeHaver Markly Example

  Markly uses GitHub's **cmark-gfm** library for fast Markdown parsing.

  ## GitHub Flavored Markdown

  ### Tables

  | Feature | Status |
  |---------|--------|
  | Tables  | ✓      |
  | Strikethrough | ~~not~~ ✓ |
  | Autolinks | https://github.com |

  ### Task Lists

  - [x] Implement position API
  - [x] Add to all backends
  - [ ] Write documentation

  ## Code

  ```ruby
  doc = Markly.parse(source, flags: Markly::UNSAFE)
  doc.each do |node|
    puts node.type
  end
  ```

  Great for GitHub-style Markdown!
MARKDOWN

puts "Markdown Source:"
puts "-" * 70
puts markdown_source
puts

# Parse the Markdown source with markly
puts "Parsing Markdown with Markly (GFM extensions enabled)..."
doc = Markly.parse(markdown_source, flags: Markly::UNSAFE, extensions: [:table, :strikethrough, :tasklist, :autolink])
puts "✓ Parsed successfully with GFM extensions"
puts "✓ Uses cmark-gfm (C library)"
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
  when :table then "📊"
  when :text then "📖"
  else "•"
  end

  # Get position info from source_position hash
  sp = node.source_position
  pos_info = "(L#{sp[:start_line]}-#{sp[:end_line]})"
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
  sp = heading.source_position
  text = heading.first_child&.string_content || ""
  puts "  H#{heading.header_level} (lines #{sp[:start_line]}-#{sp[:end_line]}): #{text}"
end
puts

# Find GFM extensions
puts "GFM Extensions Found:"
puts "-" * 70

tables = find_nodes_by_type(doc, :table)
if tables.any?
  puts "  Tables: #{tables.size}"
  tables.each_with_index do |table, i|
    sp = table.source_position
    puts "    Table #{i + 1} at lines #{sp[:start_line]}-#{sp[:end_line]}"
  end
end

strikethrough = find_nodes_by_type(doc, :strikethrough)
if strikethrough.any?
  puts "  Strikethrough: #{strikethrough.size} instances"
end

tasklists = find_nodes_by_type(doc, :tasklist)
if tasklists.any?
  puts "  Task Lists: #{tasklists.size}"
end
puts

# Find all code blocks
puts "Code Blocks:"
puts "-" * 70
code_blocks = find_nodes_by_type(doc, :code_block)
code_blocks.each do |block|
  sp = block.source_position
  info = block.fence_info || "plain"
  content = block.string_content || ""
  puts "  Language: #{info} (lines #{sp[:start_line]}-#{sp[:end_line]})"
  puts "    #{content.lines.first&.strip}"
end
puts

# Demonstrate position API
puts "Position API Demo:"
puts "-" * 70
first_heading = headings.first
if first_heading
  sp = first_heading.source_position
  puts "First heading analysis:"
  puts "  Type: #{first_heading.type}"
  puts "  Level: H#{first_heading.header_level}"
  puts "  source_position: #{sp.inspect}"
  puts "    start_line: #{sp[:start_line]}"
  puts "    end_line: #{sp[:end_line]}"
  puts "    start_column: #{sp[:start_column]}"
  puts "    end_column: #{sp[:end_column]}"
end
puts

# Demonstrate the advantages
puts "=" * 70
puts "Why Use Markly?"
puts "=" * 70
puts "1. Fast C-based parser (cmark-gfm)"
puts "2. Full GitHub Flavored Markdown support"
puts "3. Tables, task lists, strikethrough, autolinks"
puts "4. Excellent error tolerance"
puts
puts "Note: Markly is NOT a TreeHaver backend."
puts "For TreeHaver-style parsing, see the markly-merge and markdown-merge gems"
puts "which provide tree_haver integration for markdown merging."
puts
puts "Perfect for:"
puts "  - GitHub-style documentation"
puts "  - README processing"
puts "  - Wiki content"
puts "  - Blog posts with GFM features"
puts "=" * 70
