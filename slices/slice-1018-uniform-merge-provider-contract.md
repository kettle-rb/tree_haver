# Slice 1018: Uniform Merge Provider Contract

## Goal

Define one provider API for every active Ruby `*-merge` implementation so
two-way analysis/diff/merge and three-way merge do not depend on family-specific
entrypoint names.

`ast-merge` owns provider registration and dispatch. `ast-merge-git` adapts Git
driver inputs and outputs to this contract. Format and language gems own parsing,
merge semantics, conflict localization, and source-aware rendering.

## Layering

### `ast-merge`

The substrate MUST expose:

- provider registration by stable provider ID;
- provider resolution by family, dialect, backend, and optional profile;
- capability inspection without parsing or mutation;
- dispatch for `analyze`, `diff2`, `merge2`, and `merge3`;
- validation of request and result envelopes.

### Family and backend `*-merge` gems

Every active Ruby merge gem MUST expose `merge_provider`, returning an object
that implements the provider API below. Workflow gems and backend-specific gems
use the same protocol. A workflow provider MAY delegate to a selected backend
provider, but it MUST preserve the request roles and result envelope.

### `ast-merge-git`

The Git package MUST:

- convert `%O`, `%A`, `%B`, and `%P` driver inputs into a `merge3` request;
- resolve an advertised provider through `ast-merge`;
- preserve provider diagnostics, conflicts, changes, and render metadata;
- write the provider output to `%A` only when Git driver policy permits;
- report unsupported capability without substituting a two-way operation;
- apply only explicit, machine-reported fallback policy.

It MUST NOT implement family parsing or rendering and MUST NOT serialize a
provider's semantic value through a generic serializer.

## Provider API

Each `merge_provider` object MUST implement:

- `provider_id` — stable namespaced identifier;
- `family` — portable family identifier;
- `capabilities` — supported operations, dialects, backends, profiles, and
  source-preservation guarantees;
- `analyze(request)` — parse and describe one source;
- `diff2(request)` — compute structural changes from `before` to `after`;
- `merge2(request)` — apply directional incoming/current merge policy;
- `merge3(request)` — reconcile base-relative `ours` and `theirs` changes.

All methods accept and return hashes conforming to the envelopes in this slice.
Ruby implementations MUST declare corresponding RBS interfaces.

## Request Roles

Roles are semantic and MUST NOT be inferred from positional order after request
normalization.

### `analyze`

- `source`
- `source_role`
- `path_name`
- `family`
- `dialect`
- `backend`
- `profile_id`

### `diff2`

- `before_source`
- `after_source`
- the common selection fields above

### `merge2`

- `incoming_source`
- `current_source`
- `merge_policy`
- the common selection fields above

`merge2` preserves the directional behavior used by templating. It is not a
substitute for `merge3`.

### `merge3`

- `base_source`
- `ours_source`
- `theirs_source`
- `conflict_marker_size`
- `fallback_policy`
- `render_policy`
- the common selection fields above

A provider MUST demonstrate that `base_source` participates in change
classification. Calling `merge2`, dropping the base, or treating either side as
a template is a contract violation.

## Result Envelope

Every operation returns:

- `schema`;
- `operation`;
- `ok`;
- `provider`;
- `profile`;
- `diagnostics`;
- `changes`;
- `conflicts`;
- `fallbacks`;
- `render_report`;
- `verification`.

Operation-specific payload fields are:

- `analyze`: `analysis`;
- `diff2`: `diff`;
- `merge2` and `merge3`: `output` or `conflicted_output`.

The provider object contains provider ID, family, dialect, backend, package, and
package version. Verification records whether output reparsed, whether the base
participated for `merge3`, and whether source-preservation guarantees passed.

## Outcomes

Providers distinguish:

- successful operation;
- invalid request;
- parse failure, including source role;
- unsupported family, dialect, backend, profile, or operation;
- unresolved conflict;
- render failure;
- verification failure;
- internal failure.

An unsupported outcome is valid only when capabilities do not advertise that
surface. Advertising an operation and then returning unsupported is a
conformance failure.

## Source-Aware Rendering

The selected provider owns rendering. It MUST use its AST/CST representation and
family emitter to preserve supported comments, formatting, ordering, quoting,
and dialect syntax.

In particular:

- JSON, JSONC, and JSON5 are dialects of the JSON family provider;
- JSONC and JSON5 output MUST NOT pass through `JSON.generate`,
  `JSON.pretty_generate`, or another JSON-only serializer;
- a canonical serializer MAY be an explicit fallback for strict JSON when the
  request permits it;
- canonicalization MUST be reported in `fallbacks` and `render_report`;
- conflict rendering MUST either preserve syntactic coherence in an owned
  region or report an explicit full-file fallback.

## Conformance

The shared fixture matrix lists every active Ruby merge gem. Conformance MUST
check:

1. `merge_provider` exists and returns the uniform provider interface.
2. Capabilities and actual behavior agree.
3. `diff2`, `merge2`, and `merge3` retain distinct request roles.
4. `merge3` uses the base for independent edits and conflict classification.
5. Parse diagnostics identify the failing source role.
6. Provider rendering reparses under the selected dialect/backend.
7. Unsupported behavior is explicit and never silently replaced by another
   operation.
8. Git integration tests invoke the actual driver with `%O %A %B %P`.

Binary and archive providers still implement the complete API. They MAY use
coarse-grained replacement/conflict semantics where structural semantics do not
apply, but they MUST consume all roles and report those semantics in
capabilities.

## Compatibility

Existing family-specific public methods remain compatibility wrappers during
the migration. Each wrapper delegates to the provider and emits the same
semantic result it did previously. Removal or signature changes require a
separate compatibility decision.

Git merge support MUST be advertised only for provider/dialect rows that pass
the `merge3` and real-driver conformance suites.
