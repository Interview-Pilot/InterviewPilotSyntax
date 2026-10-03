# InterviewPilotSyntax

Shared, offline syntax highlighting for Interview Pilot clients. The Rust core
uses the pinned Interview Pilot Syntect fork and exposes bounded, ownership-safe
FFI. Platform adapters render the immutable line-and-run response natively.

The supported clients are iOS, macOS, and Android. Each platform adapter uses
the same immutable line-and-run payload while rendering with its native UI
framework.

## Safety contract

- Highlighting is presentation-only. The caller always retains the original
  source and must render it unchanged if highlighting is unavailable.
- Inputs larger than 64 KiB, invalid UTF-8, and invalid appearance values are
  rejected before parsing.
- Rust allocations returned over FFI have one matching release function.
- The engine performs no network, file-system, process, or dynamic-code access.
- Unsupported language identifiers return plain code rather than an error.

## Apple development

```sh
./scripts/build-apple-xcframework.sh
swift build --disable-sandbox --build-tests \
  --triple arm64-apple-ios17.0-simulator \
  --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"
swift test --disable-sandbox
```

The build script produces
`platforms/apple/InterviewPilotSyntax.xcframework` with iOS device, iOS
simulator, and universal macOS slices. The iOS slices are static. The macOS
slice is dynamic so it can coexist with other Rust-backed libraries without
linking duplicate Rust runtime symbols into the app. `Package.swift` uses the
local artifact for development and testing.

## Apple release

An `apple-v*` tag runs the verified build and publishes the zipped XCFramework as
a GitHub release asset. The workflow then creates an immutable `spm/<tag>`
branch whose `Package.swift` references that asset by its computed checksum.
Clients should pin the resulting Swift package commit rather than the mutable
development branch.

## Android development

The Android adapter is a standard AAR containing a small Kotlin API and one
Rust JNI library for each ABI supported by Interview Pilot. Build and verify it
with:

```sh
./scripts/build-android-aar.sh
```

The script uses Android NDK `26.3.11579264`, `cargo-ndk 4.1.2`, API level 24,
and produces `dist/android/InterviewPilotSyntax.aar`. The AAR contains
`arm64-v8a`, `armeabi-v7a`, `x86`, and `x86_64` libraries. `JNI_OnLoad`
registers a single private native method; callers use the Kotlin API and never
depend on the native ABI directly.

Android validates the payload version, colors, style bits, and exact source
reconstruction before exposing highlighted runs. Library loading, JNI, parsing,
or validation failures return `null`, so the app renders its original source as
plain code without affecting answer content.

## Android release

An `android-v*` tag runs the Rust tests, rebuilds and verifies every ABI, runs
the Android adapter tests, and publishes the AAR plus its SHA-256 checksum as a
GitHub release. App clients should vendor that immutable release artifact and
record its checksum.

## Dependency ownership

Syntect is pinned to `Interview-Pilot/syntect` commit
`e4670846ecf16d8832db6c43d531bec466214e27`, corresponding to upstream
`v5.3.0`. Updates require an explicit dependency review, corpus test run, and
new Apple binary build. CI and iOS releases use Rust `1.98.1` so published
artifacts remain reproducible without forcing local developers onto that
toolchain.
