# Slice 1017: Git Driver Opt-In Setup

## Goal

Define a portable install contract for Git diff and merge driver setup without
making repository-provided executable commands run automatically on clone.

## Contract

StructuredMerge implementations expose a `git install` planning surface that
can be used directly by `smorg-*` CLIs and by template tooling such as
`kettle-jem`.

The default profile is `semantic-diff`. A `builtin-diff` profile MUST remain
available for projects that only want Git's built-in hunk and word-diff
behavior.

Local setup writes repository attributes only. Global setup registers installed
`smorg-*` driver commands once per user with `git config --global`.

## Versioned Inputs

Generated projects SHOULD commit:

- `.structuredmerge/git-drivers.toml`
- `.structuredmerge/kettle-jem.yml`

Implementations MUST treat `.structuredmerge/kettle-jem.yml` as the canonical
template configuration path. During the migration window they MAY read legacy
`.kettle-jem.yml` when the canonical file is absent.

### Driver Manifest

`.structuredmerge/git-drivers.toml` is declarative. It MUST NOT be executed or
included directly by Git.

The manifest root contains:

- `version`: integer manifest version, initially `1`.
- `driver_namespace`: string namespace, normally `smorg`.
- `profiles`: table keyed by profile name.

Each profile MAY contain:

- `description`: human-readable string.
- `attributes`: ordered list of file pattern attribute entries.
- `git_config`: ordered list of Git config entries.

Attribute entries contain:

- `pattern`: `.gitattributes` file pattern.
- any supported Git attribute keys such as `diff`, `merge`, or
  `conflict-marker-size`.

Git config entries contain:

- `scope`: `global` for executable driver registrations.
- `key`: Git config key such as `diff.smorg-ruby.command`.
- `value`: one argv-safe string value passed to `git config`.

Committed manifests MUST reject shell interpolation and MUST NOT rely on shell
splitting to represent command arguments.

## Managed Attributes

Installers update `.gitattributes` through managed blocks:

```gitattributes
# <<structuredmerge:git-drivers>> do not edit below this line
*.rb diff=smorg-ruby merge=smorg-ruby conflict-marker-size=32
# <</structuredmerge:git-drivers>>
```

Rules:

- Preserve unmanaged lines and comments.
- Replace only the matching StructuredMerge managed block.
- Report conflicting unmanaged attributes instead of silently overwriting them.
- Support removal of managed blocks for undo.

## Plan Shape

Install planning returns a `GitDriverInstallPlan` object:

```json
{
  "profile": "semantic-diff",
  "scope": "local",
  "mode": "apply",
  "attribute_updates": [
    {
      "path": ".gitattributes",
      "managed_block": "structuredmerge:git-drivers",
      "pattern": "*.rb",
      "attributes": {"diff": "smorg-ruby"}
    }
  ],
  "config_updates": [],
  "diagnostics": []
}
```

Global setup uses the same shape with `scope: "global"` and `config_updates`
entries:

```json
{
  "scope": "global",
  "config_updates": [
    {
      "key": "diff.smorg-ruby.command",
      "value": "smorg-ruby diff-driver",
      "argv": ["git", "config", "--global", "diff.smorg-ruby.command", "smorg-ruby diff-driver"]
    }
  ]
}
```

## Report Shape

Apply and check operations return a `GitDriverInstallReport` object:

```json
{
  "ok": true,
  "profile": "semantic-diff",
  "scope": "local",
  "changed_files": [".gitattributes"],
  "config_keys": [],
  "missing": [],
  "diagnostics": []
}
```

`--check` MUST:

- exit `0` when the selected profile is installed;
- exit nonzero when required attributes, global config entries, or executables
  are missing;
- print a short human report by default;
- print stable JSON with `ok`, `profile`, `scope`, and `missing` when `--json`
  is requested.

## Modes

- `local`: write managed `.gitattributes` blocks only.
- `global`: register all installed `smorg-*` diff and merge driver commands
  once per user.
- `check`: inspect the selected profile without changing files or config.
- `undo`: remove managed blocks and unset global StructuredMerge config keys.
- `include-file`: optional future mode that writes generated config below
  `.git/smorg/` and includes it from local Git config.

## Diagnostics

Implementations MUST use stable diagnostic keys for:

- `unsupported_language`
- `missing_executable`
- `conflicting_attributes`
- `unsupported_scope`
- `dirty_managed_block`
- `missing_global_config`
- `missing_attributes`
- `unsafe_manifest_command`
- `legacy_kettle_config_conflict`

Diagnostics SHOULD include `path`, `profile`, `scope`, `severity`, and
`blocking` when those fields are applicable.

## Fixture Coverage

Shared fixtures SHOULD cover:

- local semantic-diff planning;
- global driver registration planning;
- builtin-diff planning;
- check success and check failure;
- undo planning;
- include-file planning;
- conflicting unmanaged attributes;
- dirty managed blocks;
- missing executable diagnostics;
- legacy `.kettle-jem.yml` migration and conflict diagnostics.
