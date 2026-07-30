// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Taskflow",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "TaskflowCore",
            path: "Sources/TaskflowCore"
        ),
        .executableTarget(
            name: "Taskflow",
            dependencies: ["TaskflowCore"],
            path: "Sources/Taskflow"
        ),
        .executableTarget(
            name: "TaskflowVerify",
            dependencies: ["TaskflowCore"],
            path: "Sources/TaskflowVerify",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
