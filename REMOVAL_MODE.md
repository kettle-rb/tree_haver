# Plan: Normalize Removed-Node Removal-Mode Behavior Across the `*-merge` Family

_Date: 2026-03-13_
_Last updated: 2026-03-14_

This plan starts after the shared comment rollout reached completion in `prism-merge`.
Its focus is narrower than the broader shared comment-normalization effort:
make `remove_template_missing_nodes: true` behave consistently across the merge-gem family.

## Goal

When removal mode is enabled, destination-only structural nodes should be removed predictably without silently dropping user-authored comments that semantically belong to the removed content.

## Canonical Target Semantics

These are the normalization targets for family-wide behavior:

1. **Destination-only structural nodes are removed when removal mode is enabled.**
   - No destination-only body content should survive merely because it was unmatched.

2. **Attached destination comments are preserved or promoted.**
   - leading comments stay in output
   - inline comments are promoted to standalone comment lines when needed
   - external trailing comments stay in output

3. **Separator blank lines remain stable.**
   - blank lines that separate preserved promoted comments from the next kept node should remain
   - blank lines internal to the removed node body should not be preserved unless a format-specific rule requires it

4. **Recursive scopes obey the same rule.**
   - top-level and nested removal behavior should not diverge
   - container/body sub-mergers must pass removal-mode configuration through consistently

5. **Header-only semantics remain format-specific but principled.**
   - Ruby shebang + valid header magic comments remain special file-header metadata
   - misplaced header-like comments are ordinary comments and should not receive header-only treatment
   - comment-only files should respect removal mode without regressing format-required header preservation

6. **Freeze or equivalent preservation boundaries remain stronger than removal mode.**
   - removal mode must not punch through an intentional freeze/protection boundary

## Current Starting Point

From the current workspace state on 2026-03-13:

- `prism-merge` is now complete for the current shared-comment plan, including destination-only removal-mode behavior for top-level and recursive Ruby nodes plus strict header-only magic-comment handling.
- `rbs-merge` already has explicit removed-node removal-mode support and comment promotion coverage.
- the broader shared comment rollout already treats removed-node preservation as part of the intended family parity surface for the more mature gems.
- broader family semantics are still not documented as one explicit cross-repo contract, which is the gap this plan addresses.

## Phase 1: Define the shared contract

1. Write canonical examples for:
   - removed top-level node with leading comments
   - removed node with inline comment promotion
   - removed node with external trailing comments
   - removed nested node inside a recursive/container merge
   - comment-only / header-only file behavior under removal mode
2. Decide which parts belong in `ast-merge` shared examples versus per-format fixtures.
3. Document the canonical terminology for:
   - removed node
   - promoted comment
   - preserved separator blank line
   - header-only comment

## Phase 2: Build a family inventory

For each active merge gem, record:

- whether removal mode exists today
- whether top-level destination-only nodes are removed
- whether nested destination-only nodes are removed
- whether leading/inline/trailing comments are preserved or promoted
- whether comment-only or header-only files have explicit removal-mode coverage
- whether freeze/protection boundaries interact safely with removal mode

Initial audit order:

1. `prism-merge`
2. `rbs-merge`
3. `psych-merge`
4. `jsonc-merge`
5. `toml-merge`
6. `bash-merge`
7. Markdown-family gems

### Phase 2 inventory snapshot (2026-03-14)

| Gem / family | Exposed removal-mode surface | Top-level removal | Nested / recursive removal | Preserved / promoted comments | Comment-only / header-only evidence | Freeze / protection precedence | Current gap summary |
|---|---|---|---|---|---|---|---|
| `prism-merge` | explicit `remove_template_missing_nodes` through `SmartMerger`, top-level runner, and recursive body sub-mergers | yes | yes | leading, inline, and external trailing comments preserved/promoted; separator blank line preserved | yes — shebang, strict valid-header magic comments, comment-only misplaced-header handling | yes | current reference implementation for the family |
| `rbs-merge` | explicit `remove_template_missing_nodes` in `Rbs::Merge::SmartMerger` and resolver wiring | yes | wired through recursive member merge paths | declaration-leading docs preserved/promoted; format has no general inline comment body syntax | comment-only destination and postlude coverage present | yes | shared compliance now covers top-level ordering and recursive member removal; inline-comment promotion remains explicit N/A by format |
| `psych-merge` | explicit `remove_template_missing_nodes` in `Psych::Merge::ConflictResolver` / `SmartMerger` | yes | yes — mappings, sequences, nested sequence mappings | leading comments preserved, inline comments promoted, recursive blank-line stability covered | comment-only destination/header coverage present; no format-specific header special case beyond YAML comments | yes | add shared-family trailing-comment compliance language, though YAML already has strong recursive promotion coverage |
| `jsonc-merge` | explicit `remove_template_missing_nodes` in `Jsonc::Merge::ConflictResolver` / `SmartMerger` | yes | yes — nested objects and keyed arrays/array items | leading comments preserved, inline comments promoted; recursive array-item promotion covered | comment-only destination plus header/footer document-boundary coverage present | yes | external trailing/orphan removal expectations should be made explicit in shared compliance coverage |
| `toml-merge` | explicit `remove_template_missing_nodes` in `Toml::Merge::ConflictResolver` / `SmartMerger` | yes | yes — removed tables recurse through children | leading docs preserved, inline comments promoted for removed keys/tables and nested children | comment-only destination and document postlude coverage present | no TOML freeze boundary currently in play | shared compliance now locks leading/inline/separator/recursive removal behavior; future work is mostly table-postlude or other trailing edge coverage |
| `bash-merge` | explicit `remove_template_missing_nodes` in `Bash::Merge::SmartMerger` | yes | not a current recursive/container merge path | leading comments preserved; safe single-line command/assignment inline comments promoted | shebang/header/footer and comment-only destination coverage present | yes | shared compliance now covers the top-level contract; recursive/container removal remains explicitly unsupported rather than silently divergent |
| Markdown family (`markdown-merge`, `markly-merge`, `commonmarker-merge`) | explicit `remove_template_missing_nodes` in `Markdown::Merge::SmartMergerBase` and thin wrappers for full-document smart merge | yes — top-level destination-only structural blocks | no generic recursive/nested removal mode yet | standalone HTML comment-only fragments preserved; link reference definitions and freeze blocks preserved; separator blank line before or after preserved standalone HTML comment fragments remains stable when removed structural content collapses around them | focused shared compliance plus wrapper parity specs cover standalone HTML comment-only removed-node preservation in full-document smart merge | yes — freeze blocks still override removal mode | first safe slice is landed, including explicit top-level trailing/orphan standalone-comment boundary coverage; generic Markdown inline promotion, recursive section removal, and `replace_mode`/link-reference ownership expansion remain deferred |

