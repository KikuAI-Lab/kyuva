// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Kyuva",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Kyuva", targets: ["Kyuva"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Kyuva",
            path: "Kyuva",
            exclude: ["Resources/Info.plist"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
