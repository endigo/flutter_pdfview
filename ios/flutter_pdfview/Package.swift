// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_pdfview",
    platforms: [
        .iOS("12.0"),
    ],
    products: [
        .library(name: "flutter-pdfview", targets: ["flutter_pdfview"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "flutter_pdfview",
            dependencies: [],
            resources: [],
            cSettings: [
                .headerSearchPath("include/flutter_pdfview")
            ]
        )
    ]
)
