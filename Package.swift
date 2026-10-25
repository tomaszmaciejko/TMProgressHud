// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TMProgressHud",
    platforms: [.iOS(.v17), .tvOS(.v15)],
    products: [.library(name: "TMProgressHudUIKit", targets: ["TMProgressHudUIKit"])],
    targets: [
        .target(name: "TMProgressHudUIKit", resources: [.copy("PrivacyInfo.xcprivacy"), .copy("Resources")]),
        .target(
            name: "MBProgressHUDReference",
            path: "Reference/MBProgressHUD",
            exclude: ["LICENSE", "Package.swift", "PrivacyInfo.xcprivacy", "README.md", "provenance.json"],
            sources: ["MBProgressHUD.m"],
            publicHeadersPath: "."
        ),
        .testTarget(
            name: "TMProgressHudUIKitTests",
            dependencies: ["TMProgressHudUIKit", "MBProgressHUDReference"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
