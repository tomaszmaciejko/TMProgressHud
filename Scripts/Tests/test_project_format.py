import importlib.util
import json
from unittest import mock
from pathlib import Path
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
from project_format import build_settings, compiled_swift_sources, read_project

spec = importlib.util.spec_from_file_location("project_factory", SCRIPTS / "project-factory.py")
factory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(factory)


class ProjectFormatTests(unittest.TestCase):
    def test_host_registry_tracks_additions_and_removals(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sources = root / "Sources/TMProgressHudUIKit"
            tests = root / "Tests/TMProgressHudUIKitTests"
            sources.mkdir(parents=True)
            tests.mkdir(parents=True)
            (sources / "First.swift").write_text("struct First {}")
            (tests / "Layout").mkdir()
            (tests / "Layout/ExampleTests.swift").write_text("struct ExampleTests {}")
            bundle = root / "Host.xcodeproj"
            bundle.mkdir()
            original = read_project(SCRIPTS.parent / "Tests/Host/TMProgressHudTestHost.xcodeproj")
            (bundle / "project.xcproj").write_text(json.dumps(original))
            with mock.patch.object(factory, "ROOT", root):
                factory.generate(bundle, "test-sources")
                (sources / "First.swift").unlink()
                (sources / "Layout").mkdir()
                (sources / "Layout/Second.swift").write_text("struct Second {}")
                factory.generate(bundle, "test-sources")
            result = read_project(bundle)
            self.assertEqual(compiled_swift_sources(result, bundle.parent, "TMProgressHudUIKit"), {(sources / "Layout/Second.swift").resolve()})
            self.assertEqual(compiled_swift_sources(result, bundle.parent, "TMProgressHudUIKitTests"), {(tests / "Layout/ExampleTests.swift").resolve()})
            self.assertEqual({key: value for key, value in result.items() if key != "files"}, {key: value for key, value in original.items() if key != "files"})

    def test_shipping_registry_discovers_nested_sources_without_adding_a_test_target(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            nested = root / "Sources/TMProgressHudUIKit/Layout"
            nested.mkdir(parents=True)
            source = nested / "Layout.swift"
            source.write_text("struct Layout {}")
            bundle = root / "Library.xcodeproj"
            bundle.mkdir()
            original = read_project(SCRIPTS.parent / "TMProgressHud.xcodeproj")
            (bundle / "project.xcproj").write_text(json.dumps(original))
            with mock.patch.object(factory, "ROOT", root):
                factory.generate(bundle, "test-sources")
            result = read_project(bundle)
            self.assertEqual(compiled_swift_sources(result, bundle.parent, "TMProgressHudUIKit"), {source.resolve()})
            self.assertEqual(result["targets"], original["targets"])
            library = next(entry for entry in result["files"] if entry.get("name") == "TMProgressHudUIKit")
            self.assertEqual([entry["name"] for entry in library["children"]], ["Layout"])

    def test_host_registry_is_idempotent_and_preserves_reference_resources(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "Host.xcodeproj"
            bundle.mkdir()
            original = read_project(SCRIPTS.parent / "Tests/Host/TMProgressHudTestHost.xcodeproj")
            def unmanaged(entries):
                result = []
                for entry in entries:
                    if entry.get("kind") == "group":
                        result.extend(unmanaged(entry.get("children", [])))
                    elif not entry.get("path", "").endswith(".swift"):
                        result.append(entry)
                return result
            (bundle / "project.xcproj").write_text(json.dumps(original))
            factory.generate(bundle, "test-sources")
            first = (bundle / "project.xcproj").read_bytes()
            factory.generate(bundle, "test-sources")
            self.assertEqual((bundle / "project.xcproj").read_bytes(), first)
            self.assertEqual(unmanaged(read_project(bundle)["files"]), unmanaged(original["files"]))

    def test_host_registry_rejects_mixed_source_membership_without_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "Host.xcodeproj"
            bundle.mkdir()
            project = read_project(SCRIPTS.parent / "Tests/Host/TMProgressHudTestHost.xcodeproj")
            project["files"].append({"path": "Shared.swift", "target-membership": ["TMProgressHudUIKit/compile-sources", "Other/compile-sources"]})
            path = bundle / "project.xcproj"
            path.write_text(json.dumps(project))
            before = path.read_bytes()
            with self.assertRaisesRegex(ValueError, "mixed Swift source"):
                factory.generate(bundle, "test-sources")
            self.assertEqual(path.read_bytes(), before)


    def test_framework_defaults_to_json_and_keeps_scheme_target_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "Library.xcodeproj"
            factory.generate(bundle, "framework")
            project = read_project(bundle)
            self.assertFalse((bundle / "project.pbxproj").exists())
            sources = compiled_swift_sources(project, bundle.parent, "TMProgressHudUIKit")
            self.assertEqual(sources, {p.resolve() for p in (SCRIPTS.parent / "Sources/TMProgressHudUIKit").rglob("*.swift")})
            scheme = (bundle / "xcshareddata/xcschemes/TMProgressHudUIKit.xcscheme").read_text()
            self.assertIn('BlueprintIdentifier="' + project["targets"][0]["id"] + '"', scheme)

    def test_disposable_consumers_and_explicit_framework_support_legacy_tools(self):
        with tempfile.TemporaryDirectory() as directory:
            for kind in ["spm", "cocoapods", "binary", "carthage", "framework"]:
                bundle = Path(directory) / (kind + ".xcodeproj")
                factory.generate(bundle, kind, artifact=Path(directory) / "Library.xcframework", project_format="plist")
                self.assertTrue((bundle / "project.pbxproj").is_file())
                self.assertFalse((bundle / "project.xcproj").exists())

    def test_configuration_specific_settings_preserve_sdk_conditions(self):
        objects = {"configs": {"buildConfigurations": ["debug", "release"]},
                   "debug": {"name": "Debug", "buildSettings": {"SDKROOT": "iphoneos", "FLAGS[sdk=appletv*]": ["debug"], "ONLY_DEBUG": "YES"}},
                   "release": {"name": "Release", "buildSettings": {"SDKROOT": "iphoneos", "FLAGS[sdk=appletv*]": ["release"]}}}
        self.assertEqual(build_settings(objects, "configs"), {
            "SDKROOT": "iphoneos", "FLAGS[sdk=appletv*][config=Debug]": ["debug"],
            "FLAGS[sdk=appletv*][config=Release]": ["release"], "ONLY_DEBUG[config=Debug]": "YES"})

    def test_json5_comments_and_trailing_commas_are_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory)
            (bundle / "project.xcproj").write_text('{ // Xcode edit\n "targets": [], "files": [], }')
            self.assertEqual(read_project(bundle), {"targets": [], "files": []})

    def test_competing_project_formats_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory)
            (bundle / "project.xcproj").write_text('{}')
            (bundle / "project.pbxproj").write_text('{}')
            with self.assertRaisesRegex(ValueError, "legacy"):
                read_project(bundle)

    def test_duplicate_and_missing_memberships_cannot_hide_coverage_gaps(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Source.swift").write_text('import Foundation\n')
            project = {"targets": [{"name": "Library"}], "files": [{"path": "Source.swift", "target-membership": ["Library/compile-sources", {"build-phase": "Library/compile-sources"}]}]}
            with self.assertRaisesRegex(ValueError, "Duplicate"):
                compiled_swift_sources(project, root, "Library")
            project["files"][0]["target-membership"].pop()
            (root / "Source.swift").unlink()
            with self.assertRaisesRegex(ValueError, "Missing"):
                compiled_swift_sources(project, root, "Library")

    def test_nested_groups_and_project_relative_paths_resolve_membership(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Source.swift").write_text('import Foundation\n')
            project = {"targets": [{"name": "Library"}], "files": [{"kind": "group", "path": "Group", "children": [{"path": "<PROJECT>/Source.swift", "target-membership": ["Library/compile-sources"]}]}]}
            self.assertEqual(compiled_swift_sources(project, root, "Library"), {(root / "Source.swift").resolve()})
            project["files"][0]["kind"] = "folder"
            with self.assertRaisesRegex(ValueError, "Unsupported"):
                compiled_swift_sources(project, root, "Library")

    def test_changing_generated_format_keeps_only_one_active_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "Library.xcodeproj"
            factory.generate(bundle, "framework", project_format="plist")
            factory.generate(bundle, "framework")
            self.assertFalse((bundle / "project.pbxproj").exists())
            self.assertEqual(len(read_project(bundle)["targets"]), 1)
            factory.generate(bundle, "framework", project_format="plist")
            self.assertFalse((bundle / "project.xcproj").exists())
