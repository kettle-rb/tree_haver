#!/usr/bin/env ruby
# frozen_string_literal: true

# Validate all available backends for API compliance
#
# Usage:
#   ruby examples/validate_backends.rb
#
# This script checks each backend module for API compliance with the
# TreeHaver::BackendAPI contract.

require "bundler/setup"
require "tree_haver"

puts "=" * 70
puts "TreeHaver Backend API Validation"
puts "=" * 70
puts
puts "Ruby: #{RUBY_ENGINE} #{RUBY_VERSION}"
puts

# All known backends
BACKENDS = {
  mri: TreeHaver::Backends::MRI,
  ffi: TreeHaver::Backends::FFI,
  rust: TreeHaver::Backends::Rust,
  java: TreeHaver::Backends::Java,
  citrus: TreeHaver::Backends::Citrus,
  prism: TreeHaver::Backends::Prism,
  psych: TreeHaver::Backends::Psych,
  commonmarker: TreeHaver::Backends::Commonmarker,
  markly: TreeHaver::Backends::Markly,
}.freeze

results_summary = {
  valid: [],
  invalid: [],
  unavailable: [],
}

BACKENDS.each do |name, backend_module|
  puts "-" * 70
  puts "Backend: #{name}"
  puts "-" * 70

  # Check availability first
  unless backend_module.available?
    puts "  Status: NOT AVAILABLE"
    puts "  Reason: #{backend_module.respond_to?(:load_error) ? backend_module.load_error : "Unknown"}"
    results_summary[:unavailable] << name
    puts
    next
  end

  puts "  Status: AVAILABLE"
  puts "  Capabilities: #{backend_module.capabilities.inspect}"

  # Validate API compliance
  results = TreeHaver::BackendAPI.validate(backend_module)

  if results[:valid]
    puts "  API Validation: PASSED"
    results_summary[:valid] << name
  else
    puts "  API Validation: FAILED"
    results_summary[:invalid] << name
  end

  if results[:errors].any?
    puts "  Errors:"
    results[:errors].each { |e| puts "    - #{e}" }
  end

  if results[:warnings].any?
    puts "  Warnings:"
    results[:warnings].each { |w| puts "    - #{w}" }
  end

  if results[:capabilities][:node]
    puts "  Node methods:"
    puts "    Required: #{results[:capabilities][:node][:required].join(", ")}"
    puts "    Optional: #{results[:capabilities][:node][:optional].join(", ")}"
  end

  puts
end

puts "=" * 70
puts "Summary"
puts "=" * 70
puts
puts "Valid backends:       #{results_summary[:valid].empty? ? "None" : results_summary[:valid].join(", ")}"
puts "Invalid backends:     #{results_summary[:invalid].empty? ? "None" : results_summary[:invalid].join(", ")}"
puts "Unavailable backends: #{results_summary[:unavailable].empty? ? "None" : results_summary[:unavailable].join(", ")}"
puts
puts "Total: #{results_summary[:valid].size} valid, " \
  "#{results_summary[:invalid].size} invalid, " \
  "#{results_summary[:unavailable].size} unavailable"
