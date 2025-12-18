#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Prism Backend with Ruby
#
# This demonstrates how tree_haver's Prism backend provides Ruby parsing
# using Prism (Ruby's official parser, stdlib in Ruby 3.4+).
#
# Prism: https://github.com/ruby/prism
# Ruby parser used by CRuby, JRuby, TruffleRuby

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tree_haver", path: File.expand_path("..", __dir__)
  # Prism is stdlib in Ruby 3.4+, gem for 3.2-3.3
  gem "prism", "~> 1.0" if RUBY_VERSION < "3.4"
end

require "tree_haver"
require "prism" # Explicitly require prism

puts "=" * 70
puts "TreeHaver Prism Backend - Ruby Parsing"
puts "=" * 70
puts

ruby_source = <<~RUBY
  # TreeHaver Position API Demo
  class PositionExample
    attr_reader :start_line, :end_line

    def initialize(node)
      @start_line = node.start_line
      @end_line = node.end_line
    end

    def source_position
      {
        start_line: @start_line,
        end_line: @end_line,
        start_column: 0,
        end_column: 0
      }
    end

    def first_child
      @children&.first
    end
  end

  # Example usage
  node = parse("x = 42")
  pos = PositionExample.new(node)
  puts "Lines: \#{pos.start_line}-\#{pos.end_line}"
RUBY

puts "Ruby Source:"
puts "-" * 70
puts ruby_source
puts

# Force Prism backend
puts "Setting backend to Prism..."
TreeHaver.backend = :prism
puts "✓ Backend: #{TreeHaver.backend_module}"
puts "✓ Ruby Version: #{RUBY_VERSION}"
puts "✓ Prism: #{Prism.const_defined?(:VERSION) ? Prism::VERSION : "stdlib"}"
puts

# Check availability
if TreeHaver::Backends::Prism.available?
  puts "✓ Prism is available"
else
  puts "✗ Prism not found"
  exit 1
end
puts

# Parse the Ruby source
puts "Parsing Ruby source with TreeHaver..."
parser = TreeHaver::Parser.new
parser.language = TreeHaver::Backends::Prism::Language.ruby
tree = parser.parse(ruby_source)
puts "✓ Parsed successfully"
puts

# Check for errors
if tree.has_errors?
  puts "⚠ Parse errors found:"
  tree.errors.each do |error|
    puts "  #{error.message}"
  end
  puts
end

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
  when "program_node" then "📄"
  when "class_node" then "🏛️"
  when "def_node" then "⚙️"
  when "call_node" then "📞"
  when "constant_read_node" then "📌"
  when "instance_variable_read_node" then "💾"
  when "string_node" then "📝"
  else "•"
  end

  # Show node info with position
  text_preview = node.text[0..40].gsub("\n", "\\n")
  pos_info = "(L#{node.start_line}:#{node.end_line})"
  puts "#{prefix}#{marker} #{node.type} #{pos_info}: #{text_preview.inspect}"

  # Recurse into children (limit for readability)
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

# Find all classes
puts "Classes with Position Info:"
puts "-" * 70
def find_nodes_by_type(node, type_name, results = [])
  results << node if node.type == type_name
  node.children.each { |child| find_nodes_by_type(child, type_name, results) }
  results
end

classes = find_nodes_by_type(root, "class_node")
classes.each do |cls|
  # Get class name (Prism stores it differently than tree-sitter)
  name = begin
    cls.text.lines.first.match(/class\s+(\w+)/)[1]
  rescue
    "Unknown"
  end
  pos = cls.source_position
  puts "  Class #{name} (lines #{pos[:start_line]}-#{pos[:end_line]})"
end
puts

# Find all method definitions
puts "Method Definitions:"
puts "-" * 70
methods = find_nodes_by_type(root, "def_node")
methods.each do |method|
  # Extract method name from source
  first_line = method.text.lines.first.strip
  name = begin
    first_line.match(/def\s+(\w+)/)[1]
  rescue
    "unknown"
  end
  pos = method.source_position
  puts "  def #{name} (lines #{pos[:start_line]}-#{pos[:end_line]})"
end
puts

# Find all calls
puts "Method Calls:"
puts "-" * 70
calls = find_nodes_by_type(root, "call_node")
calls.take(5).each do |call|
  text = call.text.strip[0..50]
  pos = call.source_position
  puts "  #{text} (line #{pos[:start_line]})"
end
puts "  ... #{calls.size - 5} more calls" if calls.size > 5
puts

# Demonstrate position API
puts "Position API Demo:"
puts "-" * 70
first_class = classes.first
if first_class
  puts "First class analysis:"
  puts "  Type: #{first_class.type}"
  puts "  start_line: #{first_class.start_line} (1-based)"
  puts "  end_line: #{first_class.end_line} (1-based)"
  puts "  start_point: row=#{first_class.start_point[:row]}, col=#{first_class.start_point[:column]} (0-based)"
  puts "  end_point: row=#{first_class.end_point[:row]}, col=#{first_class.end_point[:column]} (0-based)"
  puts "  source_position: #{first_class.source_position.inspect}"
  puts "  first_child: #{first_class.first_child&.type || "none"}"
  puts
  puts "  Source text:"
  first_class.text.lines.take(3).each { |line| puts "    #{line}" }
end
puts

# Show Prism-specific features
puts "Prism-Specific Features:"
puts "-" * 70
puts "Parse result info:"
puts "  Errors: #{tree.errors.size}"
puts "  Warnings: #{tree.warnings.size}"
puts "  Comments: #{tree.comments.size}"
puts "  Magic comments: #{tree.magic_comments.size}"

if tree.comments.any?
  puts
  puts "Comments:"
  tree.comments.take(3).each do |comment|
    location = comment.location
    puts "  Line #{location.start_line}: #{comment.slice}"
  end
end
puts

# Demonstrate the advantages
puts "=" * 70
puts "Why Use Prism Backend?"
puts "=" * 70
puts "1. Official Ruby parser (used by CRuby, JRuby, TruffleRuby)"
puts "2. Excellent error recovery"
puts "3. Detailed location information"
puts "4. Fast and memory-efficient"
puts "5. Supports all Ruby versions"
puts "6. Stdlib in Ruby 3.4+, gem for older versions"
puts
puts "Position API Features:"
puts "  - start_line/end_line: 1-based line numbers (human-readable)"
puts "  - source_position: Complete position hash"
puts "  - start_point/end_point: 0-based rows and columns (hash format)"
puts "  - first_child: Convenient child access"
puts
puts "Perfect for:"
puts "  - Ruby code analysis"
puts "  - Linters and formatters"
puts "  - Refactoring tools"
puts "  - Documentation generators"
puts "  - AST-based transformations"
puts "=" * 70
