# Slice 848: Tree Haver Old Backend Implementation Inventory

## Goal

Classify the old Ruby `tree_haver` backend implementation files and aliases
against the active StructuredMerge backend substrate, and identify which prior
backend code is restored.

## Contract

Surviving active backend families:

- `tslp` is the default generic `tree-sitter-language-pack` backend surface;
- `kreuzberg-language-pack` remains a compatibility backend id for the same
  language-pack surface;
- `mri`, `rust`, `ffi`, and `java` are explicit parser-capable native
  tree-sitter backends restored from the reference implementation;
- PEG backends survive as explicit Citrus and Parslet adapter primitives;
- Kaitai survives as the binary/schema tree substrate;
- native/source providers survive through capability reports, normalized tree
  projection, metadata, diagnostics, and provider-local parsers.

Retired shared backend paths and aliases:

- old compatibility aliases such as `TreeSitter::*` shims are retired;
- old Prism and Psych tree-haver backends remain provider-local Ruby and YAML
  implementations that project normalized trees and provider capability
  reports;
- grammar finder and path validator primitives remain active because restored
  native backends need guarded shared-library discovery.

Rule:

- a backend implementation is active only if it has a backend reference,
  capability/profile fixture, provider diagnostics, and at least one conformance
  path using it.
