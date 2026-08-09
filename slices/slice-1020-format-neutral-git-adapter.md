# Slice 1020: Format-neutral Git adapter

## Purpose

Define the boundary between Git's custom merge-driver protocol and portable
StructuredMerge providers. The adapter maps Git roles into `merge3`, but owns no
family parser, semantic merge algorithm, owner model, or renderer.

## Inputs

- ancestor path/content (`%O`) as `base_source`;
- current path/content (`%A`) as `ours_source`;
- incoming path/content (`%B`) as `theirs_source`;
- logical path (`%P`) as `path_name`;
- conflict marker size (`%L`);
- optional base/current/incoming labels;
- provider selectors: `provider_id` or `family`, plus optional dialect,
  backend, and profile.

Provider packages are loaded by the embedding application. The executable may
load explicitly configured require paths, but it must not map a family to a
parser package or require a family implementation directly.

## Dispatch

1. Read the three Git role files without modifying them.
2. Normalize selectors and role names into a portable provider request.
3. Dispatch exactly one provider `merge3` operation.
4. Never substitute `merge2` when `merge3` is unsupported or fails.
5. Preserve the provider result envelope and add only Git compatibility aliases
   and write/exit metadata.

## Output policy

- A successful provider result must contain String `output`; write it to `%A`.
- A conflicted result may contain String `conflicted_output`.
- Under `write`, write conflicted output to `%A`; under `leave_ours`, do not
  modify `%A`.
- Missing or non-String output fails explicitly as `invalid_provider_output`.
- File read/write errors fail explicitly as `file_error`.

## Exit codes

- `0`: clean provider merge written to `%A`;
- `1`: provider reported unresolved conflicts;
- `2`: unsupported capability, invalid request/result/output, provider error,
  configuration error, or file error.

## Compatibility

`merged_source`, `conflicted_source`, and `change_classifications` remain
adapter aliases for provider `output`, `conflicted_output`, and `changes`.
Family-specific legacy fields are removed from this boundary and remain the
responsibility of provider result reports.

## Conformance

The corresponding fixture must cover clean output, unresolved conflict output,
unsupported capability, and invalid successful output. Every result retains
provider diagnostics, conflicts, provenance, verification, and fallbacks.
