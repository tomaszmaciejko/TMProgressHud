#!/usr/bin/env python3
"""Build a distribution consumer and report only verified installation and runtime facts."""
import argparse
from dataclasses import dataclass
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
POD_NAME = "TMProgressHudUIKit"
RECEIPT_ATTEMPTS = 80
RECEIPT_INTERVAL_SECONDS = 0.25
EXPECTED_MODE_COUNT = 6


@dataclass(frozen=True)
class RemoteSource:
    url: str
    revision: str

    def as_dict(self):
        return {"url": self.url, "revision": self.revision}


@dataclass(frozen=True)
class ConsumerPlan:
    root: Path
    kind: str
    platform: str
    minimum_os: str
    work: Path
    sdk: str
    destination: str
    artifact: Path | None
    remote_source: RemoteSource | None
    simulator_id: str | None

    @property
    def project(self):
        return self.work / "Consumer.xcodeproj"

    @property
    def app(self):
        return self.work / "Build/Build/Products" / f"Release-{self.sdk}/TMProgressHudConsumer.app"


def argument_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=["spm", "cocoapods", "binary", "carthage"])
    parser.add_argument("--platform", choices=["ios", "tvos"], required=True)
    parser.add_argument("--artifact", type=Path)
    parser.add_argument("--source-url", help="Resolve an SPM or CocoaPods dependency from this Git URL")
    parser.add_argument("--revision", help="Exact 40-character Git commit for --source-url")
    parser.add_argument("--simulator-id", help="Also launch the consumer on an explicitly selected dedicated simulator")
    return parser


def make_plan(args, root=ROOT):
    if args.kind in ["binary", "carthage"] and args.artifact is None:
        raise ValueError("Binary consumers require --artifact")
    remote_source = None
    if args.source_url or args.revision:
        if args.kind not in ["spm", "cocoapods"] or not args.source_url or not re.fullmatch(r"[0-9a-f]{40}", args.revision or ""):
            raise ValueError("Remote SPM/CocoaPods checks require --source-url and an exact 40-character --revision")
        remote_source = RemoteSource(args.source_url, args.revision)
    if args.artifact is not None and not (args.artifact / "Info.plist").is_file():
        raise ValueError(f"Missing XCFramework Info.plist: {args.artifact}")
    minimums = json.loads((root / "Scripts/deployment-targets.json").read_text())
    suffix = "-remote" if remote_source else ""
    work = root / ".build/Consumers" / f"{args.kind}-{args.platform}{suffix}"
    sdk, destination = ("iphoneos", "generic/platform=iOS") if args.platform == "ios" else ("appletvos", "generic/platform=tvOS")
    if args.simulator_id:
        simulator_platform = "iOS Simulator" if args.platform == "ios" else "tvOS Simulator"
        destination = f"platform={simulator_platform},id={args.simulator_id}"
        sdk = "iphonesimulator" if args.platform == "ios" else "appletvsimulator"
    return ConsumerPlan(root, args.kind, args.platform, minimums[args.platform], work, sdk, destination,
                        args.artifact, remote_source, args.simulator_id)


def validate_destination(plan):
    if plan.simulator_id:
        subprocess.run(["python3", str(plan.root / "Scripts/test-destination.py"), plan.destination], check=True)


def ruby_string(value):
    return "'" + str(value).replace("\\", "\\\\").replace("'", "\\'") + "'"


def prepare_consumer(plan):
    spec = importlib.util.spec_from_file_location("project_factory", plan.root / "Scripts/project-factory.py")
    factory = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(factory)
    source = plan.remote_source.as_dict() if plan.remote_source else None
    factory.generate(plan.project, plan.kind, plan.platform, plan.artifact, source)
    if plan.kind != "cocoapods":
        return ["-project", str(plan.project)]
    source = f":path => {ruby_string(plan.root)}"
    if plan.remote_source:
        source = f":git => {ruby_string(plan.remote_source.url)}, :commit => {ruby_string(plan.remote_source.revision)}"
    (plan.work / "Podfile").write_text(
        f"platform :{plan.platform}, '{plan.minimum_os}'\nuse_frameworks!\nproject 'Consumer.xcodeproj'\n"
        f"target 'TMProgressHudConsumer' do\n  pod '{POD_NAME}', {source}\nend\n"
    )
    subprocess.run(["pod", "install", "--project-directory=" + str(plan.work)], check=True)
    return ["-workspace", str(plan.work / "Consumer.xcworkspace")]


def build_consumer(plan, container):
    if plan.simulator_id:
        subprocess.run(["xcrun", "simctl", "bootstatus", plan.simulator_id, "-b"], check=True)
    scm_options = ["-scmProvider", "system"] if plan.remote_source and plan.kind == "spm" else []
    subprocess.run([
        "xcodebuild", *container, *scm_options, "-scheme", "TMProgressHudConsumer", "-configuration", "Release",
        "-sdk", plan.sdk, "-destination", plan.destination, "-derivedDataPath", str(plan.work / "Build"),
        "CODE_SIGNING_ALLOWED=NO", "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES", "SWIFT_SUPPRESS_WARNINGS=NO", "build",
    ], check=True)


