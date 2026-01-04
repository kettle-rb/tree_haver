#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify backend environment variables affect dependency tag availability
#
# Environment Variables:
#   TREE_HAVER_BACKEND - Single backend selection (auto, mri, ffi, rust, java, citrus, etc.)
#   TREE_HAVER_NATIVE_BACKEND - Allow list for native backends (all, none, or comma-separated)
#   TREE_HAVER_RUBY_BACKEND - Allow list for pure Ruby backends (all, none, or comma-separated)
#
# Usage (from tree_haver root directory):
#   # Test single backend selection
#   TREE_HAVER_BACKEND=mri bundle exec ruby examples/backend_selection.rb
#
#   # Test native backend restriction
#   TREE_HAVER_NATIVE_BACKEND=mri,ffi bundle exec ruby examples/backend_selection.rb
#
#   # Test pure Ruby only (no native backends)
#   TREE_HAVER_NATIVE_BACKEND=none bundle exec ruby examples/backend_selection.rb
#
#   # Combine: select MRI, but only allow citrus for Ruby
#   TREE_HAVER_BACKEND=mri TREE_HAVER_RUBY_BACKEND=citrus bundle exec ruby examples/backend_selection.rb

require "bundler/setup"
require "rspec"
require_relative "../lib/tree_haver/rspec/dependency_tags"

deps = TreeHaver::RSpec::DependencyTags

puts "=" * 70
puts "Testing TreeHaver Backend Environment Variables"
puts "=" * 70
puts

puts "Environment Variables:"
puts "  TREE_HAVER_BACKEND:        #{ENV["TREE_HAVER_BACKEND"].inspect}"
puts "  TREE_HAVER_NATIVE_BACKEND: #{ENV["TREE_HAVER_NATIVE_BACKEND"].inspect}"
puts "  TREE_HAVER_RUBY_BACKEND:   #{ENV["TREE_HAVER_RUBY_BACKEND"].inspect}"
puts

puts "Parsed Values:"
puts "  selected_backend:        #{deps.selected_backend.inspect}"
puts "  allowed_native_backends: #{deps.allowed_native_backends.inspect}"
puts "  allowed_ruby_backends:   #{deps.allowed_ruby_backends.inspect}"
puts

puts "Backend allowed? checks:"
puts "  Native backends:"
[:mri, :ffi, :rust, :java].each do |backend|
  allowed = deps.backend_allowed?(backend)
  puts "    #{backend}: #{allowed ? "✓ allowed" : "✗ NOT allowed"}"
end
puts "  Ruby backends:"
[:citrus, :prism, :psych, :commonmarker, :markly].each do |backend|
  allowed = deps.backend_allowed?(backend)
  puts "    #{backend}: #{allowed ? "✓ allowed" : "✗ NOT allowed"}"
end
puts

puts "Backend availability (actual checks):"
puts "  Native backends:"
puts "    ffi_backend:  #{begin
  deps.ffi_available?
rescue
  $!.class
end}"
puts "    mri_backend:  #{begin
  deps.mri_backend_available?
rescue
  $!.class
end}"
puts "    rust_backend: #{begin
  deps.rust_backend_available?
rescue
  $!.class
end}"
puts "    java_backend: #{begin
  deps.java_backend_available?
rescue
  $!.class
end}"
puts "  Ruby backends:"
puts "    citrus_backend:      #{begin
  deps.citrus_available?
rescue
  $!.class
end}"
puts "    prism_backend:       #{begin
  deps.prism_available?
rescue
  $!.class
end}"
puts "    psych_backend:       #{begin
  deps.psych_available?
rescue
  $!.class
end}"
puts "    commonmarker_backend: #{begin
  deps.commonmarker_available?
rescue
  $!.class
end}"
puts "    markly_backend:      #{begin
  deps.markly_available?
rescue
  $!.class
end}"
puts

puts "=" * 70
puts "EXPECTED BEHAVIOR:"
puts "=" * 70

native_env = ENV["TREE_HAVER_NATIVE_BACKEND"]
ruby_env = ENV["TREE_HAVER_RUBY_BACKEND"]

puts "\nNative backends (TREE_HAVER_NATIVE_BACKEND=#{native_env.inspect}):"
case native_env&.downcase
when nil, "", "auto"
  puts "  Auto-select from available native backends (default)"
when "none"
  puts "  NO native backends allowed - pure Ruby only mode"
else
  puts "  Only these native backends allowed: #{native_env}"
end

puts "\nRuby backends (TREE_HAVER_RUBY_BACKEND=#{ruby_env.inspect}):"
case ruby_env&.downcase
when nil, "", "auto"
  puts "  Auto-select from available Ruby backends (default)"
when "none"
  puts "  NO Ruby backends allowed - native only mode"
else
  puts "  Only these Ruby backends allowed: #{ruby_env}"
end
