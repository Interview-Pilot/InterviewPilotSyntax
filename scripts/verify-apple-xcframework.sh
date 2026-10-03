#!/usr/bin/env bash

set -euo pipefail

XCFRAMEWORK_PATH="${1:?Usage: verify-apple-xcframework.sh <path>}"
INFO_PLIST="$XCFRAMEWORK_PATH/Info.plist"

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Missing XCFramework Info.plist: $INFO_PLIST" >&2
  exit 1
fi

LIBRARY_PATHS="$(python3 - "$INFO_PLIST" <<'PY'
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

if len(macos) != 1:
    raise SystemExit(f"Expected one universal macOS slice, found {len(macos)}")

print(
    ios_device[0]["LibraryIdentifier"],
    ios_simulator[0]["LibraryIdentifier"],
    macos[0]["LibraryIdentifier"],
)
PY
)"
read -r IOS_DEVICE_LIBRARY_PATH IOS_SIMULATOR_LIBRARY_PATH MACOS_LIBRARY_PATH <<< "$LIBRARY_PATHS"

for library_path in "$IOS_DEVICE_LIBRARY_PATH" "$IOS_SIMULATOR_LIBRARY_PATH"; do
  binary="$XCFRAMEWORK_PATH/$library_path/InterviewPilotSyntaxFFI.framework/InterviewPilotSyntaxFFI"
  if ! file "$binary" | grep -q "current ar archive"; then
    echo "iOS slice is not a static framework: $binary" >&2
    exit 1
  fi
done

MACOS_BINARY="$XCFRAMEWORK_PATH/$MACOS_LIBRARY_PATH/InterviewPilotSyntaxFFI.framework/InterviewPilotSyntaxFFI"
if ! file "$MACOS_BINARY" | grep -q "dynamically linked shared library"; then
  echo "macOS slice is not a dynamic framework: $MACOS_BINARY" >&2
  exit 1
fi

EXPECTED_INSTALL_NAME="@rpath/InterviewPilotSyntaxFFI.framework/Versions/A/InterviewPilotSyntaxFFI"
if ! otool -D "$MACOS_BINARY" | tail -n +2 | grep -Fxq "$EXPECTED_INSTALL_NAME"; then
  echo "Unexpected macOS framework install name: $MACOS_BINARY" >&2
  exit 1
fi

echo "Verified static iOS slices and a universal dynamic macOS slice"
