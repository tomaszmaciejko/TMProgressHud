import copy
import importlib.util
from pathlib import Path
import sys
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location("release_metadata", SCRIPTS / "verify-release-metadata.py")
metadata = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metadata)


class ReleaseMetadataTests(unittest.TestCase):
    def setUp(self):
        self.minimums = {"ios": "17.0", "tvos": "17.0"}
        self.package = {"platforms": [{"platformName": name, "version": value} for name, value in self.minimums.items()]}
        self.podspec = {"version": "2.0.0", "platforms": self.minimums.copy(), "source": {"tag": "v2.0.0"}}
        self.settings = {"MARKETING_VERSION": "2.0.0", "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "TVOS_DEPLOYMENT_TARGET": "17.0"}

    def test_matching_metadata_passes(self):
        self.settings["MARKETING_VERSION[config=Release]"] = "2.0.0"
        metadata.verify_package(self.package, self.minimums)
        metadata.verify_podspec(self.podspec, "2.0.0", self.minimums)
        metadata.verify_settings("framework", self.settings, "2.0.0", self.minimums)

    def test_stale_package_minimum_is_rejected(self):
        for platform in self.package["platforms"]:
            with self.subTest(platform=platform["platformName"]):
                broken = copy.deepcopy(self.package)
                next(item for item in broken["platforms"] if item["platformName"] == platform["platformName"])["version"] = "15.0"
                with self.assertRaisesRegex(ValueError, "SwiftPM platforms"):
                    metadata.verify_package(broken, self.minimums)

    def test_missing_extra_and_duplicate_platforms_are_rejected(self):
        for entries in (self.package["platforms"][:1], self.package["platforms"] + [{"platformName": "macos", "version": "14.0"}], self.package["platforms"] * 2):
            with self.subTest(entries=entries), self.assertRaises(ValueError):
                metadata.verify_package({"platforms": entries}, self.minimums)

    def test_stale_pod_version_or_minimum_is_rejected(self):
        for key in ("version", "ios", "tvos"):
            broken = copy.deepcopy(self.podspec)
            if key == "version":
                broken[key] = "1.0.0"
            else:
                broken["platforms"][key] = "15.0"
            with self.subTest(key=key), self.assertRaises(ValueError):
                metadata.verify_podspec(broken, "2.0.0", self.minimums)

    def test_stale_pod_source_tag_is_rejected(self):
        self.podspec["source"]["tag"] = "v1.0.0"
        with self.assertRaisesRegex(ValueError, "source tag"):
            metadata.verify_podspec(self.podspec, "2.0.0", self.minimums)

    def test_stale_or_missing_build_setting_is_rejected(self):
        for key in self.settings:
            for value in (None, "1.0"):
                broken = self.settings.copy()
                if value is None:
                    del broken[key]
                else:
                    broken[key] = value
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    metadata.verify_settings("framework", broken, "2.0.0", self.minimums)

    def test_conditional_overrides_cannot_hide_a_stale_value(self):
        for key in self.settings:
            broken = {**self.settings, key + "[config=Release]": "1.0"}
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "config=Release"):
                metadata.verify_settings("framework", broken, "2.0.0", self.minimums)

    def test_equivalent_manifest_version_spellings_are_accepted(self):
        self.podspec["platforms"] = {"ios": "17", "tvos": "17.0.0"}
        metadata.verify_podspec(self.podspec, "2.0.0", self.minimums)

    def test_invalid_deployment_expressions_are_rejected(self):
        for version in ("$(inherited)", "17.0-beta", "", "17.0.0.1", 17):
            with self.subTest(version=version), self.assertRaises(ValueError):
                metadata.normalized_platforms({"ios": version})
