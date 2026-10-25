#!/usr/bin/env python3
"""Ensure hosted coverage tests compile exactly the current production/test sources."""
import json
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
registries = [
    ("Tests/Host/TMProgressHudTestHost.xcodeproj/project.pbxproj", [("TMProgressHudUIKit", "Sources/TMProgressHudUIKit"), ("TMProgressHudUIKitTests", "Tests/TMProgressHudUIKitTests")]),
    ("TMProgressHud.xcodeproj/project.pbxproj", [("TMProgressHudUIKit", "Sources/TMProgressHudUIKit")]),
]
for project_path, targets_to_check in registries:
    project = root / project_path
    data = json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(project)]))
    objects = data["objects"]
    for name, directory in targets_to_check:
        targets = [item for item in objects.values() if item.get("isa") == "PBXNativeTarget" and item.get("name") == name]
        if len(targets) != 1:
            raise SystemExit(f"Expected exactly one target: {project_path}/{name}")
        files = set()
        for phase_id in targets[0]["buildPhases"]:
            phase = objects[phase_id]
            if phase["isa"] != "PBXSourcesBuildPhase":
                continue
            for build_id in phase["files"]:
                ref = objects[objects[build_id]["fileRef"]]
                path = (project.parent.parent / ref["path"]).resolve()
                if path.suffix == ".swift":
                    if path in files:
                        raise SystemExit(f"Duplicate compiled source: {path}")
                    files.add(path)
        expected = {path.resolve() for path in (root / directory).glob("*.swift")}
        if files != expected:
            raise SystemExit(f"Source registry differs for {project_path}/{name}: {files ^ expected}")
print("Hosted tests and shipping framework compile every registered Swift source exactly once.")
