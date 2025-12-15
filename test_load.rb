#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify the FFI backend loads without errors

begin
  require_relative "lib/tree_haver/backends/ffi"
  puts "✓ FFI backend loaded successfully"

  if defined?(TreeHaver::Backends::FFI::Native::TSNode)
    puts "✓ TSNode class is defined"
  else
    puts "✗ TSNode class is NOT defined"
  end

  if TreeHaver::Backends::FFI::Native.respond_to?(:lib_candidates)
    puts "✓ lib_candidates method is available"
  else
    puts "✗ lib_candidates method is NOT available"
  end

  puts "\nAll checks passed! The fix is working."
rescue => e
  puts "✗ Error loading FFI backend:"
  puts "  #{e.class}: #{e.message}"
  puts "\nBacktrace:"
  puts e.backtrace.first(10).map { |line| "  #{line}" }.join("\n")
  exit(1)
end
