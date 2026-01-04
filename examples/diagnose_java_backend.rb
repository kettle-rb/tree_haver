#!/usr/bin/env ruby
# frozen_string_literal: true

# Diagnostic script to check Java backend availability
#
# Usage (from tree_haver root directory):
#   jruby examples/diagnose_java_backend.rb

puts "=" * 70
puts "Java Backend Diagnostics"
puts "=" * 70
puts

puts "Ruby Engine: #{RUBY_ENGINE}"
puts "Ruby Version: #{RUBY_VERSION}"
puts

puts "Environment Variables:"
puts "  TREE_SITTER_JAVA_JARS_DIR: #{ENV["TREE_SITTER_JAVA_JARS_DIR"].inspect}"
puts "  TREE_SITTER_RUNTIME_LIB:   #{ENV["TREE_SITTER_RUNTIME_LIB"].inspect}"
puts "  TREE_SITTER_TOML_PATH:     #{ENV["TREE_SITTER_TOML_PATH"].inspect}"
puts "  CLASSPATH:                 #{ENV["CLASSPATH"]&.split(":")&.first(3)&.join(":")}..."
puts

unless RUBY_ENGINE == "jruby"
  puts "ERROR: This script must be run with JRuby!"
  puts "Usage: jruby examples/diagnose_java_backend.rb"
  exit 1
end

puts "JRuby-specific checks:"
puts

# Check Java availability
begin
  require "java"
  puts "  ✓ Java bridge available"
rescue LoadError => e
  puts "  ✗ Java bridge NOT available: #{e.message}"
  exit(1)
end

# Check for jtreesitter JAR
jars_dir = ENV["TREE_SITTER_JAVA_JARS_DIR"]
if jars_dir && Dir.exist?(jars_dir)
  jars = Dir[File.join(jars_dir, "**", "*.jar")]
  puts "  ✓ TREE_SITTER_JAVA_JARS_DIR exists: #{jars_dir}"
  puts "    JARs found: #{jars.map { |j| File.basename(j) }.join(", ")}"
else
  puts "  ✗ TREE_SITTER_JAVA_JARS_DIR not set or directory doesn't exist"
  puts "    Run: bin/setup-jtreesitter"
end
puts

# Try loading tree_haver
puts "Loading tree_haver..."
require "bundler/setup"
require "tree_haver"
puts "  ✓ tree_haver loaded"
puts

# Check Java backend
puts "Java Backend Status:"
backend = TreeHaver::Backends::Java

puts "  available?: #{backend.available?}"
if backend.respond_to?(:load_error) && backend.load_error
  puts "  load_error: #{backend.load_error}"
end
puts

# Check if classes loaded
if backend.available?
  puts "  Java classes loaded:"
  backend.java_classes.each do |name, klass|
    puts "    #{name}: #{klass}"
  end
  puts

  puts "  Capabilities: #{backend.capabilities.inspect}"
  puts
end

# Try loading a grammar
puts "Grammar Loading Test:"
toml_path = ENV["TREE_SITTER_TOML_PATH"]
if toml_path && File.exist?(toml_path)
  puts "  TOML grammar path: #{toml_path}"
  puts "  File exists: #{File.exist?(toml_path)}"
  puts "  File size: #{File.size(toml_path)} bytes"

  # Check the file with nm to see exported symbols
  puts ""
  puts "  Checking exported symbols:"
  symbols = begin
    %x(nm -D "#{toml_path}" 2>/dev/null | grep tree_sitter).strip
  rescue
    "nm not available"
  end
  puts "    #{symbols.empty? ? "No tree_sitter symbols found" : symbols.split("\n").first(3).join("\n    ")}"
  puts ""

  begin
    TreeHaver.with_backend(:java) do
      lang = TreeHaver::Backends::Java::Language.from_library(toml_path, symbol: "tree_sitter_toml")
      puts "  ✓ Grammar loaded successfully!"
      puts "    Language: #{lang.inspect}"
    end
  rescue => e
    puts "  ✗ Grammar loading failed!"
    puts "    Error class: #{e.class}"
    puts "    Error message: #{e.message}"
    puts ""
    puts "  Full backtrace:"
    e.backtrace.first(10).each { |line| puts "    #{line}" }
  end
else
  puts "  ✗ TREE_SITTER_TOML_PATH not set or file doesn't exist"
  puts "    Value: #{toml_path.inspect}"
end
puts

# Also test the dependency tag check directly
puts "Dependency Tag Check:"
require "rspec"
require_relative "../lib/tree_haver/rspec/dependency_tags"
deps = TreeHaver::RSpec::DependencyTags
puts "  jruby?: #{deps.jruby?}"
puts "  backend_allowed?(:java): #{deps.backend_allowed?(:java)}"
puts "  TreeHaver::Backends::Java.available?: #{TreeHaver::Backends::Java.available?}"
puts "  java_grammar_loadable?: #{deps.send(:java_grammar_loadable?)}"
puts "  java_backend_available?: #{deps.java_backend_available?}"
puts

puts "=" * 70
puts "SETUP INSTRUCTIONS"
puts "=" * 70
puts
puts "1. Install jtreesitter JAR:"
puts "   bin/setup-jtreesitter"
puts
puts "2. Add to your .envrc or shell profile:"
puts "   export TREE_SITTER_JAVA_JARS_DIR=\"$HOME/.local/share/jtreesitter\""
puts
puts "3. Ensure libtree-sitter.so is available:"
puts "   export TREE_SITTER_RUNTIME_LIB=\"/usr/local/lib/libtree-sitter.so\""
puts "   # or wherever your libtree-sitter is installed"
puts
puts "4. Ensure grammar .so files are available:"
puts "   export TREE_SITTER_TOML_PATH=\"/usr/local/lib/libtree-sitter-toml.so\""
puts
