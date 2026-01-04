#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to investigate MRI backend parse failures
#
# Run from tree_haver directory with MRI Ruby:
#   ruby examples/debug_mri_parse.rb

# Use bundler/inline to load the LOCAL patched ruby-tree-sitter gem
require "bundler/inline"

gemfile do
  source "https://gem.coop"
  # Load the local patched ruby-tree-sitter built for tree-sitter 0.26.3
  gem "ruby_tree_sitter", require: "tree_sitter", path: File.expand_path("../../ruby-tree-sitter", __dir__)
  # Load local tree_haver
  gem "tree_haver", path: File.expand_path("..", __dir__)
end

puts "=" * 70
puts "Debugging MRI Backend Parse Issue"
puts "=" * 70
puts

puts "Ruby Engine: #{RUBY_ENGINE}"
puts "Ruby Version: #{RUBY_VERSION}"
puts

# Check if ruby_tree_sitter is available
puts "TreeSitter loaded successfully!"
puts "  TreeSitter::VERSION: #{TreeSitter::VERSION}"
puts "  TreeSitter::LANGUAGE_VERSION: #{TreeSitter::LANGUAGE_VERSION}"
puts "  TreeSitter::MIN_COMPATIBLE_LANGUAGE_VERSION: #{TreeSitter::MIN_COMPATIBLE_LANGUAGE_VERSION}"

puts

# Check if MRI backend is available
puts "MRI Backend available?: #{TreeHaver::Backends::MRI.available?}"
puts

# Load the TOML grammar
toml_path = ENV["TREE_SITTER_TOML_PATH"]
puts "TREE_SITTER_TOML_PATH: #{toml_path.inspect}"
puts "  File exists: #{File.exist?(toml_path.to_s)}" if toml_path
puts

# Try to load language directly with ruby_tree_sitter
puts "-" * 70
puts "Step 1: Load language directly with ruby_tree_sitter"
puts "-" * 70

begin
  ts_lang = TreeSitter::Language.load("toml", toml_path)
  puts "  Language loaded: #{ts_lang.class}"
  puts "  Language ABI version: #{ts_lang.version}"
  puts "  Inspect: #{ts_lang.inspect}"
rescue => e
  puts "  ERROR loading language: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end
puts

puts "-" * 70
puts "Step 2: Create parser and set language with ruby_tree_sitter"
puts "-" * 70

begin
  ts_parser = TreeSitter::Parser.new
  puts "  Parser created: #{ts_parser.class}"
  puts "  Parser.language before set: #{ts_parser.language.inspect}"

  result = ts_parser.language = ts_lang
  puts "  parser.language= returned: #{result.inspect}"
  puts "  Parser.language after set: #{ts_parser.language.inspect}"
  puts "  Parser.language.nil?: #{ts_parser.language.nil?}"
rescue => e
  puts "  ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end
puts

puts "-" * 70
puts "Step 3: Try to parse with ruby_tree_sitter"
puts "-" * 70

source = 'key = "value"'
begin
  puts "  Source: #{source.inspect}"
  result = ts_parser.parse_string(nil, source)
  puts "  parse_string returned: #{result.inspect}"
  puts "  Result class: #{result.class}"
  puts "  Result nil?: #{result.nil?}"

  if result
    root = result.root_node
    puts "  Root node type: #{root.type}"
    puts "  Root node child_count: #{root.child_count}"
  end
rescue => e
  puts "  ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).join("\n")
end
puts

puts "-" * 70
puts "Step 4: Try TreeHaver.parser_for(:toml)"
puts "-" * 70

begin
  th_parser = TreeHaver.parser_for(:toml)
  puts "  TreeHaver.parser_for(:toml): #{th_parser.class}"
  puts "  Backend: #{th_parser.backend}"

  result = th_parser.parse('key = "value"')
  puts "  Parse result: #{result.class}"
  puts "  Root node type: #{result.root_node.type}"
  puts "  Root node child_count: #{result.root_node.child_count}"
rescue => e
  puts "  ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end
puts

puts "-" * 70
puts "Step 5: Try TreeHaver with explicit MRI backend"
puts "-" * 70

begin
  TreeHaver.with_backend(:mri) do
    th_parser = TreeHaver.parser_for(:toml)
    puts "  TreeHaver.parser_for(:toml) with MRI backend"
    puts "  Parser class: #{th_parser.class}"
    puts "  Backend: #{th_parser.backend}"

    result = th_parser.parse('key = "value"')
    puts "  Parse result: #{result.class}"
    puts "  Root node type: #{result.root_node.type}"
    puts "  Root node child_count: #{result.root_node.child_count}"
  end
rescue => e
  puts "  ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).join("\n")
end
puts

puts "=" * 70
puts "Done!"
puts "=" * 70
