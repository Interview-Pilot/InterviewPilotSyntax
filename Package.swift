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
    url: "https://github.com/Interview-Pilot/InterviewPilotSyntax/releases/download/apple-v0.2.2/InterviewPilotSyntax.xcframework.zip",
    checksum: "2dfa3dddd5c17844529d9538f68ad1a81d841df2a2a0d3763f2ce1cb88bf1895"
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
