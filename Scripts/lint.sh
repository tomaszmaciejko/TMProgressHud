#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
linter="${SWIFTLINT_BIN:-swiftlint}"
if [ -z "${SWIFTLINT_BIN:-}" ] && [ -x .build/Tools/swiftlint ]; then
    linter="$PWD/.build/Tools/swiftlint"
fi
if ! command -v "$linter" >/dev/null 2>&1; then
    printf '%s\n' 'Install SwiftLint using the instructions in Docs/TESTING.md.' >&2
    exit 1
fi
required_version="$(cat .swiftlint-version)"
if [ "$("$linter" version)" != "$required_version" ]; then
    printf 'SwiftLint %s is required; see .swiftlint-version.\n' "$required_version" >&2
    exit 1
fi
"$linter" lint --config .swiftlint.yml --strict --no-cache "$@"
