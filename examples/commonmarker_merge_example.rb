#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Smart Markdown Merging with Commonmarker Backend
#
# This demonstrates how markdown-merge uses the commonmarker parser
# to intelligently merge a template into a destination file while preserving
# destination customizations.
#
# markdown-merge: Base gem providing SmartMerger for template/destination merging
# commonmarker-merge: Commonmarker backend integration for markdown-merge

require "bundler/inline"

gemfile do
  source "https://gem.coop"

  # stdlib gems
  gem "benchmark"

  # Parser
  gem "commonmarker", ">= 0.23"

  # Load markdown-merge from local path
  gem "markdown-merge", path: File.expand_path("../../markdown-merge", __dir__)

  # Commonmarker backend for markdown-merge
  gem "commonmarker-merge", path: File.expand_path("../../commonmarker-merge", __dir__)

  # AST merging framework
  gem "ast-merge", path: File.expand_path("../../..", __dir__)

  # Tree parsing
  gem "tree_haver", path: File.expand_path("..", __dir__)
end

require "commonmarker/merge"

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
  result.conflicts.each do |conflict|
    puts "  - #{conflict}"
  end
  puts
end

puts "=" * 80
puts "Why Use SmartMerger?"
puts "=" * 80
puts "1. Preserves destination customizations while updating from template"
puts "2. Node-by-node intelligent comparison (not line-by-line)"
puts "3. Configurable merge strategies per node type"
puts "4. Uses Commonmarker for fast, accurate markdown parsing"
puts "=" * 80
