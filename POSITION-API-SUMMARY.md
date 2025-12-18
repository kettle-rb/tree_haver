# Position API

**Date:** December 18, 2025
**Feature:** Unified Position API for all tree_haver backends
**Version:** Unreleased (planned for v3.1.0)

---

## What Was Done

Added four position-related methods to all tree_haver backend Node classes to provide a consistent API for position information across all backends:

### New Methods

1. **`start_line`** - Returns 1-based line number where node starts
   - Converts 0-based row to 1-based line number
   - Formula: `start_point.row + 1` (or uses backend's native 1-based line if available)

2. **`end_line`** - Returns 1-based line number where node ends
   - Converts 0-based row to 1-based line number
   - Formula: `end_point.row + 1` (or uses backend's native 1-based line if available)

3. **`source_position`** - Returns position hash with 1-based lines and 0-based columns
   - Format: `{start_line:, end_line:, start_column:, end_column:}`
   - Compatible with `*-merge` gems' `FileAnalysisBase` expectations
   - Lines are 1-based (human-readable)
   - Columns are 0-based (matches tree-sitter convention)

4. **`first_child`** - Convenience method for iteration
   - Returns `children.first`
   - Provides compatibility with code expecting `first_child` method

---

## Backends Updated

### ✅ Main TreeHaver::Node Wrapper
**File:** `vendor/tree_haver/lib/tree_haver/node.rb`
**Lines:** 113-149, 230-241

Added all four methods to the main unified Node wrapper. This automatically covers:
- Tree-sitter MRI backend
- Tree-sitter FFI backend
- Tree-sitter Java backend
- Tree-sitter Rust backend

All tree-sitter backends use `TreeHaver::Node` to wrap their raw nodes, so they inherit these methods automatically.

### ✅ Commonmarker Backend (Already Complete)
**File:** `vendor/tree_haver/lib/tree_haver/backends/commonmarker.rb`
**Lines:** 286-324, 342-348

Already had all four methods implemented. Uses Commonmarker's `sourcepos` array which provides 1-based line numbers directly.

### ✅ Markly Backend (Already Complete)
**File:** `vendor/tree_haver/lib/tree_haver/backends/markly.rb`
**Lines:** 346-382

Already had all four methods implemented. Uses Markly's `source_position` hash which provides 1-based line numbers directly.

### ✅ Prism Backend (Already Complete)
**File:** `vendor/tree_haver/lib/tree_haver/backends/prism.rb`
**Lines:** 398-438

Already had all four methods implemented. Uses Prism's `Location` object which provides 1-based line numbers directly.

### ✅ Psych Backend (Newly Added)
**File:** `vendor/tree_haver/lib/tree_haver/backends/psych.rb`
**Lines:** 363-402

Added all four methods:
- `start_line` - Calculates from `start_point.row + 1`
- `end_line` - Calculates from `end_point.row + 1`
- `source_position` - Returns hash with 1-based lines and 0-based columns
- `first_child` - Returns `children.first`

### ✅ Citrus Backend (Newly Added)
**File:** `vendor/tree_haver/lib/tree_haver/backends/citrus.rb`
**Lines:** 375-409

Added all four methods:
- `start_line` - Calculates from `start_point[:row] + 1`
- `end_line` - Calculates from `end_point[:row] + 1`
- `source_position` - Returns hash with 1-based lines and 0-based columns
- `first_child` - Returns `child(0)`

---

## Testing

### Manual Verification

Tested Psych backend successfully:
```ruby
require "tree_haver/backends/psych"
parser = TreeHaver::Backends::Psych::Parser.new
parser.language = TreeHaver::Backends::Psych::Language.yaml
tree = parser.parse("foo: bar")
node = tree.root_node

# Verified all methods work:
node.respond_to?(:start_line)      # => true
node.respond_to?(:end_line)        # => true
node.respond_to?(:source_position) # => true
node.respond_to?(:first_child)     # => true
node.start_line                    # => 1
node.source_position               # => {start_line: 1, end_line: 2, start_column: 0, end_column: 0}
```

### No Syntax Errors

Both Psych and Citrus backends load without syntax errors:
```bash
ruby -I vendor/tree_haver/lib -r tree_haver/backends/psych -r tree_haver/backends/citrus -e "puts 'Backends loaded successfully'"
# Output: Backends loaded successfully
```

---

## Benefits

### 1. Consistent API Across All Backends
All Node classes now respond to the same position methods, regardless of backend.

### 2. Compatible with *-merge Gems
The `source_position` method returns exactly what `FileAnalysisBase` expects, eliminating the need for per-gem workarounds.

### 3. Backward Compatible
Existing code using `start_point`/`end_point` continues to work unchanged. The new methods are additive only.

### 4. Language-Agnostic
Position information is a property of the source text, not the language. These methods work identically for:
- Ruby (Prism backend)
- Markdown (Commonmarker, Markly backends)
- YAML (Psych backend)
- TOML (Citrus backend via toml-rb)
- JSON (tree-sitter backends)
- Any future language backends

---

## Implementation Notes

### Why Not a Mixin?

The original plan suggested a mixin (`NodePositionMixin`), but the implementation uses direct method definitions instead because:

1. **Backend-Specific Optimizations** - Some backends already have 1-based line numbers (Commonmarker, Markly, Prism), so they can skip the conversion
2. **Different Point Representations** - Some backends return Point objects, others return hashes
3. **Already Implemented** - Many backends already had these methods, just needed to verify/add missing ones

### Conversion Formula

For backends with 0-based rows (tree-sitter, Psych, Citrus):
- `start_line = start_point.row + 1`
- `end_line = end_point.row + 1`

For backends with 1-based lines (Commonmarker, Markly, Prism):
- Use the backend's native line number directly

---
