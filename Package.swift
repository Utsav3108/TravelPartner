// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TravelPartner",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TravelPartnerCore",
            targets: ["TravelPartnerCore"]
        ),
        .executable(
            name: "TravelPartner",
            targets: ["TravelPartner"]
        )
    ],
    targets: [
        .target(
            name: "TravelPartnerCore",
            path: ".",
            exclude: [
                "App/TravelPartnerApp.swift",
                "App/Info.plist",
                "App/Assets.xcassets",
                "Tests",
                "TravelPartner.xcodeproj",
                "README.md",
                "ARCHITECTURE.md",
                "Configuration/Secrets.example",
                "Configuration/Secrets.example.xcconfig"
            ],
            sources: [
                "App/AppContainer.swift",
                "App/AppEnvironment.swift",
                "Features",
                "Domain",
                "Data",
                "AI",
                "Configuration",
                "Shared"
            ]
        ),
        .executableTarget(
            name: "TravelPartner",
            dependencies: ["TravelPartnerCore"],
            path: "App",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "AppContainer.swift",
                "AppEnvironment.swift"
            ],
            sources: [
                "TravelPartnerApp.swift"
            ]
        ),
        .testTarget(
            name: "TravelPartnerCoreTests",
            dependencies: ["TravelPartnerCore"],
            path: "Tests/TravelPartnerCoreTests"
        )
    ]
)
