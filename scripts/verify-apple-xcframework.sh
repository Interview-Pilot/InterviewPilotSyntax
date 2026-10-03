#!/usr/bin/env bash

set -euo pipefail

XCFRAMEWORK_PATH="${1:?Usage: verify-apple-xcframework.sh <path>}"
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

ios_device = [
    item for item in libraries
    if item.get("SupportedPlatform") == "ios" and "SupportedPlatformVariant" not in item
]
ios_simulator = [
    item for item in libraries
    if item.get("SupportedPlatform") == "ios"
    and item.get("SupportedPlatformVariant") == "simulator"
]
macos = [item for item in libraries if item.get("SupportedPlatform") == "macos"]

if not ios_device or "arm64" not in set().union(
    *(set(item.get("SupportedArchitectures", [])) for item in ios_device)
):
    raise SystemExit("Missing arm64 iOS device slice")

ios_simulator_architectures = set().union(
    *(set(item.get("SupportedArchitectures", [])) for item in ios_simulator)
)
if not {"arm64", "x86_64"}.issubset(ios_simulator_architectures):
    raise SystemExit(
        f"Incomplete iOS simulator slice: {sorted(ios_simulator_architectures)}"
    )

macos_architectures = set().union(
    *(set(item.get("SupportedArchitectures", [])) for item in macos)
)
if not {"arm64", "x86_64"}.issubset(macos_architectures):
    raise SystemExit(f"Incomplete macOS slice: {sorted(macos_architectures)}")

print("Verified iOS device, iOS simulator, and universal macOS slices")
PY
