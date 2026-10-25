"""Check the configured safety boundary, including regex syntax filtering."""
import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class SwiftLintConfigurationTests(unittest.TestCase):
    def lint(self, source):
        result = subprocess.run(
            [str(ROOT / "Scripts/lint.sh"), "--use-stdin", "--quiet", "--reporter", "json"],
            input=source, capture_output=True, text=True, cwd=ROOT,
        )
        self.assertIn(result.returncode, [0, 2], result.stderr)
        findings = json.loads(result.stdout)
        self.assertEqual(result.returncode == 0, len(findings) == 0, result.stderr)
        return {finding["rule_id"] for finding in findings}

    def test_checked_cast_is_accepted(self):
        self.assertEqual(self.lint("func value(_ x: Any) -> Int? { x as? Int }\n"), set())

    def test_forced_cast_is_rejected(self):
        self.assertIn("force_cast", self.lint("func value(_ x: Any) -> Int { x as! Int }\n"))

    def test_comments_and_strings_do_not_trigger_safety_rules(self):
        self.assertEqual(self.lint('let text = "x as! Int; fatalError(); @unchecked; nonisolated(unsafe)"\n// @preconcurrency import Foundation; preconditionFailure()\n'), set())

    def test_concurrency_escapes_are_rejected(self):
        for source in ["final class Value: @unchecked Sendable {}\n", "@preconcurrency import Foundation\n", "nonisolated(unsafe) var value = 0\n"]:
            with self.subTest(source=source):
                self.assertIn("unsafe_concurrency", self.lint(source))

    def test_runtime_traps_are_rejected(self):
        for function in ["fatalError", "preconditionFailure"]:
            with self.subTest(function=function):
                self.assertIn("forbidden_runtime_traps", self.lint(f'func value() {{ {function}("Unsupported") }}\n'))

    def test_force_try_unwrap_and_implicit_optional_are_rejected(self):
        for rule, source in [
            ("force_try", "func value() throws {}\ntry! value()\n"),
            ("force_unwrapping", "let value: Int? = nil\nlet result = value!\n"),
            ("implicitly_unwrapped_optional", "var value: Int!\n"),
        ]:
            with self.subTest(rule=rule):
                self.assertIn(rule, self.lint(source))

    def test_size_and_complexity_limits_are_active(self):
        for rule, source in [
            ("file_length", "let value = 0\n" * 351),
            ("function_body_length", "func value() {\n" + "    let _ = 0\n" * 42 + "}\n"),
            ("cyclomatic_complexity", "func value(_ condition: Bool) {\n" + "    if condition {}\n" * 10 + "}\n"),
        ]:
            with self.subTest(rule=rule):
                self.assertIn(rule, self.lint(source))
