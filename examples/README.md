# TreeHaver Examples

This directory contains **24 executable examples** demonstrating tree_haver's capabilities across multiple backends and languages.

## Quick Start

All examples use bundler inline and are self-contained - no Gemfile needed! Just run:

```bash
ruby examples/auto_json.rb
```

## Test Runner

Run all examples and see results:

```bash
ruby examples/run_all.rb
```

**Current Status: ✅ 100% pass rate (12/12 runnable on MRI)**

---

## Examples by Language

### JSON (5 examples)

Parse JSON with different backends:

- **`auto_json.rb`** - Auto-selects best available backend ✨ **Start here!**
- **`mri_json.rb`** - MRI C extension (fastest on MRI)
- **`rust_json.rb`** - Rust extension (very fast, precompiled)
- **`ffi_json.rb`** - FFI (most portable: MRI/JRuby/TruffleRuby)
- **`java_json.rb`** - Java/JNI (optimal for JRuby)

```bash
ruby examples/auto_json.rb
```

**What they show:**
- Grammar registration with `GrammarFinder`
- Backend selection and capabilities
- AST traversal and node access
- Finding specific node types (objects, arrays)

---

### JSONC (5 examples)

Parse JSON with Comments (VSCode settings, tsconfig.json, etc.):

- **`auto_jsonc.rb`** - Auto-selects backend
- **`mri_jsonc.rb`** - MRI backend
- **`rust_jsonc.rb`** - Rust backend
- **`ffi_jsonc.rb`** - FFI backend
- **`java_jsonc.rb`** - Java backend

```bash
ruby examples/auto_jsonc.rb
```

**What they show:**
- Parsing JSON with `//` and `/* */` comments
- Trailing commas support
- Finding and extracting comments from AST

---

### Bash (5 examples)

Parse shell scripts for analysis:

- **`auto_bash.rb`** - Auto-selects backend
- **`mri_bash.rb`** - MRI backend ⚠️ Known incompatibility (use FFI)
- **`rust_bash.rb`** - Rust backend ⚠️ Version mismatch (use FFI)
- **`ffi_bash.rb`** - FFI backend ✅ **Recommended for Bash**
- **`java_bash.rb`** - Java backend

```bash
ruby examples/auto_bash.rb
```

**What they show:**
- Finding functions, if statements, loops
- Shell script analysis and traversal
- AST structure exploration

**Note:** MRI and Rust backends have known incompatibilities with Bash grammar. Use FFI backend instead.

---

### Citrus Backend (3 examples)

Pure Ruby parsing with Citrus grammars:

- **`citrus_toml.rb`** - TOML parsing with toml-rb
- **`citrus_finitio.rb`** - Finitio data validation language
- **`citrus_dhall.rb`** - Dhall configuration language

```bash
ruby examples/citrus_toml.rb
ruby examples/citrus_dhall.rb
```

**What they show:**
- Pure Ruby parsing (no native extensions needed)
- Language-agnostic design (works with ANY Citrus grammar)
- Dynamic node type extraction
- `structural?` method for filtering meaningful nodes

**Use cases:**
- When tree-sitter native library unavailable
- Pure Ruby portability (JRuby, TruffleRuby)
- Fallback when native builds fail
- Esoteric languages with Citrus grammars
- Type-safe configuration files (Dhall)

---

### Markdown (2 examples)

Parse Markdown with different backends:

- **`commonmarker_markdown.rb`** - Commonmarker (comrak Rust parser)
- **`markly_markdown.rb`** - Markly (cmark-gfm C library)

```bash
ruby examples/commonmarker_markdown.rb
ruby examples/markly_markdown.rb
```

**What they show:**
- Position API: `start_line`, `end_line`, `source_position`, `first_child`
- Finding headings with header levels
- Finding code blocks with language info
- GitHub Flavored Markdown extensions (Markly)
- CommonMark compliance

**Use cases:**
- Documentation processing
- Markdown linting and formatting
- README rendering
- Static site generators

---

### Ruby (1 example)

Parse Ruby code with Prism:

- **`prism_ruby.rb`** - Ruby parsing with Prism (official Ruby parser)

```bash
ruby examples/prism_ruby.rb
```

**What it shows:**
- Official Ruby parser (stdlib in Ruby 3.4+, gem for 3.2-3.3)
- Finding classes, methods, calls
- Excellent error recovery
- Position API with 1-based line numbers
- Parse errors, warnings, and comments

**Use cases:**
- Ruby code analysis
- Linters and formatters (RuboCop, etc.)
- Refactoring tools
- Documentation generators
- AST-based transformations

---

### YAML (1 example)

Parse YAML with Psych:

- **`psych_yaml.rb`** - YAML parsing with Psych (Ruby stdlib)

```bash
ruby examples/psych_yaml.rb
```

