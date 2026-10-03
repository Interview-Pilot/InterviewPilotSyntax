#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
JNI_LIBS_DIR="$ROOT_DIR/platforms/android/src/main/jniLibs"
OUTPUT_DIR="$ROOT_DIR/dist/android"
NDK_HOME=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}
SDK_ROOT=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}

if ! command -v cargo-ndk >/dev/null 2>&1; then
    echo "cargo-ndk is required (verified version: 4.1.2)" >&2
    exit 1
fi

if [ -z "$NDK_HOME" ]; then
    if [ -d "$SDK_ROOT/ndk/26.3.11579264" ]; then
        NDK_HOME="$SDK_ROOT/ndk/26.3.11579264"
    else
        echo "Android NDK 26.3.11579264 was not found" >&2
        exit 1
    fi
fi

if [ ! -d "$SDK_ROOT" ]; then
    echo "Android SDK was not found: $SDK_ROOT" >&2
    exit 1
fi
export ANDROID_HOME="$SDK_ROOT"

rm -rf "$JNI_LIBS_DIR" "$ROOT_DIR/platforms/android/build" "$OUTPUT_DIR"
mkdir -p "$JNI_LIBS_DIR" "$OUTPUT_DIR"

ANDROID_NDK_HOME="$NDK_HOME" cargo ndk \
    --platform 24 \
    --target arm64-v8a \
    --target armeabi-v7a \
    --target x86 \
    --target x86_64 \
    --output-dir "$JNI_LIBS_DIR" \
    build --manifest-path "$ROOT_DIR/Cargo.toml" \
    --locked --release --package interview-pilot-syntax-android

"$ROOT_DIR/gradlew" --no-daemon --project-dir "$ROOT_DIR" \
    :android:testReleaseUnitTest :android:lintRelease :android:assembleRelease

cp "$ROOT_DIR/platforms/android/build/outputs/aar/InterviewPilotSyntax-release.aar" \
    "$OUTPUT_DIR/InterviewPilotSyntax.aar"

"$ROOT_DIR/scripts/verify-android-aar.sh" "$OUTPUT_DIR/InterviewPilotSyntax.aar"
