#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
case "${TMHUD_REFERENCE_PLATFORM:-ios}" in
    ios) reference_platform=iphoneos; reference_target=arm64-apple-ios15.0 ;;
    tvos) reference_platform=appletvos; reference_target=arm64-apple-tvos15.0 ;;
    *) printf '%s\n' 'Choose ios or tvos for TMHUD_REFERENCE_PLATFORM.' >&2; exit 1 ;;
esac
reference_sdk="$(xcrun --sdk "$reference_platform" --show-sdk-path)"
xcrun --sdk "$reference_platform" swiftc -typecheck -swift-version 6 -warnings-as-errors \
    -target "$reference_target" -sdk "$reference_sdk" \
    -import-objc-header Reference/MBProgressHUD/MBProgressHUD.h \
    Tests/ReferenceAPI/ImportedAPI.swift
printf '%s\n' 'Pinned upstream Swift import probe passed (compile only; not port/runtime tests).'
