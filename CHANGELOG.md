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

- `TreeHaver::RSpec::TestableNode` - A testable node class for creating mock TreeHaver::Node instances
  in tests without requiring an actual parser backend. Available via `require "tree_haver/rspec/testable_node"`
  or automatically when using `require "tree_haver/rspec"`.
  - `TestableNode.create(type:, text:, ...)` - Create a single test node
  - `TestableNode.create_list(...)` - Create multiple test nodes
  - `MockInnerNode` - The underlying mock that simulates backend-specific nodes
  - Top-level `TestableNode` constant for convenience in specs
- **Fully Dynamic Tag Registration** in `TreeHaver::BackendRegistry`:
  - `register_tag(tag_name, category:, backend_name:, require_path:)` - Register a complete dependency tag
    with lazy loading support. External gems can now get full RSpec tag support without any hardcoded
    knowledge in tree_haver.
  - `tag_available?(tag_name)` - Check if a tag's dependency is available, with automatic lazy loading
    via the registered `require_path`
  - `registered_tags` - Get all registered tag names
  - `tags_by_category(category)` - Get tags filtered by category (:backend, :gem, :parsing, :grammar, :engine, :other)
  - `tag_metadata(tag_name)` - Get full metadata for a registered tag
  - `tag_summary` - Get availability status of all registered tags

### Changed

- **Fully Dynamic Backend Availability** in `BackendRegistry` and `DependencyTags`:
  - `register_tag` now dynamically defines `*_available?` methods on `DependencyTags` at registration time
  - External gems automatically get availability methods when they call `register_tag`
  - No changes to tree_haver are needed for new external backend gems
  - Built-in backends (prism, psych, citrus, parslet) retain explicit methods
  - `summary` method dynamically includes registered backends from BackendRegistry
  - `backend_availability_methods` and `backend_tags` hashes are built dynamically
- RSpec exclusion filters for backend tags are configured dynamically from BackendRegistry

### Deprecated

### Removed

### Fixed

- **`TreeHaver::Parser#unwrap_language` bug fix for MRI and Rust backends**
  - `:mri` and `:rust` cases were not returning the unwrapped language value
  - The code called `lang.to_language` / `lang.inner_language` / `lang.name` but didn't `return` the result
  - Now properly returns the unwrapped language for all backend types
- `any_markdown_backend_available?` now uses `BackendRegistry.tag_available?` instead of calling
  `markly_available?` and `commonmarker_available?` directly. This fixes `NoMethodError` when
  the external markdown backend gems haven't registered their tags yet.

### Security

## [5.0.0] - 2026-01-11

- TAG: [v5.0.0][5.0.0t]
- COVERAGE: 92.04% -- 2289/2487 lines in 30 files
- BRANCH COVERAGE: 79.33% -- 929/1171 branches in 30 files
- 96.21% documented

### Added

