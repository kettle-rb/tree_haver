#!/usr/bin/env ruby
# frozen_string_literal: true

# Run all tree_haver examples and report results
#
# This script executes each example and summarizes the results in a table,
# showing which examples passed and which failed.

require "open3"
require "pathname"

EXAMPLES_DIR = __dir__
EXAMPLES = [
  # JSON examples
  {file: "auto_json.rb", name: "JSON (Auto)", backend: "auto", language: "JSON"},
  {file: "mri_json.rb", name: "JSON (MRI)", backend: "mri", language: "JSON"},
  {file: "rust_json.rb", name: "JSON (Rust)", backend: "rust", language: "JSON"},
  {file: "ffi_json.rb", name: "JSON (FFI)", backend: "ffi", language: "JSON"},
  {file: "java_json.rb", name: "JSON (Java)", backend: "java", language: "JSON"},

  # JSONC examples
  {file: "auto_jsonc.rb", name: "JSONC (Auto)", backend: "auto", language: "JSONC"},
  {file: "mri_jsonc.rb", name: "JSONC (MRI)", backend: "mri", language: "JSONC"},
  {file: "rust_jsonc.rb", name: "JSONC (Rust)", backend: "rust", language: "JSONC"},
  {file: "ffi_jsonc.rb", name: "JSONC (FFI)", backend: "ffi", language: "JSONC"},
  {file: "java_jsonc.rb", name: "JSONC (Java)", backend: "java", language: "JSONC"},

  # Bash examples
  {file: "auto_bash.rb", name: "Bash (Auto)", backend: "auto", language: "Bash"},
  {file: "mri_bash.rb", name: "Bash (MRI)", backend: "mri", language: "Bash"},
  {file: "rust_bash.rb", name: "Bash (Rust)", backend: "rust", language: "Bash"},
  {file: "ffi_bash.rb", name: "Bash (FFI)", backend: "ffi", language: "Bash"},
  {file: "java_bash.rb", name: "Bash (Java)", backend: "java", language: "Bash"},

  # Citrus examples
  {file: "citrus_toml.rb", name: "TOML (Citrus)", backend: "citrus", language: "TOML"},
  {file: "citrus_finitio.rb", name: "Finitio (Citrus)", backend: "citrus", language: "Finitio"},
  {file: "citrus_dhall.rb", name: "Dhall (Citrus)", backend: "citrus", language: "Dhall"},
].freeze

# ANSI color codes
GREEN = "\e[32m"
RED = "\e[31m"
YELLOW = "\e[33m"
BLUE = "\e[34m"
RESET = "\e[0m"

def colorize(text, color)
  "#{color}#{text}#{RESET}"
end

def example_compatible_with_engine?(example)
  backend = example[:backend]
  engine = RUBY_ENGINE

  case backend
  when "java"
    engine == "jruby"
  when "mri"
    # MRI backend requires MRI Ruby (C extensions)
    return false unless engine == "ruby"

    # Known incompatibility: MRI backend doesn't work with Bash grammar
    # due to ABI/symbol loading issues between ruby_tree_sitter and bash grammar
    # FFI backend works fine with Bash
    if example[:language] == "Bash"
      return false # Mark as incompatible (will be skipped)
    end

    true
  when "rust"
    # Known incompatibility: Rust backend + Bash has version mismatch
    # tree_stump statically links tree-sitter; system bash.so built with different version
    # This is documented in rust_bash.rb example
    if example[:language] == "Bash"
      return false # Mark as incompatible (will be skipped)
    end

    true
  else
    # auto, ffi, citrus work on all engines
    true
  end
end

def run_example(example, verbose: false)
  file_path = File.join(EXAMPLES_DIR, example[:file])

  unless File.exist?(file_path)
    return {
      success: false,
      status: :missing,
      message: "File not found",
      full_error: "File not found: #{file_path}",
      duration: 0,
    }
  end

  # Skip if not compatible with current engine
  unless example_compatible_with_engine?(example)
    backend = example[:backend]
    reason = if backend == "java"
      "Requires JRuby (current: #{RUBY_ENGINE})"
    elsif backend == "mri" && example[:language] == "Bash"
      "Known incompatibility: MRI+Bash (use FFI backend)"
    elsif backend == "rust" && example[:language] == "Bash"
      "Known incompatibility: Rust+Bash version mismatch (use FFI)"
    else
      "Requires MRI (current: #{RUBY_ENGINE})"
    end

    return {
      success: true, # Count as success (expected skip)
      status: :skipped,
      message: reason,
      duration: 0,
    }
  end

  start_time = Time.now
  stdout, stderr, status = Open3.capture3("ruby", file_path)
  duration = Time.now - start_time

  if status.success?
    {
      success: true,
      status: :passed,
      message: "OK",
      duration: duration,
      output: stdout,
    }
  else
    # Parse error message from output
    full_output = stdout + stderr

    # Check if this is a grammar not found error
    if full_output.include?("grammar not found") || full_output.include?("Install tree-sitter-")
      return {
        success: true, # Count as success (expected unavailable)
        status: :unavailable,
        message: "Grammar library not installed",
        full_error: full_output,
        duration: duration,
      }
    end

    error_msg = if stderr && !stderr.empty?
      # Extract first meaningful error line from stderr
      error_line = stderr.lines.find { |l| l.include?("Error") || l.include?("error") } || stderr.lines.first
      error_line.to_s.strip
    elsif stdout.include?("⚠️")
      "Requires specific Ruby implementation"
    elsif stdout.include?("✗")
      stdout.lines.grep(/✗/).first.to_s.strip
    else
      "Exit code: #{status.exitstatus}"
    end

    {
      success: false,
      status: :failed,
      message: error_msg[0..80],
      full_error: full_output,
      duration: duration,
      output: full_output,
    }
  end