def verify_resources_and_minimum(plan):
    resources = [
        ("PrivacyInfo.xcprivacy", plan.root / "Sources/TMProgressHudUIKit/PrivacyInfo.xcprivacy"),
        ("TMProgressHud-LICENSE.txt", plan.root / "LICENSE"),
        ("TMProgressHud-NOTICES.txt", plan.root / "THIRD_PARTY_NOTICES.md"),
    ]
    for filename, canonical in resources:
        matches = list(plan.app.rglob(filename))
        if not matches or any(path.read_bytes() != canonical.read_bytes() for path in matches):
            raise ValueError(f"Missing or stale resource in {plan.kind}/{plan.platform}: {filename}")
    metadata = subprocess.check_output(["xcrun", "vtool", "-show-build", str(plan.app / "TMProgressHudConsumer")], text=True)
    minimum = re.search(r"\bminos\s+(\S+)", metadata)
    if minimum is None or minimum.group(1) != plan.minimum_os:
        raise ValueError(f"Consumer binary does not carry the expected minimum OS {plan.minimum_os}")


def verify_remote_source(plan):
    if plan.remote_source is None:
        return
    if plan.kind == "spm":
        checkouts = list((plan.work / "Build/SourcePackages/checkouts").glob("*/Sources/TMProgressHudUIKit"))
        if len(checkouts) != 1:
            raise ValueError("Expected exactly one resolved remote package checkout")
        checkout = checkouts[0].parents[1]
        resolved = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
        if resolved != plan.remote_source.revision:
            raise ValueError("SwiftPM checkout differs from the requested commit")
    else:
        checkout = plan.work / "Pods" / POD_NAME
        if f":commit: {plan.remote_source.revision}" not in (plan.work / "Podfile.lock").read_text():
            raise ValueError("CocoaPods lockfile does not record the requested commit")
    for source in (plan.root / "Sources/TMProgressHudUIKit").glob("*.swift"):
        if source.read_bytes() != (checkout / "Sources/TMProgressHudUIKit" / source.name).read_bytes():
            raise ValueError(f"Resolved remote source differs from the reviewed source: {source.name}")


def wait_for_receipt(receipt, identifier):
    for _ in range(RECEIPT_ATTEMPTS):
        if receipt.exists():
            try:
                candidate = json.loads(receipt.read_text())
            except json.JSONDecodeError:
                # The consumer may still be writing its receipt.
                candidate = None
            if isinstance(candidate, dict) and candidate.get("identifier") == identifier:
                return candidate
        time.sleep(RECEIPT_INTERVAL_SECONDS)
    raise ValueError("Consumer runtime verification timed out")


def verify_runtime(plan):
    bundle = "com.github.tomaszmaciejko.TMProgressHudConsumer"
    identifier = uuid.uuid4().hex
    subprocess.run(["xcrun", "simctl", "install", plan.simulator_id, str(plan.app)], check=True)
    terminate = ["xcrun", "simctl", "terminate", plan.simulator_id, bundle]
    subprocess.run(terminate, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    subprocess.run(["xcrun", "simctl", "launch", plan.simulator_id, bundle, "--tmhud-check-id", identifier], check=True)
    try:
        container = Path(subprocess.check_output([
            "xcrun", "simctl", "get_app_container", plan.simulator_id, bundle, "data",
        ], text=True).strip())
        outcome = wait_for_receipt(container / "Documents/TMProgressHud-verification.json", identifier)
        if outcome.get("result") != "passed" or outcome.get("modes") != EXPECTED_MODE_COUNT or outcome.get("primaryActions") != EXPECTED_MODE_COUNT:
            raise ValueError(f"Consumer runtime verification failed: {outcome}")
        return {key: outcome[key] for key in ["result", "modes", "primaryActions"]}
    finally:
        subprocess.run(terminate, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)


def verified_report(plan, runtime):
    report = {
        "channel": plan.kind, "platform": plan.platform, "result": "built and resources verified",
        "minimumOS": plan.minimum_os, "remoteInstallation": "not requested; local source or supplied artifact",
    }
    if plan.remote_source:
        report["remoteInstallation"] = {**plan.remote_source.as_dict(), "selection": "Git commit"}
    if runtime is not None:
        report["runtimeVerification"] = runtime
    return report


def execute(plan):
    # A failed new execution must not leave the previous success report looking current.
    report_path = plan.work / "validation.json"
    report_path.unlink(missing_ok=True)
    validate_destination(plan)
    container = prepare_consumer(plan)
    build_consumer(plan, container)
    verify_resources_and_minimum(plan)
    verify_remote_source(plan)
    runtime = verify_runtime(plan) if plan.simulator_id else None
    report = verified_report(plan, runtime)
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    return report


def main(argv=None):
    parser = argument_parser()
    args = parser.parse_args(argv)
    try:
        plan = make_plan(args)
    except ValueError as error:
        parser.error(str(error))
    print(json.dumps(execute(plan)))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(f"Distribution check failed: {error}") from error
