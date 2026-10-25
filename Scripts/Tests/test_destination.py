import importlib.util
import unittest
import json
import subprocess
from unittest.mock import patch
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("destination", Path(__file__).parents[1] / "test-destination.py")
DESTINATION = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DESTINATION)


class DestinationTests(unittest.TestCase):
    def setUp(self):
        self.devices = {"com.apple.CoreSimulator.SimRuntime.iOS-27-0": [{"name": "Dedicated", "udid": "owned", "isAvailable": True}]}

    def test_explicit_dedicated_name_resolves(self):
        self.assertEqual(DESTINATION.resolve("platform=iOS Simulator,name=Dedicated", self.devices), "owned")

    def test_physical_device_is_not_selected(self):
        with self.assertRaisesRegex(ValueError, "iOS Simulator"):
            DESTINATION.resolve("platform=iOS,id=physical", self.devices)

    def test_ambiguous_name_requires_explicit_id(self):
        self.devices["com.apple.CoreSimulator.SimRuntime.iOS-26-5"] = [{"name": "Dedicated", "udid": "second"}]
        with self.assertRaisesRegex(ValueError, "ambiguous"):
            DESTINATION.resolve("platform=iOS Simulator,name=Dedicated", self.devices)

    def test_tv_destination_does_not_select_iphone_with_same_name(self):
        self.devices["com.apple.CoreSimulator.SimRuntime.tvOS-27-0"] = [{"name": "Dedicated", "udid": "tv"}]
        self.assertEqual(DESTINATION.resolve("platform=tvOS Simulator,name=Dedicated", self.devices), "tv")
        self.assertEqual(DESTINATION.resolve("platform=iOS Simulator,name=Dedicated", self.devices), "owned")

    def test_unavailable_destination_fails(self):
        with self.assertRaisesRegex(ValueError, "unavailable"):
            DESTINATION.resolve("platform=iOS Simulator,id=missing", self.devices)


class SimulatorDiscoveryTests(unittest.TestCase):
    def test_hung_simulator_service_fails_without_claiming_tests_ran(self):
        with patch.object(DESTINATION.subprocess, "check_output", side_effect=subprocess.TimeoutExpired("simctl", 30)):
            with self.assertRaisesRegex(RuntimeError, "no tests executed"):
                DESTINATION.available_devices()

    def test_discovery_retains_device_availability_data(self):
        devices = {"com.apple.CoreSimulator.SimRuntime.iOS-26-5": [{"name": "Dedicated", "udid": "owned", "isAvailable": False}]}
        with patch.object(DESTINATION.subprocess, "check_output", return_value=json.dumps({"devices": devices}).encode()):
            self.assertEqual(DESTINATION.available_devices(), devices)
