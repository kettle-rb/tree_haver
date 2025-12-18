#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Psych Backend with YAML
#
# This demonstrates how tree_haver's Psych backend provides YAML parsing
# using Psych (Ruby's standard library YAML parser).
#
# Psych: https://ruby-doc.org/stdlib/libdoc/psych/rdoc/Psych.html
# Part of Ruby stdlib

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  # Psych is part of Ruby stdlib
end

require "tree_haver"
require "psych" # Explicitly require psych

puts "=" * 70
puts "TreeHaver Psych Backend - YAML Parsing"
puts "=" * 70
puts

yaml_source = <<~YAML
  # TreeHaver Configuration
  version: 3.1.0
  
  backends:
    - mri
    - ffi
    - rust
    - java
    - prism
    - psych
    - commonmarker
    - markly
    - citrus
  
  features:
    position_api:
      start_line: 1-based line numbers
      end_line: 1-based line numbers
      source_position: complete position hash
      first_child: convenience method
    
    compatibility:
      tree_sitter: true
      native_parsers: true
      pure_ruby: true
  
  metadata:
    author: Peter Boling
    license: MIT
    homepage: https://github.com/kettle-rb/tree_haver
YAML

puts "YAML Source:"
puts "-" * 70
puts yaml_source
puts

# Force Psych backend
puts "Setting backend to Psych..."
TreeHaver.backend = :psych
puts "✓ Backend: #{TreeHaver.backend_module}"
puts "✓ Psych Version: #{Psych::VERSION}"
puts "✓ Part of Ruby stdlib"
puts

# Check availability
if TreeHaver::Backends::Psych.available?
  puts "✓ Psych is available"
else
  puts "✗ Psych not found"
  exit 1
end
puts

# Parse the YAML source
puts "Parsing YAML source with TreeHaver..."
parser = TreeHaver::Parser.new
parser.language = TreeHaver::Backends::Psych::Language.yaml
tree = parser.parse(yaml_source)
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
  when "stream" then "🌊"
  when "document" then "📄"
  when "mapping" then "🗺️"
  when "sequence" then "📋"
  when "scalar" then "📝"
  when "alias" then "🔗"
  else "•"
  end

  # Show node info with position
  text_preview = if node.scalar?
    node.value.to_s[0..40].gsub("\n", "\\n")
  else
    node.text[0..40].gsub("\n", "\\n")
  end
  pos_info = "(L#{node.start_line}:#{node.end_line})"
  puts "#{prefix}#{marker} #{node.type} #{pos_info}: #{text_preview.inspect}"

  # Recurse into children
  if node.child_count > 0 && node.child_count < 30
    node.children.each { |child| show_tree(child, indent + 1, max_depth) }
  elsif node.child_count > 0
    puts "#{prefix}  ... #{node.child_count} children ..."
  end
end

puts "AST Structure (first 3 levels):"
puts "-" * 70
show_tree(root, 0, 2)
puts

# Find document node
puts "YAML Structure:"
puts "-" * 70
def find_nodes_by_type(node, type_name, results = [])
  results << node if node.type == type_name
  node.children.each { |child| find_nodes_by_type(child, type_name, results) }
  results
end

documents = find_nodes_by_type(root, "document")
puts "Documents: #{documents.size}"

mappings = find_nodes_by_type(root, "mapping")
puts "Mappings: #{mappings.size}"

sequences = find_nodes_by_type(root, "sequence")
puts "Sequences: #{sequences.size}"

scalars = find_nodes_by_type(root, "scalar")
puts "Scalars: #{scalars.size}"
puts

# Analyze top-level mapping
puts "Top-Level Keys:"
puts "-" * 70
if documents.any? && documents.first.child_count > 0
  doc = documents.first
  if doc.mapping?
    # Mappings have key-value pairs as alternating children
    entries = doc.mapping_entries
    entries.each do |key, value|
      pos = key.source_position
      puts "  #{key.value} (line #{pos[:start_line]}): #{value.type}"
    end
  end
end
puts

