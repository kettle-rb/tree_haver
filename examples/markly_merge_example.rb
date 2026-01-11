#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Smart GFM Merging with Markly Backend
#
# This demonstrates how markdown-merge uses the markly parser
# to intelligently merge GFM template into destination with customizations.
#
# markdown-merge: Base gem providing SmartMerger for template/destination merging
# markly-merge: Markly backend integration for markdown-merge

require "bundler/inline"

gemfile do
  source "https://gem.coop"

  # stdlib gems
  gem "benchmark"

  # Parser
  gem "markly", "~> 0.12"

  # Load markdown-merge from local path
  gem "markdown-merge", path: File.expand_path("../../markdown-merge", __dir__)

  # Markly backend for markdown-merge
  gem "markly-merge", path: File.expand_path("../../markly-merge", __dir__)

  # AST merging framework
  gem "ast-merge", path: File.expand_path("../../..", __dir__)

  # Tree parsing
  gem "tree_haver", path: File.expand_path("..", __dir__)
end

require "markly/merge"

puts "=" * 80
puts "Markdown::Merge with Markly Backend (GitHub Flavored Markdown)"
puts "=" * 80
puts

# Example: GFM Template (with tables and task lists)
template_markdown = <<~MARKDOWN
  # API Documentation Template

  ## Endpoints

  | Method | Path | Description |
  |--------|------|-------------|
  | GET | /api/users | List users |
  | POST | /api/users | Create user |
  | DELETE | /api/users/:id | Delete user |

  ## Tasks

  - [x] Implement GET endpoint
  - [ ] Implement POST endpoint
  - [ ] Implement DELETE endpoint
  - [ ] Add authentication

  ## Rate Limiting

  Standard rate limit: ~~500~~ 1000 requests/hour.
MARKDOWN

# Example: Destination file (has customizations)
destination_markdown = <<~MARKDOWN
  # My API Documentation

  ## Endpoints

  | Method | Path | Description |
  |--------|------|-------------|
  | GET | /api/users | List all users |
  | POST | /api/users | Create new user |
  | PUT | /api/users/:id | Update user (custom) |

  ## Tasks

  - [x] Implement GET endpoint
  - [x] Implement POST endpoint ✅
  - [x] Add authentication 🔐

  ## Authentication

  Using JWT tokens with refresh tokens.

  ## Custom Notes

  My specific implementation details here.
MARKDOWN

puts "Template (GFM with tables and tasks):"
puts "-" * 80
puts template_markdown
puts

puts "Destination (with customizations):"
puts "-" * 80
puts destination_markdown
puts

# Perform the smart merge (template → destination)
puts "Merging GFM template into destination (preserving customizations)..."
puts "-" * 80

merger = Markdown::Merge::SmartMerger.new(
  template_markdown,
  destination_markdown,
  backend: :markly,
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

puts "=" * 80
puts "Why Use SmartMerger with Markly?"
puts "=" * 80
puts "1. Preserves destination customizations while updating from template"
puts "2. Full GFM support (tables, task lists, strikethrough, autolinks)"
puts "3. Node-by-node intelligent comparison (not line-by-line)"
puts "4. Uses GitHub's official cmark-gfm library"
puts "=" * 80
