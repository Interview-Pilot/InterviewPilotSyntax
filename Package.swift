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
    url: "https://github.com/Interview-Pilot/InterviewPilotSyntax/releases/download/apple-v0.2.1/InterviewPilotSyntax.xcframework.zip",
    checksum: "f1dab8588b4eef43a675fe9b60c5a145fa9d8ba59d77f63234eb6e390c4ef0e9"
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
