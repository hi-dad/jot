// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QuickNote",
    platforms: [.macOS(.v13)],
    // The app is built by build.sh; this keeps `swift build` and editors working too.
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .executableTarget(name: "QuickNote", dependencies: [.product(name: "Sparkle", package: "Sparkle")],
                          path: "Sources/QuickNote")
    ]
)
