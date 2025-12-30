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

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [3.2.0] - 2025-12-30

- TAG: [v3.2.0][3.2.0t]
- COVERAGE: 86.82% -- 2167/2496 lines in 22 files
- BRANCH COVERAGE: 66.79% -- 734/1099 branches in 22 files
- 90.03% documented

### Added

- `TreeHaver::CITRUS_DEFAULTS` constant with default Citrus configurations for known languages
  - Enables automatic Citrus fallback for TOML without explicit `citrus_config` parameter
  - Currently includes configuration for `:toml` (gem: `toml-rb`, const: `TomlRB::Document`)
- Regression test suite for Citrus fallback (`spec/integration/citrus_fallback_spec.rb`)
  - Tests `parser_for` with all tree-sitter backends stubbed as unavailable (simulating TruffleRuby)
  - Tests `CitrusGrammarFinder` with nil `gem_name` and `require_path`
  - Tests explicit Citrus backend usage on MRI via `with_backend(:citrus)`
- Shared examples for TOML parsing tests (`spec/support/shared_examples/toml_parsing_examples.rb`)
  - `"toml parsing basics"` - tests basic parsing, positions, children, text extraction
  - `"toml node navigation"` - tests first_child, named_children navigation
- Multi-backend TOML test suite (`spec/integration/multi_backend_toml_spec.rb`)
  - Runs shared examples against both tree-sitter-toml and Citrus/toml-rb backends
  - Tests backend equivalence for parsing results and positions
  - Tagged appropriately so tests run on whichever backends are available
- Backend Platform Compatibility section to README
  - Complete compatibility matrix showing which backends work on MRI, JRuby, TruffleRuby
  - Detailed explanations for TruffleRuby and JRuby limitations
- `FFI.available?` method at module level for API consistency with other backends
- `TreeHaver.resolve_native_backend_module` method for resolving only tree-sitter backends
- `TreeHaver::NATIVE_BACKENDS` constant listing backends that support shared libraries
- TruffleRuby short-circuit in `resolve_native_backend_module` for efficiency
  - Avoids trying 3 backends that are all known to fail on TruffleRuby
- `citrus_available?` method to check if Citrus backend is available

### Fixed

- **`TreeHaver::Node#child` now returns `nil` for out-of-bounds indices on all backends**
  - MRI backend (ruby_tree_sitter) raises `IndexError` for invalid indices
  - Other backends return `nil` for invalid indices
  - Now consistently returns `nil` across all backends for API compatibility
- **Citrus backend `calculate_point` returns negative column values**
  - When `offset` was 0, `@source.rindex("\n", -1)` searched from end of string
  - This caused `column = 0 - (position_of_last_newline) - 1` to be negative (e.g., -34)
  - Fix: Early return `{row: 0, column: 0}` for `offset <= 0`
  - This bug affected both MRI and TruffleRuby when using Citrus backend
- **Citrus fallback fails on TruffleRuby when no explicit `citrus_config` provided**
  - `parser_for(:toml)` would fail with `TypeError: no implicit conversion of nil into String`
  - Root cause: `citrus_config` defaulted to `{}`, so `citrus_config[:gem_name]` was `nil`
  - `CitrusGrammarFinder` was instantiated with `gem_name: nil`, causing `require nil`
  - On TruffleRuby, this triggered a bug in `bundled_gems.rb` calling `File.path` on nil
  - Fix: Added `CITRUS_DEFAULTS` with known Citrus configurations (TOML currently)
  - Fix: `parser_for` now uses `CITRUS_DEFAULTS[name]` when no explicit config provided
  - Fix: Added guard in `CitrusGrammarFinder#available?` to return false when `require_path` is nil
  - Fix: Added `TypeError` to rescue clause for TruffleRuby-specific edge cases
- **`from_library` no longer falls back to pure-Ruby backends**
  - Previously, calling `Language.from_library(path)` on TruffleRuby would fall back to Citrus
    backend which then raised a confusing error about not supporting shared libraries
  - Now `from_library` only considers native tree-sitter backends (MRI, Rust, FFI, Java)
  - Clear error message when no native backend is available explaining the situation