### Evidence sources used for this inventory

- `prism-merge`: `prism-merge/lib/prism/merge/file_analysis.rb`, `prism-merge/lib/prism/merge/smart_merger.rb`, `prism-merge/spec/prism/merge/removal_mode_compliance_spec.rb`, `prism-merge/spec/prism/merge/comment_only_file_merger_spec.rb`, and `prism-merge/spec/integration/magic_comment_handling_spec.rb`
- `rbs-merge`: `rbs-merge/lib/rbs/merge/file_aligner.rb`, `rbs-merge/lib/rbs/merge/smart_merger.rb`, `rbs-merge/spec/integration/reproducible_merge_spec.rb`, `rbs-merge/spec/rbs/merge/file_aligner_spec.rb`, `rbs-merge/spec/rbs/merge/smart_merger_spec.rb`, `rbs-merge/spec/rbs/merge/removal_mode_compliance_spec.rb`
- `psych-merge`: `psych-merge/lib/psych/merge/conflict_resolver.rb`, `psych-merge/spec/psych/merge/smart_merger_spec.rb`, `psych-merge/spec/integration/reproducible_merge_spec.rb`
- `jsonc-merge`: `jsonc-merge/lib/jsonc/merge/conflict_resolver.rb`, `jsonc-merge/spec/support/shared_examples/smart_merger_examples.rb`, `jsonc-merge/spec/integration/merge_output_validation_spec.rb`, `jsonc-merge/spec/integration/reproducible_merge_spec.rb`
- `toml-merge`: `toml-merge/lib/toml/merge/conflict_resolver.rb`, `toml-merge/spec/toml/merge/smart_merger_spec.rb`, `toml-merge/spec/toml/merge/conflict_resolver_spec.rb`, `toml-merge/spec/toml/merge/removal_mode_compliance_spec.rb`
- `bash-merge`: `bash-merge/lib/bash/merge/smart_merger.rb`, `bash-merge/spec/support/shared_examples/smart_merger_examples.rb`, `bash-merge/spec/bash/merge/removal_mode_compliance_spec.rb`
- Markdown family: `markdown-merge/lib/markdown/merge/smart_merger_base.rb`, `markdown-merge/lib/markdown/merge/file_analysis_base.rb`, `markdown-merge/lib/markdown/merge/gap_line_node.rb`, `markdown-merge/spec/markdown/merge/removal_mode_compliance_spec.rb`, `markdown-merge/spec/markdown/merge/smart_merger_spec.rb`, `markdown-merge/spec/markdown/merge/partial_template_merger_spec.rb`, `markdown-merge/spec/integration/smart_merger_comment_preservation_spec.rb`, plus wrapper entrypoints and parity specs in `markly-merge/lib/markly/merge/smart_merger.rb`, `markly-merge/spec/markly/merge/smart_merger_spec.rb`, `commonmarker-merge/lib/commonmarker/merge/smart_merger.rb`, and `commonmarker-merge/spec/commonmarker/merge/smart_merger_spec.rb`

### Key inventory findings

