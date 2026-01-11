#!/usr/bin/env bash

# Finds files without exactly one trailing newline
# Pass "-f" to also fix those files
#
# Always have exactly one newline at the end of every file comprised of text.
# In a POSIX system a file missing a final newline is technically not a text file.
# Some tools will not parse them, or parse them in unexpected ways.
# NOTE: We'll forgive external files, in node_modules, and vendor.
# See:
#   Official POSIX Standard: https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html#tag_03_206
#   Discussion of "why newline at EOF?": https://stackoverflow.com/q/729692/213191
#   Theory behind `-not \( -path ... \)`: https://stackoverflow.com/a/69830768/213191
#   Thanks: Gabriel Staples, https://stackoverflow.com/users/4561887/gabriel-staples
#
# Author: Peter H Boling
# Copyright (c) 2026 Peter H Boling. All rights reserved.
# License MIT (see LICENSE file in repository root for details)

set -euo pipefail

FIX_MODE=false
if [[ "${1:-}" == "-f" ]]; then
    FIX_MODE=true
fi

# Function to check if file has exactly one trailing newline
check_eof() {
    local file="$1"
    # Empty files are OK (nothing to fix)
    [[ ! -s "$file" ]] && return 0

    # Check last two bytes to detect:
    # - Missing newline (last byte != newline)
    # - Multiple trailing newlines (last two bytes == newline newline)
    local last_bytes
    last_bytes=$(tail -c 2 "$file" | od -An -tx1 | tr -d ' \n')

    # 0a = newline in hex
    case "$last_bytes" in
        *0a0a) return 1 ;;  # Multiple trailing newlines
        *0a)   return 0 ;;  # Exactly one trailing newline
        *)     return 1 ;;  # Missing trailing newline
    esac
}

# Function to fix file to have exactly one trailing newline
fix_eof() {
    local file="$1"
    # Remove all trailing newlines, then add exactly one
    # Using perl for portability (sed -i behaves differently on macOS vs Linux)
    perl -pi -e 'chomp if eof' "$file"
    echo >> "$file"
}

# Find all text files, excluding specified patterns
invalid_files=()

while IFS= read -r -d '' file; do
    # Skip if not a text file
    if ! file -b "$file" | grep -q text; then
        continue
    fi

    if ! check_eof "$file"; then
        invalid_files+=("$file")
        if $FIX_MODE; then
            fix_eof "$file"
            echo "Fixed: $file"
        else
            echo "$file"
        fi
    fi
done < <(find . \
    -type f \
    -not \( -name "*.csv" \) \
    -not \( -name "*.dio" \) \
    -not \( -name "*.gem" \) \
    -not \( -name "*.json" \) \
    -not \( -name "*.pem" \) \
    -not \( -name "*.tpl" \) \
    -not \( -name "VERSION*" \) \
    -not \( -path "*/.bundle/*" -prune \) \
    -not \( -path "*/.git/*" -prune \) \
    -not \( -path "*/.idea/*" -prune \) \
    -not \( -path "*/.vscode/*" -prune \) \
    -not \( -path "*/.yardoc/*" -prune \) \
    -not \( -path "*/angular/*" -prune \) \
    -not \( -path "*/certs/*" -prune \) \
    -not \( -path "*/checksums/*" -prune \) \
    -not \( -path "*/coverage/*" -prune \) \
    -not \( -path "*/doc/*" -prune \) \
    -not \( -path "*/docs/*" -prune \) \
    -not \( -path "*/log/*" -prune \) \
    -not \( -path "*/node_modules/*" -prune \) \
    -not \( -path "*/pkg/*" -prune \) \
    -not \( -path "*/public/*" -prune \) \
    -not \( -path "*/results/*" -prune \) \
    -not \( -path "*/test-results/*" -prune \) \
    -not \( -path "*/tmp/*" -prune \) \
    -not \( -path "*/vendor/*" -prune \) \
    -print0)

# Exit with appropriate status
if [[ ${#invalid_files[@]} -eq 0 ]]; then
    exit 0
else
    if $FIX_MODE; then
        echo ""
        echo "Fixed ${#invalid_files[@]} file(s)"
        exit 0
    else
        echo ""
        echo "Found ${#invalid_files[@]} file(s) with invalid EOF"
        echo "Run with -f to fix"
        exit 1
    fi
fi
