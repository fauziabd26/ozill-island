// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OzillIsland",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "OzillIsland",
            targets: ["OzillIsland"]
        ),
        .executable(
            name: "OzillValidator",
            targets: ["OzillValidator"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/batoulapps/adhan-swift.git", exact: "1.5.0")
    ],
    targets: [
        .target(
            name: "OzillIslandCore",
            dependencies: [
                .product(name: "Adhan", package: "adhan-swift")
            ],
            path: "Sources/OzillIslandCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "OzillIsland",
            dependencies: [
                "OzillIslandCore"
            ],
            path: "Sources/OzillIslandApp"
        ),
        .executableTarget(
            name: "OzillValidator",
            dependencies: [
                "OzillIslandCore"
            ],
            path: "Sources/OzillValidator"
        )
    ]
)
