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

# Row number validation
puts "=== Row Number Validation ==="
row_errors = []

puts "Top-level nodes with positions:"
i = 0
root.each do |child|
  start_row = child.start_point.row
  end_row = child.end_point.row
  start_col = child.start_point.column
  end_col = child.end_point.column

  puts "  Node #{i}: #{child.type}"
  puts "    rows: #{start_row}-#{end_row}, cols: #{start_col}-#{end_col}"
  puts "    text: #{child.to_s[0..40].gsub("\n", "\\n")}..."

  # The [features] table should start on row 4 (0-indexed), not row 0
  if child.type.to_s == "table" && child.to_s.include?("[features]")
    expected_row = 4
    if start_row != expected_row && start_row == 0
      row_errors << "[features] table has start_row=#{start_row}, expected ~#{expected_row}"
    end
  end

  i += 1
end

puts
if row_errors.empty?
  puts "✓ Row numbers look correct!"
  puts
  puts "=" * 70
  puts "Java Backend:"
  puts "  - Native JRuby integration"
  puts "  - Uses JNI to call tree-sitter"
  puts "  - Optimal performance on JRuby"
  puts "=" * 70
else
  puts "✗ Row number issues detected:"
  row_errors.each { |err| puts "  - #{err}" }
  exit 1
end
