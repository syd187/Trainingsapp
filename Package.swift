// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Trainingsapp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "PersonalSportCore", targets: ["PersonalSportCore"])
    ],
    targets: [
        .target(name: "PersonalSportCore"),
        .testTarget(
            name: "PersonalSportCoreTests",
            dependencies: ["PersonalSportCore"]
        )
    ]
)
