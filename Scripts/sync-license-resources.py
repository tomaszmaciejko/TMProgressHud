#!/usr/bin/env python3
"""Copy or verify canonical license notices included by every distribution channel."""
import argparse
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--write", action="store_true")
args = parser.parse_args()
for source, filename in [("LICENSE", "TMProgressHud-LICENSE.txt"), ("THIRD_PARTY_NOTICES.md", "TMProgressHud-NOTICES.txt")]:
    destination = root / "Sources/TMProgressHudUIKit/Resources" / filename
    expected = (root / source).read_bytes()
    if args.write:
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(expected)
    elif not destination.exists() or destination.read_bytes() != expected:
        raise SystemExit(f"Stale packaged notice: {destination.relative_to(root)}; run sync-license-resources.py --write")
print("Canonical license and attribution resources verified.")
