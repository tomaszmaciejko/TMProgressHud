#!/usr/bin/env python3
"""Fail closed on uncovered production lines exported by xccov.

Input is a normalized mapping of relative source paths to executable line counts.
The runner exports every production file from the result bundle before this gate.
"""

import argparse
import hashlib
import json
from pathlib import Path


def validate_snapshot(root, payload):
    sources = {str(p.relative_to(root)) for p in (root / "Sources").rglob("*.swift")}
    if payload.get("schema") != 1 or set(payload.get("sourceDigests", {})) != sources:
        raise ValueError("Missing coverage source fingerprint")
    for path, digest in payload["sourceDigests"].items():
        if hashlib.sha256((root / path).read_bytes()).hexdigest() != digest:
            raise ValueError(f"Stale coverage source: {path}")
    return payload["counts"]


def check(root, report, exceptions, unmapped=()):
    sources = {str(p.relative_to(root)) for p in (root / "Sources").rglob("*.swift")}
    if set(report) != sources:
        raise ValueError(f"Coverage source set mismatch: {sources ^ set(report)}")
    exemptions = {}
    for entry in exceptions:
        path = entry["file"]
        if path not in sources or not entry.get("reason") or not entry.get("decision"):
            raise ValueError("Unreviewed or unknown coverage exception")
        if hashlib.sha256((root / path).read_bytes()).hexdigest() != entry["sha256"]:
            raise ValueError(f"Stale exception: {path}")
        key = (path, entry["line"])
        if key in exemptions:
            raise ValueError(f"Duplicate exception: {key}")
        exemptions[key] = entry
    unmapped_files = {}
    for entry in unmapped:
        path = entry["file"]
        if path not in sources or not entry.get("reason") or not entry.get("decision") or path in unmapped_files:
            raise ValueError("Invalid non-instrumentable declaration record")
        if hashlib.sha256((root / path).read_bytes()).hexdigest() != entry["sha256"]:
            raise ValueError(f"Stale declaration record: {path}")
        if report[path]:
            raise ValueError(f"Declaration file now has executable lines: {path}")
        unmapped_files[path] = entry
    missing = []
    total = covered = excluded = 0
    for path, counts in report.items():
        if not isinstance(counts, dict) or (not counts and path not in unmapped_files):
            raise ValueError(f"Missing executable lines: {path}")
        file_lines = (root / path).read_text().splitlines()
        for number, count in counts.items():
            line = int(number)
            if line < 1 or line > len(file_lines) or type(count) is not int or count < 0 or str(line) != number:
                raise ValueError(f"Invalid coverage count: {path}:{number}")
            total += 1
            if count > 0:
                covered += 1
            elif (path, line) in exemptions:
                excluded += 1
            else:
                missing.append(f"{path}:{line}")
        for key in exemptions:
            if key[0] == path and str(key[1]) not in counts:
                raise ValueError(f"Nonexecutable exception: {key}")
    print(f"Production coverage: raw {covered}/{total}; adjusted {covered}/{total-excluded}; exceptions {excluded}")
    if missing:
        raise ValueError("Uncovered production lines:\n" + "\n".join(missing))
    if not total or total == excluded:
        raise ValueError("No tested production executable lines")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    try:
        check(root, validate_snapshot(root, json.loads(args.report.read_text())), json.loads((root / "Scripts/coverage-exceptions.json").read_text()), json.loads((root / "Scripts/coverage-unmapped.json").read_text()))
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.exit(1, f"Coverage gate failed: {error}\n")


if __name__ == "__main__":
    main()
