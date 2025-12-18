#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Smart Markdown Merging with Commonmarker Backend
#
# This demonstrates how markdown-merge uses tree_haver's Commonmarker backend
# to intelligently merge a template into a destination file while preserving
# destination customizations.
#
# markdown-merge: Base gem providing SmartMerger for template/destination merging
# tree_haver: Multi-backend parser (using Commonmarker for Markdown)

require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  # stdlib gems
  gem "benchmark"

  # Parser
  gem "commonmarker", ">= 0.23"

  # Load markdown-merge from local path
  gem "markdown-merge", path: File.expand_path("../../markdown-merge", __dir__)

  # AST merging framework
  gem "ast-merge", path: File.expand_path("../../..", __dir__)

  # Tree parsing
  gem "tree_haver", path: File.expand_path("..", __dir__)
end

require "tree_haver"
require "markdown/merge"
require "commonmarker"

puts "=" * 80
puts "Markdown::Merge with Commonmarker Backend"
puts "=" * 80
puts

# Example: Template file (source of updates)
template_markdown = <<~MARKDOWN
  # Project README Template

  ## Overview

  This is the standard project template.

  ## Installation

  ```bash
  gem install my_project
  ```

  ## Features

  - Feature A
  - Feature B
  - Feature C (new in template)

  ## Configuration

  Configure using environment variables.
MARKDOWN

# Example: Destination file (has customizations to preserve)
destination_markdown = <<~MARKDOWN
  # My Awesome Project

  ## Overview

  This is MY custom project description with extra details!

  ## Installation

  ```bash
  # Custom installation steps
  gem install my_project
  bundle install
  ```

  ## Features

  - Feature A
  - Feature B
  - My Custom Feature (keep this!)

  ## Usage

  Here's how I use it in my project...
MARKDOWN

puts "Template (source of updates):"
puts "-" * 80
puts template_markdown
puts

puts "Destination (has customizations to preserve):"
puts "-" * 80
puts destination_markdown
puts

# Force Commonmarker backend
puts "Setting backend to Commonmarker..."
TreeHaver.backend = :commonmarker
puts "✓ Backend: #{TreeHaver.backend_module}"
puts

# Check availability
if TreeHaver::Backends::Commonmarker.available?
  puts "✓ Commonmarker is available"
else
  puts "✗ Commonmarker not found - cannot run example"
  exit 1
end
puts

# Perform the smart merge (template → destination)
puts "Merging template into destination (preserving customizations)..."
puts "-" * 80

merger = Markdown::Merge::SmartMerger.new(
  template_markdown,
  destination_markdown,
  backend: :commonmarker,
)

result = merger.merge_result

puts
puts "Merge Result:"
puts "-" * 80
puts result.content
puts

# Show merge statistics
puts "Merge Statistics:"
puts "-" * 80
puts "  Success: #{result.success?}"
puts "  Nodes Added: #{result.nodes_added}"
puts "  Nodes Modified: #{result.nodes_modified}"
puts "  Nodes Removed: #{result.nodes_removed}"
puts "  Frozen Blocks: #{result.frozen_count}"
puts "  Merge Time: #{result.merge_time_ms}ms"
puts

if result.conflicts?
  puts "Conflicts:"
  puts "-" * 80
  result.conflicts.each_with_index do |conflict, i|
    puts "  Conflict #{i + 1}: #{conflict}"
  end
  puts
end

# Show what was preserved vs merged
puts "Smart Merge Behavior:"
puts "-" * 80
puts "✓ Custom heading preserved: 'My Awesome Project'"
puts "✓ Custom overview text preserved (destination wins)"
puts "✓ Installation section: Destination's custom steps preserved"
puts "✓ Features: Destination's 'My Custom Feature' preserved"
puts "✓ New sections from template: 'Configuration' added"
puts "✓ Destination-only sections preserved: 'Usage'"
puts

# Demonstrate position API usage in merge process
puts "Position API in Action:"
puts "-" * 80
puts "markdown-merge uses tree_haver's Position API to track:"
puts "  - start_line/end_line: 1-based line numbers for each node"
puts "  - source_position: Complete position hash for precise node location"
puts "  - first_child: Navigate AST structure during merge"
puts
puts "This enables intelligent section matching and structure-aware merging!"
puts

puts "=" * 80
puts "Why Use Commonmarker Backend?"
puts "=" * 80
puts "✓ Fast Rust-based parser (comrak)"
puts "✓ Fully CommonMark compliant"
puts "✓ Excellent error tolerance"
puts "✓ Consistent Position API"
puts "✓ Perfect for documentation workflows"
puts "=" * 80
