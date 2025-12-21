#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Java Backend with TOML
#
# Forces the Java backend (JRuby only).
# Uses java-tree-sitter (jtreesitter) JAR for native Java bindings.
# @see https://github.com/tree-sitter/java-tree-sitter source
# @see https://tree-sitter.github.io/java-tree-sitter/ java-tree-sitter documentation
# @see https://central.sonatype.com/artifact/io.github.tree-sitter/jtreesitter Maven Central

# Check Ruby implementation
unless RUBY_ENGINE == "jruby"
  puts "⚠️  Java backend requires JRuby"
  puts "Current Ruby: #{RUBY_ENGINE} #{RUBY_VERSION}"
  puts "Run with: jruby #{__FILE__}"
  exit 1
end

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
end

require "tree_haver"

puts "=" * 70
puts "TreeHaver Java Backend - TOML Parsing"
puts "=" * 70
puts

toml_source = <<~TOML
  [package]
  name = "tree_haver"
  version = "3.0.0"
  
  [features]
  java_backend = true
  jruby = true
TOML

puts "TOML Source:"
puts "-" * 70
puts toml_source
puts

# Register TOML
puts "Registering TOML grammar..."
finder = TreeHaver::GrammarFinder.new(:toml)
if finder.available?
  finder.register!
  puts "✓ Registered from: #{finder.find_library_path}"
else
  puts "✗ tree-sitter-toml not found"
  puts finder.not_found_message
  exit 1
end

# Force Java backend
TreeHaver.backend = :java
puts "Backend: #{TreeHaver.backend_module}"
puts "Capabilities: #{TreeHaver.capabilities.inspect}"
puts "Ruby Engine: #{RUBY_ENGINE}"
puts

# Parse
parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.toml
tree = parser.parse(toml_source)

root = tree.root_node
puts "✓ Parsed: #{root.type} with #{root.child_count} children"
puts

# Show structure
puts "Top-level nodes:"
root.children.each do |child|
  puts "  • #{child.type}: #{child.text[0..40].gsub("\n", "\\n")}..."
end
puts

puts "=" * 70
puts "Java Backend:"
puts "  - Uses java-tree-sitter JAR"
puts "  - JRuby only"
puts "  - Native Java performance"
puts "  - Requires TREE_SITTER_JAVA_JARS_DIR env var"
puts "=" * 70
