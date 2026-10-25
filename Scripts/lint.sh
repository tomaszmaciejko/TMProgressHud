#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/Tools
lint_host="$(xcrun --find swiftc)"
lint_host="$(dirname "$lint_host")/../lib/swift/host"
xcrun swiftc -swift-version 6 -warnings-as-errors -I "$lint_host" -L "$lint_host" \
    -lSwiftParser -lSwiftSyntax -Xlinker -rpath -Xlinker "$lint_host" \
    Tools/SourceLint.swift -o .build/Tools/source-lint
find Sources -name '*.swift' -print0 | xargs -0 .build/Tools/source-lint
