# InterviewPilotSyntax

Shared, offline syntax highlighting for Interview Pilot clients. The Rust core
uses the pinned Interview Pilot Syntect fork and exposes bounded, ownership-safe
FFI. Platform adapters render the immutable line-and-run response natively.

The supported Apple clients are iOS and macOS. Other platform adapters are
intentionally out of scope until they are implemented and verified separately.

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

## Dependency ownership

Syntect is pinned to `Interview-Pilot/syntect` commit
`e4670846ecf16d8832db6c43d531bec466214e27`, corresponding to upstream
`v5.3.0`. Updates require an explicit dependency review, corpus test run, and
new Apple binary build. CI and iOS releases use Rust `1.98.1` so published
artifacts remain reproducible without forcing local developers onto that
toolchain.
