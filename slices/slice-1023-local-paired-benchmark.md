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
operation. Budgets are explicit and are never silently extended.

## Paired execution and classification

Each selected `merge3` case is materialized beneath the gem-local `tmp/`
directory. The runner executes `git merge-file -p ours base theirs`, then the
installed `ast-merge-git` executable with the case's exact provider selector.
The candidate process runs from the materialized Git working directory and the
runner proves that its own cwd is unchanged.

Raw records retain status, stdout, stderr, selected output, byte length,
SHA-256, diagnostics, conflict regions, exact and structural checks,
independent-edit evidence, provenance, and runtime as separate fields.
`metamorphic` and `diff` cases are selection-only until a correct installed
adapter exists and are reported `unsupported`, reducing coverage only.

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

## CLI

`ast-merge-git benchmark validate|select|run|report --corpus PATH` emits JSON.
`select`, `run`, and `report` accept `--profile micro|dev` and repeatable
`--changed-path PATH`; `run` and `report` accept an installed `--driver`.
Network and external services are denied by contract.
