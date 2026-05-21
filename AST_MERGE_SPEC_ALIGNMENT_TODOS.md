# Ast::Merge Spec-Alignment Todos

This document tracks the implementation work needed to make `ast-merge` look more like the emerging merge-ruleset specification while also preventing `ast-merge` from becoming an unbounded dumping ground.

The guiding principle is:

> Push shared behavior down into `ast-merge` when it is truly common, declarative, and spec-shaped. Push things out of `ast-merge` when they are runtime-specific, fixture-oriented, or only reusable once the interfaces have stabilized.

## Primary goals

1. Align internal terminology with the draft ruleset vocabulary.
2. Turn one-off merge-gem behavior into shared, ruleset-shaped behavior where possible.
3. Keep `ast-merge` usable as a reference implementation without making it even more monolithic.
4. Separate runtime substrate from conformance artifacts and implementation-specific extras when the seams become clear.

## Regex removal and native parser defaults

The StructuredMerge stack should prefer native parser-backed structural logic over
regular expressions. Regex remains acceptable for scalar validation, simple path
normalization, generated badge/link text handling, or deliberately documented
fallbacks, but it should not drive source ownership, node discovery, dependency
discovery, require/import discovery, block boundaries, or merge ownership when a
parser-backed API can answer the question.

For every language family, the generic `*-merge` gem is the TreeHaver / TSLP
substrate boundary. Native-parser gems should build on that shared layer, not
replace it. The purpose of the TSLP layer is partly operational and partly
architectural: it exposes which merge behaviors are common across parser records
and which behaviors need native-parser-specific treatment.

- [x] Document the AST-first rule in the workspace agent guide.
- [x] Document the TreeHaver / TSLP substrate boundary in the workspace agent guide.
- [x] Make Ruby Gemfile templating use `prism-merge` by default, including modifier `if` DSL calls.
- [x] Make Ruby and Rakefile templating use `prism-merge` by default instead of the TSLP-backed `ruby-merge` path.
- [x] Make `ast-template` prefer the native Prism adapter for Ruby directory sessions, with TSLP-backed `ruby-merge` retained only as an optional fallback when `prism-merge` is absent.
- [x] Preserve plain Ruby's existing “do not add template-only requires” policy with Prism call records.
- [x] Preserve Gemfile commented dependency policy with Prism call/comment records instead of line regexes.
- [x] Update the workspace Ruby templating runner to run with `K_JEM_TEMPLATING=true` and normalize lockfiles afterward without templating/local-path env.
- [x] Classify remaining Ruby regex usage as source-structure, parser fallback, comment/trivia lexing, scalar validation, path/config parsing, test-only assertion, or documentation/example.
- [x] Replace Gemfile eval bucket discovery with Prism call records and path-segment normalization.
- [x] Replace Appraisals block discovery and minimum-Ruby pruning with Prism call records.
- [x] Replace Rakefile scaffold cleanup with Prism top-level call records.
- [x] Replace gemspec block parameter and dependency discovery/removal with Prism records.
- [x] Replace gemspec assignment and metadata extraction with Prism records.
- [x] Replace gemspec assignment rewrite and insertion helpers with Prism records.
- [x] Replace Gemfile `%w[...]` dependency list discovery/removal and local-gem overrides with Prism records.
- [x] Replace version entrypoint namespace and constant discovery with Prism records.
- [x] Replace Rakefile orphaned require cleanup with Prism top-level require records.
- [x] Replace or justify remaining source-structure regex collectors in kettle-jem.
  - [x] Replace install-task gemspec development dependency extraction with Prism-backed gemspec dependency records.
  - [x] Replace install-task gemspec summary/description grapheme rewrites with Prism string assignment records.
  - [x] Replace install-task gemspec homepage repair with Prism assignment records.
  - [x] Replace README H1 project/grapheme rewrites with `ast-crispr-markdown-markly` heading owners.
  - [x] Replace kettle-jem README section collection with `ast-crispr-markdown-markly` heading owners.
  - [x] Replace GitHub Actions matrix pruning line scanner with Psych YAML AST mapping records.
  - [x] Replace Appraisal `eval_gemfile` exclusion discovery with Prism call records.
  - [x] Replace GitHub Actions top-level section insertion with Psych YAML AST key records.
  - [x] Replace GitHub Actions action pin rewrites with Psych YAML scalar records.
  - [x] Replace GitHub Actions coverage-step insertion with Psych YAML sequence records.
  - [x] Replace changelog heading normalization with `ast-crispr-markdown-markly` heading owners.
  - [x] Replace `.kettle-jem.yml` bootstrap emoji/license rewrites with Psych YAML node records.
  - [x] Replace README project emoji discovery and funding YAML key sync with Markly/Psych records.
  - [x] Replace template checksum YAML block replacement with Psych YAML node records.
  - [x] Replace README compatibility/workflow link definition discovery and deletion with `ast-crispr-markdown-markly` link definition owners.
  - [x] Replace README badge-cloud inline reference scans and badge occurrence deletion with `ast-crispr-markdown-markly` inline reference owners.
  - [x] Replace README compatibility row pruning with `ast-crispr-markdown-markly` table/loose-pipe row owners; remaining README postprocessor regexes are scalar label/version parsing or whitespace formatting.