- **Integration specs now use `parser_for` instead of explicit paths**
  - `tree_edge_cases_spec.rb` and `node_edge_cases_spec.rb` now use `TreeHaver.parser_for(:toml)`
    which auto-discovers the best available backend (tree-sitter or Citrus fallback)
  - Tests now work correctly on all platforms (MRI, JRuby, TruffleRuby)
  - Tagged with `:toml_parsing` which passes if ANY toml parser is available
- **Core specs now use `parser_for` instead of explicit paths**
  - `tree_spec.rb`, `node_spec.rb`, `parser_spec.rb` converted to use `TreeHaver.parser_for(:toml)`
  - All `:toml_grammar` tags changed to `:toml_parsing` for cross-platform compatibility
  - Tests now run on JRuby and TruffleRuby via Citrus/toml-rb fallback
- FFI backend now properly reports as unavailable on TruffleRuby
  - `ffi_gem_available?` returns `false` on TruffleRuby since tree-sitter uses STRUCT_BY_VALUE return types
  - `FFI.available?` added at module level (was only in Native submodule)
  - Prevents confusing runtime errors (Polyglot::ForeignException) by detecting incompatibility upfront
  - Dependency tags now check `truffleruby?` before attempting FFI backend tests
- MRI backend now properly reports as unavailable on JRuby and TruffleRuby
  - `available?` returns `false` on non-MRI platforms (C extension only works on MRI)
