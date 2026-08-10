# Slice 1021: Reviewed Git-history corpus foundation

## Purpose

Define a portable, review-first corpus for comparing Git's text merge with an
installed StructuredMerge Git driver against real, pinned merge history. This
slice establishes evidence collection; it makes no quality claim.

## Case contract

Each manifest pins the public repository URL, source revision, SPDX license,
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

Ambiguous, excluded, or false-auto-merge-unreviewed cases are never eligible
for scoring or claims.

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
   result digest, parse validity where supported, exact and safe structural
   equivalence, conflict-marker count and byte localization, deterministic
   rerun, and runtime.
8. Runtime remains outside deterministic comparison and is explicitly
   non-comparable.

Missing repositories, commits, blobs, providers, unsupported selectors,
octopus merges, dirty source checkouts, command failures, and timeouts are
explicit errors and are never silently skipped.

## Seed policy

Canonical manifests contain metadata and Git object IDs, not external source
trees or excerpts. The first seeds are reviewed clean-history preservation
cases from public `structuredmerge/structuredmerge-ruby` merge commits. Their
first parent is the exact merge-base, so they are honestly classified as clean
history rather than conflict-oracle evidence.

The manifest also carries an explicit blocked admission-backlog record: no
path-level conflict oracle is admitted until conflict evidence and its human
resolution can be safely attributed and reviewed.
