#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Markly Backend with Markdown
#
# This demonstrates how tree_haver's Markly backend provides fast
# Markdown parsing using the markly gem (cmark-gfm C library).
#
# markly gem: https://github.com/ioquatix/markly
# cmark-gfm: https://github.com/github/cmark-gfm

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "markly", "~> 0.11"
end

require "tree_haver"
require "markly" # Explicitly require markly

puts "=" * 70
puts "TreeHaver Markly Backend - Markdown Parsing"
puts "=" * 70
puts

markdown_source = <<~MARKDOWN
  # TreeHaver Markly Backend

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
  parser = TreeHaver::Parser.new
  parser.language = TreeHaver::Backends::Markly::Language.markdown(
    extensions: [:table, :strikethrough, :tasklist]
  )
  tree = parser.parse(source)
  ```

  Great for GitHub-style Markdown!
MARKDOWN

puts "Markdown Source:"
puts "-" * 70
puts markdown_source
puts

# Force Markly backend
puts "Setting backend to Markly..."
TreeHaver.backend = :markly
puts "✓ Backend: #{TreeHaver.backend_module}"
puts "✓ Uses cmark-gfm (C library) via FFI"
puts

# Check availability
if TreeHaver::Backends::Markly.available?
  puts "✓ Markly gem is available"
else
  puts "✗ Markly gem not found"
  exit 1
end
puts

# Parse the Markdown source with GFM extensions
puts "Parsing Markdown with GFM extensions..."
parser = TreeHaver::Parser.new
parser.language = TreeHaver::Backends::Markly::Language.markdown(
  extensions: [:table, :strikethrough, :tasklist, :autolink],
)
tree = parser.parse(markdown_source)
puts "✓ Parsed successfully with GFM extensions"
puts

# Explore the AST
root = tree.root_node
puts "Root Node:"
puts "  Type: #{root.type}"
puts "  Raw Type: #{begin
  root.raw_type
rescue
  root.type
end}"
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
  when "table" then "📊"
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

  # Tables should NOT be on row 0 (they appear after headings)
  if child.type.to_s == "table" && start_row == 0
    row_errors << "Table has start_row=0, expected > 0"
  end

  i += 1
  break if i > 8  # Check more nodes due to structure
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

# Find GFM extensions
puts "GFM Extensions Found:"
puts "-" * 70

tables = find_nodes_by_type(root, "table")
if tables.any?
  puts "  Tables: #{tables.size}"
  tables.each_with_index do |table, i|
    pos = table.source_position
    puts "    Table #{i + 1} at lines #{pos[:start_line]}-#{pos[:end_line]}"
  end
end

strikethrough = find_nodes_by_type(root, "strikethrough")
if strikethrough.any?
  puts "  Strikethrough: #{strikethrough.size} instances"
end

tasklists = find_nodes_by_type(root, "tasklist")
if tasklists.any?
  puts "  Task Lists: #{tasklists.size}"
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
  lines = block.text.lines
  puts "    #{lines.first.strip}" if lines.any?
end
puts

# Demonstrate position API
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

# Demonstrate conversion methods
puts "Markly-Specific Features:"
puts "-" * 70
if first_heading
  puts "Output formats:"
  puts "  to_html: #{first_heading.to_html.strip[0..50]}..."
  puts "  to_commonmark: #{first_heading.to_commonmark.strip[0..50]}..."
  puts "  to_plaintext: #{first_heading.to_plaintext.strip[0..50]}..."
end
puts

# Show type normalization
puts "Type Normalization:"
puts "-" * 70
puts "Markly normalizes types to match Commonmarker:"
puts "  header -> heading"
puts "  hrule -> thematic_break"
puts "  html -> html_block"
puts
puts "Raw vs Normalized:"
headings.each do |h|
  puts "  raw_type='#{h.raw_type}' -> type='#{h.type}'"
  break
end if headings.any?
puts

# Demonstrate the advantages
puts "=" * 70
puts "Why Use Markly Backend?"
puts "=" * 70
puts "1. Fast C-based parser (cmark-gfm)"
puts "2. Official GitHub Flavored Markdown implementation"
puts "3. Extensive GFM extensions (tables, strikethrough, etc.)"
puts "4. Multiple output formats (HTML, CommonMark, plaintext)"
puts "5. Same TreeHaver API as other backends"
puts
puts "Position API Features:"
puts "  - start_line/end_line: 1-based line numbers (human-readable)"
puts "  - source_position: Complete position hash"
puts "  - start_point/end_point: 0-based rows and columns"
puts "  - first_child: Convenient child access"
puts
puts "Perfect for:"
puts "  - GitHub-compatible Markdown processing"
puts "  - README rendering"
puts "  - Issue/PR description parsing"
puts "  - Documentation generation"
puts "=" * 70
