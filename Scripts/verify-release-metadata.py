#!/usr/bin/env python3
"""Check distribution versions and minimum OS metadata without building or resolving dependencies."""
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import tempfile

from project_format import read_project

ROOT = Path(__file__).resolve().parents[1]
PLATFORM_SETTINGS = {"ios": "IPHONEOS_DEPLOYMENT_TARGET", "tvos": "TVOS_DEPLOYMENT_TARGET"}


def require_equal(label, actual, expected):
    if actual != expected:
        raise ValueError(f"{label}: expected {expected!r}, found {actual!r}")


def normalized_platforms(platforms):
    result = {}
    for name, value in platforms.items():
        if not isinstance(value, str) or not re.fullmatch(r"\d+(?:\.\d+){0,2}", value):
            raise ValueError(f"Invalid {name} deployment version: {value!r}")
        components = [int(part) for part in value.split(".")]
        result[name] = tuple(components + [0] * (3 - len(components)))
    return result


def verify_package(package, minimums):
    platforms = package["platforms"]
    actual = {item["platformName"]: item["version"] for item in platforms}
    require_equal("SwiftPM platform count", len(actual), len(platforms))
    require_equal("SwiftPM platforms", normalized_platforms(actual), normalized_platforms(minimums))


def verify_podspec(podspec, version, minimums):
    require_equal("CocoaPods version", podspec["version"], version)
    require_equal("CocoaPods source tag", podspec["source"]["tag"], "v" + version)
    require_equal("CocoaPods platforms", normalized_platforms(podspec["platforms"]), normalized_platforms(minimums))


def verify_settings(label, settings, version, minimums):
    expected = {PLATFORM_SETTINGS[platform]: value for platform, value in minimums.items()}
    if version is not None:
        expected["MARKETING_VERSION"] = version
    for key, value in expected.items():
        require_equal(f"{label}/{key}", settings.get(key), value)
        for conditional, actual in settings.items():
            if conditional.startswith(key + "["):
                require_equal(f"{label}/{conditional}", actual, value)


def verify_project(bundle, version, minimums):
    project = read_project(bundle)
    for target in project["targets"]:
        settings = {**project.get("build-settings", {}), **target.get("build-settings", {})}
        verify_settings(f"{bundle.name}/{target['name']}", settings, version, minimums)


def check(root=ROOT):
    version = (root / "VERSION").read_text().strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", version):
        raise ValueError(f"Invalid release version: {version!r}")
    minimums = json.loads((root / "Scripts/deployment-targets.json").read_text())
    require_equal("Deployment platforms", set(minimums), set(PLATFORM_SETTINGS))
    normalized_platforms(minimums)
    require_equal("Parallel iOS/tvOS minimums", minimums["ios"], minimums["tvos"])
    package = json.loads(subprocess.check_output(["swift", "package", "dump-package"], cwd=root, timeout=60))
    podspec = json.loads(subprocess.check_output(["pod", "ipc", "spec", "TMProgressHudUIKit.podspec"], cwd=root, timeout=60))
    verify_package(package, minimums)
    verify_podspec(podspec, version, minimums)
    verify_project(root / "TMProgressHud.xcodeproj", version, minimums)
    for relative in ("Tests/Host/TMProgressHudTestHost.xcodeproj", "Examples/UIKitDemo/TMProgressHudDemo.xcodeproj"):
        verify_project(root / relative, None, minimums)
    spec = importlib.util.spec_from_file_location("metadata_project_factory", root / "Scripts/project-factory.py")
    factory = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(factory)
    generated_projects = 0
    with tempfile.TemporaryDirectory(prefix="tmhud-metadata-") as directory:
        for kind in ("framework", "spm", "cocoapods", "binary", "carthage"):
            for platform in minimums:
                bundle = Path(directory) / f"{kind}-{platform}.xcodeproj"
                factory.generate(bundle, kind, platform, artifact=Path(directory) / "Library.xcframework", project_format="json")
                verify_project(bundle, version, minimums)
                generated_projects += 1
    return {"version": version, "minimumOS": minimums, "generatedProjects": generated_projects}


if __name__ == "__main__":
    try:
        print(json.dumps(check(), sort_keys=True))
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(f"Release metadata check failed: {error}") from error
