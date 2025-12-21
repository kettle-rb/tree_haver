# GitHub Copilot Instructions for ast-merge

This document contains important information for AI assistants working on this codebase.

## Tool Usage Preferences

### Prefer Internal Tools Over Terminal Commands

**IMPORTANT**: Copilot cannot see terminal output. Every terminal command requires the user to manually copy/paste the output back to the chat. This is slow and frustrating.

✅ **PREFERRED** - Use internal tools:
- `grep_search` instead of `grep` command
- `file_search` instead of `find` command
- `read_file` instead of `cat` command
- `list_dir` instead of `ls` command
- `replace_string_in_file` or `create_file` instead of `sed` / manual editing

❌ **AVOID** when possible:
- `run_in_terminal` for information gathering
- Running grep/find/cat in terminal

Only use terminal for:
- Running tests (`bundle exec rspec`)
- Installing dependencies (`bundle install`)
- Git operations that require interaction
- Commands that actually need to execute (not just gather info)

## Search Tool Limitations

### grep_search and Nested Git Projects

**CRITICAL**: The `vendor/*` directories in this workspace are **nested git projects** (they have their own `.git/` directory, separated from the parent by gitignore patterns). The `grep_search` tool **CANNOT search inside nested git projects** - it only searches the main workspace.

To search inside vendor gems:
1. Use `read_file` to read specific files directly (this always works)
2. Use `list_dir` to explore the directory structure
3. Do NOT rely on `grep_search` with `includePattern: "vendor/**"` - it will return no results

**Working approach for finding code in vendor gems:**
```
# Step 1: List the directory structure
list_dir("/home/pboling/src/kettle-rb/ast-merge/vendor/markdown-merge/lib/markdown/merge")

# Step 2: Read specific files you need to search
read_file("/home/pboling/src/kettle-rb/ast-merge/vendor/markdown-merge/lib/markdown/merge/file_analysis.rb", 0, 100)

# Step 3: If looking for a specific method, read more of the file or multiple files
```

### grep_search includePattern (for non-nested-git directories)

**IMPORTANT**: The `includePattern` parameter uses glob patterns relative to the workspace root.

✅ **WORKS** - Use these patterns:
```
# Search recursively within a directory (use ** for recursive)
includePattern: "vendor/**"           # All files under vendor/
includePattern: "vendor/kettle-dev/**" # All files under vendor/kettle-dev/

# Search a specific file
includePattern: "vendor/prism-merge/README.md"
includePattern: "lib/ast/merge/freezable.rb"

# Search files matching a pattern in a specific directory
includePattern: "spec/**"              # All spec files recursively
```

❌ **DOES NOT WORK** - Avoid these:
```
# The | character does NOT work for alternation in includePattern
includePattern: "vendor/prism-merge/**|vendor/kettle-dev/**"

# Cannot use ** in the middle of a path with file extension
includePattern: "vendor/**/spec/**/*.rb"  # Too complex, may fail
```

**Key insights:**
- `vendor/**` searches ALL files recursively under vendor/ (including subfolders)
- Without `includePattern`, `grep_search` searches the ENTIRE workspace (root project only, may miss vendor submodules)
- For vendor gems, always use `includePattern: "vendor/**"` or `includePattern: "vendor/gem-name/**"`
- To search multiple specific locations, make separate `grep_search` calls

### replace_string_in_file and Unicode Characters

**IMPORTANT**: The `replace_string_in_file` tool can fail silently when files contain special Unicode characters like:
- Curly apostrophes (`'` U+2019 instead of `'`)
- Em-dashes (`—` U+2014 instead of `-`)
- Emoji (🔧, 🎨, etc.)

When `replace_string_in_file` fails with "Could not find matching text":
1. The file likely contains Unicode characters that don't match what you're sending
2. Try using a smaller, more unique portion of the text
3. Avoid including lines with emojis or special punctuation in your oldString
4. Use `read_file` to see the exact content, but be aware the display may normalize characters

## Project Structure

- `lib/ast/merge/` - Base library classes (ast-merge gem)
- `vendor/prism-merge/` - Ruby/Prism-specific merge implementation
- `vendor/*/` - Other format-specific merge implementations (markly-merge, json-merge, etc.)

## API Conventions

### SmartMergerBase API
- `merge` - Returns a **String** (the merged content)
- `merge_result` - Returns a **MergeResult** object
- `to_s` on MergeResult returns the merged content as a string