- [x] Route `ruby-merge` parsing through TreeHaver / TSLP process analysis and use process records first for Ruby declaration discovery.
- [x] Fix upstream `tree-sitter-language-pack` Ruby structure extraction so TSLP emits Ruby module, class, instance method, and singleton method records.
- [x] Decide the downstream TreeHaver behavior for unreadable or too-old TSLP Ruby bindings: fail closed with an upstream bug-report diagnostic.
- [x] Remove TreeHaver's regex-backed language-pack process fallback and require readable process records for TSLP-backed merge paths.
- [ ] Replace or justify source-structure regex collectors in `ruby-merge` itself, or narrow that gem to explicit TSLP backend parity paths where Prism is not the active default.
  - [x] Stop mixing legacy regex declaration discovery into parser-backed Ruby structure when TSLP process records are present.
  - [x] Narrow `Ruby::Merge.merge_ruby` to the TSLP-record-backed top-level declaration/import subset; unmodeled top-level Ruby content now fails closed with a `prism-merge`/upstream TSLP diagnostic instead of using legacy scanners.
  - [x] Replace `Prism::Merge.parse_ruby`'s dependency on `Ruby::Merge.analyze_ruby_document` with Prism-node-backed shared analysis owners and YARD surface discovery.
  - [x] Keep `Prism::Merge` reviewed nested Ruby merges on the Prism parent/discovery path instead of delegating back to TSLP-backed `Ruby::Merge`.
  - [x] Make Prism's public Ruby merge honor the shared plain-Ruby policy: destination-owned requires win by default, and template-only declarations append after destination-owned top-level nodes.
  - [x] Delete the unused `ruby-merge` top-level DSL, Rakefile scaffold, and `:nocov:` require-block scanners now owned by Prism-backed templating paths.
  - [x] Use TSLP import records for parser-backed Ruby require owners and drop the unused public `collect_ruby_require_entries` scanner.
- [x] Add native-parser default contract fixtures so each implementation can declare its preferred parser per language family.
  - [x] Fix Markly README reapply idempotence by preserving cross-source paragraph boundaries and fenced-code trailing newlines in the shared Markdown merge substrate.
  - [x] Make `ast-template` prefer the native Markly adapter for Markdown directory sessions, with TSLP-backed `markdown-merge` retained only as an optional fallback when `markly-merge` is absent.
- [x] Propagate the marker/slice replacement change away from regex/index logic in the Rust, TypeScript, and Go implementations.
- [x] Audit non-Ruby implementations for regex-backed source-structure matching and prioritize parser-native replacements.
- [ ] Replace import-source normalization regexes in generic TSLP packages with TreeHaver process-record fields, and fail closed when the binding only exposes raw source text.
  - [ ] TypeScript implementation: `javascript-merge`, `python-merge`, `go-merge`, `java-merge`, `csharp-merge`, `c-merge`, `cpp-merge`, and TreeHaver's TypeScript import normalization.
  - [ ] Rust implementation: generic `go-merge`, `rust-merge`, `typescript-merge`, and TreeHaver process import normalization.
  - [ ] Go implementation: generic `gomerge`, `rustmerge`, `typescriptmerge`, and TreeHaver process import normalization.
- [ ] Replace generic Markdown heading/fence regex owner discovery in Go, Rust, and TypeScript with TreeHaver / TSLP Markdown process records once the binding exposes the needed section and fenced-code records; until then, native Markdown packages remain the preferred parser-backed path.
- [ ] Replace native C/C++/C# import extraction regexes in TypeScript implementation packages with native parser records or fail-closed diagnostics; these packages must not silently supplement missing TSLP records with text scanners.
- [ ] Replace native Go source-location fallbacks in Go implementation packages (`goparsermerge`, `godstmerge`) with parser position data for imports and declarations, and keep `decls[n]` path parsing classified as scalar target-path validation.
- [ ] Replace or explicitly quarantine Rust native backend fallback scanners in `rust-merge`; the `syn` path should use `syn` item records and spans where available, and should fail closed when spans are not available rather than searching source text.

### Ruby Regex Classification Snapshot

This snapshot is intentionally coarse-grained. It exists to guide removal order,
not to bless every regex permanently.

**Source-structure / parser-backed replacement required**

- `ruby-merge`: `declaration_for_line`, `REQUIRE_PATTERN`, `DEF_PATTERN`,
  constant assignment detection, and block-depth detection are still used by
  legacy no-process owner discovery, direct body child extraction, and Ruby
  source-region generation. These are the next high-risk targets. The preferred
  direction is Prism for native Ruby templating paths and TreeHaver / TSLP
  process records for the generic `ruby-merge` substrate.
- `go-merge` and `rust-merge`: current import source cleanup uses text patterns.
  These should move behind TreeHaver / TSLP record normalization when backend
  process records are available.
- `markdown-merge`: fallback heading/fence parsing in the generic markdown
  package should be replaced by TreeHaver / TSLP Markdown records where that
  package is acting as the generic substrate. Native markdown parser packages
  should keep delegating shared behavior down rather than reimplementing it.

### Non-Ruby Regex Audit Snapshot

**Source-structure / parser-backed replacement required**

- TypeScript implementation:
  - `go-merge`, `java-merge`, `javascript-merge`, `python-merge`, and
    `csharp-merge` normalize import match keys with source-text regexes even
    though they already depend on TreeHaver process import records.
  - `c-merge` and `cpp-merge` extract `#include` lines and C/C++ function names
    with source-text regexes. Those packages should use parser records or fail
    closed when TSLP/native records do not expose include/function identity.
  - `markdown-merge` parses ATX headings and fenced-code blocks with regexes.
    The replacement is TreeHaver / TSLP Markdown section and code-fence records,
    with `markdown-it-merge` as the native preferred path where available.
  - `tree-haver` normalizes TypeScript imports from raw source text. The
    TreeHaver process boundary should prefer structured import fields from the
    language-pack binding and report missing fields as a backend deficiency.
- Rust implementation:
  - `ruby-merge` still mirrors old regex-based Ruby helper behavior; the generic
    Ruby path should stay TSLP-record-only and native Ruby behavior belongs in
    `prism-merge`.
  - `rust-merge` native `syn` backend extracts imports and fallback declaration
    spans from source text. The native backend should use parser item identity
    and fail closed where span information is unavailable.
  - Generic `go-merge`, `rust-merge`, and `typescript-merge` use process records
    for spans but still clean import match keys from source text. That belongs
    at the TreeHaver process-record boundary.
  - `markdown-merge` parses headings and fenced-code blocks directly. Replace
    with TreeHaver / TSLP records once the process binding exposes them.