# Find all sequence nodes
puts "Sequences (Arrays):"
puts "-" * 70
sequences.take(3).each_with_index do |seq, i|
  pos = seq.source_position
  items = seq.children.select(&:scalar?).map(&:value)
  puts "  Sequence #{i + 1} (lines #{pos[:start_line]}-#{pos[:end_line]}):"
  items.take(5).each { |item| puts "    - #{item}" }
  puts "    ... #{items.size - 5} more items" if items.size > 5
end
puts

# Find nested mappings
puts "Nested Mappings:"
puts "-" * 70
nested_mappings = mappings.select do |m|
  # Check if parent is also a mapping
  parent_is_mapping = false
  mappings.each do |parent|
    if parent.children.include?(m)
      parent_is_mapping = true
      break
    end
  end
  parent_is_mapping
end

nested_mappings.take(3).each do |mapping|
  pos = mapping.source_position
  puts "  Mapping at lines #{pos[:start_line]}-#{pos[:end_line]}"
  if mapping.mapping?
    entries = mapping.mapping_entries
    entries.take(3).each do |key, value|
      puts "    #{key.value}: #{value.scalar? ? value.value : value.type}"
    end
  end
end
puts

# Demonstrate position API
puts "Position API Demo:"
puts "-" * 70
first_scalar = scalars.first
if first_scalar
  puts "First scalar analysis:"
  puts "  Type: #{first_scalar.type}"
  puts "  Value: #{first_scalar.value.inspect}"
  puts "  start_line: #{first_scalar.start_line} (1-based)"
  puts "  end_line: #{first_scalar.end_line} (1-based)"
  puts "  start_point: row=#{first_scalar.start_point.row}, col=#{first_scalar.start_point.column} (0-based)"
  puts "  end_point: row=#{first_scalar.end_point.row}, col=#{first_scalar.end_point.column} (0-based)"
  puts "  source_position: #{first_scalar.source_position.inspect}"
  puts "  first_child: #{first_scalar.first_child&.type || "none (leaf node)"}"
end
puts

# Show Psych-specific features
puts "Psych-Specific Features:"
puts "-" * 70
puts "Node type checks:"
sample_nodes = [mappings.first, sequences.first, scalars.first].compact
sample_nodes.each do |node|
  pos = node.source_position
  puts "  Line #{pos[:start_line]}:"
  puts "    mapping?: #{node.mapping?}"
  puts "    sequence?: #{node.sequence?}"
  puts "    scalar?: #{node.scalar?}"
  puts "    alias?: #{node.alias?}"
end
puts

# Show anchors and tags if any
scalars_with_tags = scalars.select { |s| s.tag && !s.tag.empty? }
if scalars_with_tags.any?
  puts "Scalars with tags:"
  scalars_with_tags.each do |scalar|
    puts "  #{scalar.tag}: #{scalar.value}"
  end
  puts
end

# Demonstrate the advantages
puts "=" * 70
puts "Why Use Psych Backend?"
puts "=" * 70
puts "1. Part of Ruby stdlib (always available)"
puts "2. Fast and reliable YAML parsing"
puts "3. Supports YAML 1.1 and subset of YAML 1.2"
puts "4. Works on all Ruby implementations"
puts "5. No external dependencies"
puts
puts "Position API Features:"
puts "  - start_line/end_line: 1-based line numbers (human-readable)"
puts "  - source_position: Complete position hash"
puts "  - start_point/end_point: 0-based rows and columns"
puts "  - first_child: Convenient child access"
puts
puts "Psych-Specific Methods:"
puts "  - mapping?: Check if node is a hash/mapping"
puts "  - sequence?: Check if node is an array/sequence"
puts "  - scalar?: Check if node is a primitive value"
puts "  - alias?: Check if node is an alias/anchor reference"
puts "  - mapping_entries: Get key-value pairs from mappings"
puts "  - anchor: Get anchor name"
puts "  - tag: Get YAML tag"
puts "  - value: Get scalar value"
puts
puts "Perfect for:"
puts "  - Configuration file parsing"
puts "  - Data serialization"
puts "  - CI/CD pipeline configs (GitHub Actions, etc.)"
puts "  - Kubernetes manifests"
puts "  - Docker Compose files"
puts "=" * 70
