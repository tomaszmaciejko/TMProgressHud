import contextlib
import io
from pathlib import Path
import runpy
import sys
import unittest
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / "check-distribution.py"


class DistributionCLIContractTests(unittest.TestCase):
    def run_cli(self, arguments, expected_code):
        output, errors = io.StringIO(), io.StringIO()
        with mock.patch.object(sys, "argv", [str(SCRIPT), *arguments]), \
                mock.patch("subprocess.run", side_effect=AssertionError("Validation must precede execution")), \
                mock.patch("subprocess.check_output", side_effect=AssertionError("Validation must precede execution")), \
                mock.patch.object(Path, "mkdir", side_effect=AssertionError("Validation must precede writes")), \
                contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
            with self.assertRaises(SystemExit) as result:
                runpy.run_path(str(SCRIPT), run_name="__main__")
        self.assertEqual(result.exception.code, expected_code)
        return output.getvalue(), errors.getvalue()

    def test_help_does_not_build_or_generate(self):
        output, errors = self.run_cli(["--help"], 0)
        self.assertIn("--source-url", output)
        self.assertIn("--simulator-id", output)
        self.assertEqual(errors, "")

    def test_binary_channels_require_an_artifact_before_execution(self):
        for channel, platform in (("binary", "ios"), ("carthage", "tvos")):
            with self.subTest(channel=channel):
                _, errors = self.run_cli([channel, "--platform", platform], 2)
                self.assertIn("Binary consumers require --artifact", errors)

    def test_invalid_remote_requests_fail_before_execution(self):
        url = "https://example.com/library.git"
        cases = [
            ["spm", "--platform", "ios", "--source-url", url],
            ["spm", "--platform", "ios", "--source-url", url, "--revision", "invalid"],
            ["binary", "--platform", "ios", "--artifact", "unused.xcframework", "--source-url", url, "--revision", "a" * 40],
        ]
        for arguments in cases:
            with self.subTest(arguments=arguments):
                _, errors = self.run_cli(arguments, 2)
                self.assertIn("Remote SPM/CocoaPods checks require", errors)