- Go implementation:
  - `gomerge`, `rustmerge`, and `typescriptmerge` use process records for spans
    but still clean import match keys from source text. That belongs at the
    TreeHaver process-record boundary.
  - `goparsermerge` and `godstmerge` are native parser paths, but fallback
    source searches for import/declaration text should be replaced with native
    parser positions.
  - `markdownmerge` parses headings and fenced-code blocks directly. Replace
    with TreeHaver / TSLP records once the process binding exposes them.

**Scalar validation / path and generated-text parsing, acceptable**

- Compact ruleset identifiers, structured-edit selector limits, TreeHaver
  language/library/path validators, generated token replacement delimiters,
  gitattributes-style wildcard parsing, ZIP path safety checks, and edit
  projection target paths such as `decls[n]` are scalar/config operations. They
  can remain regex-backed unless they begin determining source ownership.

**Conflict marker and test assertions, acceptable**

- Conflict-marker parsing/rendering and fixture assertions that only count or
  locate emitted text are not source-structure discovery. They can remain simple
  string or regex checks.

**Comment/trivia lexing, retained unless a parser can expose equivalent trivia**

- `prism-merge`, `rbs-merge`, `toml-merge`, `json-merge`, and
  `markdown-merge` still use regexes for freeze markers, comment delimiters,
  link reference text, markdown container spacing, and generated corruption
  cleanup. These are text/trivia policies rather than source ownership
  discovery. Remove them only when parser records expose the same trivia with
  enough fidelity.

**Scalar validation / path and config parsing, acceptable**

- `ast-crispr` cardinality specs, ruleset token parsing, path validators,
  extension checks, SPDX / URL / badge label cleanup, generated slugging, and
  version bucket parsing are scalar text operations. These can remain regex
  backed unless they start driving source ownership or merge structure.

**Test-only assertions and docs/examples, acceptable**

- Specs that count emitted strings, assert diagnostics, or describe APIs may use
  regexes. They do not participate in runtime merge decisions.

## Immediate wins

### Terminology alignment

- [x] Rename `source_augmented_synthetic` to `source_augmented_portable_write` in runtime code.
- [x] Rename `native_read_synthetic_write` to `native_read_portable_write` in runtime code.
- [x] Rename helper predicates to match:
  - `source_augmented_synthetic?` -> `source_augmented_portable_write?`
  - `native_read_synthetic_write?` -> `native_read_portable_write?`
  - `synthetic_write?` -> `portable_write?`
- [x] Update `Ast::Merge::Ruleset::Config::READ_STRATEGIES` to use the new names.
- [x] Update `Ast::Merge::Ruleset::Config#support_style` to use the new names.
- [x] Update `FileAnalyzable#comment_support_style` and `#shared_comment_support_style` to use the new names.
- [x] Update spec fixtures and harnesses to use the new terms.
- [x] Keep the word `synthetic` in targeted inline comments only where it explains the actual architecture, not the public contract.
- [x] Remove compatibility aliases for the old `synthetic` terminology in runtime code and ruleset parsing.

### Terminology separation

- [x] Separate clearly in code and docs between:
  - parser capability
  - merge capability
  - support style / write model
  - ruleset capability declaration
- [x] Audit whether `Comment::Capability` and `Comment::SupportStyle` names still match the spec direction, or whether one should be renamed to something closer to `ReadModel`, `WriteModel`, or `MergeRealization`.
- [x] Add a concise glossary comment near the relevant classes so the codebase reflects the same distinctions as the draft.

## Shared behavior to push down into `ast-merge`

### Corruption-healing boundary

- [x] Define a separate corruption-healing layer that sits above core merge semantics and can be switched or configured independently.
- [x] Introduce the first explicit healing policy seam in `prism-merge` for duplicate template-owned leading-prefix recovery, with `:heal`, `:warn`, `:error`, and `:skip` modes.
- [x] Propagate the initial corruption policy through recursive body merges and partial-template merge entry points so nested merges respect the same handling mode.
- [x] Extract the shared healing-policy contract into `ast-merge` as `Ast::Merge::Healer` so mode normalization and heal/warn/error/skip control flow are shared instead of reimplemented per merge gem.
- [x] Extract the repeated overlap-filter control flow into `Ast::Merge::Healer.filter_items` so downstream gems can share the same conditional-heal filtering contract instead of cloning it at each call site.
- [x] Gate removed-owner/orphan-rehoming overlap in `prism-merge` behind the same policy seam so comment-promotion cleanup does not silently define ownership semantics.
- [x] Classify current duplicate-collapse, dedup, rehoming, and ownership-repair logic as either:
  - normative merge behavior
  - corruption recovery for historical outputs
  - ambiguous cases that need explicit policy names
- [x] Design a policy surface for suspected corruption handling, with modes such as:
  - `heal`
  - `warn`
  - `error`
  - `skip`
