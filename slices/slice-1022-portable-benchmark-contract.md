# Slice 1022: Portable benchmark contract

## Status and scope

This slice defines the first language-neutral benchmark exchange contract. It
defines data, selection, and reporting; it does not define an executable
runner. Go, Rust, TypeScript, and Ruby consumers remain a later phase.

The contract version is `structuredmerge.benchmark/v1`. Producers MUST reject
unknown major versions and preserve unknown fields from compatible minor
versions when forwarding records.

## Common envelope

Every case, run, raw result, and aggregate report has `schema_version`, `kind`,
a globally unique stable `id`, and provenance. Every case additionally has:

- `family`, `provider`, `dialect`, and sorted `capabilities`;
- one `partition`: `sentinel`, `gold`, `metamorphic`, `history`, or `holdout`;
- provenance with origin URI, revision, SPDX expression, license evidence URI,
  author/reviewer status, and derivation notes.

Results inherit case tags and partition through their mandatory `case_id`;
reports stratify those inherited values rather than copying mutable metadata.

SHA-256 digests are lowercase hexadecimal over the exact bytes. Inputs at most
4 KiB MAY use `inline`; larger, licensed external, history, and holdout inputs
MUST use a content-addressed `reference`. Inline inputs still require a digest.
References MUST identify the owning corpus and path/object ID; a reference is
never permission to fetch during a run.

Case IDs describe behavior, not an implementation. A case declares one
operation: `diff`, `merge3`, `history_replay`, or `metamorphic`. The operation
envelopes are versioned independently under the common major version.

## Case contracts

### Diff

A diff case supplies `before` and `after`, an oracle, expected edit units, and
acceptable equivalence. Edit units have stable IDs, operation, structural path,
and optional source region. Reports MUST represent precision and recall with
the exact `true_positive`, `false_positive`, and `false_negative` edit-unit ID
sets as well as their derived ratios. A producer MUST state the unit matching
rule; a single undifferentiated "diff accuracy" number is invalid.

### Three-way merge

A merge case supplies exact `base`, `ours`, and `theirs` bytes, identifies
independent edits, and declares whether a clean result or conflict is expected.
It records expected conflict regions and preservation policy separately from
semantic correctness. A clean candidate differing byte-for-byte from the
expected result is correct when it satisfies the declared structural or
invariant equivalence and preservation policy.

Conflict regions use half-open byte ranges plus structural paths where known.
Reports MUST retain expected and observed regions, matched region IDs,
false-positive and missed region IDs, and localization error in bytes. Region
precision/recall and localization are distinct from whether the final outcome
was correctly conflicted. A conflicted output for an intentional-conflict case
is `true_conflict`, never `false_conflict`.

`false_auto_merge_severity` is one of `none`, `low`, `high`, or `critical`.
Any observed false auto-merge is a non-compensable safety failure regardless of
severity; severity supports triage, not compensation.

### History replay reference

History cases MUST reference, not copy, a reviewed source manifest and case ID.
For this slice, history references target Slice 1021's
`diagnostics/slice-1021-reviewed-git-history-corpus/manifest.json`. Its Git
object IDs remain authoritative. Eligibility from the referenced case is
preserved: pending false-auto-merge review, ambiguous, and excluded history
cannot become scoreable merely by inclusion in a benchmark run.

### Metamorphic

The transformation vocabulary is:

`rename`, `move`, `reorder`, `formatting`, `comment`, `independent_edit`,
`delete_modify`, `duplicate_key_identity`, and `schema_aware_mutation`.

Each generated case records generator ID/version/digest, seed, parent case ID,
ordered transformations with deterministic parameters, generated input
digests, and expected invariants. Replaying those fields MUST reproduce the
same bytes. Expected invariants explicitly say which semantics, diagnostics,
conflict behavior, edit identities, and preservation properties remain equal
or deliberately change. Random generation without recorded deterministic
metadata is invalid.

## Oracle and equivalence contract

`oracle.class` is exactly one of:

- `exact`;
- `structural_ast`;
- `invariant`;
- `parser`;
- `downstream_test`;
- `human`;
- `llm`.

An oracle includes its artifact or procedure digest, reviewer/admission state,
and score eligibility. `acceptable_equivalence` is an ordered conjunction of
`exact_bytes`, `normalized_text`, `structural_ast`, `declared_invariants`,
`parser_acceptance`, or `downstream_tests`, with required parser/test identity
and version where applicable. Human and LLM judgments retain prompt/rubric,
model/reviewer identity, evidence digest, and decision provenance. LLM oracles
MUST NOT be used for `micro` or `dev` hard gates and never override an
intentional-conflict safety oracle.

