#!/usr/bin/env python3
"""Export all production xccov file counts to the strict coverage gate."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("result", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
report = json.loads(subprocess.check_output(["xcrun", "xccov", "view", "--report", "--json", str(args.result)]))
production = [target for target in report["targets"] if target["name"] in {"TMProgressHudUIKit", "TMProgressHudUIKit.framework"}]
if len(production) != 1 or production[0]["executableLines"] == 0:
    raise SystemExit("Missing or empty production coverage target")
counts = {}
for file in production[0]["files"]:
    path = Path(file["path"])
    relative = str(path.resolve().relative_to(root))
    if not relative.startswith("Sources/"):
        raise SystemExit(f"Unexpected production source: {relative}")
    archive = json.loads(subprocess.check_output(["xcrun", "xccov", "view", "--archive", "--file", str(path), "--json", str(args.result)]))
    counts[relative] = {str(row["line"]): row["executionCount"] for row in archive[str(path)] if row["isExecutable"]}
for entry in json.loads((root / "Scripts/coverage-unmapped.json").read_text()):
    if entry["file"] not in counts:
        counts[entry["file"]] = {}
args.output.parent.mkdir(parents=True, exist_ok=True)
digests = {}
run_start = args.result.stat().st_birthtime
for source in (root / "Sources").rglob("*.swift"):
    if source.stat().st_mtime > run_start:
        raise SystemExit(f"Source changed after test run began: {source}")
    digests[str(source.relative_to(root))] = hashlib.sha256(source.read_bytes()).hexdigest()
payload = {"schema": 1, "resultBundle": str(args.result.resolve()), "sourceDigests": digests, "counts": counts}
args.output.write_text(json.dumps(payload, indent=2) + "\n")