**What it shows:**
- Ruby standard library YAML parser (always available)
- Node type checks: `mapping?`, `sequence?`, `scalar?`, `alias?`
- `mapping_entries` for extracting key-value pairs
- Position API with 1-based line numbers
- Anchors and tags

**Use cases:**
- Configuration file parsing
- CI/CD pipeline configs (GitHub Actions, etc.)
- Kubernetes manifests
- Docker Compose files

---

### Markdown Merge (2 examples)

Demonstrate intelligent template-to-destination Markdown merging using markdown-merge gem:

- **`commonmarker_merge_example.rb`** - Smart merge with Commonmarker backend
- **`markly_merge_example.rb`** - Smart GFM merge with Markly backend

```bash
ruby examples/commonmarker_merge_example.rb
ruby examples/markly_merge_example.rb
```

**What they show:**
- Real-world usage of Position API in markdown-merge
- Template-to-destination merge (template updates + destination customizations)
- Preserving destination customizations while applying template structure
- Structure-aware section matching and merging
- GFM features: tables, task lists, strikethrough
- Merge statistics and warnings

**Use cases:**
- Update project READMEs from template while preserving customizations
- Maintain consistent documentation structure across projects
- Apply template updates to API docs without losing custom content
- GitHub documentation template workflows

**Note:** These examples require the `markdown-merge` and `ast-merge` gems in addition to `tree_haver`.

---

## Common Patterns

### Auto Backend

Let tree_haver pick the best backend:

```bash
ruby examples/auto_json.rb   # JSON
ruby examples/auto_jsonc.rb  # JSONC
ruby examples/auto_bash.rb   # Bash
```

**Priority order:** MRI > Rust > FFI > Java > Citrus

---

### MRI Backend

Fastest on MRI Ruby (requires `ruby_tree_sitter` gem):

```bash
ruby examples/mri_json.rb    # JSON
ruby examples/mri_jsonc.rb   # JSONC
# mri_bash.rb has known issues - use FFI instead
```

**Best for:** Performance-critical applications on MRI

---

### Rust Backend

Very fast with precompiled binaries (requires `tree_stump` gem):

```bash
ruby examples/rust_json.rb   # JSON
ruby examples/rust_jsonc.rb  # JSONC
# rust_bash.rb has version issues - use FFI instead
```

**Best for:** Fast parsing without compilation
**Note:** May have version compatibility issues with system grammars

---

### FFI Backend

Most portable - works everywhere (requires `ffi` gem):

```bash
ruby examples/ffi_json.rb    # JSON ✅
ruby examples/ffi_jsonc.rb   # JSONC ✅
ruby examples/ffi_bash.rb    # Bash ✅ **Recommended for Bash**
```

**Best for:**
- Cross-Ruby compatibility (MRI, JRuby, TruffleRuby)
- Avoiding version conflicts (dynamic linking)
- When other backends have issues

---

### Java Backend

Optimal for JRuby (requires JRuby):

```bash
jruby examples/java_json.rb   # JSON
jruby examples/java_jsonc.rb  # JSONC
jruby examples/java_bash.rb   # Bash
```

**Best for:** JRuby applications

---

### Citrus Backend

Pure Ruby parsing:

```bash
ruby examples/citrus_toml.rb     # TOML
ruby examples/citrus_finitio.rb  # Finitio
ruby examples/citrus_dhall.rb    # Dhall (configuration language)
```

**Best for:** Pure Ruby portability, fallback, type-safe configs

---

### Commonmarker Backend

Fast Markdown parsing with comrak (Rust):

```bash
ruby examples/commonmarker_markdown.rb  # Markdown
```

**What it shows:**
- Fast CommonMark-compliant parsing
- Position API: `start_line`, `end_line`, `source_position`, `first_child`
- Finding headings with `header_level`
- Finding code blocks with `fence_info`
- GitHub Flavored Markdown support

**Best for:** Documentation processing, Markdown linting, content management

---

### Markly Backend

Markdown parsing with cmark-gfm (C library):

```bash
ruby examples/markly_markdown.rb  # Markdown
```

**What it shows:**
- GitHub's official Markdown implementation
- GFM extensions: tables, strikethrough, task lists, autolinks
- Position API with 1-based line numbers
- Type normalization (`header` → `heading`)
- Multiple output formats: HTML, CommonMark, plaintext

**Best for:** GitHub-compatible Markdown, README rendering, issue/PR parsing

---

### Prism Backend

Ruby parsing with Prism (official Ruby parser):

```bash
ruby examples/prism_ruby.rb  # Ruby
```

**What it shows:**
- Official Ruby parser (stdlib in Ruby 3.4+)
- Excellent error recovery
- Position API: `start_line`, `end_line`, `source_position`
- Finding classes, methods, calls
- Parse errors, warnings, comments
- Works on all Ruby implementations

