#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${TMHUD_TEST_DESTINATION:?Set a dedicated iOS/tvOS Simulator destination; this script never opens Simulator.app.}"
test_device="$(python3 Scripts/test-destination.py "$TMHUD_TEST_DESTINATION")"
case "$TMHUD_TEST_DESTINATION" in
    platform=iOS\ Simulator,*) test_platform='iOS Simulator'; test_sdk=iphonesimulator; report_platform=ios ;;
    platform=tvOS\ Simulator,*) test_platform='tvOS Simulator'; test_sdk=appletvsimulator; report_platform=tvos ;;
esac
xcrun simctl bootstatus "$test_device" -b
TMHUD_TEST_DESTINATION="platform=$test_platform,id=$test_device"
test_run="$report_platform-$(date +%Y%m%d-%H%M%S)-$$"
test_result=".build/TestResults/$test_run.xcresult"
python3 Scripts/verify-test-sources.py
xcodebuild -project Tests/Host/TMProgressHudTestHost.xcodeproj -scheme TMProgressHudTestHost -sdk "$test_sdk" -destination "$TMHUD_TEST_DESTINATION" \
    -derivedDataPath .build/HostedTests -resultBundlePath "$test_result" \
    -parallel-testing-enabled NO -enableCodeCoverage YES \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES test
python3 Scripts/export-coverage.py "$test_result" .build/coverage/production.json
python3 Scripts/coverage-gate.py .build/coverage/production.json

cp .build/coverage/production.json ".build/coverage/production-$report_platform.json"
