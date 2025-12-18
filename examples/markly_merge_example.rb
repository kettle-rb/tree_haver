#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Smart GFM Merging with Markly Backend
#
# This demonstrates how markdown-merge uses tree_haver's Markly backend
# to intelligently merge GFM template into destination with customizations.
#
# markdown-merge: Base gem providing SmartMerger for template/destination merging
# tree_haver: Multi-backend parser (using Markly for GFM)

require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  # stdlib gems
  gem "benchmark"

  # Parser
  gem "markly", "~> 0.11"

  # Load markdown-merge from local path
  gem "markdown-merge", path: File.expand_path("../../markdown-merge", __dir__)

  # AST merging framework
  gem "ast-merge", path: File.expand_path("../../..", __dir__)

  # Tree parsing
  gem "tree_haver", path: File.expand_path("..", __dir__)
end

require "tree_haver"
require "markdown/merge"
require "markly" # Explicitly require markly

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

# Force Markly backend
puts "Setting backend to Markly..."
TreeHaver.backend = :markly
puts "✓ Backend: #{TreeHaver.backend_module}"
puts

# Check availability
if TreeHaver::Backends::Markly.available?
  puts "✓ Markly is available"
else
  puts "✗ Markly not found - cannot run example"
  exit 1
end
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

# Show GFM-specific features handled
puts "Smart GFM Merge Behavior:"
puts "-" * 80
puts "✓ Custom heading preserved: 'My API Documentation'"
puts "✓ Tables: Destination's PUT endpoint preserved, DELETE from template added"
puts "✓ Task lists: Destination's custom checkboxes (✅ 🔐) preserved"
puts "✓ Strikethrough from template: ~~500~~ preserved in Rate Limiting"
puts "✓ New sections from template: 'Rate Limiting' added"
puts "✓ Destination-only sections preserved: 'Authentication', 'Custom Notes'"
puts

# Demonstrate position API usage in merge process
puts "Position API in Action:"
puts "-" * 80
puts "markdown-merge uses tree_haver's Position API to track:"
puts "  - start_line/end_line: 1-based line numbers for each GFM node"
puts "  - source_position: Complete position hash for precise node location"
puts "  - first_child: Navigate AST structure (tables, lists, etc.)"
puts
puts "Markly provides additional GFM-specific node types:"
puts "  - table nodes with rows and cells"
puts "  - tasklist items with checkbox state"
puts "  - strikethrough, autolinks, etc."
puts

puts "=" * 80
puts "Why Use Markly Backend for GFM?"
puts "=" * 80
puts "✓ GitHub's official Markdown implementation (cmark-gfm)"
puts "✓ Full GFM extension support (tables, strikethrough, task lists)"
puts "✓ Type normalization for consistency"
puts "✓ Perfect for GitHub-style documentation template merging"
puts
puts "Use Cases:"
puts "  - Update project READMEs from template while preserving customizations"
puts "  - Merge API documentation updates with custom endpoints"
puts "  - Maintain consistent structure across team documentation"
puts "  - Preserve team-specific task lists and tables"
puts "=" * 80
