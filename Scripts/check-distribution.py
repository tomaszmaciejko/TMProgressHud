#!/usr/bin/env python3
"""Build a clean distribution consumer and inspect its notices and optional runtime receipt."""
import argparse
import importlib.util
import json
import re
import subprocess
import time
import uuid
from pathlib import Path

root = Path(__file__).resolve().parents[1]
POD_NAME = "TMProgressHudUIKit"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("kind", choices=["spm", "cocoapods", "binary", "carthage"])
parser.add_argument("--platform", choices=["ios", "tvos"], required=True)
parser.add_argument("--artifact", type=Path)
parser.add_argument("--source-url", help="Resolve an SPM or CocoaPods dependency from this Git URL")
parser.add_argument("--revision", help="Exact 40-character Git commit for --source-url")
parser.add_argument("--simulator-id", help="Also launch the consumer on an explicitly selected dedicated simulator")
args = parser.parse_args()
if args.kind in ["binary", "carthage"] and args.artifact is None:
    parser.error("Binary consumers require --artifact")
remote_source = None
if args.source_url or args.revision:
    if args.kind not in ["spm", "cocoapods"] or not args.source_url or not re.fullmatch(r"[0-9a-f]{40}", args.revision or ""):
        parser.error("Remote SPM/CocoaPods checks require --source-url and an exact 40-character --revision")
    remote_source = {"url": args.source_url, "revision": args.revision}
suffix = "-remote" if remote_source else ""
work = root / ".build/Consumers" / f"{args.kind}-{args.platform}{suffix}"
project = work / "Consumer.xcodeproj"
module_spec = importlib.util.spec_from_file_location("project_factory", root / "Scripts/project-factory.py")
factory = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(factory)
minimum_os = factory.DEPLOYMENT_TARGETS[args.platform]
factory.generate(project, args.kind, args.platform, args.artifact, remote_source)
container = ["-project", str(project)]
if args.kind == "cocoapods":
    def ruby_string(value):
        return "'" + str(value).replace("\\", "\\\\").replace("'", "\\'") + "'"

    source = f":path => {ruby_string(root)}"
    if remote_source:
        source = f":git => {ruby_string(args.source_url)}, :commit => {ruby_string(args.revision)}"
    (work / "Podfile").write_text(
        f"platform :{args.platform}, '{minimum_os}'\nuse_frameworks!\nproject 'Consumer.xcodeproj'\n"
        f"target 'TMProgressHudConsumer' do\n  pod '{POD_NAME}', {source}\nend\n"
    )
    subprocess.run(["pod", "install", "--project-directory=" + str(work)], check=True)
    container = ["-workspace", str(work / "Consumer.xcworkspace")]
sdk, destination = ("iphoneos", "generic/platform=iOS") if args.platform == "ios" else ("appletvos", "generic/platform=tvOS")
if args.simulator_id:
    simulator_platform = "iOS Simulator" if args.platform == "ios" else "tvOS Simulator"
    destination = f"platform={simulator_platform},id={args.simulator_id}"
    subprocess.run(["python3", str(root / "Scripts/test-destination.py"), destination], check=True)
    subprocess.run(["xcrun", "simctl", "bootstatus", args.simulator_id, "-b"], check=True)
    sdk = "iphonesimulator" if args.platform == "ios" else "appletvsimulator"
scm_options = ["-scmProvider", "system"] if remote_source and args.kind == "spm" else []
subprocess.run(["xcodebuild", *container, *scm_options, "-scheme", "TMProgressHudConsumer", "-configuration", "Release", "-sdk", sdk, "-destination", destination, "-derivedDataPath", str(work / "Build"), "CODE_SIGNING_ALLOWED=NO", "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES", "SWIFT_SUPPRESS_WARNINGS=NO", "build"], check=True)
app = work / "Build/Build/Products" / f"Release-{sdk}/TMProgressHudConsumer.app"
for filename, canonical in [("PrivacyInfo.xcprivacy", root / "Sources/TMProgressHudUIKit/PrivacyInfo.xcprivacy"), ("TMProgressHud-LICENSE.txt", root / "LICENSE"), ("TMProgressHud-NOTICES.txt", root / "THIRD_PARTY_NOTICES.md")]:
    matches = list(app.rglob(filename))
    if not matches or any(path.read_bytes() != canonical.read_bytes() for path in matches):
        raise SystemExit(f"Missing or stale resource in {args.kind}/{args.platform}: {filename}")
metadata = subprocess.check_output(["xcrun", "vtool", "-show-build", str(app / "TMProgressHudConsumer")], text=True)
minimum = re.search(r"\bminos\s+(\S+)", metadata)
if minimum is None or minimum.group(1) != minimum_os:
    raise SystemExit(f"Consumer binary does not carry the expected minimum OS {minimum_os}")
report = {"channel": args.kind, "platform": args.platform, "result": "built and resources verified", "minimumOS": minimum.group(1), "remoteInstallation": "not performed; release repository/tag not published"}
if remote_source:
    if args.kind == "spm":
        checkouts = list((work / "Build/SourcePackages/checkouts").glob("*/Sources/TMProgressHudUIKit"))
        if len(checkouts) != 1:
            raise SystemExit("Expected exactly one resolved remote package checkout")
        checkout = checkouts[0].parents[1]
        resolved = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
        if resolved != args.revision:
            raise SystemExit("SwiftPM checkout differs from the requested commit")
    else:
        checkout = work / "Pods" / POD_NAME
        if f":commit: {args.revision}" not in (work / "Podfile.lock").read_text():
            raise SystemExit("CocoaPods lockfile does not record the requested commit")
    for source in (root / "Sources/TMProgressHudUIKit").glob("*.swift"):
        if source.read_bytes() != (checkout / "Sources/TMProgressHudUIKit" / source.name).read_bytes():
            raise SystemExit(f"Resolved remote source differs from the reviewed source: {source.name}")
    report["remoteInstallation"] = {**remote_source, "selection": "Git commit; final release tag not published"}
if args.simulator_id:
    bundle = "com.github.tomaszmaciejko.TMProgressHudConsumer"
    check_id = uuid.uuid4().hex
    subprocess.run(["xcrun", "simctl", "install", args.simulator_id, str(app)], check=True)
    subprocess.run(["xcrun", "simctl", "terminate", args.simulator_id, bundle], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    subprocess.run(["xcrun", "simctl", "launch", args.simulator_id, bundle, "--tmhud-check-id", check_id], check=True)
    container = Path(subprocess.check_output(["xcrun", "simctl", "get_app_container", args.simulator_id, bundle, "data"], text=True).strip())
    receipt = container / "Documents/TMProgressHud-verification.json"
    outcome = None
    for _ in range(80):
        if receipt.exists():
            candidate = json.loads(receipt.read_text())
            if candidate.get("identifier") == check_id:
                outcome = candidate
                break
        time.sleep(0.25)
    subprocess.run(["xcrun", "simctl", "terminate", args.simulator_id, bundle], check=True)
    if outcome is None or outcome.get("result") != "passed" or outcome.get("modes") != 6 or outcome.get("primaryActions") != 6:
        raise SystemExit(f"Consumer runtime verification failed: {outcome}")
    report["runtimeVerification"] = {key: outcome[key] for key in ["result", "modes", "primaryActions"]}
(work / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))
