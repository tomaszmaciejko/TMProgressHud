#!/usr/bin/env python3
"""Verify the immutable reference snapshot and classified public-header inventory.

This scanner intentionally understands only the pinned header's declaration forms.
It is not a general Objective-C parser and does not prove runtime equivalence.
"""

import argparse
import hashlib
import json
import re
from collections import Counter
from pathlib import Path


def declarations(header):
    """Return public declaration identifiers with stable source line locations."""
    clean = re.sub(r"/\*.*?\*/|//[^\n]*", lambda m: "".join("\n" if c == "\n" else " " for c in m[0]), header, flags=re.S)
    result = []

    def add(identifier, kind, position):
        result.append({"id": identifier, "kind": kind, "header_line": clean.count("\n", 0, position) + 1})

    for match in re.finditer(r"typedef NS_ENUM\(\w+,\s*(\w+)\)\s*\{(.*?)\};", clean, re.S):
        name, body = match.groups()
        add(name, "enum", match.start())
        for item in re.finditer(r"\b" + re.escape(name) + r"\w+\b", body):
            add(item[0], "enum_case", match.start(2) + item.start())
    for match in re.finditer(r"extern\s+\w+\s+const\s+(\w+)\s*;", clean):
        add(match[1], "constant", match.start())
    for match in re.finditer(r"typedef\s+void\s*\(\^(\w+)\)", clean):
        add(match[1], "closure_alias", match.start())
    for match in re.finditer(r"@(interface|protocol)\s+(\w+)\s*[:<].*?@end", clean, re.S):
        kind, owner = match[1], match[2]
        add(owner, "class" if kind == "interface" else "protocol", match.start())
        body = match[0]
        for prop in re.finditer(r"@property[^;]*?\b(\w+)\s*(?:UI_APPEARANCE_SELECTOR)?\s*;", body):
            # The optional macro must not be consumed as the property's name.
            declaration = re.sub(r"\s*UI_APPEARANCE_SELECTOR\s*;", ";", prop[0])
            name = re.search(r"(\w+)\s*;", declaration)[1]
            add(f"{owner}.{name}", "property", match.start() + prop.start())
        for method in re.finditer(r"^[+-]\s*\([^)]*\)\s*(.*?);", body, re.M):
            signature = re.sub(r"NS_SWIFT_NAME\(.*\)", "", method[1])
            labels = re.findall(r"(\w+)\s*:", signature)
            selector = "".join(label + ":" for label in labels) if labels else signature.strip()
            scope = method[0][0]
            add(f"{owner}.{scope}{selector}", "method", match.start() + method.start())
    return sorted(result, key=lambda item: item["id"])


def verify(reference, inventory_path):
    manifest = json.loads((reference / "provenance.json").read_text())
    if not re.fullmatch(r"[0-9a-f]{40}", manifest["revision"]):
        raise ValueError("Reference must name a full immutable commit SHA")
    required_files = {"MBProgressHUD.h", "MBProgressHUD.m", "LICENSE", "Package.swift", "PrivacyInfo.xcprivacy"}
    if set(manifest["files"]) != required_files:
        raise ValueError("Reference file set is incomplete or unexpected")
    for name, expected in manifest["files"].items():
        actual = hashlib.sha256((reference / name).read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f"Reference checksum mismatch: {name}")
    actual = declarations((reference / "MBProgressHUD.h").read_text())
    tracked = json.loads(inventory_path.read_text())
    if tracked["revision"] != manifest["revision"]:
        raise ValueError("Inventory and provenance revisions differ")
    entries = tracked["declarations"]
    identifiers = [item["id"] for item in entries]
    if any(count != 1 for count in Counter(identifiers).values()):
        raise ValueError("Duplicate inventory declaration")
    actual_map = {item["id"]: item for item in actual}
    if set(identifiers) != set(actual_map):
        raise ValueError(f"Unclassified or obsolete declarations: {set(identifiers) ^ set(actual_map)}")
    for item in entries:
        if any(item[key] != actual_map[item["id"]][key] for key in ("kind", "header_line")):
            raise ValueError(f"Source location or kind differs: {item['id']}")
        if item.get("disposition") != "preserve" or not item.get("contract") or not item.get("test_group"):
            raise ValueError(f"Incomplete classification: {item['id']}")
    print(f"Reference verified: {manifest['revision']}; {len(manifest['files'])} checksums; {len(entries)} classified declarations")


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, default=root / "Reference/MBProgressHUD")
    parser.add_argument("--inventory", type=Path, default=root / "Tests/ReferenceAPI/api-inventory.json")
    args = parser.parse_args()
    try:
        verify(args.reference, args.inventory)
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"Reference verification failed: {error}\n")


if __name__ == "__main__":
    main()
