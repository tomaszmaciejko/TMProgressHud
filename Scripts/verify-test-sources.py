#!/usr/bin/env python3
"""Ensure hosted coverage tests compile exactly the current production/test sources."""
from pathlib import Path
from project_format import compiled_swift_sources, read_project

root = Path(__file__).resolve().parents[1]
registries = [
    ("Tests/Host/TMProgressHudTestHost.xcodeproj", [("TMProgressHudUIKit", "Sources/TMProgressHudUIKit"), ("TMProgressHudUIKitTests", "Tests/TMProgressHudUIKitTests")]),
    ("TMProgressHud.xcodeproj", [("TMProgressHudUIKit", "Sources/TMProgressHudUIKit")]),
]
for project_path, targets_to_check in registries:
    bundle = root / project_path
    data = read_project(bundle)
    for name, directory in targets_to_check:
        files = compiled_swift_sources(data, bundle.parent, name)
        expected = {path.resolve() for path in (root / directory).rglob("*.swift")}
        if files != expected:
            raise SystemExit(f"Source registry differs for {project_path}/{name}: {files ^ expected}")
print("Hosted tests and shipping framework compile every registered Swift source exactly once.")
