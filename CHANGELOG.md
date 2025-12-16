# Changelog

[![SemVer 2.0.0][📌semver-img]][📌semver] [![Keep-A-Changelog 1.0.0][📗keep-changelog-img]][📗keep-changelog]

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][📗keep-changelog],
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html),
and [yes][📌major-versions-not-sacred], platform and engine support are part of the [public API][📌semver-breaking].
Please file a bug if you notice a violation of semantic versioning.

[📌semver]: https://semver.org/spec/v2.0.0.html
[📌semver-img]: https://img.shields.io/badge/semver-2.0.0-FFDD67.svg?style=flat
[📌semver-breaking]: https://github.com/semver/semver/issues/716#issuecomment-869336139
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html
[📗keep-changelog]: https://keepachangelog.com/en/1.0.0/
[📗keep-changelog-img]: https://img.shields.io/badge/keep--a--changelog-1.0.0-FFDD67.svg?style=flat

## [Unreleased]

### Added

#### Backend Requirements
- **MRI Backend**: Requires `ruby_tree_sitter` v2.0+ (exceptions inherit from `Exception` not `StandardError`)
  - In ruby_tree_sitter v2.0, TreeSitter errors were changed to inherit from Exception for thread-safety
  - TreeHaver now properly handles: `ParserNotFoundError`, `LanguageLoadError`, `SymbolNotFoundError`, etc.

#### Thread-Safe Backend Selection (Hybrid Approach)
- **NEW: Block-based backend API** - `TreeHaver.with_backend(:ffi) { ... }` for thread-safe backend selection
  - Thread-local context with proper nesting support
  - Exception-safe (context restored even on errors)
  - Fully backward compatible with existing global backend setting
- **NEW: Explicit backend parameters**
  - `Parser.new(backend: :mri)` - specify backend when creating parser
  - `Language.from_library(path, backend: :ffi)` - specify backend when loading language
  - Backend parameters override thread context and global settings
- **NEW: Backend introspection** - `parser.backend` returns the current backend name (`:ffi`, `:mri`, etc.)
- **Backend precedence chain**: `explicit parameter > thread context > global setting > :auto`
- **Backend-aware caching** - Language cache now includes backend in cache key to prevent cross-backend pollution
- Added `TreeHaver.effective_backend` - returns the currently effective backend considering precedence
- Added `TreeHaver.current_backend_context` - returns thread-local backend context
- Added `TreeHaver.resolve_backend_module(explicit_backend)` - resolves backend module with precedence

#### Examples and Discovery
- Added 18 comprehensive examples demonstrating all backends and languages
  - JSON examples (5): auto, MRI, Rust, FFI, Java
  - JSONC examples (5): auto, MRI, Rust, FFI, Java
  - Bash examples (5): auto, MRI, Rust, FFI, Java
  - Citrus examples (3): TOML, Finitio, Dhall
  - All examples use bundler inline (self-contained, no Gemfile needed)
  - Added `examples/run_all.rb` - comprehensive test runner with colored output
  - Updated `examples/README.md` - complete guide to all examples
- Added `TreeHaver::CitrusGrammarFinder` for language-agnostic discovery and registration of Citrus-based grammar gems
  - Automatically discovers Citrus grammar gems by gem name and grammar constant path
  - Validates grammar modules respond to `.parse(source)` before registration
  - Provides helpful error messages when grammars are not found
- Added multi-backend language registry supporting multiple backends per language simultaneously
  - Restructured `LanguageRegistry` to use nested hash: `{ language: { backend_type: config } }`
  - Enables registering both tree-sitter and Citrus grammars for the same language without conflicts
  - Supports runtime backend switching, benchmarking, and fallback scenarios
