// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenuGauge",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MenuGauge",
            path: "Sources/MenuGauge",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(name: "MenuGaugeTests", dependencies: ["MenuGauge"])
    ]
)
