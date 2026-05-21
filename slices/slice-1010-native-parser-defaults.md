# Slice 1010: Native Parser Defaults

Implementation roots declare their preferred native parser providers separately
from generic TreeHaver / TSLP substrate providers.

## Contract

1. A native default entry names the implementation, source family, native
   provider, native backend, parser, generic substrate provider, generic
   substrate backend, fallback behavior, and scope.
2. Native defaults are implementation-level policy. They do not change the role
   of generic `*-merge` packages as TreeHaver / TSLP substrate boundaries.
3. When a native provider is unavailable and an implementation falls back to the
   generic substrate, unsupported required records fail closed with a diagnostic
   naming the responsible parser/provider.

## Fixture

- `fixtures/diagnostics/slice-1010-native-parser-defaults/native-parser-defaults.json`
