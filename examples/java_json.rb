#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Java Backend with JSON
#
# Forces the Java backend (JRuby native integration).
# Uses JNI to call tree-sitter - optimal for JRuby.

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "tree_haver", path: File.expand_path("..", __dir__)
end

require "tree_haver"

unless RUBY_ENGINE == "jruby"
  puts "⚠️  This example requires JRuby"
  puts "Current engine: #{RUBY_ENGINE}"
  puts
  puts "To run with JRuby:"
  puts "  jruby examples/java_json.rb"
  puts
  puts "Or install JRuby:"
  puts "  rbenv install jruby-9.4.0.0"
  puts "  rbenv shell jruby-9.4.0.0"
  puts "  ruby examples/java_json.rb"
  exit 1
end

puts "=" * 70
puts "TreeHaver Java Backend - JSON Parsing (JRuby)"
puts "=" * 70
puts

json_source = '{"backend": "Java", "engine": "JRuby", "integration": "JNI"}'

puts "JSON Source: #{json_source}"
puts

# Register JSON
puts "Registering JSON grammar..."
finder = TreeHaver::GrammarFinder.new(:json)
if finder.available?
  finder.register!
  puts "✓ Registered from: #{finder.find_library_path}"
else
  puts "✗ tree-sitter-json not found"
  puts finder.not_found_message
  exit 1
end

# Force Java backend
TreeHaver.backend = :java
puts "Backend: #{TreeHaver.backend_module}"
puts "Capabilities: #{TreeHaver.capabilities.inspect}"
puts "Ruby Engine: #{RUBY_ENGINE} #{JRUBY_VERSION}"
puts

# Parse
parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.json
tree = parser.parse(json_source)

root = tree.root_node
puts "✓ Parsed: #{root.type} with #{root.child_count} children"
puts

# Show structure
root.children.each_with_index do |child, i|
  puts "Child #{i}: #{child.type}"
end
puts

puts "=" * 70
puts "Java Backend:"
puts "  - Native JRuby integration"
puts "  - Uses JNI to call tree-sitter"
puts "  - Optimal performance on JRuby"
puts "  - Takes advantage of JVM optimizations"
puts "  - Best choice for JRuby applications"
puts "=" * 70
