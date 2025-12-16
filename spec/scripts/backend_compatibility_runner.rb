#!/usr/bin/env ruby
# frozen_string_literal: true

# Backend Compatibility Test Runner
#
# This script tests backend combinations in separate processes to avoid
# symbol conflicts that occur when multiple backends are loaded together.
#
# Usage:
#   ruby spec/scripts/backend_compatibility_runner.rb
#   ruby spec/scripts/backend_compatibility_runner.rb --verbose
#   ruby spec/scripts/backend_compatibility_runner.rb --backend ffi
#   ruby spec/scripts/backend_compatibility_runner.rb --test "ffi -> mri"

require "open3"
require "json"

BACKENDS = %w[mri ffi rust citrus].freeze

# Test a single backend in isolation
def test_single_backend(backend, verbose: false)
  script = <<~RUBY
    require "bundler/setup"
    require "tree_haver"

    begin
      case "#{backend}"
      when "citrus"
        require "toml-rb"
      end

      available = case "#{backend}"
      when "mri" then TreeHaver::Backends::MRI.available?
      when "ffi" then TreeHaver::Backends::FFI.available?
      when "rust" then TreeHaver::Backends::Rust.available?
      when "citrus" then TreeHaver::Backends::Citrus.available?
      end

      unless available
        puts JSON.generate({ status: "skip", reason: "not available" })
        exit 0
      end

      path = ENV["TREE_SITTER_TOML_PATH"]

      TreeHaver.with_backend(:#{backend}) do
        lang = case "#{backend}"
        when "citrus"
          TreeHaver::Backends::Citrus::Language.new(TomlRB::Document)
        else
          TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
        end

        parser = TreeHaver::Parser.new
        parser.language = lang
        tree = parser.parse("x = 42")
        root_type = tree.root_node.type

        puts JSON.generate({ status: "pass", root_type: root_type })
      end
    rescue => e
      puts JSON.generate({ status: "fail", error: e.class.to_s, message: e.message })
      exit 1
    end
  RUBY

  run_ruby_script(script, verbose: verbose)
end

# Test a backend transition (A then B)
def test_backend_transition(first, second, verbose: false)
  script = <<~RUBY
    require "bundler/setup"
    require "tree_haver"

    results = {}

    begin
      # Load toml-rb if needed for citrus
      require "toml-rb" if "#{first}" == "citrus" || "#{second}" == "citrus"

      path = ENV["TREE_SITTER_TOML_PATH"]

      # First backend
      first_available = case "#{first}"
      when "mri" then TreeHaver::Backends::MRI.available?
      when "ffi" then TreeHaver::Backends::FFI.available?
      when "rust" then TreeHaver::Backends::Rust.available?
      when "citrus" then TreeHaver::Backends::Citrus.available?
      end

      unless first_available
        puts JSON.generate({ status: "skip", reason: "#{first} not available" })
        exit 0
      end

      TreeHaver.with_backend(:#{first}) do
        lang = case "#{first}"
        when "citrus"
          TreeHaver::Backends::Citrus::Language.new(TomlRB::Document)
        else
          TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
        end

        parser = TreeHaver::Parser.new
        parser.language = lang
        tree = parser.parse("x = 42")
        results[:first] = { status: "pass", root_type: tree.root_node.type }
      end

      TreeHaver::LanguageRegistry.clear_cache!

      # Second backend
      second_available = case "#{second}"
      when "mri" then TreeHaver::Backends::MRI.available?
      when "ffi" then TreeHaver::Backends::FFI.available?
      when "rust" then TreeHaver::Backends::Rust.available?
      when "citrus" then TreeHaver::Backends::Citrus.available?
      end

      unless second_available
        results[:second] = { status: "blocked", reason: "#{second} not available after #{first}" }
        puts JSON.generate({ status: "blocked", results: results })
        exit 0
      end

      TreeHaver.with_backend(:#{second}) do
        lang = case "#{second}"
        when "citrus"
          TreeHaver::Backends::Citrus::Language.new(TomlRB::Document)
        else
          TreeHaver::Language.from_library(path, symbol: "tree_sitter_toml")
        end

        parser = TreeHaver::Parser.new
        parser.language = lang
        tree = parser.parse("x = 42")
        results[:second] = { status: "pass", root_type: tree.root_node.type }
      end

      puts JSON.generate({ status: "pass", results: results })
    rescue => e
      results[:error] = { class: e.class.to_s, message: e.message }
      puts JSON.generate({ status: "fail", results: results })
      exit 1
    end
  RUBY

  run_ruby_script(script, verbose: verbose)
end

def run_ruby_script(script, verbose: false)
  # Write script to temp file
  require "tempfile"

  Tempfile.create(["backend_test", ".rb"]) do |f|
    f.write(script)
    f.flush

    stdout, stderr, status = Open3.capture3(
      {"BUNDLE_GEMFILE" => File.expand_path("../../Gemfile", __dir__)},
      "ruby",
      f.path,
      chdir: File.expand_path("../..", __dir__),
    )

    if verbose
      $stderr.puts "STDERR: #{stderr}" unless stderr.empty?
    end

    begin
      result = JSON.parse(stdout.strip)
      [result, status.success?]
    rescue JSON::ParserError
      [{"status" => "error", "output" => stdout, "stderr" => stderr}, false]
    end
  end
end

def print_result(test_name, result, success)
  status = result["status"]
  icon = case status
  when "pass" then "✓"
  when "skip" then "○"
  when "blocked" then "⊘"
  when "fail" then "✗"
  else "?"
  end

  color = case status
  when "pass" then "\e[32m"      # green
  when "skip" then "\e[33m"      # yellow
  when "blocked" then "\e[35m"   # magenta
  when "fail" then "\e[31m"      # red
  else "\e[37m"                  # white
  end

  reset = "\e[0m"

  details = case status
  when "pass"
    result["root_type"] || result.dig("results", "second", "root_type") || ""
  when "skip", "blocked"
    result["reason"] || result.dig("results", "second", "reason") || ""
  when "fail"
    result["message"] || result.dig("results", "error", "message") || result.dig("error", "message") || ""
  else
    result.inspect
  end

  puts "#{color}#{icon}#{reset} #{test_name}: #{details}"
end

# Main execution
verbose = ARGV.include?("--verbose") || ARGV.include?("-v")
specific_backend = ARGV.find { |a| a.start_with?("--backend=") }&.split("=")&.last
specific_test = ARGV.find { |a| a.start_with?("--test=") }&.split("=", 2)&.last

puts "=" * 70
puts "Backend Compatibility Matrix Test"
puts "=" * 70
puts

# Single backend tests
puts "Single Backend Operations:"
puts "-" * 40

BACKENDS.each do |backend|
  next if specific_backend && backend != specific_backend
  next if specific_test

  result, success = test_single_backend(backend, verbose: verbose)
  print_result("  #{backend}", result, success)
end

puts

# Transition tests (A -> B)
puts "Backend Transitions (A -> B):"
puts "-" * 40

BACKENDS.each do |first|
  BACKENDS.each do |second|
    next if first == second
    next if specific_backend && first != specific_backend && second != specific_backend
    next if specific_test && specific_test != "#{first} -> #{second}"

    result, success = test_backend_transition(first, second, verbose: verbose)
    print_result("  #{first} -> #{second}", result, success)
  end
end

puts
puts "=" * 70
puts "Legend: ✓ pass  ○ skip  ⊘ blocked  ✗ fail"
puts "=" * 70
