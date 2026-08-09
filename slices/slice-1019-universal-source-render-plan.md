# Slice 1019: Universal Source Render Plan

## Goal

Render source-preserving merge and diff output through one language-neutral
pipeline. Family providers decide semantics and syntax-specific synthesis;
`ast-merge` assembles exact source fragments, synthesized fragments, and
localized conflicts without reparsing or pretty-printing.

## Separation of responsibilities

### Provider semantic layer

The selected family provider owns:

- parsing and owner discovery;
- base/ours/theirs matching;
- change and conflict classification;
- merged owner ordering;
- selection of exact source spans;
- requests for separators or other synthesized syntax;
- syntax-aware synthesis when no revision contains the required fragment.

### Shared render-plan layer

`ast-merge` owns a passive ordered plan containing:

- source fragments copied from a named revision;
- synthesized fragments with explicit reason and provenance;
- localized conflict fragments containing base/ours/theirs alternatives;
- optional owner, region, attachment, and decision metadata.

The plan MUST NOT call a parser, matcher, or family emitter.

### Shared renderer

The renderer:

- copies source fragment bytes exactly;
- concatenates fragments in plan order;
- emits conflict markers around only the conflicting fragments;
- records output-line provenance;
- reports every synthesized fragment;
- preserves final-newline state unless the plan explicitly changes it.

It MUST NOT infer ownership, separators, indentation, commas, quoting, or other
syntax.

### Family fragment synthesizer

A provider MAY use a family emitter to create a fragment that does not exist in
any input revision. The emitted fragment enters the shared plan as
`synthesized`; it is never confused with source-preserved content.

## Fragment model

### Source fragment

- `kind`: `source`
- `revision`: `base`, `ours`, or `theirs`
- `start_line` and `end_line`, inclusive and one-based
- optional byte-column boundaries for partial-line ownership
- `metadata`

The first implementation MAY require whole-line fragments. The transport shape
reserves byte-column boundaries so line rendering does not permanently prevent
token-precise ownership.

### Synthesized fragment

- `kind`: `synthesized`
- `content`
- `reason`: for example `separator`, `indentation`, `conflict_marker`,
  `family_emission`, or `fallback`
- `producer`
- `metadata`

### Conflict fragment

- `kind`: `conflict`
- `base`, `ours`, and `theirs` child fragment lists
- labels and marker size
- owner and region metadata

Conflict children MAY be source or synthesized fragments. Conflicts MUST be
localized by the provider before rendering.

## Line records

Rendering produces:

- `content`;
- ordered `line_records`;
- `synthesized_fragments`;
- `conflicts`;
- `verification_input`.

Each line record contains:

- output line number;
- fragment kind;
- revision and original line when source-backed;
- owner and region identifiers when supplied;
- decision/change identifiers when supplied;
- synthesized reason and producer when synthesized;
- conflict identifier and side when inside a conflict.

Line records are the shared substrate for:

- writing merged source;
- unified or side-by-side diff presentation;
- provenance and diagnostics;
- conflict review;
- benchmark attribution.

Diff presentation is a separate consumer. It compares line records or rendered
content and MUST NOT change the merged source.

## Source preservation

Exact fragments retain their source revision and range until rendering. The
normal path MUST copy those bytes rather than reconstructing values from an AST.

This preserves comments, quote style, key style, trailing commas, whitespace,
and formatting whenever the selected fragment already exists in a revision.
Language-specific pretty-printing is reserved for explicit synthesized
fragments and optional post-merge formatting.

## Verification and fallback

After rendering, the provider reparses the output under the selected
dialect/backend and compares the rendered structure with the planned merged
structure.

Verification reports:

- output reparsed;
- structural/isomorphic verification passed;
- source fragments remained byte-identical;
- synthesized fragments and reasons;
- localized conflict sides reparsed when the grammar permits conflict-side
  validation;
- fallback requested.

A verification failure MUST NOT be returned as successful structured output.
The caller may use an explicit fallback policy, normally:

1. source-plan rendering;
2. structurally assisted line merge;
3. ordinary line merge with explicit report.

## JSON-family application

For JSON, JSONC, and JSON5:

- unchanged or selected owner fragments come directly from source revisions;
- JSONC/JSON5 comments and lexical style survive with their source fragments;
- comma, indentation, or newly created key/value syntax is synthesized by
  `json-merge`, then recorded explicitly;
- the shared renderer never calls `JSON.generate` or
  `JSON.pretty_generate`;
- successful output reparses in the requested dialect and matches the planned
  semantic value.

## Conformance

Shared fixtures MUST prove:

1. untouched source lines are byte-identical;
2. fragments from different revisions retain provenance;
3. synthesized separators are reported;
4. conflicts are localized and contain base/ours/theirs;
5. overlapping or invalid source ranges are rejected;
6. output line records map back to source or synthesis;
7. final-newline behavior is deterministic;
8. rendering has no parser or family dependency.
