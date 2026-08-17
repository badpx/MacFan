// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacFan",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacFan",
            path: "Sources/MacFan",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