- Added `LanguageRegistry.register(name, backend_type, **config)` with backend-specific configuration storage
- Added `LanguageRegistry.registered(name, backend_type = nil)` to query by specific backend or get all backends
- Added `TreeHaver::Backends::Citrus::Node#structural?` method to distinguish structural nodes from terminals
  - Uses Citrus grammar's `terminal?` method to dynamically determine node classification
  - Works with any Citrus grammar without language-specific knowledge

### Changed

- **BREAKING**: `LanguageRegistry.register` signature changed from `register(name, path:, symbol:)` to `register(name, backend_type, **config)`
  - This enables proper separation of tree-sitter and Citrus configurations
  - Users should update to use `TreeHaver.register_language` instead of calling `LanguageRegistry.register` directly
- Updated `TreeHaver.register_language` to support both tree-sitter and Citrus grammars in single call or separate calls
  - Can now register: `register_language(:toml, path: "...", symbol: "...", grammar_module: TomlRB::Document)`
  - **INTENTIONAL DESIGN**: Uses separate `if` statements (not `elsif`) to allow registering both backends simultaneously
  - Enables maximum flexibility: runtime backend switching, performance benchmarking, fallback scenarios
  - Multiple registrations for same language now merge instead of overwrite

### Improved

#### Code Quality and Documentation
- **Uniform backend API**: All backends now implement `reset!` method for consistent testing interface
  - Eliminates need for tests to manipulate private instance variables
  - Provides clean way to reset backend state between tests
- **Documented design decisions** with inline rationale
  - FFI Tree finalizer behavior and why Parser doesn't use finalizers
  - `resolve_backend_module` early-return pattern with comprehensive comments
  - `register_language` multi-backend registration capability extensively documented
- **Enhanced YARD documentation**
  - All Citrus examples now include `gem_name` parameter (matches actual usage patterns)
  - Added complete examples showing both single-backend and multi-backend registration
  - Documented backend precedence chain and thread-safety guarantees
- **Comprehensive test coverage** for thread-safe backend selection
  - Thread-local context tests (`spec/tree_haver/thread_local_backend_spec.rb`)
  - Parser backend parameter tests (`spec/tree_haver/parser_backend_spec.rb`)
  - Language backend parameter tests (`spec/tree_haver/language_backend_spec.rb`)
  - Concurrent parsing tests with multiple backends
  - Backend-aware cache isolation tests
  - Nested block behavior tests (inner blocks override outer blocks)
  - Exception safety tests (context restored even on errors)
  - Explicit parameter precedence tests
- Updated `Language.method_missing` to automatically select appropriate grammar based on active backend
  - tree-sitter backends (MRI, Rust, FFI, Java) query `:tree_sitter` registry key
  - Citrus backend queries `:citrus` registry key
  - Provides clear error messages when requested backend has no registered grammar
- Improved `TreeHaver::Backends::Citrus::Node#type` to use dynamic Citrus grammar introspection
  - Uses event `.name` method and Symbol events for accurate type extraction
  - Works with any Citrus grammar without language-specific code
  - Handles compound rules (Repeat, Choice, Optional) intelligently

### Fixed

#### Thread-Safety and Backend Selection
- Fixed `resolve_backend_module` to properly handle mocked backends without `available?` method
  - Assumes modules without `available?` are available (for test compatibility and backward compatibility)
  - Only rejects if module explicitly has `available?` method and returns false
  - Makes code more defensive and test-friendly
- Fixed Language cache to include backend in cache key
  - Prevents returning wrong backend's Language object when switching backends
  - Essential for correctness with multiple backends in use
  - Cache key now: `"#{path}:#{symbol}:#{backend}"` instead of just `"#{path}:#{symbol}"`
- Fixed `TreeHaver.register_language` to properly support multi-backend registration
  - Documented intentional design: uses `if` not `elsif` to allow both backends in one call
  - Added comprehensive inline comments explaining why no early return
  - Added extensive YARD documentation with examples

### Deprecated

### Removed

### Known Issues

### Notes on Backward Compatibility

