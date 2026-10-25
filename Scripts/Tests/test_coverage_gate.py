"""Failure-path tests for the production coverage gate."""
import hashlib
import importlib.util
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("coverage_gate", Path(__file__).parents[1] / "coverage-gate.py")
GATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATE)


class CoverageGateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.source = self.root / "Sources/Library/Value.swift"
        self.source.parent.mkdir(parents=True)
        self.source.write_text("func value() -> Int {\n    1\n}\n")
        self.path = "Sources/Library/Value.swift"

    def test_all_executable_lines_must_be_covered(self):
        GATE.check(self.root, {self.path: {"1": 2, "2": 2, "3": 2}}, [])

    def test_uncovered_line_fails(self):
        with self.assertRaisesRegex(ValueError, "Uncovered production"):
            GATE.check(self.root, {self.path: {"2": 0}}, [])

    def test_missing_source_fails(self):
        with self.assertRaisesRegex(ValueError, "source set mismatch"):
            GATE.check(self.root, {}, [])

    def test_zero_executable_lines_fails(self):
        with self.assertRaisesRegex(ValueError, "Missing executable"):
            GATE.check(self.root, {self.path: {}}, [])

    def test_stale_exception_fails(self):
        exception = {"file": self.path, "line": 2, "reason": "required unreachable init", "decision": "reviewed", "sha256": "old"}
        with self.assertRaisesRegex(ValueError, "Stale exception"):
            GATE.check(self.root, {self.path: {"2": 0}}, [exception])

    def test_precise_reviewed_exception_is_accounted_separately(self):
        exception = {"file": self.path, "line": 2, "reason": "required unreachable init", "decision": "reviewed", "sha256": hashlib.sha256(self.source.read_bytes()).hexdigest()}
        GATE.check(self.root, {self.path: {"1": 1, "2": 0, "3": 1}}, [exception])

    def test_blank_exception_reason_fails(self):
        with self.assertRaisesRegex(ValueError, "Unreviewed"):
            GATE.check(self.root, {self.path: {"2": 0}}, [{"file": self.path}])

    def test_exact_noninstrumentable_declaration_file_is_accounted(self):
        declaration = self.root / "Sources/Library/Contract.swift"
        declaration.write_text("protocol Contract { func act() }\n")
        record = {"file": "Sources/Library/Contract.swift", "reason": "declaration only", "decision": "reviewed", "sha256": hashlib.sha256(declaration.read_bytes()).hexdigest()}
        GATE.check(self.root, {self.path: {"2": 1}, record["file"]: {}}, [], [record])

    def test_changed_noninstrumentable_file_fails_closed(self):
        record = {"file": self.path, "reason": "declaration only", "decision": "reviewed", "sha256": "stale"}
        with self.assertRaisesRegex(ValueError, "Stale declaration"):
            GATE.check(self.root, {self.path: {}}, [], [record])

    def test_stale_report_source_fingerprint_is_rejected(self):
        payload = {"schema": 1, "sourceDigests": {self.path: "old"}, "counts": {self.path: {"2": 1}}}
        with self.assertRaisesRegex(ValueError, "Stale coverage source"):
            GATE.validate_snapshot(self.root, payload)

    def test_missing_report_source_fingerprint_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "fingerprint"):
            GATE.validate_snapshot(self.root, {"schema": 1, "counts": {}})