rescue => e
  {
    success: false,
    status: :error,
    message: "#{e.class}: #{e.message}",
    full_error: "#{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}",
    duration: 0,
  }
end

verbose = ARGV.include?("--verbose") || ARGV.include?("-v")

puts "=" * 80
puts "TreeHaver Examples Test Runner"
puts "=" * 80
puts "Verbose mode: #{verbose ? "ON" : "OFF"} (use --verbose or -v for details)"
puts

results = []
total_duration = 0

EXAMPLES.each_with_index do |example, idx|
  print "[#{idx + 1}/#{EXAMPLES.size}] Running #{example[:name]}... "
  $stdout.flush

  result = run_example(example, verbose: verbose)
  results << {example: example, result: result}
  total_duration += result[:duration]

  case result[:status]
  when :passed
    puts colorize("✓ PASS", GREEN) + " (#{result[:duration].round(2)}s)"
  when :skipped
    puts colorize("⊘ SKIP", YELLOW) + " (#{result[:message]})"
  when :unavailable
    puts colorize("◯ N/A", YELLOW) + " (#{result[:message]})"
  when :failed, :error, :missing
    puts colorize("✗ FAIL", RED) + " (#{result[:message][0..50]})"
    if verbose && result[:full_error]
      puts "  Details:"
      result[:full_error].lines.first(10).each do |line|
        puts "    #{line}"
      end
      puts "  ---"
    end
  end
end

puts
puts "=" * 80
puts "Results Summary"
puts "=" * 80
puts

# Group by language
by_language = results.group_by { |r| r[:example][:language] }

by_language.each do |language, lang_results|
  puts colorize("#{language} Examples:", BLUE)
  puts "-" * 80

  # Table header
  printf "  %-20s %-12s %-8s %s\n", "Example", "Backend", "Status", "Message"
  puts "  " + "-" * 76

  lang_results.each do |r|
    example = r[:example]
    result = r[:result]

    status_str = case result[:status]
    when :passed
      colorize("✓ PASS", GREEN)
    when :failed
      colorize("✗ FAIL", RED)
    when :missing
      colorize("⚠ MISS", YELLOW)
    when :skipped
      colorize("⊘ SKIP", YELLOW)
    when :unavailable
      colorize("◯ N/A", YELLOW)
    when :error
      colorize("✗ ERROR", RED)
    end

    printf "  %-20s %-12s %-18s %s\n",
      example[:name],
      example[:backend],
      status_str,
      result[:message]
  end

  puts
end

# Overall statistics
passed = results.count { |r| r[:result][:status] == :passed }
skipped = results.count { |r| r[:result][:status] == :skipped }
unavailable = results.count { |r| r[:result][:status] == :unavailable }
failed = results.count { |r| [:failed, :error, :missing].include?(r[:result][:status]) }
runnable = results.size - skipped - unavailable
pass_rate = (runnable > 0) ? (passed.to_f / runnable * 100).round(1) : 0.0

puts "=" * 80
puts "Overall Statistics"
puts "=" * 80
printf "Total Examples: %d\n", results.size
printf "Passed:         %s (%d/%d runnable)\n", colorize("✓ #{passed}", GREEN), passed, runnable
printf "Skipped:        %s (%d/%d) - Wrong Ruby engine\n", colorize("⊘ #{skipped}", YELLOW), skipped, results.size
printf "Unavailable:    %s (%d/%d) - Grammar not installed\n", colorize("◯ #{unavailable}", YELLOW), unavailable, results.size
printf "Failed:         %s (%d/%d runnable)\n", colorize("✗ #{failed}", RED), failed, runnable
printf "Pass Rate:      %.1f%% (of runnable)\n", pass_rate
printf "Total Duration: %.2f seconds\n", total_duration
printf "Ruby Engine:    %s\n", RUBY_ENGINE
puts

# Detailed failure report
if failed > 0 && !verbose
  puts "=" * 80
  puts "Failed Examples Details"
  puts "=" * 80
  puts

  failed_results = results.select { |r| !r[:result][:success] }
  failed_results.each do |r|
    example = r[:example]
    result = r[:result]

    puts colorize("#{example[:name]} (#{example[:backend]} backend):", RED)
    puts "-" * 80

    if result[:status] == :missing
      puts "  File not found: #{example[:file]}"
    elsif example[:backend] == "java" && result[:message].include?("Requires specific Ruby")
      puts "  Requires JRuby (current: #{RUBY_ENGINE})"
      puts "  This is expected - Java backend only works on JRuby"
    elsif result[:full_error]
      # Show first error line prominently
      error_lines = result[:full_error].lines
      error_line = error_lines.find { |l| l.include?("Error") || l.include?("error") } || error_lines.first
      puts "  Error: #{error_line.strip}"

      # Show context if available
      if error_lines.size > 1
        puts "  Context:"
        error_lines.first(5).each { |line| puts "    #{line.rstrip}" }
        puts "    ..." if error_lines.size > 5
      end
    end

    puts
  end

  puts "Run with --verbose flag for full error output"
  puts
end

# Exit with appropriate status
if failed > 0
  puts colorize("⚠ Some examples failed. See details above.", YELLOW)
  exit 1
else
  puts colorize("✅ All examples passed!", GREEN)
  exit 0
end