1. The shared contract already fits the mature removal-mode implementations in `prism-merge`, `psych-merge`, `jsonc-merge`, `toml-merge`, `bash-merge`, and `rbs-merge`, and the Markdown family now has an explicit top-level-only first slice instead of being a total outlier.
2. `prism-merge` is the strongest end-state reference because it already covers top-level + recursive removal, external trailing comment preservation, separator blank lines, and strict header-only semantics.
3. `psych-merge` has the strongest non-Ruby recursive removal evidence today; it already exercises nested mappings, nested sequences, and promoted inline comments under removal mode.
4. `jsonc-merge` and `toml-merge` both support recursive/container removal; after the new shared-compliance adoption, their remaining follow-up is mostly external trailing/orphan and table-postlude edge coverage rather than core behavior changes.
5. `rbs-merge` now has direct shared-compliance proof for both top-level removed-declaration ordering and recursive member removal; its only remaining shared-contract exception is that inline-comment promotion is intrinsically N/A for RBS declarations.
6. `bash-merge` already has good top-level removal semantics plus shebang/header/footer coverage; shared compliance now records recursive/container removal as explicitly unsupported, so any future nested shell-structure work will be an intentional contract expansion.
7. The Markdown family now has a narrow full-document `remove_template_missing_nodes` contract for top-level structural block removal with standalone HTML comment preservation, while recursive section semantics, inline promotion, and broader link-reference ownership rules remain intentionally deferred.

## Phase 3: Add shared compliance coverage

Add shared examples or helper-driven compliance checks for removal mode in the shared layer when practical.

Status: started on 2026-03-14.

Initial shared-compliance landing:

- added shipped `ast-merge` shared examples for generic removal-mode compliance in `ast-merge/lib/ast/merge/rspec/shared_examples/removal_mode_compliance.rb`
- added an `ast-merge` self-test for the new shared contract under `ast-merge/spec/ast/merge/rspec/shared_examples/removal_mode_compliance_spec.rb`
- adopted the shared contract first in `prism-merge`, `psych-merge`, and `jsonc-merge` via focused `removal_mode_compliance_spec.rb` coverage
- extended the shared example so format-specific non-applicable cases can be recorded explicitly instead of forcing fake inline or recursive coverage where the format cannot support it
- expanded focused `removal_mode_compliance_spec.rb` adoption to `rbs-merge`, `toml-merge`, and `bash-merge`; `rbs-merge` marks inline promotion as N/A by format, and `bash-merge` marks recursive/container removal as explicitly unsupported today
- landed the first Markdown-family removal-mode slice in `markdown-merge` and thin-wrapper parity specs in `markly-merge` / `commonmarker-merge`: top-level destination-only structural blocks are now removable while standalone HTML comment-only fragments, link reference definitions, freeze blocks, and one separator blank line before the next kept block remain preserved
- added focused Markdown-family follow-up regressions for destination-only standalone link reference definitions and freeze blocks under removal mode, and confirmed the same preservation behavior through both thin wrappers without needing wrapper-specific merge logic
- tightened Markdown gap-line signatures to use preceding-node signature context where available so preserved separator blanks stay attached to the correct kept block under reordering/removal without regressing existing Markdown suite behavior
- landed a Markdown-family boundary follow-up so preserved standalone HTML comment postlude/orphan fragments keep one separator blank line on the leading edge as removed top-level structural content collapses ahead of them, and revalidated the same behavior through both thin wrappers plus the full `markdown-merge`, `markly-merge`, and `commonmarker-merge` suites
- adopted the shipped shared removal-mode compliance example directly in `markly-merge` and `commonmarker-merge` as wrapper-level guardrails for the same top-level Markdown contract, including idempotent trailing standalone-comment separator behavior and explicit N/A markers for inline/recursive cases
- aligned repo-facing Markdown-family README / PLAN / changelog wording with the landed top-level-only removal-mode contract and reran the focused Markdown-family removal-mode / smart-merger evidence set (`markdown-merge`: `58 examples, 0 failures, 4 pending`; `markly-merge`: `129 examples, 0 failures, 4 pending`; `commonmarker-merge`: `53 examples, 0 failures, 4 pending`)
- fixed `rbs-merge` destination-relative alignment ordering so promoted removed declaration docs can remain ahead of later matched declarations without regressing freeze-block ordering
- fixed a JSONC removal-mode spacing/idempotence gap so promoted removed-node comments now preserve internal separator blank lines before the next kept comment block or node
- revalidated the shared-example self-tests plus focused removal-mode compliance specs for `prism-merge`, `psych-merge`, `jsonc-merge`, `rbs-merge`, `toml-merge`, `bash-merge`, and `markdown-merge`, plus full-suite markdown family validation (`markdown-merge`, `markly-merge`, `commonmarker-merge`) in sibling workspace mode under `KETTLE_DEV_DEV=/home/pboling/src/kettle-dev`

Minimum shared cases:

- remove unmatched destination-only node
- preserve promoted leading comments
- preserve promoted inline comments
- preserve promoted external trailing comments
- preserve separator blank line before the next kept node
- recurse consistently into nested/container scopes

## Phase 4: Close remaining gem-level gaps

Normalize the remaining gems one by one, preferring the smallest behavior-preserving slice per repo.

## Exit Gate

This plan is complete when:

- removal mode means the same thing across the family
- preserved/promoted comment behavior is explicit and tested
- recursive and top-level removal semantics match
- header-only special cases remain correct per format
- the broader shared comment-normalization docs can describe removal mode as a shared platform contract instead of repo-by-repo folklore
