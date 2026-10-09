// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Camsil",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CamsilCore", targets: ["CamsilCore"]),
        .executable(name: "Camsil", targets: ["Camsil"]),
    ],
    targets: [
        // SwiftPM does not compile .metal files on the command line. MetalContext compiles them at run time.
        .target(
            name: "CamsilCore",
            resources: [.copy("Shaders")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Camsil",
            dependencies: ["CamsilCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CamsilCoreTests",
            dependencies: ["CamsilCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
