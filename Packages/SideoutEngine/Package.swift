// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SideoutEngine",
    // watchOS(.v8) matches the watch app target's floor (Series 3
    // support) — see the comment in project.yml. The package itself is
    // plain Swift/Foundation with no OS-version-gated API, so this only
    // affects which targets are allowed to link it.
    platforms: [.iOS(.v17), .watchOS(.v8)],
    products: [
        .library(name: "SideoutEngine", targets: ["SideoutEngine"])
    ],
    targets: [
        .target(name: "SideoutEngine"),
        .testTarget(name: "SideoutEngineTests", dependencies: ["SideoutEngine"])
    ]
)
