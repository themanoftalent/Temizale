// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Temizale",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Temizale", targets: ["Temizale"]),
        .library(name: "TemizCacheCore", targets: ["TemizCacheCore"])
    ],
    targets: [
        .target(name: "TemizCacheCore"),
        .executableTarget(
            name: "Temizale",
            dependencies: ["TemizCacheCore"]
        ),
        .testTarget(
            name: "TemizCacheCoreTests",
            dependencies: ["TemizCacheCore"]
        )
    ]
)
