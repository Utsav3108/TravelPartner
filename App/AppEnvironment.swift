import Foundation

/// Environment flags and runtime configuration parameters.
public struct AppEnvironment: Sendable {
    public enum Mode: String, Sendable {
        case development = "Development"
        case test = "Test"
        case production = "Production"
    }
    
    public let mode: Mode
    public let appVersion: String
    public let buildNumber: String
    public let isMockSearchActive: Bool
    public let isCoreMLActive: Bool
    
    public init(
        mode: Mode = .development,
        appVersion: String = "1.0.0",
        buildNumber: String = "1",
        isMockSearchActive: Bool = true,
        isCoreMLActive: Bool = true
    ) {
        self.mode = mode
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.isMockSearchActive = isMockSearchActive
        self.isCoreMLActive = isCoreMLActive
    }
    
    public static let current = AppEnvironment(
        mode: .development,
        isMockSearchActive: AppConfiguration.shared.searchMode == .mock,
        isCoreMLActive: AppConfiguration.shared.mlMode == .hybridCoreML
    )
}
