// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DHVKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DHVKit", targets: ["DHVKit"]),
        .executable(name: "dhv-check", targets: ["dhv-check"]),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
    ],
    targets: [
        .target(name: "DHVKit", dependencies: ["SwiftSoup"]),
        .executableTarget(name: "dhv-check", dependencies: ["DHVKit"]),
        .testTarget(
            name: "DHVKitTests",
            dependencies: ["DHVKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