- Rust backend now properly reports as unavailable on JRuby and TruffleRuby
  - `available?` returns `false` on non-MRI platforms (magnus requires MRI's C API)
- Backend compatibility matrix spec now properly skips tests for platform-incompatible backends
  - MRI and Rust backends skip on JRuby/TruffleRuby with clear skip messages
  - FFI backend skips on TruffleRuby with clear skip message

### Changed

- **BREAKING: RSpec Dependency Tag Naming Convention Overhaul**
  - All dependency tags now follow consistent naming conventions with suffixes
  - Backend tags now use `*_backend` suffix (e.g., `:commonmarker_backend`, `:markly_backend`)
  - Engine tags now use `*_engine` suffix (e.g., `:mri_engine`, `:jruby_engine`, `:truffleruby_engine`)
  - Grammar tags now use `*_grammar` suffix (e.g., `:bash_grammar`, `:toml_grammar`, `:json_grammar`)
  - Parsing capability tags now use `*_parsing` suffix (e.g., `:toml_parsing`, `:markdown_parsing`)
  - **Migration required**: Update specs using legacy tags:
    - `:commonmarker` → `:commonmarker_backend`
    - `:markly` → `:markly_backend`
    - `:mri` → `:mri_engine`
    - `:jruby` → `:jruby_engine`
    - `:truffleruby` → `:truffleruby_engine`
    - `:tree_sitter_bash` → `:bash_grammar`
    - `:tree_sitter_toml` → `:toml_grammar`
    - `:tree_sitter_json` → `:json_grammar`
    - `:tree_sitter_jsonc` → `:jsonc_grammar`
    - `:toml_backend` → `:toml_parsing`
    - `:markdown_backend` → `:markdown_parsing`
- **Removed inner-merge dependency tags from tree_haver**
  - Tags `:toml_merge`, `:json_merge`, `:prism_merge`, `:psych_merge` removed
  - These belong in ast-merge gem, not tree_haver
  - Use `require "ast/merge/rspec/dependency_tags"` for merge gem tags
- **API Consistency**: All backends now have uniform `available?` API at module level:
  - `TreeHaver::Backends::FFI.available?` - checks ffi gem + not TruffleRuby + MRI not loaded
  - `TreeHaver::Backends::MRI.available?` - checks MRI platform + ruby_tree_sitter gem
  - `TreeHaver::Backends::Rust.available?` - checks MRI platform + tree_stump gem
  - `TreeHaver::Backends::Java.available?` - checks JRuby platform + jtreesitter JAR
  - `TreeHaver::Backends::Prism.available?` - checks prism gem (all platforms)
  - `TreeHaver::Backends::Psych.available?` - checks psych stdlib (all platforms)
  - `TreeHaver::Backends::Commonmarker.available?` - checks commonmarker gem (all platforms)
  - `TreeHaver::Backends::Markly.available?` - checks markly gem (all platforms)
  - `TreeHaver::Backends::Citrus.available?` - checks citrus gem (all platforms)
- README now accurately documents TruffleRuby backend support
  - FFI backend doesn't work on TruffleRuby due to `STRUCT_BY_VALUE` limitation in TruffleRuby's FFI
  - Rust backend (tree_stump) doesn't work due to magnus/rb-sys incompatibility with TruffleRuby's C API
  - TruffleRuby users should use Prism, Psych, Commonmarker, Markly, or Citrus backends
- Documented confirmed tree-sitter backend limitations:
  - **TruffleRuby**: No tree-sitter backend works (FFI, MRI, Rust all fail)
  - **JRuby**: Only Java and FFI backends work; Rust/MRI don't
- Updated Rust Backend section with platform compatibility notes
- Updated FFI Backend section with TruffleRuby limitation details
- Use kettle-rb/ts-grammar-setup GHA in CI workflows

### Fixed

- Rakefile now properly overrides `test` task after `require "kettle/dev"`
  - Works around a bug in kettle-dev where test task runs minitest loader in CI
  - Ensures `rake test` runs RSpec specs instead of empty minitest suite
- `TreeHaver::RSpec::DependencyTags` now catches TruffleRuby FFI exceptions
  - TruffleRuby's FFI raises `Polyglot::ForeignException` for unsupported types like `STRUCT_BY_VALUE`
  - `ffi_available?` and `libtree_sitter_available?` now return `false` instead of crashing
  - Fixes spec loading errors on TruffleRuby
- `TreeHaver::Backends::FFI::Language.from_library` now catches `RuntimeError` from TruffleRuby
  - TruffleRuby raises `RuntimeError` instead of `LoadError` when a shared library cannot be opened
  - Now properly converts to `TreeHaver::NotAvailable` with descriptive message
- `TreeHaver::Backends::FFI::Native.try_load!` now only sets `@loaded = true` after all `attach_function` calls succeed
  - Previously, `loaded?` returned `true` even when `attach_function` failed (e.g., on TruffleRuby)
  - Now `loaded?` correctly returns `false` when FFI functions couldn't be attached
  - Ensures FFI tests are properly skipped on TruffleRuby

## [3.1.2] - 2025-12-29

- TAG: [v3.1.2][3.1.2t]
- COVERAGE: 87.40% -- 2171/2484 lines in 22 files
- BRANCH COVERAGE: 67.04% -- 726/1083 branches in 22 files
- 90.03% documented

### Added

- Enhanced `TreeHaver::RSpec::DependencyTags` debugging
  - `env_summary` method returns relevant environment variables for diagnosis
  - `grammar_works?` now logs detailed trace when `TREE_HAVER_DEBUG=1`
  - `before(:suite)` prints both env vars and dependency status when debugging
  - Helps diagnose differences between local and CI environments
- Many new specs for:
  - TreeHaver::GrammarFinder
  - TreeHaver::Node
  - TreeHaver::Tree

## [3.1.1] - 2025-12-28

- TAG: [v3.1.1][3.1.1t]
- COVERAGE: 87.44% -- 2152/2461 lines in 22 files
- BRANCH COVERAGE: 66.67% -- 710/1065 branches in 22 files
- 90.02% documented

### Added

- **`TreeHaver::RSpec::DependencyTags`**: Shared RSpec dependency detection for the entire gem family
  - New `lib/tree_haver/rspec.rb` entry point - other gems can simply `require "tree_haver/rspec"`
  - Detects all TreeHaver backends: FFI, MRI, Rust, Java, Prism, Psych, Commonmarker, Markly, Citrus
  - Ruby engine detection: `jruby?`, `truffleruby?`, `mri?`
  - Language grammar detection: `tree_sitter_bash_available?`, `tree_sitter_toml_available?`, `tree_sitter_json_available?`, `tree_sitter_jsonc_available?`
  - Inner-merge dependency detection: `toml_merge_available?`, `json_merge_available?`, `prism_merge_available?`, `psych_merge_available?`
  - Composite checks: `any_toml_backend_available?`, `any_markdown_backend_available?`
  - Records MRI backend usage when checking availability (critical for FFI conflict detection)
  - Configures RSpec exclusion filters for all dependency tags automatically
  - Supports debug output via `TREE_HAVER_DEBUG=1` environment variable
  - Comprehensive documentation with usage examples

- **`TreeHaver.parser_for`**: New high-level factory method for creating configured parsers
  - Handles all language loading complexity in one call
  - Auto-discovers tree-sitter grammar via `GrammarFinder`
  - Falls back to Citrus grammar if tree-sitter unavailable
  - Accepts `library_path` for explicit grammar location
  - Accepts `citrus_config` for Citrus fallback configuration
  - Raises `NotAvailable` with helpful message if no backend works
  - Example: `parser = TreeHaver.parser_for(:toml)`
  - Raises `NotAvailable` if the specified path doesn't exist (Principle of Least Surprise)
  - Does not back to auto-discovery when an explicit path is provided
  - Re-raises with context-rich error message if loading from explicit path fails
  - Auto-discovery still works normally when no `library_path` is provided

### Changed

- **Backend sibling navigation**: Backends that don't support sibling/parent navigation now raise `NotImplementedError` instead of returning `nil`
  - This distinguishes "not implemented" from "no sibling exists"
  - Affected backends: Prism, Psych
  - Affected methods: `next_sibling`, `prev_sibling`, `parent`

- **Canonical sibling method name**: All backends now use `prev_sibling` as the canonical method name (not `previous_sibling`)
  - Matches the universal `TreeHaver::Node` API

### Fixed

- **Backend conflict detection**: Fixed bug where MRI backend usage wasn't being recorded during availability checks
  - `mri_backend_available?` now calls `TreeHaver.record_backend_usage(:mri)` after successfully loading ruby_tree_sitter
  - This ensures FFI conflict detection works correctly even when MRI is loaded indirectly

- **GrammarFinder#not_found_message**: Improved error message when grammar file exists but no tree-sitter runtime is available
  - Now suggests adding `ruby_tree_sitter`, `ffi`, or `tree_stump` gem to Gemfile
  - Clearer guidance for users who have grammar files but are missing the Ruby tree-sitter bindings

## [3.1.0] - 2025-12-18

- TAG: [v3.1.0][3.1.0t]
- COVERAGE: 82.65% -- 943/1141 lines in 11 files
- BRANCH COVERAGE: 63.80% -- 349/547 branches in 11 files
- 88.97% documented

### Added

- **Position API Enhancements** – Added consistent position methods to all backend Node classes for compatibility with `*-merge` gems
  - `start_line` - Returns 1-based line number where node starts (converts 0-based `start_point.row` to 1-based)
  - `end_line` - Returns 1-based line number where node ends (converts 0-based `end_point.row` to 1-based)
  - `source_position` - Returns hash `{start_line:, end_line:, start_column:, end_column:}` with 1-based lines and 0-based columns
  - `first_child` - Convenience method that returns `children.first` for iteration compatibility
  - **Fixed:** `TreeHaver::Node#start_point` and `#end_point` now handle both Point objects and hashes from backends (Prism, Citrus return hashes)
  - **Fixed:** Added Psych, Commonmarker, and Markly backends to `resolve_backend_module` and `backend_module` case statements so they can be explicitly selected with `TreeHaver.backend = :psych` etc.
  - **Fixed:** Added Prism, Psych, Commonmarker, and Markly backends to `unwrap_language` method so language objects are properly passed to backend parsers
  - **Fixed:** Commonmarker backend's `text` method now safely handles container nodes that don't have string_content (wraps in rescue TypeError)
  - **Added to:**
    - Main `TreeHaver::Node` wrapper (used by tree-sitter backends: MRI, FFI, Java, Rust)
    - `Backends::Commonmarker::Node` - uses Commonmarker's `sourcepos` (already 1-based)
    - `Backends::Markly::Node` - uses Markly's `source_position` (already 1-based)
    - `Backends::Prism::Node` - uses Prism's `location` (already 1-based)
    - `Backends::Psych::Node` - calculates from `start_point`/`end_point` (0-based)
    - `Backends::Citrus::Node` - calculates from `start_point`/`end_point` (0-based)
  - **Backward Compatible:** Existing `start_point`/`end_point` methods continue to work unchanged
  - **Purpose:** Enables all `*-merge` gems to use consistent position API without backend-specific workarounds

- **Prism Backend** – New backend wrapping Ruby's official Prism parser (stdlib in Ruby 3.4+, gem for 3.2+)
  - `TreeHaver::Backends::Prism::Language` - Language wrapper (Ruby-only)
  - `TreeHaver::Backends::Prism::Parser` - Parser with `parse` and `parse_string` methods
  - `TreeHaver::Backends::Prism::Tree` - Tree wrapper with `root_node`, `errors`, `warnings`, `comments`
  - `TreeHaver::Backends::Prism::Node` - Node wrapper implementing full TreeHaver::Node protocol
  - Registered with `:prism` backend name, no conflicts with other backends

- **Psych Backend** – New backend wrapping Ruby's standard library YAML parser
  - `TreeHaver::Backends::Psych::Language` - Language wrapper (YAML-only)
  - `TreeHaver::Backends::Psych::Parser` - Parser with `parse` and `parse_string` methods
  - `TreeHaver::Backends::Psych::Tree` - Tree wrapper with `root_node`, `errors`
  - `TreeHaver::Backends::Psych::Node` - Node wrapper implementing TreeHaver::Node protocol
  - Psych-specific methods: `mapping?`, `sequence?`, `scalar?`, `alias?`, `mapping_entries`, `anchor`, `tag`, `value`
  - Registered with `:psych` backend name, no conflicts with other backends

- **Commonmarker Backend** – New backend wrapping the Commonmarker gem (comrak Rust parser)
  - `TreeHaver::Backends::Commonmarker::Language` - Language wrapper with parse options passthrough
  - `TreeHaver::Backends::Commonmarker::Parser` - Parser with `parse` and `parse_string` methods
  - `TreeHaver::Backends::Commonmarker::Tree` - Tree wrapper with `root_node`
  - `TreeHaver::Backends::Commonmarker::Node` - Node wrapper implementing TreeHaver::Node protocol
  - Commonmarker-specific methods: `header_level`, `fence_info`, `url`, `title`, `next_sibling`, `previous_sibling`, `parent`
  - Registered with `:commonmarker` backend name, no conflicts with other backends

- **Markly Backend** – New backend wrapping the Markly gem (cmark-gfm C library)
  - `TreeHaver::Backends::Markly::Language` - Language wrapper with flags and extensions passthrough
  - `TreeHaver::Backends::Markly::Parser` - Parser with `parse` and `parse_string` methods
  - `TreeHaver::Backends::Markly::Tree` - Tree wrapper with `root_node`
  - `TreeHaver::Backends::Markly::Node` - Node wrapper implementing TreeHaver::Node protocol
  - Type normalization: `:header` → `"heading"`, `:hrule` → `"thematic_break"`, `:html` → `"html_block"`
  - Markly-specific methods: `header_level`, `fence_info`, `url`, `title`, `next_sibling`, `previous_sibling`, `parent`, `raw_type`
  - Registered with `:markly` backend name, no conflicts with other backends

- **Automatic Citrus Fallback** – When tree-sitter fails, automatically fall back to Citrus backend
  - `TreeHaver::Language.method_missing` now catches tree-sitter loading errors (`NotAvailable`, `ArgumentError`, `LoadError`, `FFI::NotFoundError`) and falls back to registered Citrus grammar
  - `TreeHaver::Parser#initialize` now catches parser creation errors and falls back to Citrus parser when backend is `:auto`
  - `TreeHaver::Parser#language=` automatically switches to Citrus parser when a Citrus language is assigned
  - Enables seamless use of pure-Ruby parsers (like toml-rb) when tree-sitter runtime is unavailable

- **GrammarFinder Runtime Check** – `GrammarFinder#available?` now verifies tree-sitter runtime is actually usable
  - New `GrammarFinder.tree_sitter_runtime_usable?` class method tests if parser can be created
  - `TREE_SITTER_BACKENDS` constant defines which backends use tree-sitter (MRI, FFI, Rust, Java)
  - Prevents registration of grammars when tree-sitter runtime isn't functional
  - `GrammarFinder.reset_runtime_check!` for testing

- **Empty ENV Variable as Explicit Skip** – Setting `TREE_SITTER_<LANG>_PATH=''` explicitly disables that grammar
  - Previously, empty string was treated same as unset (would search paths)
  - Now, empty string means "do not use tree-sitter for this language"
  - Allows explicit opt-out to force fallback to alternative backends like Citrus
  - Useful for testing and environments where tree-sitter isn't desired

- **TOML Examples** – New example scripts demonstrating TOML parsing with various backends
  - `examples/auto_toml.rb` - Auto backend selection with Citrus fallback demonstration
  - `examples/ffi_toml.rb` - FFI backend with TOML
  - `examples/mri_toml.rb` - MRI backend with TOML
  - `examples/rust_toml.rb` - Rust backend with TOML
  - `examples/java_toml.rb` - Java backend with TOML (JRuby only)

### Fixed

- **BREAKING**: `TreeHaver::Language.method_missing` no longer raises `ArgumentError` when only Citrus grammar is registered and tree-sitter backend is active – it now falls back to Citrus instead
  - Previously: Would raise "No grammar registered for :lang compatible with tree_sitter backend"
  - Now: Returns `TreeHaver::Backends::Citrus::Language` if Citrus grammar is registered
  - Migration: If you were catching this error, update your code to handle the fallback behavior
  - This is a bug fix, but would be a breaking change for some users who were relying on the old behavior

## [3.0.0] - 2025-12-16

- TAG: [v3.0.0][3.0.0t]
- COVERAGE: 85.19% -- 909/1067 lines in 11 files
- BRANCH COVERAGE: 67.47% -- 338/501 branches in 11 files
- 92.93% documented

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

- **BREAKING**: All errors now inherit from `TreeHaver::Error` which inherits from `Exception`
  - see: https://github.com/Faveod/ruby-tree-sitter/pull/83 for reasoning
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
  - Thread-local context tests
  - Parser backend parameter tests
  - Language backend parameter tests
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

#### Backend Bug Fixes

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
- Fixed `CitrusGrammarFinder` to use gem name as-is for require path (e.g., `require "toml-rb"` not `require "toml/rb"`)
- Fixed Citrus backend infinite recursion in `Node#extract_type_from_event`
  - Added cycle detection to prevent stack overflow when traversing recursive grammar structures

### Known Issues

- **MRI backend + Bash grammar**: ABI/symbol loading incompatibility
  - The ruby_tree_sitter gem cannot load tree-sitter-bash grammar (symbol not found)
  - Workaround: Use FFI backend instead (works perfectly)
  - This is documented in examples and test runner
- **Rust backend + Bash grammar**: Version mismatch due to static linking
  - tree_stump statically links tree-sitter at compile time
  - System bash.so may be compiled with different tree-sitter version
  - Workaround: Use FFI backend (dynamic linking avoids version conflicts)
  - This is documented in examples with detailed explanations

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

[Unreleased]: https://github.com/kettle-rb/tree_haver/compare/v3.2.0...HEAD
[3.2.0]: https://github.com/kettle-rb/tree_haver/compare/v3.1.2...v3.2.0
[3.2.0t]: https://github.com/kettle-rb/tree_haver/releases/tag/v3.2.0
[3.1.2]: https://github.com/kettle-rb/tree_haver/compare/v3.1.1...v3.1.2
[3.1.2t]: https://github.com/kettle-rb/tree_haver/releases/tag/v3.1.2
[3.1.1]: https://github.com/kettle-rb/tree_haver/compare/v3.1.0...v3.1.1
[3.1.1t]: https://github.com/kettle-rb/tree_haver/releases/tag/v3.1.1
[3.1.0]: https://github.com/kettle-rb/tree_haver/compare/v3.0.0...v3.1.0
[3.1.0t]: https://github.com/kettle-rb/tree_haver/releases/tag/v3.1.0
[3.0.0]: https://github.com/kettle-rb/tree_haver/compare/v2.0.0...v3.0.0
[3.0.0t]: https://github.com/kettle-rb/tree_haver/releases/tag/v3.0.0
[2.0.0]: https://github.com/kettle-rb/tree_haver/compare/v1.0.0...v2.0.0
[2.0.0t]: https://github.com/kettle-rb/tree_haver/releases/tag/v2.0.0
[1.0.0]: https://github.com/kettle-rb/tree_haver/compare/a89211bff10f4440b96758a8ac9d7d539001b0c8...v1.0.0
[1.0.0t]: https://github.com/kettle-rb/tree_haver/tags/v1.0.0
