import importlib.util
import json
import plistlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / "check-distribution.py"
spec = importlib.util.spec_from_file_location("distribution_under_test", SCRIPT)
distribution = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = distribution
spec.loader.exec_module(distribution)


class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()
        (self.root / "Scripts").mkdir()
        (self.root / "Scripts/deployment-targets.json").write_text('{"ios":"17.0","tvos":"17.0"}')

    def plan(self, *args):
        parsed = distribution.argument_parser().parse_args(args or ["spm", "--platform", "ios"])
        return distribution.make_plan(parsed, self.root)

    def test_import_does_not_parse_execute_or_write(self):
        fresh = importlib.util.module_from_spec(spec)
        with mock.patch("argparse.ArgumentParser.parse_args", side_effect=AssertionError("parsed on import")), \
                mock.patch("subprocess.run", side_effect=AssertionError("executed on import")), \
                mock.patch.object(Path, "mkdir", side_effect=AssertionError("wrote on import")):
            spec.loader.exec_module(fresh)

    def test_plans_cover_channels_platforms_and_destinations_without_writes(self):
        artifact = self.root / "Library.xcframework"
        artifact.mkdir()
        (artifact / "Info.plist").write_text("fixture")
        for channel in ("spm", "cocoapods", "binary", "carthage"):
            for platform, sdk in (("ios", "iphoneos"), ("tvos", "appletvos")):
                args = [channel, "--platform", platform]
                if channel in ("binary", "carthage"):
                    args += ["--artifact", str(artifact)]
                with self.subTest(channel=channel, platform=platform):
                    plan = self.plan(*args)
                    self.assertEqual(plan.sdk, sdk)
                    self.assertEqual(plan.minimum_os, "17.0")
                    self.assertIsNone(plan.remote_source)
                    simulator = self.plan(*args, "--simulator-id", "chosen-device")
                    self.assertIn("Simulator,id=chosen-device", simulator.destination)
                    self.assertEqual(simulator.sdk, "iphonesimulator" if platform == "ios" else "appletvsimulator")
        self.assertFalse((self.root / ".build").exists())

    def test_missing_artifact_is_rejected_before_generation(self):
        with self.assertRaisesRegex(ValueError, "Missing XCFramework Info.plist"):
            self.plan("binary", "--platform", "ios", "--artifact", str(self.root / "missing.xcframework"))
        self.assertFalse((self.root / ".build").exists())

    def test_remote_plan_and_report_contain_only_requested_facts(self):
        for channel in ("spm", "cocoapods"):
            plan = self.plan(channel, "--platform", "ios", "--source-url", "https://example.com/repo.git", "--revision", "a" * 40)
            self.assertTrue(plan.work.name.endswith("-remote"))
            report = distribution.verified_report(plan, None)
            self.assertEqual(report["remoteInstallation"], {"url": "https://example.com/repo.git", "revision": "a" * 40, "selection": "Git commit"})
            self.assertNotIn("published", json.dumps(report))
            self.assertNotIn("runtimeVerification", report)
        local = distribution.verified_report(self.plan(), None)
        self.assertEqual(local["remoteInstallation"], "not requested; local source or supplied artifact")

    def test_failed_build_removes_stale_success_report(self):
        plan = self.plan()
        plan.work.mkdir(parents=True)
        report_path = plan.work / "validation.json"
        report_path.write_text('{"result":"old success"}')
        with mock.patch.object(distribution, "prepare_consumer", return_value=["-project", "fixture"]), \
                mock.patch.object(distribution, "build_consumer", side_effect=subprocess.CalledProcessError(1, "xcodebuild")), \
                mock.patch.object(distribution, "verify_resources_and_minimum") as verify:
            with self.assertRaises(subprocess.CalledProcessError):
                distribution.execute(plan)
            verify.assert_not_called()
        self.assertFalse(report_path.exists())

    def test_invalid_destination_does_not_generate_a_consumer(self):
        plan = self.plan("spm", "--platform", "ios", "--simulator-id", "wrong-device")
        with mock.patch.object(distribution, "validate_destination", side_effect=ValueError("wrong platform")), \
                mock.patch.object(distribution, "prepare_consumer") as prepare:
            with self.assertRaisesRegex(ValueError, "wrong platform"):
                distribution.execute(plan)
            prepare.assert_not_called()
        self.assertFalse(plan.work.exists())

    def test_success_report_is_written_only_after_all_checks(self):
        plan = self.plan("spm", "--platform", "ios", "--simulator-id", "chosen-device")
        plan.work.mkdir(parents=True)
        runtime = {"result": "passed", "modes": 6, "primaryActions": 6}
        with mock.patch.object(distribution, "validate_destination"), \
                mock.patch.object(distribution, "prepare_consumer", return_value=[]), \
                mock.patch.object(distribution, "build_consumer"), \
                mock.patch.object(distribution, "verify_resources_and_minimum"), \
                mock.patch.object(distribution, "verify_remote_source"), \
                mock.patch.object(distribution, "verify_runtime", return_value=runtime):
            report = distribution.execute(plan)
        self.assertEqual(json.loads((plan.work / "validation.json").read_text()), report)
        self.assertEqual(report["runtimeVerification"], runtime)

    def test_build_preserves_release_safety_and_remote_scm_options(self):
        plan = self.plan("spm", "--platform", "tvos", "--source-url", "https://example.com/repo.git", "--revision", "a" * 40)
        with mock.patch("subprocess.run") as run:
            distribution.build_consumer(plan, ["-project", str(plan.project)])
        command = run.call_args.args[0]
        for pair in (("-configuration", "Release"), ("-scmProvider", "system"), ("-sdk", "appletvos")):
            index = command.index(pair[0])
            self.assertEqual(command[index + 1], pair[1])
        self.assertIn("CODE_SIGNING_ALLOWED=NO", command)
        self.assertIn("SWIFT_TREAT_WARNINGS_AS_ERRORS=YES", command)

    def test_resource_and_minimum_mismatches_fail(self):
        plan = self.plan()
        sources = self.root / "Sources/TMProgressHudUIKit"
        sources.mkdir(parents=True)
        plan.app.mkdir(parents=True)
        fixtures = [("PrivacyInfo.xcprivacy", sources / "PrivacyInfo.xcprivacy"), ("TMProgressHud-LICENSE.txt", self.root / "LICENSE"), ("TMProgressHud-NOTICES.txt", self.root / "THIRD_PARTY_NOTICES.md")]
        for filename, canonical in fixtures:
            canonical.write_text(filename)
            (plan.app / filename).write_text(filename)
        with mock.patch("subprocess.check_output", return_value="minos 17.0"):
            distribution.verify_resources_and_minimum(plan)
            (plan.app / "TMProgressHud-LICENSE.txt").write_text("stale")
            with self.assertRaisesRegex(ValueError, "Missing or stale resource"):
                distribution.verify_resources_and_minimum(plan)
        (plan.app / "TMProgressHud-LICENSE.txt").write_text("TMProgressHud-LICENSE.txt")
        for output in ("minos 15.0", "no minimum"):
            with self.subTest(output=output), mock.patch("subprocess.check_output", return_value=output):
                with self.assertRaisesRegex(ValueError, "expected minimum OS"):
                    distribution.verify_resources_and_minimum(plan)

    def test_resource_bundle_must_be_signable_without_changing_its_contents(self):
        plan = self.plan()
        bundle = plan.app / "Library.bundle"
        bundle.mkdir(parents=True)
        (bundle / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": "test.Library", "CFBundlePackageType": "BNDL",
            "CFBundleName": "Library", "CFBundleVersion": "1",
        }))
        resources = bundle / "Licenses"
        resources.mkdir()
        sources = self.root / "Sources/TMProgressHudUIKit"
        sources.mkdir(parents=True)
        for filename, canonical in (
            ("PrivacyInfo.xcprivacy", sources / "PrivacyInfo.xcprivacy"),
            ("TMProgressHud-LICENSE.txt", self.root / "LICENSE"),
            ("TMProgressHud-NOTICES.txt", self.root / "THIRD_PARTY_NOTICES.md"),
        ):
            canonical.write_text(filename)
            (resources / filename).write_text(filename)
        original = {path.relative_to(bundle): path.read_bytes() for path in bundle.rglob("*") if path.is_file()}
        with mock.patch("subprocess.check_output", return_value="minos 17.0"):
            distribution.verify_resources_and_minimum(plan)
            self.assertEqual(original, {path.relative_to(bundle): path.read_bytes() for path in bundle.rglob("*") if path.is_file()})
            # A top-level Resources directory makes this flat SwiftPM bundle invalid to codesign.
            resources.rename(bundle / "Resources")
            with self.assertRaisesRegex(ValueError, "Resource bundle cannot be signed"):
                distribution.verify_resources_and_minimum(plan)

    def test_runtime_requires_every_scenario_and_always_cleans_up(self):
        plan = self.plan("spm", "--platform", "ios", "--simulator-id", "chosen-device")
        expected = {"result": "passed", "modes": 6, "primaryActions": 6, "safeAreaLayouts": 6, "operationPaths": 3}
        outcomes = [expected]
        for key in expected:
            missing = dict(expected)
            del missing[key]
            wrong = {**expected, key: "failed" if key == "result" else 0}
            outcomes.extend([missing, wrong])
        for outcome in outcomes:
            with self.subTest(outcome=outcome), mock.patch("subprocess.run") as run, \
                    mock.patch("subprocess.check_output", return_value=str(self.root)), \
                    mock.patch.object(distribution, "wait_for_receipt", return_value={"identifier": "current", **outcome}):
                if outcome == expected:
                    self.assertEqual(distribution.verify_runtime(plan), expected)
                else:
                    with self.assertRaisesRegex(ValueError, "runtime verification failed"):
                        distribution.verify_runtime(plan)
                self.assertEqual(run.call_args.args[0], ["xcrun", "simctl", "terminate", "chosen-device", "com.github.tomaszmaciejko.TMProgressHudConsumer"])

    def test_receipt_rejects_stale_identifier_and_partial_json(self):
        receipt = self.root / "receipt.json"
        current = {"identifier": "current", "result": "passed", "modes": 6, "primaryActions": 6}
        for old in ('{"identifier":"old"}', '{"unfinished":'):
            receipt.write_text(old)
            with mock.patch("time.sleep", side_effect=lambda _: receipt.write_text(json.dumps(current))):
                self.assertEqual(distribution.wait_for_receipt(receipt, "current"), current)
        receipt.unlink()
        with mock.patch.object(distribution, "RECEIPT_ATTEMPTS", 2), mock.patch("time.sleep"):
            with self.assertRaisesRegex(ValueError, "timed out"):
                distribution.wait_for_receipt(receipt, "current")

    def test_failed_runtime_still_terminates_its_consumer(self):
        plan = self.plan("spm", "--platform", "ios", "--simulator-id", "chosen-device")
        with mock.patch("subprocess.run") as run, \
                mock.patch("subprocess.check_output", return_value=str(self.root)), \
                mock.patch.object(distribution, "wait_for_receipt", side_effect=ValueError("timed out")):
            with self.assertRaisesRegex(ValueError, "timed out"):
                distribution.verify_runtime(plan)
        self.assertEqual(run.call_args.args[0], ["xcrun", "simctl", "terminate", "chosen-device", "com.github.tomaszmaciejko.TMProgressHudConsumer"])

    def test_remote_revision_and_source_must_match(self):
        plan = self.plan("spm", "--platform", "ios", "--source-url", "https://example.com/repo.git", "--revision", "a" * 40)
        source = self.root / "Sources/TMProgressHudUIKit/View.swift"
        source.parent.mkdir(parents=True)
        source.write_text("reviewed source")
        checkout = plan.work / "Build/SourcePackages/checkouts/Library/Sources/TMProgressHudUIKit"
        checkout.mkdir(parents=True)
        (checkout / "View.swift").write_text("different source")
        with mock.patch("subprocess.check_output", return_value="b" * 40):
            with self.assertRaisesRegex(ValueError, "requested commit"):
                distribution.verify_remote_source(plan)
        with mock.patch("subprocess.check_output", return_value="a" * 40):
            with self.assertRaisesRegex(ValueError, "reviewed source"):
                distribution.verify_remote_source(plan)
            (checkout / "View.swift").write_text("reviewed source")
            distribution.verify_remote_source(plan)
