// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "SwiftClassDiagram",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "SwiftClassDiagramKit",
            targets: ["SwiftClassDiagramKit"]
        ),
        .executable(name: "swiftclassdiagram", targets: ["swiftclassdiagram"]),
    ],
    dependencies: [
        // AST 解析核心：SourceKitten 封装 SourceKit，提供 Swift 声明结构（类型解析、跨文件继承）
        .package(name: "SourceKitten", url: "https://github.com/jpsim/SourceKitten", from: "0.38.0"),
        .package(name: "Yams", url: "https://github.com/jpsim/Yams.git", from: "6.2.1"),
        .package(name: "swift-argument-parser", url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.1"),
    ],
    targets: [
        .target(
            name: "swiftclassdiagram",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SwiftClassDiagramKit",
                .product(name: "Yams", package: "Yams"),
            ],
            // Web 控制台静态资源随二进制打包，保证 brew install 后 serve 命令可用
            resources: [.copy("WebResources")]
        ),
        .target(
            name: "SwiftClassDiagramKit",
            dependencies: [
                .product(name: "SourceKittenFramework", package: "SourceKitten"),
                .product(name: "Yams", package: "Yams"),
            ]
        ),
        .testTarget(
            name: "SwiftClassDiagramKitTests",
            dependencies: [
                "SwiftClassDiagramKit",
            ]
        ),
    ]
)
