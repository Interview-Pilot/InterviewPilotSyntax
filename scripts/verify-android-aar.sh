#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
AAR_PATH=${1:-"$ROOT_DIR/dist/android/InterviewPilotSyntax.aar"}
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT INT TERM

if [ ! -f "$AAR_PATH" ]; then
    echo "Android AAR not found: $AAR_PATH" >&2
    exit 1
fi

unzip -q "$AAR_PATH" -d "$WORK_DIR"

test -s "$WORK_DIR/classes.jar"
for ABI in arm64-v8a armeabi-v7a x86 x86_64; do
    LIBRARY="$WORK_DIR/jni/$ABI/libinterview_pilot_syntax_android.so"
    if [ ! -s "$LIBRARY" ]; then
        echo "Missing native library for $ABI" >&2
        exit 1
    fi
done

if find "$WORK_DIR/jni" -type f ! -name 'libinterview_pilot_syntax_android.so' | grep -q .; then
    echo "Unexpected native library in AAR" >&2
    exit 1
fi

jar tf "$WORK_DIR/classes.jar" | grep -q '^com/interviewpilot/syntax/InterviewPilotSyntaxHighlighter.class$'
jar tf "$WORK_DIR/classes.jar" | grep -q '^com/interviewpilot/syntax/NativeBridge.class$'
grep -q 'com.interviewpilot.syntax.NativeBridge' "$WORK_DIR/proguard.txt"

echo "Verified Android AAR: $AAR_PATH"