Preservation is independently declared for comments, formatting, order,
encoding, line endings, unknown fields, and source regions. Each item is
`required`, `allowed_to_change`, or `not_applicable`.

## Run manifest

A run manifest declares:

- profile: `micro`, `dev`, `pr`, `nightly`, `release`, or `competitive`;
- candidate and optional paired base adapter identity, each with source SHA,
  artifact SHA-256, semantic version, configuration digest, and capabilities;
- corpus ID/version/digest;
- deterministic selection seed, selected case IDs, exclusions, and explanation;
- environment identity: runner/image/OS/architecture/CPU/memory/runtime/toolchain;
- repetitions and budgets for wall time, CPU, memory, output, and services;
- cache policy, `warm` or `cold` state, network policy, and named services;
- requested/selected capabilities and unsupported policy.

The selection explanation maps every changed path and inferred capability to
direct cases, mandatory sentinels, and deterministic neighbor samples. Each
neighbor records population, ordering algorithm, seed, and selected IDs. If a
budget cannot fit the planned selection, the runner MUST explicitly promote to
a larger profile or reduce to a named smaller profile and regenerate the
explanation. It MUST NOT silently extend a budget or drop cases.

`unsupported_policy` defaults to `coverage_only`: unsupported cases reduce
reported capability coverage but are not quality failures. A release policy
MAY separately require a capability, converting absence into a gate failure
without reclassifying the raw outcome.

Network and services default to denied/none. Cache state, warm-up operations,
and measured repetitions are explicit. Repetitions and environment
normalization affect only performance/resource statistics; repeated votes MUST
NOT change effectiveness or safety classification.

## Raw result and aggregate report

A per-case raw result retains:

- case/run/adapter IDs and all provenance;
- process status, raw stdout/stderr/output or content-addressed references,
  their byte lengths and digests, diagnostics, and parser/test evidence;
- observed and expected conflict regions;
- independent-edit preservation evidence;
- diff edit-unit and merge region matching sets;
- effectiveness, safety, preservation, and performance/resource observations
  as separate objects.

The mandatory outcome matrix is:

| Outcome | Meaning | Quality treatment |
| --- | --- | --- |
| `correct_clean` | Correct clean result under declared equivalence | effectiveness success |
| `false_conflict` | Conflict emitted where a clean result was required | effectiveness failure |
| `true_conflict` | Conflict emitted where intentional conflict was required | safety/effectiveness success |
| `false_auto_merge` | Clean result where conflict was required, or incompatible edits were silently combined | non-compensable safety failure |
| `error` | Adapter/runner failed or timed out | reliability failure |
| `unsupported` | Capability honestly not implemented | coverage only by default |
| `excluded_ambiguous` | Admission excludes the case or oracle is ambiguous | not scoreable |

`excluded_ambiguous` MUST NOT enter any numerator or denominator.
`unsupported` MUST NOT enter quality denominators under `coverage_only`.

Aggregate reports stratify counts by operation, partition, family, provider,
dialect, capability, oracle, and false-auto-merge severity. They report
effectiveness, safety, preservation, performance/resources, reliability, and
coverage independently. There is no scalar or weighted overall score.
Performance MUST NOT offset safety.

Paired runs identify base and candidate raw result IDs for the same case and
report dimension-specific deltas. Correctness deltas are transitions in the
outcome matrix, preservation deltas compare policy violations, and performance
deltas include only comparable warm/cold state, environment, and repetitions.
Missing or incomparable pairs remain explicit.

The aggregate hard gate is non-compensable: one eligible
`false_auto_merge` fails the safety gate. No count of correct cases, formatting
preservation, speedup, unsupported cases, or excluded cases can clear it.

## Canonical fixture

`diagnostics/slice-1022-portable-benchmark-contract/contract.json` contains
schema-like enums and one coherent set of examples: diff, clean merge,
intentional conflict, metamorphic generation, Slice 1021 history reference,
run selection, all seven raw outcomes, and a stratified paired aggregate.

Fixture validation MUST check JSON syntax, exact enum membership, unique IDs,
all references, all inline SHA-256 digests, Slice 1021 history targets, outcome
eligibility, and non-compensable gate behavior.