- [x] Ensure the default shared runtime can operate without corruption healing for clean inputs and performance-sensitive callers.
- [x] Add tests that prove the same input can be handled under different corruption policies without changing the core structural analysis contract.
- [x] Make the no-generic-cleanup boundary explicit in shared behavior and specs: preserve owned oddities such as trailing spaces or whitespace-only lines unless a ruleset/format-specific merge policy explicitly defines a different equivalence or rendering rule.
- [x] Classify `prism-merge` postlude handling as analysis metadata rather than a live healing seam; current EOF/postlude preservation is structurally separate from the overlap-repair paths already gated.
- [x] Classify final blank-line normalization as a real output-repair pass rather than a conservative no-op safety net; instrumentation shows it mutates runtime outputs, even though the current suite still passes when it is disabled.
- [x] Remove the final blank-line normalization post-pass from `prism-merge` so spacing drift is no longer silently repaired after emission.
- [x] Tighten permissive spacing specs to assert exact preserved blank-line runs where preference and ownership already determine the intended output.
- [x] Fix destination-only sibling gap truncation in `prism-merge` so a node does not pre-emit one blank line from a repeated destination gap owned by the next sibling.
- [x] Add regression coverage that destination-owned whitespace-only lines are preserved across node gaps, comment-only gaps, and EOF/postlude output instead of being normalized away.
- [x] Trace any remaining spacing drift back to leading-gap, trailing-gap, or orphan-gap ownership instead of reintroducing global cleanup.

### Ruleset-driven merge declarations

- [x] Introduce a clearer mapping layer between ruleset directives and runtime behavior.
- [x] Make the runtime treat `read`, `attach`, `capability`, and `logical_owner` as first-class declarative inputs rather than loosely related metadata.
- [x] Add a single place where ruleset terms are translated into merge-facing runtime objects.
- [x] Ensure the translation layer can support comment-free formats cleanly, not just comment-heavy formats.

### Shared owner-selection behavior

- [x] Extract shared owner-selector helpers where the same owner-selection shapes recur across merge gems.
- [x] Distinguish:
  - shared default owner selector behavior
  - explicit owner selector behavior
  - logical-owner selectors
- [x] Reduce one-off owner-selection code in downstream gems where the behavior is really a named ruleset feature.

### Shared attachment behavior

- [x] Audit downstream gems for one-off implementations of:
  - `layout_only`
  - `tracker_layout_merge`
  - `augmenter_preferred_tracker_layout`
  - `normalize_tracked_layout_merge`
- [x] Move recurring attachment strategy orchestration fully into shared code where possible.
- [x] Ensure attachment strategies can be selected by named behavior rather than per-gem method folklore.

### Shared layout behavior

- [x] Expand the `Ast::Merge::Layout` namespace to cover more of the recurring blank-line ownership rules currently implemented ad hoc in leaf gems.
- [x] Make layout-aware behavior explicit for formats that have layout meaning but no comment surface.
- [x] Add shared tests for comment-free but layout-aware formats.
- [x] Decide which whitespace equivalences, if any, belong to named layout policies (for example, treating whitespace-only lines as blank-line matches in some formats) instead of letting the generic engine silently normalize them.

### Shared logical-owner behavior

- [x] Formalize logical-owner handling as a first-class shared substrate, not just a ruleset parser concept.
- [x] Identify current downstream logical-owner-like cases and move their preservation/removal rules toward a common abstraction.
- [x] Add shared runtime hooks for “preserve if referenced” and similar logical-owner policies.

### Shared renderer / source-shaper behavior

- [x] Audit recurring emitter/source-shaping logic across merge gems.
- [x] Determine what can become a shared renderer contract versus what remains format-specific.
- [x] Align emitter terminology with the draft’s `render` directive language.

## Comment model follow-up

The shared comment language is already one of the strongest pieces of alignment work. The next step is to make it less like a shared convenience API and more like a reference implementation of the spec vocabulary.

- [x] Review `Ast::Merge::Comment::{Capability, Region, Attachment, Augmenter, RegionMergePolicy}` against the current draft terminology.
- [x] Decide whether any of these types should move out of the `Comment` namespace into a more general merge-model namespace.
- [x] Ensure comment support is modeled as one axis of merge behavior, not the dominant axis.
- [x] Add shared behavior for comment-free formats so the abstraction does not imply comments are always central.
- [x] Document which comment abstractions are normative to the reference implementation and which are local implementation details.

## Runtime simplification targets

- [x] Identify runtime classes in `ast-merge` that are carrying both:
  - spec-facing declarative meaning, and
  - implementation-specific convenience logic
  and split those responsibilities where practical.

- [x] Audit whether `Ruleset::Config` should remain a single class or split into:
  - parser
  - validated model
  - runtime translator

- [x] Extract the first `Ruleset::Config` seams into dedicated classes:
  - `Ast::Merge::Ruleset::Parser`
  - `Ast::Merge::Ruleset::SupportStyleResolver`

- [x] Decide whether the current `Config` class is now the long-term normalized model, or whether a distinct `Ruleset::Model` / `Ruleset::Definition` value object should replace it.

- [x] Reduce bidirectional coupling between:
  - ruleset parsing
  - comment support style construction
  - file analysis helpers

- [x] Centralize support-style translation so `Ruleset::SupportStyleResolver` is the shared bridge for both ruleset parsing and file-analysis helper flows.

- [x] Prefer named feature objects or policy objects over scattered booleans and symbols where the spec vocabulary is stabilizing.
- [x] Introduce an initial shared `Ruleset::FeatureProfile` value object and expose it through `FileAnalyzable`.

## Shared tests and conformance work

- [x] Add shared examples that assert ruleset-term behavior, not just implementation-local method behavior.
- [x] Add shared example coverage for the initial feature-profile surface.
- [x] Build conformance fixtures around:
  - owner selection
  - match keys
  - attachment strategies
  - logical-owner behavior
  - layout-aware behavior
  - comment-free formats
- [x] Make at least one downstream merge gem prove each named feature through shared examples.
- [x] Make `prism-merge` expose and assert a concrete shared feature profile.
- [x] Add terminology migration tests so old names are either rejected cleanly or supported temporarily through a compatibility layer.

## Prior-art adoption backlog

This backlog tracks the pieces we should absorb from Weave, Mergiraf, and
related structured-merge work. The goal is not to clone any one architecture.
The goal is to combine the strongest prior art with StructuredMerge's own
ruleset, fixture, review, and multi-runtime model.

