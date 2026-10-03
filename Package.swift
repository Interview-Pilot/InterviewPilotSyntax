// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "InterviewPilotSyntax",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "InterviewPilotSyntax", targets: ["InterviewPilotSyntax"]),
    ],
    targets: [
        .binaryTarget(
    name: "InterviewPilotSyntaxFFI",
    url: "https://github.com/Interview-Pilot/InterviewPilotSyntax/releases/download/apple-v0.2.0/InterviewPilotSyntax.xcframework.zip",
    checksum: "3f657e4c96f44c01363a8568a09072cdc2c9cb51caf47e455c446979d6e41676"
),
        .target(
            name: "InterviewPilotSyntax",
            dependencies: ["InterviewPilotSyntaxFFI"],
            path: "platforms/apple/Sources/InterviewPilotSyntax"
        ),
        .testTarget(
            name: "InterviewPilotSyntaxTests",
            dependencies: ["InterviewPilotSyntax"],
            path: "platforms/apple/Tests/InterviewPilotSyntaxTests"
        ),
    ]
)