Despite the major version bump to 3.0.0 (following semver due to the breaking `LanguageRegistry.register` signature change), **most users will experience NO BREAKING CHANGES**:

#### Why 3.0.0?
- `LanguageRegistry.register` signature changed to support multi-backend registration
- However, most users should use `TreeHaver.register_language` (which remains backward compatible)
- Direct calls to `LanguageRegistry.register` are rare in practice

#### What Stays the Same?
- **Global backend setting**: `TreeHaver.backend = :ffi` works unchanged
- **Parser creation**: `Parser.new` without parameters works as before
- **Language loading**: `Language.from_library(path)` works as before
- **Auto-detection**: Backend auto-selection still works when backend is `:auto`
- **All existing code** continues to work without modifications

#### What's New (All Optional)?
- Thread-safe block API: `TreeHaver.with_backend(:ffi) { ... }`
- Explicit backend parameters: `Parser.new(backend: :mri)`
- Backend introspection: `parser.backend`
- Multi-backend language registration

**Migration Path**: Existing codebases can upgrade to 3.0.0 and gain access to new thread-safe features without changing any existing code. The new features are purely additive and opt-in.

- **MRI backend + Bash grammar**: ABI/symbol loading incompatibility
  - The ruby_tree_sitter gem cannot load tree-sitter-bash grammar (symbol not found)
  - Workaround: Use FFI backend instead (works perfectly)
  - This is documented in examples and test runner
- **Rust backend + Bash grammar**: Version mismatch due to static linking
  - tree_stump statically links tree-sitter at compile time
  - System bash.so may be compiled with different tree-sitter version
  - Workaround: Use FFI backend (dynamic linking avoids version conflicts)
  - This is documented in examples with detailed explanations

### Fixed

- Fixed critical double-wrapping bug in ALL backends (MRI, Rust, FFI, Java, Citrus)
  - Backend `Parser#parse` and `parse_string` methods now return raw backend trees
  - TreeHaver::Parser wraps the raw tree in TreeHaver::Tree (single wrapping)
  - Previously backends were returning TreeHaver::Tree, then TreeHaver::Parser wrapped it again (double wrapping)
  - This caused `@inner_tree` to be a TreeHaver::Tree instead of raw backend tree, leading to nil errors
- Fixed TreeHaver::Parser to pass source parameter when wrapping backend trees
  - Enables `Node#text` to work correctly by providing source for text extraction
  - Fixes all parse and parse_string methods to include `source: source` parameter
- Fixed MRI backend to properly use ruby_tree_sitter API
  - Fixed `require "tree_sitter"` (gem name is `ruby_tree_sitter` but requires `tree_sitter`)
  - Fixed `Language.load` to use correct argument order: `(symbol_name, path)`
  - Fixed `Parser#parse` to use `parse_string(nil, source)` instead of creating Input objects
  - Fixed `Language.from_library` to implement the expected signature matching other backends
- Fixed FFI backend missing essential node methods
  - Added `ts_node_start_byte`, `ts_node_end_byte`, `ts_node_start_point`, `ts_node_end_point`
  - Added `ts_node_is_null`, `ts_node_is_named`
  - These methods are required for accessing node byte positions and metadata
  - Fixes `NoMethodError` when using FFI backend to traverse AST nodes
- Fixed GrammarFinder error messages for environment variable validation
  - Detects leading/trailing whitespace in paths and provides correction suggestions
  - Shows when TREE_SITTER_*_PATH is set but points to nonexistent file
  - Provides helpful guidance for setting environment variables correctly
- Fixed registry conflicts when registering multiple backend types for the same language
- Fixed `CitrusGrammarFinder` to properly handle gems with non-standard require paths (e.g., `toml-rb.rb` vs `toml/rb.rb`)
- Fixed Citrus backend infinite recursion in `Node#extract_type_from_event`
  - Added cycle detection to prevent stack overflow when traversing recursive grammar structures

### Security

