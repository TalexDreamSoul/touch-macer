// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TouchMacer",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TouchMacer", targets: ["TouchMacer"])
    ],
    targets: [
        .executableTarget(
            name: "TouchMacer",
            path: "Sources/TouchMacer",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("EventKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(
            name: "TouchMacerTests",
            dependencies: ["TouchMacer"],
            path: "Tests/TouchMacerTests"
        )
    ]
)
