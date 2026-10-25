#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -version
xcodebuild -project Examples/UIKitDemo/TMProgressHudDemo.xcodeproj -scheme TMProgressHudDemo \
    -configuration Release -destination 'generic/platform=iOS' -derivedDataPath .build/Demo \
    CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES SWIFT_SUPPRESS_WARNINGS=NO build