### Comment Classes
- `Ast::Merge::Comment::*` - Generic, language-agnostic comment classes
- `Prism::Merge::Comment::*` - Ruby-specific comment classes with magic comment detection

### Naming Conventions
- File paths must match class paths (Ruby convention)
- Example: `Ast::Merge::Comment::Line` → `lib/ast/merge/comment/line.rb`

## Architecture Notes

### prism-merge (as of December 2024)
- Uses section-based merging with recursive body merging
- Does NOT use FileAligner or ConflictResolver (these were removed as vestigial)
- SmartMerger handles all merge logic directly
- Comment-only files are handled via `Ast::Merge::Text::SmartMerger`

## Loading Vendor Gems in Scripts

**IMPORTANT**: When writing standalone Ruby scripts to test vendor gems, you must use `bundler/setup` to properly load the gems.

✅ **CORRECT** - Use bundler/setup:
```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "prism/merge"

# Now you can use Prism::Merge classes
```

❌ **BROKEN** - These do NOT work:
```ruby
# This doesn't load the gem properly:
require_relative "lib/prism/merge"

# This doesn't set up the load path:
require "prism/merge"  # without bundler/setup first
```

The pattern `require "bundler/setup"` followed by `require "gem/name"` works because:
1. `bundler/setup` configures the load path based on the Gemfile
2. The vendor gems are specified in the Gemfile with `path:` option
3. This allows standard `require` to find the gems

## Testing

Run tests from the appropriate directory:
```bash
# ast-merge tests
cd /var/home/pboling/src/kettle-rb/ast-merge
bundle exec rspec spec/

# prism-merge tests
cd /var/home/pboling/src/kettle-rb/ast-merge/vendor/prism-merge
bundle exec rspec spec/
```

### Coverage Reports

To generate a coverage report for any vendor gem:
```bash
cd /var/home/pboling/src/kettle-rb/ast-merge/vendor/prism-merge  # or other vendor gem
bin/rake coverage && bin/kettle-soup-cover -d
```

This runs tests with coverage instrumentation and generates detailed coverage reports in the `coverage/` directory.

## Common Pitfalls

1. **NEVER add backward compatibility** - The maintainer explicitly prohibits backward compatibility shims, aliases, or deprecation layers. Make clean breaks.
2. **Magic comments** - Ruby-specific, belong in prism-merge not ast-merge
3. **`content_string` is legacy** - Use `to_s` instead
4. **`merged_source` doesn't exist** - `merge` returns a String directly

## Terminal Command Restrictions

### Terminal Session Management

**How `run_in_terminal` works**:
- The tool sends commands to a **single persistent Copilot terminal**
- Use `isBackground=false` for `run_in_terminal`. Sometimes it works, but if it fails/hangs, use the file redirection method, and then read back with `read_file` tool.
- Commands run in sequence in the same terminal session
- Environment variables and working directory persist between calls
- The first command in a session either does not run at all, or runs before the shell initialization (direnv, motd, etc.) so it should always be a noop, like `true`.

**When things go wrong**:
- If output shows only shell banner/motd without command results, the command most likely worked, but the tool has lost the ability to see terminal output. This happens FREQUENTLY.
- EVERY TIME you do not see output, STOP and confirm output status with the user, or switch immediately to file redirection, and read the file back with `read_file` tool.
- Solution: Ask the user to share the output they see.

**Best practices**:
1. **Combine related commands** - Use `&&` to chain commands:
   ```bash
   cd /path && bundle exec rspec spec/some_spec.rb
   ```
2. **Use `get_terminal_output`** - Check output of background processes
3. **Prefer internal tools** - Use `grep_search`, `read_file`, `list_dir` instead of terminal for information gathering

### NEVER Pipe Test Commands Through head/tail

**CRITICAL**: NEVER use `head`, `tail`, or any output truncation with test commands (`rspec`, `rake`, `bundle exec rspec`, etc.).

❌ **ABSOLUTELY FORBIDDEN**:
```bash
bundle exec rspec 2>&1 | tail -50
bin/rake coverage 2>&1 | head -100
bin/rspec | tail -200
```

✅ **CORRECT** - Run commands without truncation:
```bash
bundle exec rspec
bin/rake coverage
bin/rspec
```

**Why**: 
- You cannot predict how much output a test run will produce
- Your predictions are ALWAYS wrong
- You cannot see terminal output anyway - the user will copy relevant portions for you
- Truncating output often hides the actual errors or relevant information
- The user knows what's important and will share it with you
