#!/usr/bin/env bash

set -euo pipefail

XCFRAMEWORK_PATH="${1:?Usage: verify-ios-xcframework.sh <path>}"
INFO_PLIST="$XCFRAMEWORK_PATH/Info.plist"

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Missing XCFramework Info.plist: $INFO_PLIST" >&2
  exit 1
fi

python3 - "$INFO_PLIST" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    libraries = plistlib.load(handle).get("AvailableLibraries", [])

device = [item for item in libraries if item.get("SupportedPlatform") == "ios" and "SupportedPlatformVariant" not in item]
simulator = [item for item in libraries if item.get("SupportedPlatform") == "ios" and item.get("SupportedPlatformVariant") == "simulator"]

if not device or "arm64" not in set().union(*(set(item.get("SupportedArchitectures", [])) for item in device)):
    raise SystemExit("Missing arm64 iOS device slice")

simulator_architectures = set().union(*(set(item.get("SupportedArchitectures", [])) for item in simulator))
if not {"arm64", "x86_64"}.issubset(simulator_architectures):
    raise SystemExit(f"Incomplete iOS simulator slice: {sorted(simulator_architectures)}")

print("Verified iOS device arm64 and simulator arm64/x86_64 slices")
PY
