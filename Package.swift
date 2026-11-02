// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cyclo",
    platforms: [.macOS("26.0")],
    targets: [
        .target(name: "CycloCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "Cyclo", dependencies: ["CycloCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "cyclo-checks", dependencies: ["CycloCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)

