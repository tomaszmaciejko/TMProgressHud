"""Regression checks for certificate pinning and unsigned distribution policy."""
import argparse
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("framework_audit", ROOT / "Scripts/audit-xcframework.py")
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)
CERTIFICATE = b"certificate fixture"
FINGERPRINT = hashlib.sha256(CERTIFICATE).hexdigest().upper()


class SignaturePolicyTests(unittest.TestCase):
    def run_verification(self, required=True, expected=FINGERPRINT, valid=True, certificate=True, apple=False):
        def command(arguments, **options):
            status = 0
            stderr = "Authority=TMProgressHud\nTeamIdentifier=not set\n"
            extraction = next((value for value in arguments if value.startswith("--extract-certificates=")), None)
            if extraction:
                if certificate:
                    prefix = extraction.split("=", 1)[1]
                    Path(prefix + "0").write_bytes(CERTIFICATE)
            elif "--test-requirement" in arguments:
                status = 0 if apple else 1
            elif "--verify" in arguments:
                status = 0 if valid else 1
            elif apple:
                stderr = "Authority=Apple Development\nTeamIdentifier=EXAMPLE123\n"
            return subprocess.CompletedProcess(arguments, status, "", stderr)

        with patch.object(AUDIT.subprocess, "run", side_effect=command) as commands:
            result = AUDIT.audit_signature(Path("Example.xcframework"), required, expected)
        return result, commands

    def test_matching_self_issued_certificate_is_verified(self):
        result, commands = self.run_verification()
        self.assertEqual(result["status"], "verified")
        self.assertEqual(result["certificateSHA256"], FINGERPRINT)
        self.assertEqual(result["trust"], "pinned certificate")
        self.assertFalse(any("--test-requirement" in call.args[0] for call in commands.call_args_list))

    def test_different_certificate_is_rejected_even_without_required_flag(self):
        with self.assertRaisesRegex(SystemExit, "does not match"):
            self.run_verification(required=False, expected="0" * 64)

    def test_tampered_signature_is_rejected_even_with_matching_certificate(self):
        with self.assertRaisesRegex(SystemExit, "missing or invalid"):
            self.run_verification(valid=False)

    def test_ad_hoc_signature_cannot_satisfy_certificate_requirement(self):
        with self.assertRaisesRegex(SystemExit, "ad hoc"):
            self.run_verification(certificate=False)

    def test_unpinned_self_issued_certificate_is_rejected(self):
        with self.assertRaisesRegex(SystemExit, "self-issued signature requires"):
            self.run_verification(expected=None)

    def test_unsigned_ci_candidate_is_not_reported_as_verified(self):
        result, _ = self.run_verification(required=False, expected=None, valid=False)
        self.assertEqual(result["status"], "not verified")

    def test_apple_certificate_remains_supported_without_pin(self):
        result, commands = self.run_verification(expected=None, apple=True)
        self.assertEqual(result["teamIdentifier"], "EXAMPLE123")
        self.assertTrue(any("=anchor apple generic" in call.args[0] for call in commands.call_args_list))

    def test_fingerprint_accepts_xcode_colons_and_rejects_malformed_values(self):
        self.assertEqual(AUDIT.certificate_fingerprint(":".join(["ab"] * 32)), "AB" * 32)
        for value in ["", "f" * 63, "g" * 64]:
            with self.subTest(value=value), self.assertRaises(argparse.ArgumentTypeError):
                AUDIT.certificate_fingerprint(value)


if __name__ == "__main__":
    unittest.main()