### Source-region model

- [x] Define a portable source-region shape that can represent alternating:
  - structural owner regions, such as functions, classes, methods, impl blocks,
    object members, and module declarations;
  - interstitial regions, such as imports, leading comments, blank-line gaps,
    separators, and file headers/footers.
- [x] Add fixture cases proving that source-region extraction preserves:
  - entity content;
  - leading/trailing comments attached to an owner;
  - blank-line ownership between sibling owners;
  - file-header and file-footer regions;
  - trailing newline state.
- [x] Decide how source-region identity maps to existing terms:
  - logical owner;
  - merge surface;
  - child group;
  - blank-line region;
  - attachment.
- [x] Add one source-family fixture where two branches add independent functions
  to the same textual area and the expected result is clean.
- [x] Add one source-family fixture where two branches add independent methods
  inside the same class or impl block and the expected result is clean through a
  child-group merge.
- [x] Add one source-family fixture where two branches touch the same owner body
  and the expected result delegates to an intra-owner merge rather than a global
  source-file conflict.

### Matching and identity

- [x] Define a source-owner identity profile covering:
  - owner kind;
  - owner name;
  - parent/container scope;
  - backend-provided structural identity when available;
  - content-derived fallback identity when structural identity is ambiguous.
- [x] Add duplicate-owner fixtures proving that repeated names are matched 1:1
  with ordered cursors or an equivalent stable pairing model.
- [ ] Add ambiguous-identity fixtures for:
  - anonymous closures or lambdas;
  - repeated trait/impl-like containers;
  - same-name methods in different visibility or namespace sections;
  - macro-generated or DSL-generated source owners.
- [x] Define confidence levels for source-owner matching, such as exact,
  structural, content-hash, token-similar, and unresolved.
- [x] Ensure match confidence is reported through the same diagnostic/reporting
  surface as other merge decisions.

### Rename and move detection

- [x] Add a rename-detection policy profile that can use:
  - body hash with owner-name normalization;
  - structural hash;
  - token similarity;
  - parent/scope similarity;
  - backend-native move metadata when available.
- [x] Add fixtures for clean rename-only changes.
- [x] Add fixtures for rename-plus-edit conflicts when both sides rename or edit
  the same owner in incompatible ways.
- [x] Add fixtures for moving a method between containers while preserving
  destination ordering policy.
- [x] Keep rename/move detection as an explicit capability, not an implicit
  always-on behavior.

### Interstitial and layout merge

- [x] Define interstitial-region merge rules separately from owner merge rules.
- [x] Add fixtures for import/use/require ordering where both branches add
  imports in nearby positions.
- [x] Add fixtures for comments between functions, including comments that are:
  - attached to the preceding owner;
  - attached to the following owner;
  - standalone interstitial content.
- [x] Add fixtures for blank-line-only changes where the merge must preserve the
  declared owner of whitespace instead of normalizing globally.
- [x] Add fixtures for file-header and file-footer edits.
- [ ] Decide when interstitial conflicts should be rendered as file-level
  conflicts versus scoped conflicts around nearby owners.

### Nested/container merge

- [x] Promote container member merging to a source-family child-group profile.
- [ ] Add fixtures for:
  - TypeScript class methods;
  - Rust impl items;
  - Go methods/functions grouped by receiver or file section;
  - Ruby methods under visibility sections;
  - object/map-like source constructs where order may or may not matter.
- [x] Declare which child groups are ordered, unordered, or policy-ordered.
- [x] Require commutative child-group behavior to be declared by ruleset or
  family profile; do not infer commutativity from syntax alone.
- [ ] Add scoped-conflict fixtures where only one child member conflicts inside a
  larger clean container merge.

### Non-commutative construct safety

- [ ] Add negative fixtures for Python decorators proving that independent
  decorator additions are not automatically clean unless a rule declares safe
  ordering.
- [ ] Add negative fixtures for TypeScript/JavaScript decorators and annotations
  where order or stacking can affect behavior.
- [ ] Add fixtures for ordered middleware, callback, before/after hook, and macro
  stacks where syntactic adjacency is semantically meaningful.
- [ ] Define a rule vocabulary for declared commutativity, left-preferred order,
  right-preferred order, destination-order preservation, and conflict-on-order.
- [ ] Ensure unsafe unordered merges produce diagnostics that explain the specific
  order-sensitive construct.

### Fallback floor

- [x] Define a cross-runtime fallback policy that is observable and reportable.
- [x] Add fallback triggers for:
  - binary input;
  - unsupported parser or backend;
  - parser returns no structural owners for non-empty source;
  - both branches create a file from an empty base;
  - excessive duplicate identities;
  - timeout or resource budget exceeded;
  - backend diagnostics above the accepted severity threshold.
- [x] Add a "never worse than baseline" comparison mode for merge drivers:
  compare structured output against the configured baseline merge and fall back
  when structured output produces more or broader conflicts.
- [x] Define the baseline merge provider as a runtime integration point rather
  than hardcoding `git merge-file` into portable semantics.
- [x] Add fixtures proving fallback activation is reported with reason, scope,
  selected baseline, and whether any structured result was discarded.
- [x] Add negative fixtures proving fallback does not silently widen the merge
  semantics for cases outside its declared scope.

### Post-merge validation

- [x] Define a post-merge validation phase that is separate from merge planning
  and rendering.
- [x] Add validation checks for:
  - merged output reparses successfully when both inputs parsed successfully;
  - all cleanly resolved owners appear in output;
  - expected owner count does not drop unexpectedly;
  - unchanged significant lines are not lost;
  - branch-added significant lines are not lost;
  - output length is within policy-defined sanity bounds;
  - conflict-marker shape is compatible with the host VCS/tool.