**Best for:** Ruby code analysis, linters, formatters, refactoring tools

---

### Psych Backend

YAML parsing with Psych (Ruby stdlib):

```bash
ruby examples/psych_yaml.rb  # YAML
```

**What it shows:**
- Ruby's standard library YAML parser
- Position API with 1-based line numbers
- Node type checks: `mapping?`, `sequence?`, `scalar?`, `alias?`
- `mapping_entries` for key-value pairs
- Always available (part of stdlib)

**Best for:** Configuration files, CI/CD configs, Kubernetes manifests

---

## Common Patterns

### Basic Parsing

```ruby
require "tree_haver"

# Find and register grammar
finder = TreeHaver::GrammarFinder.new(:json)
finder.register! if finder.available?

# Create parser and parse
parser = TreeHaver::Parser.new
parser.language = TreeHaver::Language.json
tree = parser.parse('{"key": "value"}')

# Access nodes
root = tree.root_node
puts root.type          # "document"
puts root.child_count   # 1
```

### Force Specific Backend

```ruby
# Force FFI backend
TreeHaver.backend = :ffi

parser = TreeHaver::Parser.new
# ... rest is the same
```

### Find Nodes by Type

```ruby
def find_nodes(node, type, results = [])
  results << node if node.type == type
  node.children.each { |child| find_nodes(child, type, results) }
  results
end

objects = find_nodes(tree.root_node, "object")
```

### Check Capabilities

```ruby
puts TreeHaver.backend          # :ffi
puts TreeHaver.capabilities     # { backend: :ffi, parse: true, ... }
```

---

## Requirements

### Grammar Libraries

Examples need tree-sitter grammar libraries installed:

```bash
# Set paths in .envrc or environment
export TREE_SITTER_JSON_PATH=/path/to/libtree-sitter-json.so
export TREE_SITTER_BASH_PATH=/path/to/libtree-sitter-bash.so
```

### Backend Gems

Examples automatically install required gems via bundler inline:
- `ffi` - For FFI backend
- `ruby_tree_sitter` - For MRI backend
- `tree_stump` - For Rust backend
- `toml-rb` - For Citrus TOML example

---

## Known Issues

### MRI + Bash

The MRI backend has ABI/symbol loading issues with Bash grammar.

**Workaround:** Use FFI backend instead:
```bash
ruby examples/ffi_bash.rb  # ✅ Works perfectly
```

### Rust + Bash

The Rust backend has version mismatches due to static linking.

**Workaround:** Use FFI backend (dynamic linking avoids version conflicts)

### Java Backend

Requires JRuby - will skip on other Ruby implementations.

---

## Key Concepts

### Language-Agnostic Design

TreeHaver doesn't have built-in knowledge of specific languages:

1. **Register** a grammar (tree-sitter or Citrus)
2. **Parse** with unified API
3. **Traverse** with same node interface

Works with: JSON, JSONC, Bash, TOML, Finitio, and 100+ other tree-sitter/Citrus grammars!

### Multi-Backend Support

Same code works across backends:
- **MRI** - C extensions (fastest on MRI)
- **Rust** - Precompiled binaries (fast, no compilation)
- **FFI** - Pure FFI (most portable)
- **Java** - JNI (optimal for JRuby)
- **Citrus** - Pure Ruby (ultimate portability)

### Auto Backend Selection

`TreeHaver.backend = :auto` picks best available:
1. MRI (if ruby_tree_sitter available)
2. Rust (if tree_stump available)
3. FFI (if ffi available)
4. Java (if JRuby)
5. Citrus (if citrus available)

---

## Adding New Languages

### Tree-Sitter Grammar

```ruby
# Find grammar
finder = TreeHaver::GrammarFinder.new(:your_language)
if finder.available?
  finder.register!
else
  # Set TREE_SITTER_YOUR_LANGUAGE_PATH
end

# Use it
parser.language = TreeHaver::Language.your_language
```

### Citrus Grammar

```ruby
require "your_citrus_gem"

TreeHaver.register_language(
  :your_language,
  grammar_module: YourGem::GrammarModule,
)

TreeHaver.backend = :citrus
parser.language = TreeHaver::Language.your_language
```

---

## Testing

Run the test suite:

```bash
ruby examples/run_all.rb
```

**Output:**
- ✅ Pass/fail status for each example
- 📊 Overall statistics
- 🎯 100% pass rate on runnable examples

---

## Contributing

Add new examples following these patterns:

1. Use bundler inline
2. Include grammar registration
3. Show AST exploration
4. Document backend-specific notes
5. Handle errors gracefully

---

## Resources

- **Main README**: `../README.md`
- **Changelog**: `../CHANGELOG.md`
- **Architecture**: See backend files in `../lib/tree_haver/backends/`
- **Tests**: `../spec/`

---

**Status: ✅ All 18 examples created and tested - 100% pass rate!**

