// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "TouchMacer",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "TouchMacer", targets: ["TouchMacer"]),
    .executable(name: "TouchMacerHelper", targets: ["TouchMacerHelper"]),
  ],
  targets: [
    .target(
      name: "TouchMacerHelperProtocol",
      path: "Sources/TouchMacerHelperProtocol"
    ),
    .executableTarget(
      name: "TouchMacerHelper",
      dependencies: ["TouchMacerHelperProtocol"],
      path: "Sources/TouchMacerHelper",
      linkerSettings: [
        .linkedFramework("Security")
      ]
    ),
    .executableTarget(
      name: "TouchMacer",
      dependencies: ["TouchMacerHelperProtocol"],
      path: "Sources/TouchMacer",
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("ApplicationServices"),
        .linkedFramework("EventKit"),
        .linkedFramework("ServiceManagement"),
        .linkedFramework("Security"),
        .linkedFramework("SwiftUI"),
      ]
    ),
    .testTarget(
      name: "TouchMacerTests",
      dependencies: ["TouchMacer"],
      path: "Tests/TouchMacerTests"
    ),
  ]
)