- [x] Make every validation failure produce either:
  - fallback to the configured baseline;
  - a scoped conflict;
  - a hard diagnostic failure.
- [x] Add fixtures for silent-data-loss prevention.
- [x] Add implementation hooks so validation can be strict in CI and more
  permissive in exploratory tooling only when explicitly configured.

### Conflict rendering and diagnostics

- [x] Define a portable conflict-kind vocabulary for source merges:
  - both modified;
  - both added;
  - modify/delete;
  - rename/rename;
  - rename/modify;
  - order-sensitive sibling additions;
  - interstitial conflict;
  - validation failure.
- [x] Add conflict complexity or risk metadata when a backend can classify the
  conflict as text-only, syntax-level, semantic-risk, or unknown.
- [x] Support enhanced conflict metadata for humans while preserving standard
  conflict-marker compatibility for tools that require it.
- [x] Add audit/report fields for:
  - owner identity;
  - owner kind;
  - strategy chosen;
  - match confidence;
  - fallback reason;
  - validation warnings;
  - conflict kind and scope.
- [x] Ensure diagnostics are stable enough to be used by review-state and replay
  workflows.

### Formatter integration

- [x] Treat formatters as optional post-merge adapters, not as proof of semantic
  correctness.
- [x] Add a formatter policy vocabulary:
  - no formatter;
  - validate-only;
  - format-after-clean-merge;
  - format-after-fallback;
  - formatter failure is warning;
  - formatter failure is hard error.
- [x] Add fixtures proving a formatter may repair whitespace without changing
  ownership, conflict scope, or validation semantics.
- [x] Keep formatter execution outside portable fixture expectations unless the
  fixture explicitly opts into a formatter profile.

### Mergiraf/PCS lessons

- [x] Preserve the option for finer AST-node merge profiles when owner-level merge
  is too coarse.
- [x] Model PCS-like or successor-based child ordering as a possible backend
  strategy under a declared merge surface.
- [x] Add fixtures where expression-level or argument-level structured merge is
  useful and owner-level fallback would be too blunt.
- [x] Add fixtures where AST-level reconstruction would be risky because
  whitespace, comments, or conflict marker placement become ambiguous.
- [x] Keep the public contract at the ruleset/fixture level so implementations
  can choose entity-level, AST-level, line-level, or hybrid algorithms.

### VCS and tool integration

- [x] Define a merge-driver integration contract for Git.
- [x] Define a merge-tool integration contract for Jujutsu.
- [x] Support host-provided marker length and standard marker modes.
- [x] Support optional enhanced markers when the host can tolerate them.
- [x] Add audit artifact output for merge-driver runs.
- [x] Add timeout/resource-budget configuration that cannot silently hang a VCS
  operation.
- [x] Add clear diagnostics for skipped structured merge, fallback activation,
  and driver/tool invocation errors.

### Multi-runtime implementation plan

- [ ] Add source-region, fallback, validation, and conflict-report fixture roles
  to the source-family manifests.
- [ ] Implement the source-region model first in the runtime with the strongest
  parser support, then port through Go, Rust, TypeScript, and Ruby with the same
  fixtures.
- [ ] Keep backend-specific tree-sitter, native-parser, and AST-library behavior
  behind provider feature profiles.
- [ ] Add conformance gates that distinguish:
  - required portable behavior;
  - backend-restricted behavior;
  - experimental prior-art parity behavior;
  - runtime-local integration behavior.
- [ ] Add benchmark scenarios for false-conflict reduction without allowing
  benchmark wins to bypass fallback and validation requirements.

### Prior-art documentation

- [x] Add a short source-family prior-art note summarizing what is adopted from
  Weave:
  - owner/interstitial region model;
  - explicit fallback floor;
  - post-merge validation;
  - confidence-scored matching;
  - scoped nested container merge.
- [x] Add a short source-family prior-art note summarizing what is adopted from
  Mergiraf:
  - fine-grained AST matching as an optional profile;
  - successor/PCS-style child ordering as a backend strategy;
  - commutative parent handling only when declared;
  - rendering and conflict-marker compatibility concerns.
- [x] Document explicit non-goals:
  - do not make entity-level merge the only architecture;
  - do not treat formatter output as semantic validation;
  - do not mark order-sensitive constructs clean by default;
  - do not hide fallback or validation failures.

## Ruby-first convergence and cross-runtime catch-up

The active Ruby stack has much more implementation surface than the Go, Rust,
and TypeScript stacks because it inherited mature prior art from the old Ruby
libraries. That is useful, but it also creates a drift risk: Ruby class names
and convenience APIs can accidentally become the architecture unless we first
classify which behavior is portable.

The work should run as repeated convergence cycles:

1. inventory Ruby behavior,
2. promote portable behavior into spec fixtures and shared contracts,
3. make Ruby conform to the fixture-backed contract,
4. port the contract into Go, Rust, and TypeScript,
5. use gaps in the non-Ruby runtimes to refine the contract,
6. repeat.

### Ruby prior-art classification

- [x] Inventory active Ruby `ast-merge` substrate classes and classify each as:
  - portable merge contract;
  - Ruby reference implementation helper;
  - Ruby test/contributor convenience;
  - historical compatibility surface;
  - candidate for future extraction.
- [x] Inventory active Ruby `tree_haver` substrate classes and classify each as:
  - portable parser/backend contract;
  - Ruby backend adapter helper;
  - security/path-validation policy;
  - runtime-local backend selection convenience;
  - historical compatibility surface.
- [x] Compare active Ruby `ast-merge` and `tree_haver` against `reference/`
  read-only prior art and record anything not yet promoted into the active
  structuredmerge Ruby gems.
