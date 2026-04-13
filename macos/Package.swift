// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Panini",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Panini", targets: ["Panini"])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", exact: "2.31.3")
    ],
    targets: [
        .target(
            name: "Panini",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm")
            ],
            path: "Panini",
            exclude: [
                "App/PaniniApp.swift",
                "Resources"
            ]
        ),
        .testTarget(
            name: "PaniniTests",
            dependencies: ["Panini"],
            path: "PaniniTests"
        )
    ]
)
