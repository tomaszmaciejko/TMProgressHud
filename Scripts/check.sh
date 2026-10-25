#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/lint.sh
python3 Scripts/sync-license-resources.py
python3 Scripts/verify-test-sources.py
python3 Scripts/verify-reference.py
python3 -m unittest discover -s Scripts/Tests -p 'test_*.py'
swift --version
swift format lint --strict --recursive Package.swift Sources Tests
swift package dump-package > /dev/null
printf '%s\n' 'Use Scripts/test.sh for iOS/tvOS build, tests and production coverage.'
printf '%s\n' 'Static checks and tooling tests passed. Run Scripts/test.sh for hosted behavior/coverage checks.'