- [x] Decide which old Ruby base classes remain normative reference
  implementations:
  - `SmartMergerBase`;
  - `ConflictResolverBase`;
  - `MergeResultBase`;
  - `FileAnalyzable`;
  - `NodeWrapperBase`;
  - `EmitterBase`;
  - `MatchRefinerBase`;
  - `DiffMapperBase`;
  - `PartialTemplateMergerBase`.
- [x] Decide which Ruby `ast-merge` modules should become portable contract
  surfaces rather than Ruby-only helpers:
  - comments and attachment;
  - layout/gap ownership;
  - freeze/frozen regions;
  - unresolved review state;
  - delegated child operations;
  - structured edit planning;
  - trailing group ordering;
  - node typing;
  - match refinement;
  - healing/repair policy.
- [x] Record any Ruby-only naming that should not leak into portable APIs, such
  as `SmartMerger`, `FileAnalysis`, or old RSpec shared-example terminology.

### Ruby reference pass

- [x] Make Ruby the first runtime to implement the prior-art backlog only where
  it already has the deepest substrate.
- [x] Add Ruby fixtures before adding new Ruby APIs, especially for:
  - source regions;
  - interstitial layout ownership;
  - nested child groups;
  - fallback floor;
  - post-merge validation;
  - diagnostics and audit records.
- [x] Use Ruby `tree_haver` to prove the parser/backend contract needed by
  source-region extraction:
  - stable node spans;
  - source fragments;
  - comments when backend supports them;
  - parser diagnostics;
  - backend capability reports;
  - backend selection context.
- [x] Use Ruby `ast-merge` to prove the merge orchestration contract:
  - analysis object;
  - match/refinement phase;
  - conflict resolver phase;
  - result object;
  - render/emission phase;
  - unresolved review state;
  - structured diagnostics.
- [x] Keep each Ruby implementation change tied to a fixture role so the other
  runtimes have a target independent of Ruby class structure.

### Portable contract extraction

- [x] Convert Ruby-proven behavior into fixture roles rather than prose-only
  expectations.
- [x] Add source-family fixture roles for:
  - `source_region_analysis`;
  - `source_owner_matching`;
  - `source_interstitial_merge`;
  - `source_child_group_merge`;
  - `source_fallback_floor`;
  - `source_post_merge_validation`;
  - `source_conflict_report`;
  - `source_merge_driver_report`.
- [x] Add tree-haver fixture roles for:
  - backend reference;
  - backend capability;
  - node/span/source-fragment contract;
  - comment extraction capability;
  - parser error tolerance;
  - backend availability;
  - edit projection capability.
- [x] Add ast-merge fixture roles for:
  - merge session;
  - decision record;
  - diagnostic record;
  - unresolved case;
  - replay bundle;
  - delegated child operation;
  - validation failure;
  - fallback activation.
- [x] For every Ruby-only feature that is not portable yet, add one of:
  - a fixture role;
  - a backend-restricted role;
  - an explicit non-portable note;
  - a retirement task.

### Cross-runtime catch-up lanes

- [ ] Run Go, Rust, and TypeScript catch-up by shared contract layer, not by gem
  or package name.
- [ ] Lane 1: parser/backend substrate parity.
  - node identity and spans;
  - source fragment extraction;
  - backend registry/reference;
  - backend selection context;
  - diagnostics;
  - capability reports.
- [ ] Lane 2: core merge contract parity.
  - parse result shape;
  - merge result shape;
  - decision records;
  - diagnostics;
  - feature profiles;
  - policy references.
- [ ] Lane 3: owner/region analysis parity.
  - owner regions;
  - interstitial regions;
  - logical owners;
  - blank-line ownership;
  - source-region reconstruction metadata.
- [ ] Lane 4: matching and ordering parity.
  - scoped owner matching;
  - duplicate owner cursors;
  - match confidence;
  - child group policies;
  - trailing group/order policy.
- [ ] Lane 5: conflict/fallback/validation parity.
  - fallback activation report;
  - baseline merge provider interface;
  - post-merge validation;
  - conflict kind vocabulary;
  - audit/report records.
- [ ] Lane 6: advanced orchestration parity.
  - nested/delegated child merge;
  - review-state replay;
  - structured edit operation triad;
  - merge-driver/tool integration.
- [ ] Propagate managed-block replacement from ad hoc string index/rindex logic
  to parser-backed AST CRISPR-style selectors in non-Ruby implementations.
  Ruby now uses `ast-crispr-ruby-prism` for Gemfile comment-delimited generated
  blocks and `ast-crispr-markdown-markly` for Markdown HTML-comment blocks.
  Go `kettlegomodder` still has analogous marker replacement logic; audit Rust
  and TypeScript for the same pattern before declaring slice 717 portable.

### Runtime-specific ordering

- [x] Ruby order:
  1. classify active/reference prior art;
  2. normalize Ruby substrate names to spec vocabulary;
  3. implement source-region fixtures;
  4. implement fallback and validation fixtures;
  5. implement nested child-group/source owner fixtures;
  6. expose audit/report details;
  7. trim or quarantine Ruby-only legacy surfaces.
- [ ] Rust order:
  1. extend `tree-haver` substrate structs to match Ruby-backed fixtures;
  2. extend `ast-merge` contract structs for source regions and validation;
  3. implement source-family fixtures for Rust source first;
  4. use Weave as local Rust prior art only where it agrees with the portable
     fixture contract;
  5. add merge-driver/tool behavior after core contracts pass.
- [ ] TypeScript order:
  1. extend contract interfaces and fixture readers;
  2. add source-region and owner matching for TypeScript source;
  3. add diagnostics/audit parity;
  4. add optional compiler-backed provider behavior as backend-restricted
     fixtures;
  5. avoid regex/string source logic where AST/provider support exists.
- [ ] Go order:
  1. extend tree-haver and ast-merge structs for fixture parity;
  2. use Go native parser/DST providers to prove source-region extraction;
  3. add owner/interstitial/child-group fixtures;
  4. add fallback and validation reports;
  5. add merge-driver integration after portable output shape stabilizes.

