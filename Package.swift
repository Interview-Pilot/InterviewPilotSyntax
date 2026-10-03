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
    url: "https://github.com/Interview-Pilot/InterviewPilotSyntax/releases/download/ios-v0.1.0/InterviewPilotSyntax.xcframework.zip",
    checksum: "7e85b48a51a6bfe6abc0acdfabb8bb6a53744930f5affecc2017905608703918"
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