## [2.0.0] - 2025-12-15

- TAG: [v2.0.0][2.0.0t]
- COVERAGE: 82.78% -- 601/726 lines in 11 files
- BRANCH COVERAGE: 70.45% -- 186/264 branches in 11 files
- 91.90% documented

### Added

- Added support for Citrus backend (`backends/citrus.rb`) - a pure Ruby grammar parser with its own distinct grammar structure
- Added `TreeHaver::Tree` unified wrapper class providing consistent API across all backends
- Added `TreeHaver::Node` unified wrapper class providing consistent API across all backends
- Added `TreeHaver::Point` class that works as both object and hash for position compatibility
- Added passthrough mechanism via `method_missing` for accessing backend-specific features
- Added `inner_node` accessor on `TreeHaver::Node` for advanced backend-specific usage
- Added `inner_tree` accessor on `TreeHaver::Tree` for advanced backend-specific usage
- Added comprehensive test suite for `TreeHaver::Node` wrapper class (88 examples)
- Added comprehensive test suite for `TreeHaver::Tree` wrapper class (17 examples)
- Added comprehensive test suite for `TreeHaver::Parser` class (12 examples)
- Added complete test coverage for Citrus backend (41 examples)
- Enhanced `TreeHaver::Language` tests for dynamic language helpers

### Changed

- **BREAKING:** All backends now return `TreeHaver::Tree` from `Parser#parse` and `Parser#parse_string`
- **BREAKING:** `TreeHaver::Tree#root_node` now returns `TreeHaver::Node` instead of backend-specific node
- **BREAKING:** All child/sibling/parent methods on nodes now return `TreeHaver::Node` wrappers
- Updated MRI backend (`backends/mri.rb`) to return wrapped `TreeHaver::Tree` with source
- Updated Rust backend (`backends/rust.rb`) to return wrapped `TreeHaver::Tree` with source
- Updated FFI backend (`backends/ffi.rb`) to return wrapped `TreeHaver::Tree` with source
- Updated Java backend (`backends/java.rb`) to return wrapped `TreeHaver::Tree` with source
- Updated Citrus backend (`backends/citrus.rb`) to return wrapped `TreeHaver::Tree` with source
- Disabled old pass-through stub classes in `tree_haver.rb` (wrapped in `if false` for reference)

### Fixed

- Fixed `TreeHaver::Tree#supports_editing?` and `#edit` to handle Delegator wrappers correctly by using `.method(:edit)` check instead of `respond_to?`
- Fixed `PathValidator` to accept versioned `.so` files (e.g., `.so.0`, `.so.14`) which are standard on Linux systems
- Fixed backend portability - code now works identically across MRI, Rust, FFI, Java, and Citrus backends
- Fixed inconsistent API - `node.type` now works on all backends (was `node.kind` on TreeStump)
- Fixed position objects - `start_point` and `end_point` now return objects that work as both `.row` and `[:row]`
- Fixed child iteration - `node.each` and `node.children` now consistently return `TreeHaver::Node` objects
- Fixed text extraction - `node.text` now works consistently by storing source in `TreeHaver::Tree`

## [1.0.0] - 2025-12-15

- TAG: [v1.0.0][1.0.0t]
- COVERAGE: 97.21% -- 487/501 lines in 8 files
- BRANCH COVERAGE: 90.75% -- 157/173 branches in 8 files
- 97.31% documented

### Added

- Initial release

[Unreleased]: https://github.com/kettle-rb/tree_haver/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/kettle-rb/tree_haver/compare/v1.0.0...v2.0.0
[2.0.0t]: https://github.com/kettle-rb/tree_haver/releases/tag/v2.0.0
[1.0.0]: https://github.com/kettle-rb/tree_haver/compare/a89211bff10f4440b96758a8ac9d7d539001b0c8...v1.0.0
[1.0.0t]: https://github.com/kettle-rb/tree_haver/tags/v1.0.0
