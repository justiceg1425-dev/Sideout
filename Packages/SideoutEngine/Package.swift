// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SideoutEngine",
    platforms: [.iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "SideoutEngine", targets: ["SideoutEngine"])
    ],
    targets: [
        .target(name: "SideoutEngine"),
        .testTarget(name: "SideoutEngineTests", dependencies: ["SideoutEngine"])
    ]
)
