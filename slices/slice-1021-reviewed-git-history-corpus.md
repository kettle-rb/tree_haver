# Slice 1021: Reviewed Git-history corpus foundation

## Purpose

Define a portable, review-first corpus for comparing Git's text merge with an
installed StructuredMerge Git driver against real, pinned merge history. This
slice establishes evidence collection; it makes no quality claim.

## Case contract

Each source has a separate manifest in the same canonical fixture directory.
The compatibility path `manifest.json` remains the Ruby source; TypeScript and
Git/Bash use source-specific manifest names. Each manifest pins its one public
repository URL, source revision, SPDX license,
license evidence URL, and oracle rationale. Every case records:

- merge, merge-base, and exactly two parent commit SHAs;
- a repository-relative path and blob object IDs for base, ours, theirs, and
  the human merge result;
- provider, family, dialect, backend, profile, require path, and capability
  tags;
- provider/dialect/conflict-type strata;
- one oracle admission: `exact_automatic_resolution`,
  `structurally_equivalent_resolution`, `conflict_expected`,
  `ambiguous_manual_review`, or `excluded`;
- human-resolution rationale and ambiguity/reclassification state;
- mandatory false-auto-merge review state.
- reviewed `git merge-tree --write-tree` content-conflict evidence and review
  provenance for admitted conflict resolutions;
- selected-provider coverage as `supported` or explicitly `unsupported`.

Ambiguous, excluded, false-auto-merge-unreviewed, and provider-unsupported
cases are never score eligible. Admission and score eligibility are separate:
reviewed Ruby, TypeScript, and Bash conflicts are score eligible. Backlog
entries therefore have meaningful `blocked`, `admitted`, or `resolved` status
rather than implying that every reviewed candidate remains blocked.

## Runner contract

1. Validate the manifest before reading history.
2. Require a clean local checkout and resolve commits and blobs using
   non-mutating Git plumbing. Remote acquisition is a separate, explicit clone
   command into a new repo-local destination.
3. Prove the merge has exactly two parents, the recorded base equals
   `git merge-base`, parent order is exact, and all four path blobs match.
4. Materialize equivalent role bytes for both candidates under repo-local
   `tmp/`.
5. Run `git merge-file` as the text baseline.
6. Configure and invoke the actual installed `ast-merge-git` executable, from
   the temporary Git repository's working directory, with the exact selector.
7. Record status/exit classification, stdout, stderr, output digest, human
   result digest, exact equivalence, and structural equivalence from the
   selector's required provider using `diff2(human, output)` and empty changes.
   Parse validity alone is never equivalence. Record provider ID/method,
   provider availability, conflict-marker count and byte localization,
   deterministic rerun, and runtime.
8. Runtime remains outside deterministic comparison and is explicitly
   non-comparable.

Candidate invocation receives only base/ours/theirs plus selector metadata,
never the human/oracle bytes. Timed-out children are explicitly terminated and
reaped. Missing repositories, commits, blobs, octopus merges, dirty source
checkouts, command failures, and timeouts are explicit errors. Unsupported
provider coverage remains explicit unscored evidence.

Results use the seven Slice 1022 outcomes: `correct_clean`, `false_conflict`,
`true_conflict`, `false_auto_merge`, `error`, `unsupported`, and
`excluded_ambiguous`. For a clean-resolution oracle, status 0 is
`correct_clean` only with exact or provider-proven structural equivalence.
StructuredMerge driver status 1 is `false_conflict` and status 2 is `error`;
Git merge-file positive conflict counts are conflicts rather than process
errors. A non-equivalent clean result is `false_auto_merge`. For
`conflict_expected`, a conflict status is `true_conflict` and a clean status is
`false_auto_merge`. Selected-provider coverage declared unsupported produces
`unsupported` for the candidate only; the Git baseline remains independently
classified. Excluded or ambiguous admission is `excluded_ambiguous`. There is
no scalar score, and false auto-merge is non-compensable.

## Seed policy

Canonical manifests contain metadata and Git object IDs, not external source
trees or excerpts. The Ruby manifest retains three clean-history seeds and adds
one reviewed, provider-supported conflict-resolution oracle. Separate
TypeScript and Git/Bash manifests admit reviewed conflict resolutions.
TypeScript is score eligible through conservative ownership of a top-level
named call with a literal string identity. Bash is score eligible through
AST-proven `test_expect_success` ownership keyed by literal title and optional
literal prerequisite. Test membership changes remain full-file conflicts until
the renderer can prove insertion order, preventing a branch's new test from
moving after `test_done`. These cases make no aggregate quality claim.
