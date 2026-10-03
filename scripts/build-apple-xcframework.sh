#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HEADER_DIR="$ROOT/crates/interview-pilot-syntax-ffi/include"
OUTPUT="$ROOT/platforms/apple/InterviewPilotSyntax.xcframework"
CRATE="interview-pilot-syntax-ffi"
STATIC_LIBRARY="libinterview_pilot_syntax_ffi.a"
DYNAMIC_LIBRARY="libinterview_pilot_syntax_ffi.dylib"
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
  "$ROOT/target/aarch64-apple-ios-sim/release/$STATIC_LIBRARY" \
  "$ROOT/target/x86_64-apple-ios/release/$STATIC_LIBRARY" \
  -output "$TEMP_DIR/ios-simulator.a"

write_framework_metadata() {
  local framework="$1"
  local minimum_system_version="${2:-}"
  local plist_directory="${3:-$framework}"

  cat > "$framework/Modules/module.modulemap" <<'MODULEMAP'
framework module InterviewPilotSyntaxFFI {
    umbrella header "interview_pilot_syntax.h"
    export *
    module * { export * }
}
MODULEMAP

  cat > "$plist_directory/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.interviewpilot.syntax.ffi</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
PLIST

  if [[ -n "$minimum_system_version" ]]; then
    cat >> "$plist_directory/Info.plist" <<PLIST
    <key>LSMinimumSystemVersion</key>
    <string>$minimum_system_version</string>
PLIST
  fi

  cat >> "$plist_directory/Info.plist" <<'PLIST'
</dict>
</plist>
PLIST
}

create_static_framework() {
  local library_path="$1"
  local output_directory="$2"
  local framework="$output_directory/$FRAMEWORK_NAME.framework"

  mkdir -p "$framework/Headers" "$framework/Modules"
  cp "$library_path" "$framework/$FRAMEWORK_NAME"
  cp "$HEADER_DIR/interview_pilot_syntax.h" "$framework/Headers/"
  write_framework_metadata "$framework"
}

create_dynamic_macos_framework() {
  local arm64_library="$1"
  local x86_64_library="$2"
  local output_directory="$3"
  local framework="$output_directory/$FRAMEWORK_NAME.framework"
  local version_directory="$framework/Versions/A"
  local binary="$version_directory/$FRAMEWORK_NAME"

  mkdir -p \
    "$version_directory/Headers" \
    "$version_directory/Modules" \
    "$version_directory/Resources"
  ln -s A "$framework/Versions/Current"
  ln -s "Versions/Current/Headers" "$framework/Headers"
  ln -s "Versions/Current/Modules" "$framework/Modules"
  ln -s "Versions/Current/Resources" "$framework/Resources"
  ln -s "Versions/Current/$FRAMEWORK_NAME" "$framework/$FRAMEWORK_NAME"
  lipo -create "$arm64_library" "$x86_64_library" -output "$binary"
  install_name_tool \
    -id "@rpath/$FRAMEWORK_NAME.framework/Versions/A/$FRAMEWORK_NAME" \
    "$binary"
  cp "$HEADER_DIR/interview_pilot_syntax.h" "$version_directory/Headers/"
  write_framework_metadata "$framework" "14.0" "$version_directory/Resources"
}

create_static_framework \
  "$ROOT/target/aarch64-apple-ios/release/$STATIC_LIBRARY" \
  "$TEMP_DIR/ios-device"
create_static_framework \
  "$TEMP_DIR/ios-simulator.a" \
  "$TEMP_DIR/ios-simulator"
create_dynamic_macos_framework \
  "$ROOT/target/aarch64-apple-darwin/release/$DYNAMIC_LIBRARY" \
  "$ROOT/target/x86_64-apple-darwin/release/$DYNAMIC_LIBRARY" \
  "$TEMP_DIR/macos"

rm -rf "$OUTPUT"
xcodebuild -create-xcframework \
  -framework "$TEMP_DIR/ios-device/$FRAMEWORK_NAME.framework" \
  -framework "$TEMP_DIR/ios-simulator/$FRAMEWORK_NAME.framework" \
  -framework "$TEMP_DIR/macos/$FRAMEWORK_NAME.framework" \
  -output "$OUTPUT"

"$ROOT/scripts/verify-apple-xcframework.sh" "$OUTPUT"
echo "Created $OUTPUT"
