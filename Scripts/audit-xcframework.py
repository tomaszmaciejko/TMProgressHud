#!/usr/bin/env python3
"""Verify every shipping slice, runtime install name and required legal resources."""
import argparse
import hashlib
import json
import plistlib
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEPLOYMENT_TARGETS = json.loads((ROOT / "Scripts/deployment-targets.json").read_text())
EXPECTED_VARIANTS = {("ios", "device"), ("ios", "simulator"), ("tvos", "device"), ("tvos", "simulator")}


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit_slice(artifact, entry, version):
    folder = artifact / entry["LibraryIdentifier"]
    framework = folder / entry["LibraryPath"]
    binary = framework / "TMProgressHudUIKit"
    info = plistlib.loads((framework / "Info.plist").read_bytes())
    require(info.get("CFBundleShortVersionString") == version, f"Wrong version: {framework}")
    build = subprocess.check_output(["xcrun", "vtool", "-show-build", str(binary)], text=True)
    minimums = re.findall(r"\bminos\s+(\S+)", build)
    minimum_os = DEPLOYMENT_TARGETS[entry["SupportedPlatform"]]
    require(minimums and set(minimums) == {minimum_os}, f"Wrong minimum OS: {binary}")
    install_names = subprocess.check_output(["otool", "-D", str(binary)], text=True)
    names = [line.strip() for line in install_names.splitlines() if line.strip() and not line.rstrip().endswith(":")]
    require(names and set(names) == {"@rpath/TMProgressHudUIKit.framework/TMProgressHudUIKit"}, f"Nonportable runtime install name: {names}")
    exports = subprocess.check_output(["nm", "-gU", str(binary)], text=True)
    require("MBProgressHUD" not in exports, f"Unexpected reference symbols: {binary}")
    for filename, canonical in [("PrivacyInfo.xcprivacy", ROOT / "Sources/TMProgressHudUIKit/PrivacyInfo.xcprivacy"), ("TMProgressHud-LICENSE.txt", ROOT / "LICENSE"), ("TMProgressHud-NOTICES.txt", ROOT / "THIRD_PARTY_NOTICES.md")]:
        require((framework / filename).read_bytes() == canonical.read_bytes(), f"Missing/stale resource: {framework / filename}")
    interfaces = list((framework / "Modules/TMProgressHudUIKit.swiftmodule").glob("*.swiftinterface"))
    require(interfaces, f"Missing public Swift interfaces: {framework}")
    compilers = set()
    for interface in interfaces:
        header = re.search(r"^// swift-compiler-version: (.+)$", interface.read_text(), re.MULTILINE)
        require(header is not None, f"Missing compiler provenance: {interface}")
        compilers.add(header.group(1))
    require(len(compilers) == 1, f"Mixed compilers within a framework slice: {framework}")
    for architecture in entry["SupportedArchitectures"]:
        require(any(path.name.startswith(architecture + "-") and not path.name.endswith(".private.swiftinterface") for path in interfaces), f"Missing public interface for {architecture}: {framework}")
    return {"identifier": entry["LibraryIdentifier"], "platform": entry["SupportedPlatform"], "variant": entry.get("SupportedPlatformVariant", "device"), "architectures": entry["SupportedArchitectures"], "minimumOS": minimum_os, "version": version, "swiftCompiler": next(iter(compilers)), "installName": names[0], "interfaces": sorted(path.name for path in interfaces), "binarySHA256": sha256(binary)}


def audit_signature(artifact, required, expected_certificate=None):
    required = required or expected_certificate is not None
    verification = subprocess.run(["codesign", "--verify", "--strict", str(artifact)], capture_output=True, text=True)
    if verification.returncode:
        require(not required, "XCFramework signature is missing or invalid")
        return {"status": "not verified", "distribution": "unsigned or invalid local/CI candidate"}

    with tempfile.TemporaryDirectory(prefix="tmhud-certificate-") as temporary:
        prefix = Path(temporary) / "certificate"
        # codesign's optional prefix must use '='; a separate argument is treated as another artifact.
        extraction = subprocess.run(["codesign", "--display", f"--extract-certificates={prefix}", str(artifact)], capture_output=True, text=True)
        leaf = Path(str(prefix) + "0")
        if extraction.returncode or not leaf.exists():
            require(not required, "XCFramework requires a certificate-backed signature; ad hoc signing is insufficient")
            return {"status": "not verified", "distribution": "no signing certificate"}
        certificate_digest = sha256(leaf).upper()

    details = subprocess.run(["codesign", "--display", "--verbose=4", str(artifact)], capture_output=True, text=True)
    metadata = details.stdout + details.stderr
    team = re.search(r"^TeamIdentifier=(.+)$", metadata, re.MULTILINE)
    authorities = re.findall(r"^Authority=(.+)$", metadata, re.MULTILINE)
    if expected_certificate is not None:
        require(certificate_digest == expected_certificate, "XCFramework signing certificate does not match the expected SHA-256 fingerprint")
        return {"status": "verified", "trust": "pinned certificate", "certificateSHA256": certificate_digest, "authorities": authorities}

    # The leading equals sign selects an inline requirement, rather than a file path.
    apple_verification = subprocess.run(["codesign", "--verify", "--strict", "--test-requirement", "=anchor apple generic", str(artifact)], capture_output=True, text=True)
    valid = apple_verification.returncode == 0 and team is not None and team.group(1) != "not set" and bool(authorities)
    require(valid or not required, "A self-issued signature requires --expected-certificate-sha256; otherwise an Apple certificate is required")
    if valid:
        return {"status": "verified", "trust": "Apple certificate", "certificateSHA256": certificate_digest, "teamIdentifier": team.group(1), "authorities": authorities}
    return {"status": "not verified", "certificateSHA256": certificate_digest, "distribution": "certificate has not been pinned"}


def certificate_fingerprint(value):
    digest = value.replace(":", "").upper()
    if not re.fullmatch(r"[0-9A-F]{64}", digest):
        raise argparse.ArgumentTypeError("Expected a 64-digit SHA-256 certificate fingerprint")
    return digest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--require-signature", action="store_true", help="Require a valid Apple or explicitly pinned certificate signature")
    parser.add_argument("--expected-certificate-sha256", type=certificate_fingerprint, help="Require this exact signing certificate, including self-issued identities")
    args = parser.parse_args()
    artifact = args.artifact.resolve()
    entries = plistlib.loads((artifact / "Info.plist").read_bytes())["AvailableLibraries"]
    variants = {(entry["SupportedPlatform"], entry.get("SupportedPlatformVariant", "device")) for entry in entries}
    require(len(entries) == 4 and variants == EXPECTED_VARIANTS, "Expected iOS/tvOS device and simulator slices")
    version = (ROOT / "VERSION").read_text().strip()
    report = {"version": version, "result": "passed", "signature": audit_signature(artifact, args.require_signature, args.expected_certificate_sha256), "slices": [audit_slice(artifact, entry, version) for entry in entries], "sourceSHA256": {str(path.relative_to(ROOT)): sha256(path) for path in sorted((ROOT / "Sources/TMProgressHudUIKit").glob("*.swift"))}}
    archive = artifact.with_suffix(".xcframework.zip")
    if archive.exists():
        report["archiveSHA256"] = sha256(archive)
    output = json.dumps(report, indent=2) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output)
    print(output)


if __name__ == "__main__":
    main()
