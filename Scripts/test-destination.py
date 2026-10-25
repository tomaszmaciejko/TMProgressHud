#!/usr/bin/env python3
"""Resolve an explicit, unambiguous iOS/tvOS simulator destination without opening UI."""
import argparse
import json
import subprocess

SIMULATOR_DISCOVERY_TIMEOUT_SECONDS = 30


def resolve(destination, devices):
    fields = dict(part.strip().split("=", 1) for part in destination.split(","))
    runtime_prefixes = {"iOS Simulator": ".iOS-", "tvOS Simulator": ".tvOS-"}
    prefix = runtime_prefixes.get(fields.get("platform"))
    if prefix is None:
        raise ValueError("Hosted tests require an explicit iOS Simulator or tvOS Simulator destination")
    candidates = [device for runtime, values in devices.items() if prefix in runtime for device in values if device.get("isAvailable", True)]
    if "id" in fields:
        candidates = [device for device in candidates if device["udid"] == fields["id"]]
    elif "name" in fields:
        candidates = [device for device in candidates if device["name"] == fields["name"]]
    else:
        raise ValueError("Choose an explicit simulator id or unique name")
    if len(candidates) != 1:
        raise ValueError("Destination is unavailable or ambiguous; provide an available simulator id")
    return candidates[0]["udid"]


def available_devices():
    try:
        output = subprocess.check_output(
            ["xcrun", "simctl", "list", "devices", "available", "-j"],
            timeout=SIMULATOR_DISCOVERY_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired as error:
        raise RuntimeError("Simulator service did not respond within 30 seconds; no tests executed") from error
    return json.loads(output)["devices"]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination")
    args = parser.parse_args()
    try:
        print(resolve(args.destination, available_devices()))
    except (ValueError, RuntimeError) as error:
        parser.exit(1, f"Invalid test destination: {error}\n")
