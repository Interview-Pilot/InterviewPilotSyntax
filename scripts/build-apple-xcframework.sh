#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HEADER_DIR="$ROOT/crates/interview-pilot-syntax-ffi/include"
OUTPUT="$ROOT/platforms/apple/InterviewPilotSyntax.xcframework"
CRATE="interview-pilot-syntax-ffi"
LIBRARY="libinterview_pilot_syntax_ffi.a"
FRAMEWORK_NAME="InterviewPilotSyntaxFFI"
TARGETS=(
  aarch64-apple-ios
  aarch64-apple-ios-sim
  x86_64-apple-ios
  aarch64-apple-darwin
  x86_64-apple-darwin
)

for target in "${TARGETS[@]}"; do
  if ! rustup target list --installed | grep -qx "$target"; then
    echo "Missing Rust target: $target" >&2
    echo "Install it with: rustup target add $target" >&2
    exit 1
  fi
done

echo "Building InterviewPilotSyntax for iOS and macOS..."
for target in "${TARGETS[@]}"; do
  cargo build \
    --locked \
    --release \
    --package "$CRATE" \
    --manifest-path "$ROOT/Cargo.toml" \
    --target "$target"
done

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

lipo -create \
  "$ROOT/target/aarch64-apple-ios-sim/release/$LIBRARY" \
  "$ROOT/target/x86_64-apple-ios/release/$LIBRARY" \
  -output "$TEMP_DIR/ios-simulator.a"

lipo -create \
  "$ROOT/target/aarch64-apple-darwin/release/$LIBRARY" \
  "$ROOT/target/x86_64-apple-darwin/release/$LIBRARY" \
  -output "$TEMP_DIR/macos.a"

create_static_framework() {
  local library_path="$1"
  local output_directory="$2"
  local framework="$output_directory/$FRAMEWORK_NAME.framework"

  mkdir -p "$framework/Headers" "$framework/Modules"
  cp "$library_path" "$framework/$FRAMEWORK_NAME"
  cp "$HEADER_DIR/interview_pilot_syntax.h" "$framework/Headers/"

  cat > "$framework/Modules/module.modulemap" <<'MODULEMAP'
framework module InterviewPilotSyntaxFFI {
    umbrella header "interview_pilot_syntax.h"
    export *
    module * { export * }
}
MODULEMAP

  cat > "$framework/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>InterviewPilotSyntaxFFI</string>
    <key>CFBundleIdentifier</key>
    <string>com.interviewpilot.syntax.ffi</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>InterviewPilotSyntaxFFI</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
PLIST
}

create_static_framework \
  "$ROOT/target/aarch64-apple-ios/release/$LIBRARY" \
  "$TEMP_DIR/ios-device"
create_static_framework \
  "$TEMP_DIR/ios-simulator.a" \
  "$TEMP_DIR/ios-simulator"
create_static_framework \
  "$TEMP_DIR/macos.a" \
  "$TEMP_DIR/macos"

rm -rf "$OUTPUT"
xcodebuild -create-xcframework \
  -framework "$TEMP_DIR/ios-device/$FRAMEWORK_NAME.framework" \
  -framework "$TEMP_DIR/ios-simulator/$FRAMEWORK_NAME.framework" \
  -framework "$TEMP_DIR/macos/$FRAMEWORK_NAME.framework" \
  -output "$OUTPUT"

"$ROOT/scripts/verify-apple-xcframework.sh" "$OUTPUT"
echo "Created $OUTPUT"
