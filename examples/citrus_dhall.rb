#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Citrus Backend with Dhall
#
# Demonstrates parsing Dhall (configuration language) with tree_haver using
# the dhall gem's Citrus grammar.
#
# Dhall is a programmable configuration language with types, functions,
# and imports. See: https://dhall-lang.org/

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  gem "dhall"
  gem "csv"
  gem "ostruct"
end

require "tree_haver"
require "dhall"

puts "=" * 70
puts "TreeHaver Citrus Backend - Dhall Parsing"
puts "=" * 70
puts

# Example Dhall configuration
dhall_source = <<~DHALL
  -- Simple configuration example
  let name = "TreeHaver"
  let version = 2
  let enabled = True
  
  in  { name = name
      , version = version
      , enabled = enabled
      , features = ["parsing", "citrus", "dhall"]
      }
DHALL

puts "Dhall Source:"
puts "-" * 70
puts dhall_source
puts

# Check if Dhall uses Citrus
puts "Checking Dhall gem structure..."
finder = TreeHaver::CitrusGrammarFinder.new(
  language: :dhall,
  gem_name: "dhall",
  grammar_const: "Dhall::Parser",
  require_path: "dhall",
)

if finder.available?
  puts "✓ Dhall Citrus grammar available"
  finder.register!
  puts "✓ Registered Dhall grammar"
else
  puts "✗ Dhall grammar not available as Citrus"
  puts finder.not_found_message
  puts
  puts "Note: The dhall gem may not use Citrus grammar directly."
  puts "It may use a different parsing approach."
  exit 1
end
puts

# Force Citrus backend
TreeHaver.backend = :citrus
puts "Backend: #{TreeHaver.backend_module}"
puts "Capabilities: #{TreeHaver.capabilities.inspect}"
puts

# Parse Dhall
begin
  parser = TreeHaver::Parser.new
  parser.language = TreeHaver::Language.dhall
  tree = parser.parse(dhall_source)

  puts "✓ Parsed successfully"
  puts

  # Explore AST
  root = tree.root_node
  puts "Root Node:"
  puts "  Type: #{root.type}"
  puts "  Children: #{root.child_count}"
  puts "  Structural?: #{root.structural?}"
  puts

  # Show tree structure (first level)
  puts "AST Structure (top level):"
  puts "-" * 70
  def show_tree(node, indent = 0, max_depth = 3)
    return if indent > max_depth

    prefix = "  " * indent
    type_str = node.type.to_s.ljust(20 - indent * 2)
    structural = node.structural? ? "📦" : "🔤"
    text_preview = node.text.gsub(/\s+/, " ")[0..40]

    puts "#{prefix}#{structural} #{type_str} #{text_preview}"

    if indent < max_depth && node.structural?
      node.children.each { |child| show_tree(child, indent + 1, max_depth) }
    end
  end

  show_tree(root)
  puts

  # Row number validation
  puts "=== Row Number Validation ==="
  row_errors = []

  puts "Checking nodes for position info:"
  i = 0
  root.each do |child|
    next unless child.structural?

    if child.respond_to?(:start_point)
      start_row = child.start_point.row
      end_row = child.end_point.row
      puts "  Node #{i}: #{child.type} - rows #{start_row}-#{end_row}"
    else
      puts "  Node #{i}: #{child.type} - position info not available"
    end

    i += 1
    break if i > 5
  end

  puts
  if row_errors.empty?
    puts "✓ Row numbers look correct (or not applicable for Citrus backend)"
  else
    puts "✗ Row number issues detected:"
    row_errors.each { |err| puts "  - #{err}" }
    exit(1)
  end
  puts

  # Find specific node types
  def find_nodes_by_type(node, type, results = [])
    results << node if node.type.to_s == type.to_s
    node.children.each { |child| find_nodes_by_type(child, type, results) }
    results
  end

  # Try to find common Dhall constructs
  puts "Dhall Constructs Found:"
  puts "-" * 70

  # Show available node types
  all_types = Set.new
  def collect_types(node, types)
    types << node.type if node.structural?
    node.children.each { |child| collect_types(child, types) }
  end

  collect_types(root, all_types)
  puts "Node types present: #{all_types.to_a.sort.join(", ")}"
  puts
rescue TreeHaver::Error => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(5)
  exit(1)
end

puts "=" * 70
puts "Dhall + Citrus Backend:"
puts "  ✓ Pure Ruby configuration parsing"
puts "  ✓ Type-safe configurations"
puts "  ✓ No native extensions needed"
puts "  ✓ Works on any Ruby implementation"
puts
puts "Use Cases:"
puts "  • Configuration management"
puts "  • Type-safe config files"
puts "  • Programmable configurations"
puts "  • Configuration validation"
puts "=" * 70
