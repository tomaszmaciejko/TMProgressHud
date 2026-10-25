#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Scripts/sync-license-resources.py
artifact_root="${TMHUD_ARTIFACT_DIR:-$PWD/Artifacts}"
mkdir -p "$artifact_root"
artifact_root="$(cd "$artifact_root" && pwd)"
if [ -e "$artifact_root/TMProgressHudUIKit.xcframework" ]; then
    printf '%s\n' 'Choose a fresh TMHUD_ARTIFACT_DIR; existing XCFramework is never silently replaced.' >&2
    exit 1
fi
framework_project="TMProgressHud.xcodeproj"
if [ "${TMHUD_PROJECT_FORMAT:-json}" = "plist" ]; then
    framework_project=".build/LegacyFramework/TMProgressHud.xcodeproj"
    python3 Scripts/project-factory.py framework "$framework_project" --format plist
fi
for variant in ios ios-simulator tvos tvos-simulator; do
    case "$variant" in
        ios) sdk=iphoneos; destination='generic/platform=iOS' ;;
        ios-simulator) sdk=iphonesimulator; destination='generic/platform=iOS Simulator' ;;
        tvos) sdk=appletvos; destination='generic/platform=tvOS' ;;
        tvos-simulator) sdk=appletvsimulator; destination='generic/platform=tvOS Simulator' ;;
    esac
    xcodebuild archive -project "$framework_project" -scheme TMProgressHudUIKit \
        -configuration Release -sdk "$sdk" -destination "$destination" \
        -archivePath "$artifact_root/$variant.xcarchive" -derivedDataPath .build/DistributionBuild \
        CODE_SIGNING_ALLOWED=NO SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES
 done
framework_args=()
for variant in ios ios-simulator tvos tvos-simulator; do
    framework_args+=(-framework "$artifact_root/$variant.xcarchive/Products/Library/Frameworks/TMProgressHudUIKit.framework")
done
if [ -e "$artifact_root/TMProgressHudUIKit.xcframework" ]; then
    printf '%s\n' 'Choose a fresh TMHUD_ARTIFACT_DIR; existing XCFramework is never silently replaced.' >&2
    exit 1
fi
xcodebuild -create-xcframework "${framework_args[@]}" -output "$artifact_root/TMProgressHudUIKit.xcframework"
./Scripts/package-xcframework.sh "$artifact_root"
printf '%s\n' "XCFramework archive ready at $artifact_root (not published)."
