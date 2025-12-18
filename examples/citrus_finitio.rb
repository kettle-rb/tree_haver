#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Using TreeHaver with Finitio Citrus Grammar
#
# This demonstrates how tree_haver's Citrus backend can parse ANY Citrus grammar,
# not just TOML. Finitio is a data validation language with its own Citrus grammar.
#
# Finitio language: https://www.finitio.io/
# Finitio gem: https://github.com/enspirit/finitio-rb

require "bundler/inline"

gemfile do
  source "https://gem.coop"

  # Load tree_haver from local path
  gem "tree_haver", path: File.expand_path("..", __dir__)

  # Load finitio from vendor (has Citrus grammar)
  gem "finitio", path: File.expand_path("../vendor/finitio", __dir__)

  gem "citrus"
end

require "tree_haver"
require "finitio"

puts "=" * 70
puts "TreeHaver + Finitio (Citrus Grammar) Example"
puts "=" * 70
puts

# Example Finitio type system definition
finitio_source = <<~FINITIO
  # Define some types
  Name = String( s | s.length > 0 )
  Age = Integer( i | i >= 0 && i <= 150 )
  Email = String( s | s =~ /\A[^@]+@[^@]+\z/ )
  
  # Define a structured type
  Person = {
    name: Name
    age: Age
    email: Email
  }
FINITIO

puts "Finitio Source:"
puts "-" * 70
puts finitio_source
puts

# Register Finitio's Citrus grammar with TreeHaver
puts "Registering Finitio grammar with TreeHaver..."
TreeHaver.register_language(
  :finitio,
  grammar_module: Finitio::Syntax::Parser,
)
puts "✓ Registered"
puts

# Force Citrus backend
puts "Setting backend to Citrus..."
TreeHaver.backend = :citrus
puts "✓ Backend: #{TreeHaver.backend_module}"
puts

# Parse the Finitio source
puts "Parsing Finitio source with TreeHaver..."
parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.finitio
tree = parser.parse(finitio_source)
puts "✓ Parsed successfully"
puts

# Explore the AST
root = tree.root_node
puts "Root Node:"
puts "  Type: #{root.type}"
puts "  Structural?: #{root.structural?}"
puts "  Children: #{root.child_count}"
puts

# Helper to display node tree
def show_tree(node, indent = 0, max_depth = 4)
  return if indent > max_depth

  prefix = "  " * indent
  marker = node.structural? ? "📦" : "🔤"

  # Show node info
  text_preview = node.text[0..40].gsub("\n", "\\n")
  puts "#{prefix}#{marker} #{node.type}: #{text_preview.inspect}"

  # Recurse into children (limit to avoid too much output)
  if node.child_count > 0 && node.child_count < 20
    node.children.each { |child| show_tree(child, indent + 1, max_depth) }
  elsif node.child_count > 0
    puts "#{prefix}  ... #{node.child_count} children ..."
  end
end

puts "AST Structure (first 4 levels):"
puts "-" * 70
show_tree(root)
puts

# Find structural nodes
structural_nodes = []
root.children.each do |child|
  structural_nodes << child if child.structural? && child.type != "spacing"
end

puts "Structural Nodes Found:"
puts "-" * 70
structural_nodes.each do |node|
  puts "  • #{node.type}: #{node.text[0..50].tr("\n", " ").inspect}"
end
puts

# Demonstrate filtering by type
puts "Type Definitions:"
puts "-" * 70
def find_nodes_by_type(node, type_name, results = [])
  results << node if node.type == type_name
  node.children.each { |child| find_nodes_by_type(child, type_name, results) }
  results
end

type_defs = find_nodes_by_type(root, "type_def")
type_defs.each do |def_node|
  puts "  • #{def_node.text[0..60].tr("\n", " ")}"
end
puts

puts "=" * 70
puts "Key Takeaways:"
puts "=" * 70
puts "1. TreeHaver's Citrus backend works with ANY Citrus grammar"
puts "2. No language-specific code needed in tree_haver"
puts "3. Node types extracted dynamically from grammar rules"
puts "4. structural? method works for any grammar using Citrus's terminal? info"
puts "5. Same TreeHaver API (Parser, Tree, Node) regardless of grammar"
puts
puts "This means tree_haver can parse:"
puts "  - TOML (via toml-rb)"
puts "  - Finitio (via finitio gem)"
puts "  - Any of the 40+ other Citrus-based grammars on RubyGems"
puts "=" * 70
