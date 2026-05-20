# StructuredMerge Cross-Language Examples

This directory contains shared, user-level merge scenarios. Each scenario has
the same template, destination, and expected output for every implementation.

The runner can select one scenario or all scenarios, and one implementation or
all known implementations:

```console
examples/bin/sm-example list
examples/bin/sm-example run all --impl ruby
examples/bin/sm-example run json_package_manifest --impl ruby
```

These examples are not primarily CI fixtures. They are larger than the conformance
slices and are designed to be readable demonstrations that can later be published
as website examples.

## Layout

| Path | Purpose |
|---|---|
| `scenarios/*/manifest.yml` | Scenario metadata, family, dialect, and file names. |
| `scenarios/*/template.*` | Template/source side of the merge. |
| `scenarios/*/destination.*` | Destination/local side of the merge. |
| `scenarios/*/expected.*` | Expected output for implementations that support the scenario. |
| `bin/sm-example` | Shared scenario runner. |

The Ruby adapter delegates to `structuredmerge/ruby/examples/bin/run-scenario`.
Go, Rust, and TypeScript adapters can be added without changing the scenario
files.

