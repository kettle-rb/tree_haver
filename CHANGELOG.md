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

- Fixed `TreeHaver::Tree#supports_editing?` to use the same check as `#edit` method for consistency
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
