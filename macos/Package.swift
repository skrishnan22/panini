// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Panini",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Panini", targets: ["Panini"])
    ],
    targets: [
        .target(
            name: "Panini",
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
