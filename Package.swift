// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TerraformKit",
    platforms: [.macOS(.v10_15)],
    products: [

        .library(
            name: "TerraformKit",
            targets: ["TerraformKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation/", .upToNextMajor(from: "0.9.0")),
    ],
    targets: [

        .target(
            name: "TerraformKit",
            dependencies: [
                "ZIPFoundation"]),
        .testTarget(
            name: "TerraformKitTests",
            dependencies: ["TerraformKit"]),
    ],
    swiftLanguageVersions: [.v5]
)
