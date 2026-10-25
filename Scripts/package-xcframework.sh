#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
artifact_root="${1:?Provide the folder containing TMProgressHudUIKit.xcframework}"
artifact_root="$(cd "$artifact_root" && pwd)"
framework="$artifact_root/TMProgressHudUIKit.xcframework"
if [ -e "$artifact_root/TMProgressHudUIKit.xcframework.zip" ]; then
    printf '%s\n' 'Choose a fresh output folder; an existing archive is never replaced.' >&2
    exit 1
fi
if [ -n "${TMHUD_SIGN_IDENTITY:-}" ]; then
    signing_arguments=(--timestamp --sign "$TMHUD_SIGN_IDENTITY")
    if [ -n "${TMHUD_SIGN_KEYCHAIN:-}" ]; then
        signing_arguments+=(--keychain "$TMHUD_SIGN_KEYCHAIN")
    fi
    codesign "${signing_arguments[@]}" "$framework"
fi
audit_arguments=("$framework" --report "$artifact_root/validation.json")
if [ -n "${TMHUD_SIGN_CERTIFICATE:-}" ]; then
    certificate_digest="$(/usr/bin/openssl x509 -in "$TMHUD_SIGN_CERTIFICATE" -outform DER | shasum -a 256 | awk '{print toupper($1)}')"
    audit_arguments+=(--expected-certificate-sha256 "$certificate_digest")
    /usr/bin/openssl x509 -in "$TMHUD_SIGN_CERTIFICATE" -out "$artifact_root/SIGNING_CERTIFICATE.pem"
    printf '%s\n' "$certificate_digest" > "$artifact_root/SIGNING_CERTIFICATE_SHA256"
fi
if [ "${TMHUD_REQUIRE_SIGNATURE:-0}" = '1' ] || [ -n "${TMHUD_SIGN_IDENTITY:-}" ]; then
    audit_arguments+=(--require-signature)
fi
cp LICENSE THIRD_PARTY_NOTICES.md "$artifact_root/"
(cd "$artifact_root" && ditto -c -k --sequesterRsrc --keepParent TMProgressHudUIKit.xcframework TMProgressHudUIKit.xcframework.zip)
(cd "$artifact_root" && shasum -a 256 TMProgressHudUIKit.xcframework.zip > SHA256SUMS)
python3 Scripts/audit-xcframework.py "${audit_arguments[@]}"
