// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenSpotlightVerification",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "OpenLauncher", targets: ["OpenLauncher"]),
    ],
    targets: [
        .executableTarget(
            name: "OpenLauncher",
            path: "OpenLauncher",
            exclude: ["Resources"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "OpenLauncherTests",
            dependencies: ["OpenLauncher"],
            path: "OpenLauncherTests"
        ),
    ]
)
