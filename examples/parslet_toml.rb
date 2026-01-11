#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Using TreeHaver with TOML Parslet Grammar
#
# This demonstrates how tree_haver's Parslet backend provides a pure Ruby
# fallback for TOML parsing using the toml gem when tree-sitter-toml is unavailable.
#
# toml gem: https://github.com/jm/toml
# TOML spec: https://toml.io/

require "bundler/inline"

gemfile do
  source "https://gem.coop"

  # Load tree_haver from local path
  gem "tree_haver", path: File.expand_path("..", __dir__)

  # TOML parser with Parslet grammar
  gem "toml", path: File.expand_path("../../toml", __dir__)

  gem "parslet"
end

require "tree_haver"
require "toml"

puts "=" * 70
puts "TreeHaver + TOML (Parslet Grammar) Example"
puts "=" * 70
puts

# Example TOML configuration
toml_source = <<~TOML
  # Application configuration
  [database]
  host = "localhost"
  port = 5432
  username = "admin"
  
  [server]
  bind = "0.0.0.0"
  port = 8080
  workers = 4
  
  [[services]]
  name = "api"
  enabled = true
  
  [[services]]
  name = "worker"
  enabled = false
TOML

puts "TOML Source:"
puts "-" * 70
puts toml_source
puts

# Register TOML's Parslet grammar with TreeHaver
puts "Registering TOML grammar with TreeHaver..."
TreeHaver.register_language(
  :toml,
  grammar_class: TOML::Parslet,
  gem_name: "toml",
)
puts "✓ Registered"
puts

# Force Parslet backend (pure Ruby parsing)
puts "Setting backend to Parslet (pure Ruby)..."
TreeHaver.backend = :parslet
puts "✓ Backend: #{TreeHaver.backend_module}"
puts "✓ This is 100% pure Ruby - no native extensions!"
puts

# Parse the TOML source
puts "Parsing TOML source with TreeHaver..."
parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.toml
tree = parser.parse(toml_source)
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
def show_tree(node, indent = 0, max_depth = 3)
  return if indent > max_depth

  prefix = "  " * indent
  marker = node.structural? ? "📦" : "🔤"

  # Show node info
  text_preview = node.text[0..40].gsub("\n", "\\n")
  puts "#{prefix}#{marker} #{node.type}: #{text_preview.inspect}"

  # Recurse into children (limit to avoid too much output)
  if node.child_count > 0 && node.child_count < 15
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

puts "Checking structural nodes for position info:"
i = 0
root.each do |child|
  next unless child.structural?

  if child.respond_to?(:start_point)
    start_row = child.start_point.row
    end_row = child.end_point.row
    puts "  Node #{i}: #{child.type} - rows #{start_row}-#{end_row}"

    # For multiline TOML, tables should have different start rows
    if child.type.to_s == "table" && child.to_s.include?("[server]")
      if start_row == 0
        row_errors << "[server] table has start_row=0, expected row > 0"
      end
    end
  else
    puts "  Node #{i}: #{child.type} - position info not available (Parslet nodes)"
  end

  i += 1
end

puts
if row_errors.empty?
  puts "✓ Row numbers look correct (or not applicable for Parslet backend)"
else
  puts "✗ Row number issues detected:"
  row_errors.each { |err| puts "  - #{err}" }
  exit 1
end
puts

# Demonstrate the advantages
puts "=" * 70
puts "Why Use Parslet Backend?"
puts "=" * 70
puts "1. 100% pure Ruby - no native extensions needed"
puts "2. Works on all Ruby implementations (MRI, JRuby, TruffleRuby)"
puts "3. No compilation step required"
puts "4. Perfect for environments without native build tools"
puts "5. Uses the well-established toml gem (Parslet-based)"
puts
puts "Note: Parslet parsing is slower than native tree-sitter,"
puts "but provides maximum portability."
puts
puts "Parslet vs Citrus:"
puts "  - Parslet: Grammar is a class (TOML::Parslet), instantiate then parse"
puts "  - Citrus:  Grammar is a module (TomlRB::Document), call parse directly"
puts
puts "Use Cases:"
puts "  - Cloud functions with restricted native dependencies"
puts "  - Embedded Ruby environments"
puts "  - Quick prototyping without compilation"
puts "  - Cross-platform CI/CD without native toolchains"
puts "=" * 70

