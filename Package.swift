// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MDApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "MDApp",
            dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")],
            path: "Sources/MDApp",
            resources: [.copy("Resources/Web"), .copy("Resources/K2Dapp.png")]
        ),
    ]
)
