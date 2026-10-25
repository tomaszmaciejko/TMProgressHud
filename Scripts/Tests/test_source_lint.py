"""Check that parser-based safety rules reject unsafe constructs."""
import subprocess
import tempfile
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parents[2] / ".build/Tools/source-lint"


class SourceLintTests(unittest.TestCase):
    def run_lint(self, source):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Fixture.swift"
            path.write_text(source)
            return subprocess.run([str(TOOL), str(path)], capture_output=True, text=True)

    def test_checked_cast_is_accepted(self):
        result = self.run_lint("func value(_ x: Any) -> Int? { x as? Int }\n")
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_forced_cast_is_rejected(self):
        result = self.run_lint("func value(_ x: Any) -> Int { x as! Int }\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("checked cast", result.stdout)

    def test_comments_and_strings_do_not_trigger_cast_rule(self):
        result = self.run_lint('let text = "x as! Int" // x as! Int\n')
        self.assertEqual(result.returncode, 0, result.stdout)
