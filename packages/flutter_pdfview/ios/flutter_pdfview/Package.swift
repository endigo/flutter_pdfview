// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_pdfview",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "flutter-pdfview", targets: ["flutter_pdfview"])
    ],
    dependencies: [
        // Flutter 3.44+ requires plugins to declare the embedder explicitly
        // instead of inheriting it from the generated Runner package. The path
        // is resolved by the Flutter tool when it assembles the app's package.
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        // Objective-C shim that turns NSException into NSError so the Swift
        // sources can keep the @try/@catch guards the plugin has always had
        // around PDFKit. SwiftPM does not allow mixed-language targets, so it
        // has to be a target of its own. It only uses Foundation, so it does
        // not depend on FlutterFramework.
        .target(
            name: "flutter_pdfview_objc"
        ),
        .target(
            name: "flutter_pdfview",
            dependencies: [
                "flutter_pdfview_objc",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)