- **Shared Example Groups for Backend API Compliance Testing**
  - `node_api_examples.rb` - Tests for Node API compliance:
    - `"node api compliance"` - Core Node interface (type, start_byte, end_byte, children)
    - `"node position api"` - Position API (start_point, end_point, start_line, end_line, source_position)
    - `"node children api"` - Children traversal (#child, #first_child, #last_child)
    - `"node enumerable behavior"` - Enumerable methods (#each, #map, #select, #find)
    - `"node comparison behavior"` - Comparison and equality (#==, #<=>, #hash)
    - `"node text extraction"` - Text content (#text, #to_s)
    - `"node inspection"` - Debug output (#inspect)
  - `tree_api_examples.rb` - Tests for Tree API compliance:
    - `"tree api compliance"` - Core Tree interface (root_node, source, errors, warnings, comments)
    - `"tree error handling"` - Error detection (#has_error?, #errors)
    - `"tree traversal"` - Depth-first traversal via root_node
  - `parser_api_examples.rb` - Tests for Parser API compliance:
    - `"parser api compliance"` - Core Parser interface (#parse, #parse_string, #language=)
    - `"parser incremental parsing"` - Incremental parsing support
    - `"parser error handling"` - Error recovery behavior
  - `language_api_examples.rb` - Tests for Language API compliance:
    - `"language api compliance"` - Core Language interface (#backend, #name/#language_name)
    - `"language comparison"` - Comparison and equality
    - `"language factory methods"` - Factory methods (.from_library, .from_path)
  - `backend_api_examples.rb` - Tests for Backend module API compliance:
    - `"backend module api"` - Backend availability and capabilities
    - `"backend class structure"` - Nested class verification
    - `"backend integration"` - Full parse cycle testing
  - `spec/support/shared_examples.rb` - Master loader for all shared examples
  - `spec/integration/backend_api_compliance_spec.rb` - Integration tests using all shared examples
- **Parslet Backend**: New pure Ruby PEG parser backend (`TreeHaver::Backends::Parslet`)
  - Wraps Parslet-based parsers (like the `toml` gem) to provide a pure Ruby alternative to tree-sitter
  - `Parslet.available?` - Check if parslet gem is available
  - `Parslet.capabilities` - Returns `{ backend: :parslet, query: false, bytes_field: true, incremental: false, pure_ruby: true }`
  - `Parslet::Language` - Wrapper for Parslet grammar classes
    - `Language.new(grammar_class)` - Create from a Parslet::Parser subclass
    - `Language.from_library(path, symbol:, name:)` - API-compatible lookup via LanguageRegistry
    - `#language_name` / `#name` - Derive language name from grammar class
  - `Parslet::Parser` - Wrapper that creates parser instances from grammar classes
    - Accepts both raw grammar class and Language wrapper (normalized API)
  - `Parslet::Tree` - Wraps Parslet parse results, inherits from `Base::Tree`
  - `Parslet::Node` - Unified node interface, inherits from `Base::Node`
    - Supports both Hash nodes (with named children) and Array nodes (with indexed children)
    - `#type` - Returns the node type (key name or "array"/"document")
    - `#children` - Returns child nodes
    - `#child_by_field_name(name)` - Access named children in Hash nodes
    - `#text` - Returns the matched text from Parslet::Slice
    - `#start_byte`, `#end_byte` - Byte positions from Parslet::Slice
    - `#start_point`, `#end_point` - Line/column positions (computed from source)
  - Registered with `BackendRegistry.register_availability_checker(:parslet)`
- **RSpec Dependency Tags**: Added `parslet_available?` method
  - Checks if parslet gem is installed via `BackendRegistry.available?(:parslet)`
  - `:parslet_backend` tag for specs requiring Parslet
  - `:not_parslet_backend` negated tag for specs that should skip when Parslet is available
- **RSpec Dependency Tags**: Added `toml_gem_available?` method and updated `any_toml_backend_available?`
  - `:toml_gem` tag for specs requiring the `toml` gem to be available
  - `:not_toml_gem` negated tag for specs that should skip when the `toml` gem is not available
- **ParsletGrammarFinder**: Utility for discovering and registering Parslet grammar gems
  - `ParsletGrammarFinder.new(language:, gem_name:, grammar_const:, require_path:)` - Find Parslet grammars
  - `#available?` - Check if the Parslet grammar gem is installed and functional
  - `#grammar_class` - Get the resolved Parslet::Parser subclass
  - `#register!` - Register the grammar with TreeHaver
  - Auto-loads via `TreeHaver::PARSLET_DEFAULTS` for known languages (toml)
- **TreeHaver.register_language**: Extended with `grammar_class:` parameter for Parslet grammars
- **TreeHaver.parser_for**: Extended with `parslet_config:` parameter for explicit Parslet configuration
- `MRI::Language#language_name` / `#name` - Derive language name from symbol or path
- `FFI::Language#language_name` / `#name` - Derive language name from symbol or path
- **spec_helper.rb**: Added `require "toml"` to load the toml gem for Parslet backend tests

### Changed

- **BREAKING: `TreeHaver::Language` converted from class to module**
  - Previously `TreeHaver::Language` was a class that wrapped backend language objects
  - Now `TreeHaver::Language` is a module providing factory methods (`method_missing` for dynamic language loading)
  - Backend-specific language classes (e.g., `TreeHaver::Backends::MRI::Language`) are now the concrete implementations
  - Code that instantiated `TreeHaver::Language.new(...)` directly must be updated to use backend-specific classes or the factory methods
- **BREAKING: `TreeHaver::Tree` now inherits from `TreeHaver::Base::Tree`**
  - `TreeHaver::Tree` is now a proper subclass of `TreeHaver::Base::Tree`
  - Inherits `inner_tree`, `source`, `lines` attributes from base class
  - Base class provides default implementations; subclass documents divergence
- **BREAKING: `TreeHaver::Node` now inherits from `TreeHaver::Base::Node`**
  - `TreeHaver::Node` is now a proper subclass of `TreeHaver::Base::Node`
  - Inherits `inner_node`, `source`, `lines` attributes from base class
  - Base class documents the API contract; subclass documents divergence
- **BREAKING: `Citrus::Node` and `Citrus::Tree` now inherit from Base classes**
  - `Citrus::Node` now inherits from `TreeHaver::Base::Node`
  - `Citrus::Tree` now inherits from `TreeHaver::Base::Tree`
  - Removes duplicated methods, uses inherited implementations
  - Adds `#language_name` / `#name` methods for API compliance
- **BREAKING: `Parslet::Node` and `Parslet::Tree` now inherit from Base classes**
  - `Parslet::Node` now inherits from `TreeHaver::Base::Node`
  - `Parslet::Tree` now inherits from `TreeHaver::Base::Tree`
  - Removes duplicated methods, uses inherited implementations
- **Base::Node#child now returns nil for negative indices** (tree-sitter API compatibility)
- **Citrus::Parser#language= now accepts Language wrapper or raw grammar module**
  - Both patterns now work: `parser.language = TomlRB::Document` or `parser.language = Citrus::Language.new(TomlRB::Document)`
- **Parslet::Parser#language= now accepts Language wrapper or raw grammar class**
  - Both patterns now work: `parser.language = TOML::Parslet` or `parser.language = Parslet::Language.new(TOML::Parslet)`
- **TreeHaver::Parser#unwrap_language** now passes Language wrappers directly to Citrus/Parslet backends
  - Previously unwrapped to raw grammar; now backends handle their own Language wrappers
- **Language.method_missing**: Now recognizes `:parslet` backend type and creates `Parslet::Language` instances
- **Parser**: Updated to recognize Parslet languages and switch to Parslet parser automatically
  - `#backend` now returns `:parslet` for Parslet-based parsers
  - `#language=` detects `Parslet::Language` and switches implementation
  - `handle_parser_creation_failure` tries Parslet as fallback after Citrus
  - `unwrap_language` extracts `grammar_class` for Parslet languages

### Fixed

- **FFI Backend Compliance Tests**: Fixed tests to use `TreeHaver::Parser` wrapper instead of raw `FFI::Parser`
  - Raw FFI classes (`FFI::Tree`, `FFI::Node`) don't have full API (missing `#children`, `#text`, `#source`, etc.)
  - TreeHaver wrapper classes (`TreeHaver::Tree`, `TreeHaver::Node`) provide the complete unified API
  - Tests now properly test the wrapped API that users actually interact with
- **Parslet TOML Sources**: Fixed test sources to be valid for the `toml` gem's Parslet grammar
  - Grammar requires table sections (not bare key-value pairs at root)
  - Grammar requires trailing newlines
- **Examples**: Fixed broken markdown examples that referenced non-existent TreeHaver backends
  - `commonmarker_markdown.rb` - Rewrote to use commonmarker gem directly (not a TreeHaver backend)
  - `markly_markdown.rb` - Rewrote to use markly gem directly with correct `source_position` API
  - `commonmarker_merge_example.rb` - Fixed to use `commonmarker/merge` gem properly
  - `markly_merge_example.rb` - Fixed to use `markly/merge` gem properly
  - `parslet_toml.rb` - Rewrote to properly use TreeHaver's Parslet backend with language registration
- **Examples**: Fixed `run_all.rb` test runner
  - Added parslet example to the test list
  - Changed markdown examples to use `backend: "standalone"` (they're not TreeHaver backends)
  - Added MRI+TOML to known incompatibilities (parse returns nil)
  - Added proper skip reason messages for all known incompatibilities
- **Examples**: Updated `examples/README.md` documentation
  - Added Parslet backend section with usage examples
  - Renamed "Commonmarker Backend" and "Markly Backend" to "Commonmarker (Standalone)" and "Markly (Standalone)"
  - Clarified that commonmarker and markly are standalone parsers, not TreeHaver backends
- **Duplicate Constants**: Removed duplicate `CITRUS_DEFAULTS` and `PARSLET_DEFAULTS` definitions
  - Constants were defined twice in `tree_haver.rb` (lines 170 and 315)
  - This was causing "already initialized constant" warnings on every require

## [4.0.5] - 2026-01-09

- TAG: [v4.0.5][4.0.5t]
- COVERAGE: 93.50% -- 2058/2201 lines in 28 files
- BRANCH COVERAGE: 81.11% -- 803/990 branches in 28 files
- 95.60% documented

### Added

- **FFI Backend**: Added `child_by_field_name` method to `TreeHaver::Backends::FFI::Node`
  - Enables field-based child access using tree-sitter's `ts_node_child_by_field_name` C API
  - Works with all grammars (JSON, JSONC, TOML, Bash, etc.) that define field names
  - Fixes compatibility issues with json-merge, jsonc-merge, and other gems that use field access
  - Example: `pair.child_by_field_name("key")` returns the key node from a JSON pair
- **RSpec Dependency Tags**: Added `compute_blocked_backends` method
  - Determines blocked backends from `TREE_HAVER_BACKEND` env and ARGV `--tag` options
  - Called by `summary` when `@blocked_backends` isn't set yet (before RSpec.configure runs)
  - Fixes issue where gem-specific `before(:suite)` hooks could load blocked backends
- **RSpec Dependency Tags**: Added `LD_LIBRARY_PATH` and `DYLD_LIBRARY_PATH` to `env_summary`
  - These library paths are relevant for tree-sitter shared library loading
  - Useful for debugging grammar loading issues
- **RSpec Dependency Tags**: Added `TREE_SITTER_RBS_PATH` to `env_summary`

### Changed

- **Language#method_missing**: Simplified error handling in `Language#method_missing`
  - Removed unreachable rescue block for `FFI::NotFoundError`
  - `FFI::NotFoundError` inherits from `LoadError`, so it's already caught by the prior rescue clause
  - Reduces code complexity without changing behavior
- **Parser#initialize**: Simplified error handling in `Parser#initialize`
  - Same fix as Language - removed unreachable `FFI::NotFoundError` handling
  - Added comment noting that `FFI::NotFoundError` inherits from `LoadError`
- **FFI Backend Native#try_load!**: Removed redundant `FFI::NotFoundError` from rescue clause
  - Only rescues `LoadError` now with comment explaining inheritance
- **GrammarFinder.tree_sitter_runtime_usable?**: Removed redundant `StandardError` rescue clause
  - `LoadError` already catches `FFI::NotFoundError`
  - Added comment explaining the inheritance relationship

### Fixed

- **Test Isolation**: Fixed state leakage in `language_registry_spec.rb`
  - Tests were registering real language names (`:toml`, `:json`, `:yaml`) with fake paths
  - These registrations persisted and polluted other tests that expected real grammar paths
  - Changed all tests to use unique test-only language names (prefixed with `test_lang_`)
  - Fixes 2 spec failures when running all tests together (`TreeHaver::Tree#edit` specs)

## [4.0.4] - 2026-01-09

- TAG: [v4.0.4][4.0.4t]
- COVERAGE: 95.27% -- 2033/2134 lines in 28 files
- BRANCH COVERAGE: 84.07% -- 802/954 branches in 28 files
- 95.49% documented

### Fixed

- **RSpec Dependency Tags**: Fixed blocked backend tests not being excluded on JRuby
  - When `TREE_HAVER_BACKEND=ffi` is set, MRI backend is blocked to prevent conflicts
  - Previously, this skipped BOTH the availability check AND the exclusion
  - Now blocked backends are excluded without checking availability
  - Tests tagged with `:mri_backend` now properly skip on JRuby when FFI is selected

## [4.0.3] - 2026-01-08

- TAG: [v4.0.3][4.0.3t]
- COVERAGE: 95.27% -- 2033/2134 lines in 28 files
- BRANCH COVERAGE: 84.17% -- 803/954 branches in 28 files
- 95.49% documented

### Changed

- **RSpec Dependency Tags**: Refactored FFI backend isolation to use standard `:ffi_backend` tag
  - The `--tag ffi_backend` now triggers `isolated_test_mode` in `dependency_tags.rb`
  - This prevents MRI backend from loading during availability checks
  - Legacy `*_backend_only` tags are still supported for backwards compatibility
  - Simplifies the testing pattern: one tag serves as both dependency tag and isolation trigger

### Deprecated

- **`:ffi_backend_only` tag**: Use `:ffi_backend` instead. The `*_backend_only` tags are now redundant.

## [4.0.2] - 2026-01-08

- TAG: [v4.0.2][4.0.2t]
- COVERAGE: 95.27% -- 2033/2134 lines in 28 files
- BRANCH COVERAGE: 84.07% -- 802/954 branches in 28 files
- 95.49% documented

### Added

- **FFI Backend**: Implemented `missing?` method on `TreeHaver::Backends::FFI::Node`
  - Added `ts_node_is_missing` FFI function attachment
  - This method was missing entirely, causing `NoMethodError` when checking for MISSING nodes

### Changed

- **TreeHaver::Node**: Removed defensive `respond_to?` checks from `has_error?` and `missing?` methods
  - All tree-sitter backends (MRI, Rust, FFI, Java) must implement these methods on their inner nodes
  - This enforces proper backend API compliance rather than silently masking missing implementations

### Fixed

- **FFI Backend**: Added explicit boolean conversion (`!!`) to `has_error?` return value
  - FFI `:bool` return type may behave inconsistently across Ruby versions and platforms
  - Ensures `has_error?` always returns `true` or `false`, not truthy/falsy values

## [4.0.1] - 2026-01-08

- TAG: [v4.0.1][4.0.1t]
- COVERAGE: 95.31% -- 2032/2132 lines in 28 files
- BRANCH COVERAGE: 84.10% -- 804/956 branches in 28 files
- 95.48% documented

### Fixed

- **FFI Backend**: Implemented `has_error?` method on `TreeHaver::Backends::FFI::Node`
  - Previously was a stub that always returned `false`, causing parse errors to go undetected
  - Now properly calls `ts_node_has_error` FFI function to detect syntax errors in parsed trees
  - This fixes error detection on JRuby when using the FFI backend with tree-sitter grammars

## [4.0.0] - 2026-01-08

- TAG: [v4.0.0][4.0.0t]
- COVERAGE: 95.31% -- 2031/2131 lines in 28 files
- BRANCH COVERAGE: 84.21% -- 805/956 branches in 28 files
- 95.48% documented

### Added

- **BackendRegistry**: New `TreeHaver::BackendRegistry` module for registering backend availability checkers
  - Allows external gems (like `commonmarker-merge`, `markly-merge`, `rbs-merge`) to register their availability checkers
  - `register_availability_checker(backend_name, &block)` - Register a callable that returns true if backend is available
  - `available?(backend_name)` - Check if a backend is available (results are cached)
  - `registered?(backend_name)` - Check if a checker is registered
  - `registered_backends` - Get all registered backend names
  - Used by `TreeHaver::RSpec::DependencyTags` for dynamic backend detection
- **Plugin System**: `commonmarker-merge` and `markly-merge` now provide their own backends via `TreeHaver`'s registry system, removing them from `TreeHaver` core.
- **Backend Architecture Documentation**: Added comprehensive documentation to base classes and all tree-sitter backends explaining the two backend categories:
  - Tree-sitter backends (MRI, Rust, FFI, Java): Use `TreeHaver::Tree` and `TreeHaver::Node` wrappers for raw tree-sitter objects
  - Pure-Ruby/Plugin backends (Citrus, Prism, Psych, Commonmarker, Markly): Define own `Backend::X::Tree` and `Backend::X::Node` classes

### Changed

- **Base Class Inheritance**: `TreeHaver::Tree` and `TreeHaver::Node` now properly inherit from their respective `Base::` classes
  - `TreeHaver::Tree < Base::Tree` - inherits `inner_tree`, `source`, `lines` attributes and default implementations
  - `TreeHaver::Node < Base::Node` - inherits `inner_node`, `source`, `lines` attributes and API contract
  - Base classes document the API contract; subclasses document divergence
- **Base::Node#initialize**: Now accepts keyword arguments `source:` and `lines:` instead of positional for consistency with subclasses
- **DependencyTags**: Now uses `BackendRegistry.available?(:backend_name)` instead of hardcoded `TreeHaver::Backends::*` checks
- **TreeHaver**: `commonmarker` and `markly` backends are no longer built-in. Use `commonmarker-merge` and `markly-merge` gems which register themselves.
- **All backends**: Now register their availability checkers with `BackendRegistry` when loaded (MRI, Rust, FFI, Java, Prism, Psych, Citrus)

### Removed

- **TreeHaver**: Removed `TreeHaver::Backends::Commonmarker` and `TreeHaver::Backends::Markly` modules. These implementations have moved to their respective gems.

## [3.2.6] - 2026-01-06

- TAG: [v3.2.6][3.2.6t]
- COVERAGE: 92.07% -- 2230/2422 lines in 23 files
- BRANCH COVERAGE: 74.69% -- 788/1055 branches in 23 files
- 90.37% documented

### Fixed

- **Java backend**: Fixed Optional handling in Node methods that could return nil incorrectly
  - `child(index)`, `child_by_field_name(name)`, `parent`, `next_sibling`, `prev_sibling` now properly check for nil before attempting to unwrap Java Optional
  - Previously, the ternary-based Optional check could fail when jtreesitter returned null directly instead of Optional.empty()
  - This fixes JRuby test failures where `key_name` returned nil and object keys were not extracted

## [3.2.5] - 2026-01-05

- TAG: [v3.2.5][3.2.5t]
- COVERAGE: 92.07% -- 2230/2422 lines in 23 files
- BRANCH COVERAGE: 74.69% -- 788/1055 branches in 23 files
- 90.37% documented

### Fixed

- **Markly backend**: `Node#text` now correctly handles container nodes (headings, paragraphs, etc.)
  - Previously returned empty string because `string_content` was checked first (responds but returns empty for containers)
  - Now falls through to `to_plaintext` or children concatenation when `string_content` is empty
- **Commonmarker backend**: `Node#text` now correctly handles container nodes
  - Previously could return empty string in edge cases
  - Now consistently falls through to children concatenation when `string_content` is empty or raises TypeError

## [3.2.4] - 2026-01-04

- TAG: [v3.2.4][3.2.4t]
- COVERAGE: 92.07% -- 2229/2421 lines in 23 files
- BRANCH COVERAGE: 74.79% -- 786/1051 branches in 23 files
- 90.37% documented

### Added

- **External backend registration via `backend_module`** - External gems can now register
  their own pure Ruby backends using the same API as built-in backends. This enables gems
  like rbs-merge to integrate with `TreeHaver.parser_for` without modifying tree_haver:
```ruby
TreeHaver.register_language(
  :rbs,
  backend_module: Rbs::Merge::Backends::RbsBackend,
  backend_type: :rbs,
  gem_name: "rbs",
)
# Now TreeHaver.parser_for(:rbs) works!
```
- **`Backends::PURE_RUBY_BACKENDS` constant** - Maps pure Ruby backend names to their
  language and module info. Used for auto-registration of built-in backends.
- **`TreeHaver.register_builtin_backends!`** - Registers built-in pure Ruby backends
  (Prism, Psych, Commonmarker, Markly) in the LanguageRegistry using the same API that
  external backends use. Called automatically by `parser_for` on first use.
- **`TreeHaver.ensure_builtin_backends_registered!`** - Idempotent helper that ensures
  built-in backends are registered exactly once.
- **`parser_for` now supports registered `backend_module` backends** - When a language
  has a registered `backend_module`, `parser_for` will use it. This enables external
  gems to provide language support without tree-sitter grammars:
  - Checks LanguageRegistry for registered `backend_module` entries
  - Creates parser from the backend module's `Parser` and `Language` classes
  - Falls back to tree-sitter and Citrus if no backend_module matches
- **RBS dependency tags in `DependencyTags`** - New RSpec tags for RBS parsing:
  - `:rbs_grammar` - tree-sitter-rbs grammar is available and parsing works
  - `:rbs_parsing` - at least one RBS parser (rbs gem OR tree-sitter-rbs) is available
  - `:rbs_gem` - the official rbs gem is available (MRI only)
  - Negated versions: `:not_rbs_grammar`, `:not_rbs_parsing`, `:not_rbs_gem`
  - New availability methods: `tree_sitter_rbs_available?`, `rbs_gem_available?`, `any_rbs_backend_available?`
- **Support for tree-sitter 0.26.x ABI** - TreeHaver now fully supports grammars built
  against tree-sitter 0.26.x (LANGUAGE_VERSION 15). This required updates to vendored
  dependencies:
  - **ruby-tree-sitter**: Updated to support tree-sitter 0.26.3 C library API changes
    including new `ts_language_abi_version()` function, UTF-16 encoding split, and
    removal of deprecated parser timeout/cancellation APIs
  - **tree_stump (Rust backend)**: Updated to tree-sitter Rust crate 0.26.3 with new
    `abi_version()` method, `u32` child indices, and streaming iterator-based query matches
- **MRI backend now loads grammars with LANGUAGE_VERSION 15** - Previously, MRI backend
  using ruby_tree_sitter could only load grammars with LANGUAGE_VERSION ≤ 14. Now supports
  grammars built against tree-sitter 0.26.x.
- **Rust backend now loads grammars with LANGUAGE_VERSION 15** - Previously, the tree_stump
  Rust backend reported "Incompatible language version 15. Expected minimum 13, maximum 14".
  Now supports the latest grammar format.
- **BackendAPI validation module** - New `TreeHaver::BackendAPI` module for validating
  backend API compliance:
  - `BackendAPI.validate(backend_module)` - Returns validation results hash
  - `BackendAPI.validate!(backend_module)` - Raises on validation failure
  - `BackendAPI.validate_node_instance(node)` - Validates a node instance
  - Defines required and optional methods for Language, Parser, Tree, and Node classes
  - Documents API contract for wrapper vs raw backends
  - New `examples/validate_backends.rb` script to validate all backends
- **Java backend Node class now implements full API** - Added missing methods to ensure
  API consistency with other backends:
  - `parent` - Get parent node
  - `next_sibling` - Get next sibling node
  - `prev_sibling` - Get previous sibling node
  - `named?` - Check if node is named
  - `child_by_field_name` - Get child by field name
  - All methods properly handle jtreesitter 0.26.0's `Optional<Node>` return types
- **Three environment variables for backend control** - Fine-grained control over which
  backends are available:
  - `TREE_HAVER_BACKEND` - Single backend selection (auto, mri, ffi, rust, java, citrus, etc.)
  - `TREE_HAVER_NATIVE_BACKEND` - Allow list for native backends (auto, none, or comma-separated
    list like `mri,ffi`). Use `none` for pure-Ruby-only mode.
  - `TREE_HAVER_RUBY_BACKEND` - Allow list for pure Ruby backends (auto, none, or comma-separated
    list like `citrus,prism`). Use `none` for native-only mode.
- **Backend availability now respects allow lists** - When `TREE_HAVER_NATIVE_BACKEND` is set
  to specific backends (e.g., `mri,ffi`), all other native backends are treated as unavailable.
  This applies to ALL backend selection mechanisms:
  - Auto-selection in `backend_module`
  - Explicit selection via `with_backend(:rust)` - returns nil/unavailable
  - Explicit selection via `resolve_backend_module(:rust)` - returns nil
  - RSpec dependency tags (`ffi_available?`, etc.)

  This makes the environment variables a **hard restriction**, not just a hint for auto-selection.
  Use `TREE_HAVER_NATIVE_BACKEND=none` for pure-Ruby-only mode, or specify exactly which
  native backends are permitted (e.g., `mri,ffi`).
- **Java backend updated for jtreesitter 0.26.0** - Full compatibility with jtreesitter 0.26.0:
  - Updated `Parser#parse` and `Parser#parse_string` to handle `Optional<Tree>` return type
  - Updated `Tree#root_node` to handle `Optional<Node>` return type
  - Fixed `parse_string` argument order to match jtreesitter 0.26.0 API: `parse(String, Tree)`
  - Updated `Language.load_by_name` to use `SymbolLookup` API (single-arg `load(name)` removed)
  - Added `bin/setup-jtreesitter` script to download jtreesitter JAR from Maven Central
  - Added `bin/build-grammar` script to build tree-sitter grammars from source
  - Older versions of jtreesitter are NOT supported
- **`TREE_HAVER_BACKEND_PROTECT` environment variable** - Explicit control over backend
  conflict protection. Set to `false` to disable protection that prevents mixing
  incompatible native backends (e.g., FFI after MRI). Useful for testing scenarios
  where you understand the risks. Default behavior (protection enabled) unchanged.

### Changed

- **API normalized: `from_library` is now universal** - All language-specific backends
  (Psych, Prism, Commonmarker, Markly) now implement `Language.from_library` for API
  consistency. This allows `TreeHaver.parser_for(:yaml)` to work uniformly regardless
  of which backend is active:
  - **Psych**: `from_library` accepts (and ignores) path/symbol, returns YAML language
  - **Prism**: `from_library` accepts (and ignores) path/symbol, returns Ruby language
  - **Commonmarker**: `from_library` accepts (and ignores) path/symbol, returns Markdown language
  - **Markly**: `from_library` accepts (and ignores) path/symbol, returns Markdown language
  - All raise `TreeHaver::NotAvailable` if a different language is requested
- **Citrus backend `from_library` now looks up registered grammars** - Instead of always
  raising an error, `Backends::Citrus::Language.from_library` now looks up registered
  Citrus grammars by name via `LanguageRegistry`. This enables `TreeHaver.parser_for(:toml)`
  to work seamlessly when a Citrus grammar has been registered with
  `TreeHaver.register_language(:toml, grammar_module: TomlRB::Document)`.
- **Java backend requires jtreesitter >= 0.26.0** - Due to API changes in jtreesitter,
  older versions are no longer supported. The tree-sitter runtime library must also be
  version 0.26.x to match.
  by the RSpec dependency tags. This ensures tests tagged with `:mri_backend` only run when
  MRI is in the allow list. Same for `TREE_HAVER_RUBY_BACKEND` and pure Ruby backends.
- New `TreeHaver.allowed_native_backends` method returns the allow list for native backends.
- New `TreeHaver.allowed_ruby_backends` method returns the allow list for pure Ruby backends.
- New `TreeHaver.backend_allowed?(backend)` method checks if a specific backend is allowed
  based on the current environment variable settings.
- New `DependencyTags.allowed_native_backends` and `DependencyTags.allowed_ruby_backends` methods.
- Updated `examples/test_backend_selection.rb` script to test all three environment variables.
- **`LanguageRegistry` now supports any backend type** - Previously only `:tree_sitter` and
  `:citrus` were documented. Now supports arbitrary backend types including `:prism`, `:psych`,
  `:commonmarker`, `:markly`, `:rbs`, or any custom type. External gems can register their
  own backend types using the same API.
- **`register_language` accepts `backend_module` parameter** - New parameter for registering
  pure Ruby backends. The module must provide `Language` and `Parser` classes with the
  standard TreeHaver API (`available?`, `capabilities`, `from_library`, etc.).

### Fixed

- **`TreeHaver::Node#text` now handles backends with different `text` method signatures** -
  Previously, `Node#text` would call `@inner_node.text` directly, but `TreeStump::Node#text`
  (Rust backend) requires the source as an argument (`text(source)`). This caused
  `ArgumentError: wrong number of arguments (given 0, expected 1)` when using the Rust
  backend. Now `Node#text` checks the method arity and passes the source when required:
  - Arity 0 or -1: calls `@inner_node.text` without arguments
  - Arity >= 1: calls `@inner_node.text(@source)` with source
  - Falls back to byte-based extraction if source is available

- **AUTO mode now gracefully falls back when explicitly requested backend is blocked** -
  Previously, if `TREE_HAVER_BACKEND=ffi` was set in the environment but FFI was blocked
  due to MRI being used first (backend conflict protection), `parser_for` would raise a
  `BackendConflict` error. Now, when the explicitly requested backend is blocked by a
  **backend conflict** (e.g., FFI after MRI causes segfaults):
  - `backend_module` detects the conflict and falls back to auto-selection
  - `resolve_native_backend_module` rescues `BackendConflict` and continues to the next
    backend in the priority list
  - This enables seamless multi-backend usage in test suites where different tests use
    different backends, but one backend has already "poisoned" the process for another.

  Note: This fallback only applies to **backend conflicts** (runtime incompatibility).
  If a backend is disallowed by `TREE_HAVER_NATIVE_BACKEND` or `TREE_HAVER_RUBY_BACKEND`,
  it will simply be unavailable—no error is raised, but no fallback occurs either.

- **`java_backend_available?` now verifies grammar loading works** - Previously, the
  `DependencyTags.java_backend_available?` method only checked if java-tree-sitter
  classes could be loaded, but didn't verify that grammars could actually be used.
  This caused tests tagged with `:java_backend` to run on JRuby even when the grammar
  `.so` files (built for MRI) were incompatible with java-tree-sitter's Foreign Function
  Memory API. Now the check does a live test by attempting to load a grammar, ensuring
  the tag accurately reflects whether the Java backend is fully functional.

## [3.2.3] - 2026-01-02

- TAG: [v3.2.3][3.2.3t]
- COVERAGE: 94.91% -- 2088/2200 lines in 22 files
- BRANCH COVERAGE: 81.37% -- 738/907 branches in 22 files
- 90.14% documented

### Fixed

- **`parser_for` now respects explicitly requested non-native backends** - Previously,
  `parser_for` would always try tree-sitter backends first and only fall back to alternative
  backends if tree-sitter was unavailable. Now it checks `effective_backend` and skips
  tree-sitter attempts entirely when a non-native backend is explicitly requested via:
  - `TREE_HAVER_BACKEND=citrus` (or `prism`, `psych`, `commonmarker`, `markly`)
  - `TreeHaver.backend = :citrus`
  - `TreeHaver.with_backend(:citrus) { ... }`

  Native backends (`:mri`, `:rust`, `:ffi`, `:java`) still use tree-sitter grammar discovery.

- **`load_tree_sitter_language` now correctly ignores Citrus registrations** - Previously,
  if a language was registered with Citrus first, `load_tree_sitter_language` would
  incorrectly try to use it even when a native backend was explicitly requested. Now it
  only uses registrations that have a `:tree_sitter` key, allowing proper backend switching
  between Citrus and native tree-sitter backends.

- **`load_tree_sitter_language` now validates registered paths exist** - Previously,
  if a language had a stale/invalid tree-sitter registration with a non-existent path
  (e.g., from a test), the code would try to use it and fail. Now it checks
  `File.exist?(path)` before using a registered path, falling back to auto-discovery
  via `GrammarFinder` if the registered path doesn't exist.

- **`Language.method_missing` no longer falls back to Citrus when native backend explicitly requested** -
  Previously, when tree-sitter loading failed (e.g., .so file missing), the code would
  silently fall back to Citrus even if the user explicitly requested `:mri`, `:rust`,
  `:ffi`, or `:java`. Now fallback to Citrus only happens when `effective_backend` is `:auto`.
  This is a **breaking change** for users who relied on silent fallback behavior.

- **Simplified `parser_for` implementation** - Refactored from complex nested conditionals to
  cleaner helper methods (`load_tree_sitter_language`, `load_citrus_language`). The logic is
  now easier to follow and maintain.

## [3.2.2] - 2026-01-01

- TAG: [v3.2.2][3.2.2t]
- COVERAGE: 94.79% -- 2076/2190 lines in 22 files
- BRANCH COVERAGE: 81.35% -- 733/901 branches in 22 files
- 90.14% documented

### Fixed

- RSpec dependency tags now respect `TREE_HAVER_BACKEND` environment variable
  - When `TREE_HAVER_BACKEND=ffi` is set, MRI backend availability is not checked
  - Prevents `BackendConflict` errors when loading gems that use tree-sitter grammars
  - The `blocked_backends` set now includes backends that would conflict with the explicitly selected backend
  - This allows `*-merge` gems to load correctly in test suites when a specific backend is selected

## [3.2.1] - 2025-12-31

- TAG: [v3.2.1][3.2.1t]
- COVERAGE: 94.75% -- 2075/2190 lines in 22 files
- BRANCH COVERAGE: 81.35% -- 733/901 branches in 22 files
- 90.14% documented

### Added

- `TreeHaver::LibraryPathUtils` module for consistent path parsing across all backends
  - `derive_symbol_from_path(path)` - derives tree-sitter symbol (e.g., `tree_sitter_toml`) from library path
  - `derive_language_name_from_path(path)` - derives language name (e.g., `toml`) from library path
  - `derive_language_name_from_symbol(symbol)` - strips `tree_sitter_` prefix from symbol
  - Handles various naming conventions: `libtree-sitter-toml.so`, `libtree_sitter_toml.so`, `tree-sitter-toml.so`, `toml.so`
- Isolated backend RSpec tags for running tests without loading conflicting backends
  - `:ffi_backend_only` - runs FFI tests without triggering `mri_backend_available?` check
  - `:mri_backend_only` - runs MRI tests without triggering `ffi_available?` check
  - Uses `TreeHaver::Backends::BLOCKED_BY` to dynamically determine which availability checks to skip
  - Enables `rake ffi_specs` to run FFI tests before MRI is loaded
- `DependencyTags.ffi_backend_only_available?` - checks FFI availability without loading MRI
- `DependencyTags.mri_backend_only_available?` - checks MRI availability without checking FFI

### Changed

- All backends now use shared `LibraryPathUtils` for path parsing
  - MRI, Rust, FFI, and Java backends updated for consistency
  - Ensures identical behavior across all tree-sitter backends
- `TreeHaver::Language` class extracted to `lib/tree_haver/language.rb`
  - No API changes, just file organization
  - Loaded via autoload for lazy loading
- `TreeHaver::Parser` class extracted to `lib/tree_haver/parser.rb`
  - No API changes, just file organization
  - Loaded via autoload for lazy loading
- Backend availability exclusions in `dependency_tags.rb` are now dynamic
  - Uses `TreeHaver::Backends::BLOCKED_BY` to skip availability checks for blocked backends
  - When running with `--tag ffi_backend_only`, MRI availability is not checked
  - Prevents MRI from being loaded before FFI tests can run
- Rakefile `ffi_specs` task now uses `:ffi_backend_only` tag
  - Ensures FFI tests run without loading MRI backend first

### Fixed

- Rakefile now uses correct RSpec tags for FFI isolation
  - The `ffi_specs` task uses `:ffi_backend_only` to prevent MRI from loading
  - The `remaining_specs` task excludes `:ffi_backend_only` tests
  - Tags in Rakefile align with canonical tags from `dependency_tags.rb`
- `TreeHaver::RSpec::DependencyTags.mri_backend_available?` now uses correct require path
  - Was: `require "ruby_tree_sitter"` (wrong - causes LoadError)
  - Now: `require "tree_sitter"` (correct - gem name is ruby_tree_sitter but require path is tree_sitter)
  - This fix ensures the MRI backend is correctly detected as available in CI environments
- `TreeHaver::Backends::MRI::Language.from_library` now properly derives symbol from path
  - Previously, calling `from_library(path)` without `symbol:` would fail because `language_name` was nil
  - Now delegates to private `from_path` after deriving symbol, ensuring proper language name derivation
  - `from_path` is now private (but still accessible via `send` for testing if needed)
  - Extracts language name from paths like `/usr/lib/libtree-sitter-toml.so` → `tree_sitter_toml`
  - Handles both dash and underscore separators in filenames
  - Handles simple language names like `toml.so` → `tree_sitter_toml`
- `TreeHaver::Backends::MRI::Parser#language=` now unwraps `TreeHaver::Backends::MRI::Language` wrappers
  - Accepts both raw `TreeSitter::Language` and wrapped `TreeHaver::Backends::MRI::Language`
- `TreeHaver::GrammarFinder.tree_sitter_runtime_usable?` no longer references `FFI::NotFoundError` directly
  - Prevents `NameError` when FFI gem is not loaded
- `TreeHaver::Parser#initialize` no longer references `FFI::NotFoundError` directly in rescue clause
  - Uses `defined?(::FFI::NotFoundError)` check to safely handle FFI errors when FFI is loaded
  - Prevents `NameError: uninitialized constant TreeHaver::Parser::FFI` when FFI gem is not available
  - Extracted error handling to `handle_parser_creation_failure` private method for clarity
- RSpec `dependency_tags.rb` now correctly detects `--tag` options during configuration
  - RSpec's `config.inclusion_filter.rules` is empty during configuration phase
  - Now parses `ARGV` directly to detect `--tag ffi_backend_only` and similar tags
  - Skips grammar availability checks (which load MRI) when running isolated backend tests
  - Skips full dependency summary in `before(:suite)` when backends are blocked
- `TreeHaver::Backends::FFI.reset!` now uses consistent pattern with other backends
  - Was using `@ffi_gem_available` with `defined?()` check, which returned truthy after `reset!` set it to nil
  - Now uses `@load_attempted` / `@loaded` pattern like MRI, Rust, Citrus, Prism, Psych, etc.
  - This fixes FFI tests failing after the first test when `reset!` was called in `after` blocks
- `TreeHaver::Language.method_missing` no longer references `FFI::NotFoundError` directly in rescue clause
  - Uses `defined?(::FFI::NotFoundError)` check to safely handle FFI errors when FFI is loaded
  - Prevents `NameError` when FFI gem is not available but tree-sitter backends are used
  - Extracted Citrus fallback logic to `handle_tree_sitter_load_failure` private method

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

[Unreleased]: https://github.com/kettle-rb/tree_haver/compare/v5.0.0...HEAD
[5.0.0]: https://github.com/kettle-rb/tree_haver/compare/v4.0.5...v5.0.0
[5.0.0t]: https://github.com/kettle-rb/tree_haver/releases/tag/v5.0.0
[4.0.5]: https://github.com/kettle-rb/tree_haver/compare/v4.0.4...v4.0.5
[4.0.5t]: https://github.com/kettle-rb/tree_haver/releases/tag/v4.0.5
[4.0.4]: https://github.com/kettle-rb/tree_haver/compare/v4.0.3...v4.0.4
[4.0.4t]: https://github.com/kettle-rb/tree_haver/releases/tag/v4.0.4
[4.0.3]: https://github.com/kettle-rb/tree_haver/compare/v4.0.2...v4.0.3
[4.0.3t]: https://github.com/kettle-rb/tree_haver/releases/tag/v4.0.3
[4.0.2]: https://github.com/kettle-rb/tree_haver/compare/v4.0.1...v4.0.2
[4.0.2t]: https://github.com/kettle-rb/tree_haver/releases/tag/v4.0.2
[4.0.1]: https://github.com/kettle-rb/tree_haver/compare/v4.0.0...v4.0.1
[4.0.1t]: https://github.com/kettle-rb/tree_haver/releases/tag/v4.0.1
[4.0.0]: https://github.com/kettle-rb/tree_haver/compare/v3.2.6...v4.0.0
[4.0.0t]: https://github.com/kettle-rb/tree_haver/releases/tag/v4.0.0
[3.2.6]: https://github.com/kettle-rb/tree_haver/compare/v3.2.5...v3.2.6
[3.2.6t]: https://github.com/kettle-rb/tree_haver/releases/tag/v3.2.6
[3.2.5]: https://github.com/kettle-rb/tree_haver/compare/v3.2.4...v3.2.5
[3.2.5t]: https://github.com/kettle-rb/tree_haver/releases/tag/v3.2.5
[3.2.4]: https://github.com/kettle-rb/tree_haver/compare/v3.2.3...v3.2.4
[3.2.4t]: https://github.com/kettle-rb/tree_haver/releases/tag/v3.2.4
[3.2.3]: https://github.com/kettle-rb/tree_haver/compare/v3.2.2...v3.2.3
[3.2.3t]: https://github.com/kettle-rb/tree_haver/releases/tag/v3.2.3
[3.2.2]: https://github.com/kettle-rb/tree_haver/compare/v3.2.1...v3.2.2
[3.2.2t]: https://github.com/kettle-rb/tree_haver/releases/tag/v3.2.2
[3.2.1]: https://github.com/kettle-rb/tree_haver/compare/v3.2.0...v3.2.1
[3.2.1t]: https://github.com/kettle-rb/tree_haver/releases/tag/v3.2.1
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
