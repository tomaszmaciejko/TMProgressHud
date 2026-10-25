"""Regression checks for reference/inventory integrity; these are tooling tests."""

import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("reference", ROOT / "Scripts/verify-reference.py")
REFERENCE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REFERENCE)


class ReferenceIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.reference = self.root / "reference"
        shutil.copytree(ROOT / "Reference/MBProgressHUD", self.reference)
        self.inventory = self.root / "inventory.json"
        shutil.copyfile(ROOT / "Tests/ReferenceAPI/api-inventory.json", self.inventory)

    def change_inventory(self, mutation):
        data = json.loads(self.inventory.read_text())
        mutation(data)
        self.inventory.write_text(json.dumps(data))

    def test_original_snapshot_and_complete_inventory_pass(self):
        REFERENCE.verify(self.reference, self.inventory)

    def test_modified_implementation_is_rejected(self):
        implementation = self.reference / "MBProgressHUD.m"
        implementation.write_text(implementation.read_text() + "\n// edited\n")
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            REFERENCE.verify(self.reference, self.inventory)

    def test_missing_reference_file_is_rejected(self):
        (self.reference / "LICENSE").unlink()
        with self.assertRaises(FileNotFoundError):
            REFERENCE.verify(self.reference, self.inventory)

    def test_unclassified_declaration_is_rejected(self):
        self.change_inventory(lambda data: data["declarations"].pop())
        with self.assertRaisesRegex(ValueError, "Unclassified or obsolete"):
            REFERENCE.verify(self.reference, self.inventory)

    def test_duplicate_classification_is_rejected(self):
        self.change_inventory(lambda data: data["declarations"].append(data["declarations"][0]))
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            REFERENCE.verify(self.reference, self.inventory)

    def test_incomplete_classification_is_rejected(self):
        self.change_inventory(lambda data: data["declarations"][0].update(contract=""))
        with self.assertRaisesRegex(ValueError, "Incomplete classification"):
            REFERENCE.verify(self.reference, self.inventory)

    def test_mismatched_revision_is_rejected(self):
        self.change_inventory(lambda data: data.update(revision="0" * 40))
        with self.assertRaisesRegex(ValueError, "revisions differ"):
            REFERENCE.verify(self.reference, self.inventory)

    def test_stale_source_location_is_rejected(self):
        self.change_inventory(lambda data: data["declarations"][0].update(header_line=1))
        with self.assertRaisesRegex(ValueError, "Source location or kind differs"):
            REFERENCE.verify(self.reference, self.inventory)

    def test_missing_checksum_entry_is_rejected(self):
        manifest = self.reference / "provenance.json"
        data = json.loads(manifest.read_text())
        data["files"].pop("LICENSE")
        manifest.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "Reference file set"):
            REFERENCE.verify(self.reference, self.inventory)


if __name__ == "__main__":
    unittest.main()
