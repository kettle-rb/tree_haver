#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Using parser_for with Citrus backend
#
# This demonstrates using TreeHaver.parser_for with explicit Citrus backend selection.
# The parser_for method handles grammar discovery and registration automatically.
#
# Run with different backend selection methods:
#   bundle exec ruby examples/parser_for_citrus.rb
#   TREE_HAVER_BACKEND=citrus bundle exec ruby examples/parser_for_citrus.rb

require "bundler/inline"

gemfile do
  source "https://gem.coop"

  # Load tree_haver from local path
  gem "tree_haver", path: File.expand_path("..", __dir__)

  # TOML parser with Citrus grammar
  gem "toml-rb", "~> 4.1"
  gem "citrus"
end

require "tree_haver"
require "toml-rb"

puts "=" * 70
puts "TreeHaver.parser_for with Citrus Backend"
puts "=" * 70
puts

toml_source = <<~TOML
  title = "Parser For Test"
  version = 1

  [database]
  host = "localhost"
  port = 5432
TOML

puts "TOML Source:"
puts "-" * 70
puts toml_source
puts

# Show environment and initial state
puts "Environment:"
puts "  TREE_HAVER_BACKEND: #{ENV["TREE_HAVER_BACKEND"].inspect}"
puts "  TreeHaver.backend: #{TreeHaver.backend.inspect}"
puts "  TreeHaver.effective_backend: #{TreeHaver.effective_backend.inspect}"
puts

# =============================================================================
# Test 1: parser_for with current effective_backend
# =============================================================================
puts "-" * 70
puts "Test 1: TreeHaver.parser_for(:toml) with current settings"
puts "-" * 70

begin
  parser = TreeHaver.parser_for(:toml)
  tree = parser.parse(toml_source)

  puts "  Parser created successfully!"
  puts "  parser.backend: #{parser.backend.inspect}"
  puts "  root_node.type: #{tree.root_node.type.inspect}"
  puts "  root_node.children.count: #{tree.root_node.children.count}"

  expected_backend = TreeHaver.effective_backend
  if expected_backend == :auto
    puts "  Backend was auto-selected: #{parser.backend.inspect}"
  elsif parser.backend == expected_backend
    puts "  ✓ PASS: Backend matches effective_backend (#{expected_backend.inspect})"
  else
    puts "  ✗ FAIL: Expected #{expected_backend.inspect}, got #{parser.backend.inspect}"
  end
rescue => e
  puts "  ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(3).map { |l| "    #{l}" }.join("\n")
end
puts

# =============================================================================
# Test 2: parser_for inside with_backend(:citrus)
# =============================================================================
puts "-" * 70
puts "Test 2: TreeHaver.with_backend(:citrus) { parser_for(:toml) }"
puts "-" * 70

begin
  TreeHaver.with_backend(:citrus) do
    puts "  Inside with_backend(:citrus):"
    puts "    effective_backend: #{TreeHaver.effective_backend.inspect}"

    parser = TreeHaver.parser_for(:toml)
    tree = parser.parse(toml_source)

    puts "    parser.backend: #{parser.backend.inspect}"
    puts "    root_node.type: #{tree.root_node.type.inspect}"

    if parser.backend == :citrus
      puts "    ✓ PASS: Citrus backend was used"
    else
      puts "    ✗ FAIL: Expected :citrus, got #{parser.backend.inspect}"
    end
  end
rescue => e
  puts "  ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(3).map { |l| "    #{l}" }.join("\n")
end
puts

# =============================================================================
# Test 3: parser_for after TreeHaver.backend = :citrus
# =============================================================================
puts "-" * 70
puts "Test 3: TreeHaver.backend = :citrus; parser_for(:toml)"
puts "-" * 70

begin
  original_backend = TreeHaver.backend
  TreeHaver.backend = :citrus

  puts "  After TreeHaver.backend = :citrus:"
  puts "    TreeHaver.backend: #{TreeHaver.backend.inspect}"
  puts "    effective_backend: #{TreeHaver.effective_backend.inspect}"

  parser = TreeHaver.parser_for(:toml)
  tree = parser.parse(toml_source)

  puts "    parser.backend: #{parser.backend.inspect}"
  puts "    root_node.type: #{tree.root_node.type.inspect}"

  if parser.backend == :citrus
    puts "    ✓ PASS: Citrus backend was used"
  else
    puts "    ✗ FAIL: Expected :citrus, got #{parser.backend.inspect}"
  end

  # Restore
  TreeHaver.backend = original_backend
rescue => e
  puts "  ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(3).map { |l| "    #{l}" }.join("\n")
end
puts

puts "=" * 70
puts "Tests Complete"
puts "=" * 70
