#!/usr/bin/env python3
"""Report shared ast-merge diagnostic fixture-key coverage across host repos."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


HOSTS = {
    "typescript": {
        "path": Path("typescript/packages/ast-merge/test/fixtures.integration.test.ts"),
        "key_patterns": [
            r"diagnosticsFixturePath\('([^']+)'\)",
            r"conformanceFixturePath\([^)]*'diagnostics', '([^']+)'\)",
        ],
        "slice_patterns": [
            r"readFixture(?:<.*?>)?\(\s*'diagnostics',\s*'(slice-\d+-[a-z0-9-]+)'",
            r"\[\s*'(slice-\d+-[a-z0-9-]+)'\s*,\s*'[^']+\.json'",
            r",\s*'(slice-\d+-[a-z0-9-]+)'\s*,\s*'[^']+\.json'",
            r"'(slice-\d+-[a-z0-9-]+/[a-z0-9-]+\.json)'",
        ],
    },
    "go": {
        "path": Path("go/astmerge/fixtures_integration_test.go"),
        "key_patterns": [
            r'diagnosticsFixturePath\(t, "([^"]+)"\)',
        ],
        "slice_patterns": [
            r'filepath\.Join\("..", "..", "fixtures", "diagnostics", "(slice-\d+-[a-z0-9-]+)"',
            r'\(\s*"(slice-\d+-[a-z0-9-]+)"\s*,\s*"[^"]+\.json"',
            r',\s*"(slice-\d+-[a-z0-9-]+)"\s*,\s*"[^"]+\.json"',
            r'"(slice-\d+-[a-z0-9-]+/[a-z0-9-]+\.json)"',
        ],
    },
    "rust": {
        "path": Path("rust/crates/ast-merge/tests/fixtures.rs"),
        "key_patterns": [
            r'diagnostics_fixture_path\(\s*"([^"]+)"\s*,?\s*\)',
        ],
        "slice_patterns": [
            r'"diagnostics",\s*"(slice-\d+-[a-z0-9-]+)"',
            r'\(\s*"(slice-\d+-[a-z0-9-]+)"\s*,\s*"[^"]+\.json"',
            r',\s*"(slice-\d+-[a-z0-9-]+)"\s*,\s*"[^"]+\.json"',
            r'"(slice-\d+-[a-z0-9-]+/[a-z0-9-]+\.json)"',
        ],
    },
    "ruby": {
        "path": Path("ruby/gems/ast-merge/spec/fixtures_integration_spec.rb"),
        "key_patterns": [
            r'diagnostics_fixture\("([^"]+)"\)',
        ],
        "slice_patterns": [
            r'fixtures_root\.join\(\s*"diagnostics",\s*"(slice-\d+-[a-z0-9-]+)"',
            r'\[\s*\[\s*"(slice-\d+-[a-z0-9-]+)"\s*,\s*"[^"]+\.json"',
            r',\s*"(slice-\d+-[a-z0-9-]+)"\s*,\s*"[^"]+\.json"',
            r',\s*\[\s*"(slice-\d+-[a-z0-9-]+)"\s*,\s*"[^"]+\.json"',
            r'(slice-\d+-[a-z0-9-]+)/[a-z0-9-]+\.json',
        ],
        "dynamic_keys": [
            r'%w\[([^\]]+)\]\.each do \|role\|\s*fixture = diagnostics_fixture\(role\)',
        ],
    },
}

KEY_ALIASES = {
    "delegated_child_group_accepted_for_apply": "delegated_child_groups_accepted_for_apply",
}

IGNORED_KEYS = {
    "analysis",
    "matching",
    "merge",
    "manifest",
    "source_family_manifest",
    "conformance_runner",
    "family_feature_profile",
    "go_family_feature_profile",
    "rust_family_feature_profile",
    "typescript_family_feature_profile",
}


def workspace_root(script_path: Path) -> Path:
    return script_path.resolve().parents[2]


def key_from_slice_dir(slice_dir: str) -> str:
    slice_dir = slice_dir.split("/", 1)[0]
    _, _, suffix = slice_dir.partition("-")
    _, _, name = suffix.partition("-")
    key = name.replace("-", "_")
    return KEY_ALIASES.get(key, key)


def fixture_keys(root: Path, relpath: Path, config: dict[str, object]) -> set[str]:
    source_path = root / relpath
    if not source_path.exists():
        raise FileNotFoundError(f"missing host test file: {source_path}")
    text = source_path.read_text()
    flags = re.MULTILINE | re.DOTALL
    keys: set[str] = set()

    for pattern in config.get("key_patterns", []):
        for key in re.findall(pattern, text, flags):
            keys.add(KEY_ALIASES.get(key, key))

    for pattern in config.get("slice_patterns", []):
        keys.update(key_from_slice_dir(match) for match in re.findall(pattern, text, flags))

    for pattern in config.get("dynamic_keys", []):
        for block in re.findall(pattern, text, flags):
            keys.update(KEY_ALIASES.get(item.strip(), item.strip()) for item in block.split() if item.strip())

    return keys


def build_report(root: Path) -> dict[str, object]:
    per_host: dict[str, list[str]] = {}
    for host, config in HOSTS.items():
        per_host[host] = sorted(fixture_keys(root, config["path"], config))

    key_presence: dict[str, list[str]] = {}
    for host, keys in per_host.items():
        for key in keys:
            key_presence.setdefault(key, []).append(host)

    parity_gaps = {
        key: hosts
        for key, hosts in sorted(key_presence.items())
        if key not in IGNORED_KEYS and len(hosts) != len(HOSTS)
    }

    return {
        "workspace_root": str(root),
        "hosts": per_host,
        "parity_gaps": parity_gaps,
    }


def print_table(report: dict[str, object]) -> int:
    hosts = list(HOSTS)
    parity_gaps: dict[str, list[str]] = report["parity_gaps"]  # type: ignore[assignment]
    print("ast-merge fixture-key parity")
    print(f"workspace: {report['workspace_root']}")
    print("")

    if not parity_gaps:
        print("All configured hosts cover the same diagnostic fixture keys.")
        return 0

    width = max(len(key) for key in parity_gaps)
    header = "fixture_key".ljust(width) + "  missing_in"
    print(header)
    print("-" * len(header))
    for key, present_hosts in parity_gaps.items():
        missing = [host for host in hosts if host not in present_hosts]
        print(f"{key.ljust(width)}  {', '.join(missing)}")
    return 1


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--workspace-root",
        type=Path,
        help="Override the inferred kettle-dev workspace root.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON instead of the table view.",
    )
    args = parser.parse_args(argv)

    root = args.workspace_root.resolve() if args.workspace_root else workspace_root(Path(__file__))
    report = build_report(root)

    if args.json:
        json.dump(report, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
        return 0 if not report["parity_gaps"] else 1

    return print_table(report)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
