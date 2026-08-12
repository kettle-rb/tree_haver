# Slice 1023: Local paired benchmark and curated corpus

## Status and scope

This slice adds an executable, offline companion to Slice 1022 without changing
`structuredmerge.benchmark/v1`. The canonical corpus is
`diagnostics/slice-1023-local-paired-benchmark/corpus.json`. Its cases use the
Slice 1022 case vocabulary; the corpus envelope adds selection profiles,
provider selectors, changed-path capability mapping, and deterministic expected
summaries. All source is inline, project-authored CC0-1.0 material.

The first runner belongs in `ast-merge-git`: it is the package that can invoke
both the real `git merge-file` executable and the installed StructuredMerge Git
driver with equivalent role bytes and a preserved working directory.

## Corpus and admission

The corpus is stratified across JSON, JSONC, JSON5, Ruby/Prism, YAML, TOML,
Markdown, HTML, Bash, and TypeScript. `sentinel`, `gold`, and `metamorphic`
partitions cover independent edits, intentional ownership conflicts,
delete/modify, duplicate identity, preservation, malformed selected revisions,
and deterministic reorder/format/comment transformations.

Every inline input and expected output has an exact SHA-256 digest. Every case
records independent edit IDs, expected conflict regions, oracle procedure or
artifact, acceptable equivalence, preservation policy, false-auto-merge
severity, and reviewed authorship/license provenance. Parse acceptance alone is
never semantic equivalence. Ambiguous admission is excluded rather than guessed.

## Profiles and deterministic selection

`micro` is exactly the mandatory clean, conflict, and malformed sentinels.
`dev` is the union, in canonical case order, of:

1. mandatory sentinels;
2. every case directly mapped from changed paths through the corpus capability
   map; and
3. a bounded deterministic neighbor sample from the remaining cases.

Neighbor order is SHA-256 of `seed + NUL + case_id`, then case ID. Selection
reports every changed path, inferred capability, direct case, sentinel, neighbor
population, ordering algorithm, seed, selected ID, exclusion, and unsupported
operation. `merge3` and `metamorphic` are executable; `diff` remains
selection-only. Budgets are explicit and are never silently extended.

## Paired execution and classification

Each selected case is materialized beneath the gem-local `tmp/` directory.
For `merge3`, the runner executes `git merge-file -p ours base theirs`, then
the installed `ast-merge-git` executable with the case's exact provider
selector. The candidate process runs from the materialized Git working
directory and the runner proves that its own cwd is unchanged.

For `metamorphic`, the baseline is `git diff --no-index` over the exact authored
source and transformed bytes. The candidate is the selected installed
provider's `diff2` operation. A shared invariant oracle separately verifies
JSON-family semantic equality and JSONC AST comment retention; adapter output
determines whether semantic edit units were emitted. The initial reorder,
formatting, and comment transformations require no semantic edit. Git's
non-empty textual edits are therefore false conflicts, while empty provider
changes are correct clean results. Generator identity, version, seed,
transformation IDs, and verified authored-byte digests remain in each result.

Raw records retain status, stdout, stderr, selected output, byte length,
SHA-256, diagnostics, conflict regions, exact and structural checks,
independent-edit evidence, provenance, and runtime as separate fields.
`diff` cases are selection-only until a correct installed adapter exists and
are reported `unsupported`, reducing coverage only.

Outcomes are the Slice 1022 matrix: `correct_clean`, `false_conflict`,
`true_conflict`, `false_auto_merge`, `error`, `unsupported`, and
`excluded_ambiguous`. A clean result where conflict is required is always
`false_auto_merge`; parse validity, formatting, speed, and other successes
cannot compensate. One eligible false auto-merge fails the safety gate.

## Report and cache identity

Paired reports keep safety, effectiveness, preservation, performance,
reliability, and coverage distinct. They stratify by operation, partition,
family, provider, dialect, capability, severity, and transition, and enumerate
newly passing, newly failing, and changed-conflict cases. No scalar score exists.

The cache identity hashes the adapter executable, selector/configuration,
canonical corpus bytes, profile and selection, and normalized environment
identity. No persistent cache is introduced. A deterministic rerun compares
correctness records with runtime removed; runtime is never used to vote on
correctness.

The initial executable metamorphic pair is deterministic: both Git textual
baselines are false conflicts and both StructuredMerge provider diffs are
correct clean results. This is development evidence only; it does not authorize
an aggregate quality claim.

## Pinned structural competitor

The corpus pins Mergiraf source revision
`13b813c02da9511c7433131aed142473ffe62d52`, version `0.18.0`, GPL-3.0-only
reference-only reuse posture, Rust 1.91.0 toolchain, build command, merge3-only
operation coverage, and supported dialects. Competitive execution is optional
and requires an explicit `--mergiraf PATH`; no binary or vendor source is
embedded in the corpus.

The runner verifies the reported version, records the binary SHA-256 and path,
executes the same exact base/ours/theirs bytes with bounded child-process
handling, and evaluates output with the same oracle and preservation checks.
Unsupported operations and dialects are coverage, not quality failures.
Competitor false auto-merges are surfaced separately and never alter the
StructuredMerge candidate safety gate.

At the pinned revision, built from the tracked source with Rust 1.91.0, the
10-case JSON-affected dev selection produced two `correct_clean`, two
`true_conflict`, one `false_conflict`, one `false_auto_merge`, and four
`unsupported` Mergiraf results. The false auto-merge is the reviewed duplicate
JSON identity case; this is a non-compensable competitor safety finding, not a
ranking or aggregate quality claim.

## CLI

`ast-merge-git benchmark validate|select|run|report --corpus PATH` emits JSON.
`select`, `run`, and `report` accept `--profile micro|dev` and repeatable
`--changed-path PATH`; `run` and `report` accept an installed `--driver` and an
optional pinned `--mergiraf PATH`. Network and external services are denied by
contract.
