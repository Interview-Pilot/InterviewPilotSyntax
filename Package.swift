// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "InterviewPilotSyntax",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "InterviewPilotSyntax", targets: ["InterviewPilotSyntax"]),
    ],
    targets: [
        .binaryTarget(
            name: "InterviewPilotSyntaxFFI",
            path: "platforms/apple/InterviewPilotSyntax.xcframework"
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
