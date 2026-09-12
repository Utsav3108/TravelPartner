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
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", "12.0.0"..<"13.0.0")
    ],
    targets: [
        .target(
            name: "TravelPartnerCore",
            dependencies: [
                .product(name: "FirebaseAI", package: "firebase-ios-sdk")
            ],
            path: ".",
            exclude: [
                "App/TravelPartnerApp.swift",
                "App/Info.plist",
                "App/Assets.xcassets",
                "App/GoogleService-Info.plist",
                "Tests",
                "TravelPartner.xcodeproj",
                "README.md",
                "ARCHITECTURE.md",
                "COREML_ARCHITECTURE.md",
                "GEMINI_AI_ARCHITECTURE.md",
                "Configuration/Secrets.example",
                "Configuration/Secrets.example.xcconfig",
                "Configuration/Secrets.plist"
            ],
            sources: [
                "App/AppContainer.swift",
                "App/AppEnvironment.swift",
                "Features",
                "Domain",
                "Data",
                "AI/Gemini",
                "AI/ML/CoreMLRecommendationEngine.swift",
                "AI/ML/DeterministicRankingEngine.swift",
                "Configuration",
                "Shared"
            ],
            resources: [
                .copy("AI/ML/Models")
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
                "AppEnvironment.swift",
                "GoogleService-Info.plist"
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
