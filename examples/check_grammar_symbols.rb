#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to check grammar symbols
#
# Run from tree_haver directory with MRI Ruby:
#   ruby examples/check_grammar_symbols.rb

toml_path = ENV["TREE_SITTER_TOML_PATH"] || "/home/pboling/.local/lib/tree-sitter/libtree-sitter-toml.so"

puts "=" * 70
puts "Checking Grammar Symbols"
puts "=" * 70
puts

puts "Grammar file: #{toml_path}"
puts "File exists: #{File.exist?(toml_path)}"
puts "File size: #{File.size(toml_path)} bytes" if File.exist?(toml_path)
puts

# Check symbols using nm
puts "-" * 70
puts "Exported symbols (nm -D):"
puts "-" * 70
system("nm -D #{toml_path} 2>&1 | grep -i tree_sitter")
puts

# Check with objdump
puts "-" * 70
puts "Dynamic symbols (objdump -T):"
puts "-" * 70
system("objdump -T #{toml_path} 2>&1 | grep -i tree_sitter")
puts

# Check if it's a valid ELF
puts "-" * 70
puts "File type:"
puts "-" * 70
system("file #{toml_path}")
puts

# Check library dependencies
puts "-" * 70
puts "Library dependencies (ldd):"
puts "-" * 70
system("ldd #{toml_path} 2>&1")
puts

# Try to dlopen and get error
puts "-" * 70
puts "Trying to load with Ruby Fiddle:"
puts "-" * 70
require "fiddle"
begin
  lib = Fiddle.dlopen(toml_path)
  puts "  dlopen succeeded!"
  puts "  Library handle: #{lib.inspect}"

  # Try to find the symbol
  begin
    func = lib["tree_sitter_toml"]
    puts "  tree_sitter_toml symbol found: #{func.inspect}"
  rescue Fiddle::DLError => e
    puts "  tree_sitter_toml symbol NOT found: #{e.message}"
  end
rescue Fiddle::DLError => e
  puts "  dlopen failed: #{e.message}"
end
puts

puts "=" * 70
puts "Done!"
puts "=" * 70
