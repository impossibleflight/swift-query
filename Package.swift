// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "swift-query",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftQuery",
            targets: ["SwiftQuery"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.8.1"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.4.3"),
        .package(url: "https://github.com/swiftlang/swift-syntax", "600.0.0"..<"603.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftQuery",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                "SwiftQueryMacros"
            ]
        ),
        .macro(
            name: "SwiftQueryMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "SwiftQueryTests",
            dependencies: [
                "SwiftQuery",
                "SwiftQueryMacros",
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