### Drift controls

- [ ] Add a cross-runtime capability matrix that reports which runtime satisfies
  each portable fixture role.
- [ ] Add a Ruby-reference column, but do not let Ruby-only helper classes count
  as portable conformance.
- [ ] Require every new Ruby feature in `ast-merge` or `tree_haver` to declare
  whether it is:
  - portable contract work;
  - Ruby reference implementation work;
  - backend/provider-specific work;
  - packaging/testing convenience.
- [ ] Reject cross-runtime ports that only mimic Ruby API shape without passing
  fixture-backed behavior.
- [ ] Keep `reference/` read-only and treat it as prior-art evidence, not an
  implementation target.

## Things that may need to move out of `ast-merge`

These should not be extracted immediately unless the interface stabilizes, but they are good candidates to avoid future bloat.

### Conformance corpus

- [ ] Plan for a future `merge-ruleset-fixtures` or `merge-ruleset-tests` artifact once fixture reuse becomes language-neutral.

### Ruleset runtime

- [ ] Plan for a future `merge-ruleset` runtime gem once:
  - a second Ruby consumer exists, or
  - a non-Ruby implementation wants to share the same grammar/model.

### Draft / standards artifacts

- [ ] Keep draft text out of runtime packaging concerns.
- [ ] If the draft work grows, move it to a spec/docs-oriented home rather than keeping it coupled to gem packaging.

### Vendor- or app-specific recipe packs

- [ ] Do not let customer- or app-specific rule bundles accumulate in `ast-merge`.
- [ ] Keep private recipes, policy packs, and enterprise orchestration outside the reference implementation.

## Downstream gem audit backlog

- [x] Audit each `*-merge` gem for behavior that should be replaced by named shared features.
- [x] Build a matrix for each downstream gem covering:
  - owner selector
  - match key
  - attachment strategy
  - comment style
  - layout awareness
  - logical-owner behavior
  - render/source-shaper family
- [x] Use that matrix to decide what belongs in:
  - shared substrate
  - per-format adapters
  - future conformance fixtures

## Suggested implementation order

1. Finish any remaining vocabulary cleanup around old `synthetic`
   read-strategy terms and decide whether compatibility aliases remain.
2. Classify active Ruby and read-only reference prior art so Ruby's richer stack
   becomes an intentional reference implementation rather than an accidental
   portability contract.
3. Define the corruption-healing boundary so recovery heuristics do not get
   mistaken for normative shared merge behavior.
4. Build a Ruby feature matrix for `ast-merge`, `tree_haver`, and downstream
   merge gems:
   - owner selectors;
   - match keys;
   - attachment strategies;
   - comment style;
   - layout awareness;
   - logical-owner behavior;
   - render/source-shaper family;
   - fallback/repair policy;
   - validation and diagnostics.
5. Promote Ruby-proven behavior into source-family, ast-merge, and tree-haver
   fixture roles before changing Go, Rust, or TypeScript.
6. Make Ruby pass the new fixtures first, using Ruby's richer substrate to prove
   the intended behavior and expose any missing contract details.
7. Port the fixture-backed contracts across Go, Rust, and TypeScript in lanes:
   - parser/backend substrate parity;
   - core merge contract parity;
   - owner/region analysis parity;
   - matching and ordering parity;
   - conflict/fallback/validation parity;
   - advanced orchestration parity.
8. Add cross-runtime capability matrix reporting so gaps stay visible and are
   not hidden behind package-local claims.
9. Extract the next shared behavior layer only after at least Ruby plus one
   non-Ruby runtime prove the fixture-backed contract.
10. Only then decide what should leave `ast-merge` as a separate runtime or
    fixture artifact.

## First concrete code targets

- `ast-merge/lib/ast/merge/smart_merger_base.rb`
- `ast-merge/lib/ast/merge/conflict_resolver_base.rb`
- `ast-merge/lib/ast/merge/merge_result_base.rb`
- `ast-merge/lib/ast/merge/file_analyzable.rb`
- `ast-merge/lib/ast/merge/node_wrapper_base.rb`
- `ast-merge/lib/ast/merge/emitter_base.rb`
- `ast-merge/lib/ast/merge/match_refiner_base.rb`
- `ast-merge/lib/ast/merge/layout/`
- `ast-merge/lib/ast/merge/comment/`
- `ast-merge/lib/ast/merge/runtime/`
- `tree_haver/lib/tree_haver/base/`
- `tree_haver/lib/tree_haver/contracts.rb`
- `tree_haver/lib/tree_haver/backend_registry.rb`
- `tree_haver/lib/tree_haver/backend_context.rb`
- `ast-merge/lib/ast/merge/comment/support_style.rb`
- `ast-merge/lib/ast/merge/ruleset/config.rb`
- `ast-merge/spec/ast/merge/ruleset/config_spec.rb`
- `ast-merge/spec/ast/merge/file_analyzable_spec.rb`
- `ast-merge/spec/support/fictive_language_harness.rb`
- `spec/slices/`
- `fixtures/`
- `go/astmerge/`
- `go/treehaver/`
- `rust/crates/ast-merge/`
- `rust/crates/tree-haver/`
- `typescript/packages/ast-merge/`
- `typescript/packages/tree-haver/`

## Success criteria

- Public/spec-facing terminology in code matches the current draft.
- Shared behavior is selected by named feature or ruleset term more often than by one-off per-gem plumbing.
- Corruption recovery is explicit policy rather than an invisible default baked into core merge semantics.
- `ast-merge` becomes a clearer reference implementation of the draft rather than a growing pile of useful but disconnected merge utilities.
- Clear seams exist for future extraction of:
  - ruleset runtime
  - conformance fixtures
  - standards artifacts
