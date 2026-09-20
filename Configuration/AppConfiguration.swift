import Foundation
import FirebaseCore
import FirebaseAppCheck

/// Centralized configuration management for API keys and cloud services.
///
/// **Security Guarantee:**
/// Never hardcodes API keys or private tokens inside source code.
/// Checks runtime sources in hierarchical order:
/// 1. Environment variables (`GEMINI_API_KEY`, `FIREBASE_PROJECT_ID`, etc.)
/// 2. GoogleService-Info.plist (App bundle, module bundle, or filesystem)
/// 3. Optional unversioned `Secrets.plist` or `Secrets.xcconfig`
/// 4. Secure in-app settings configured via the Profile / Settings screen
public final class AppConfiguration: @unchecked Sendable {
    public static let shared = AppConfiguration()
    
    private let userDefaultsKey = "com.travelpartner.gemini_api_key"
    private let searchModeKey = "com.travelpartner.search_mode"
    private let mlModeKey = "com.travelpartner.ml_mode"
    private let geminiModelKey = "com.travelpartner.gemini_model"
    private let lock = NSRecursiveLock()
    
    public enum SearchMode: String, CaseIterable, Sendable {
        case mock = "Simulated Real-Time"
        case production = "Live Web API Providers"
    }
    
    public enum MLEngineMode: String, CaseIterable, Sendable {
        case hybridCoreML = "Core ML On-Device"
        case deterministicMCDA = "Deterministic Utility (MCDA)"
    }
    
    private init() {}
    
    // MARK: - GoogleService-Info.plist Resolution
    
    /// Discovers the GoogleService-Info.plist file across bundle resources and local search paths.
    public var googleServiceInfoPlistFilePath: String? {
        // 1. Bundle.main
        if let mainPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           FileManager.default.fileExists(atPath: mainPath) {
            return mainPath
        }
        
        // 2. Bundle.module (if SPM resources are present)
        #if SWIFT_PACKAGE
        if let modulePath = Bundle.module.path(forResource: "GoogleService-Info", ofType: "plist"),
           FileManager.default.fileExists(atPath: modulePath) {
            return modulePath
        }
        #endif
        
        // 3. Known project filesystem locations
        let currentDir = FileManager.default.currentDirectoryPath
        let searchCandidates = [
            "\(currentDir)/App/GoogleService-Info.plist",
            "\(currentDir)/GoogleService-Info.plist",
            Bundle.main.bundleURL.appendingPathComponent("GoogleService-Info.plist").path,
            Bundle.main.bundleURL.appendingPathComponent("App/GoogleService-Info.plist").path
        ]
        
        for candidate in searchCandidates {
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }
        
        return nil
    }
    
    /// Parsed dictionary from GoogleService-Info.plist if available.
    public var googleServiceInfoDict: [String: Any]? {
        guard let path = googleServiceInfoPlistFilePath,
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }
        return dict
    }
    
    /// Parsed dictionary from local unversioned Secrets.plist if available.
    public var secretsDict: [String: Any]? {
        let candidates = [
            Bundle.main.path(forResource: "Secrets", ofType: "plist"),
            Bundle.main.bundleURL.appendingPathComponent("Secrets.plist").path,
            Bundle.main.bundleURL.appendingPathComponent("Configuration/Secrets.plist").path,
            "/Users/utsav/Documents/Projects/TravelPartner/Configuration/Secrets.plist",
            "\(FileManager.default.currentDirectoryPath)/Configuration/Secrets.plist",
            "\(FileManager.default.currentDirectoryPath)/Secrets.plist"
        ].compactMap { $0 }
        
        for path in candidates {
            if FileManager.default.fileExists(atPath: path),
               let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
                return dict
            }
        }
        return nil
    }
    
    // MARK: - Firebase Credentials & Secrets
    
    /// Active Firebase API Key.
    public var firebaseApiKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["FIREBASE_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        if let plistKey = googleServiceInfoDict?["API_KEY"] as? String, !plistKey.isEmpty {
            return plistKey
        }
        if let secretKey = secretsDict?["FIREBASE_API_KEY"] as? String, !secretKey.isEmpty {
            return secretKey
        }
        return nil
    }
    
    /// Active Firebase Project ID.
    public var firebaseProjectId: String? {
        if let envVal = ProcessInfo.processInfo.environment["FIREBASE_PROJECT_ID"], !envVal.isEmpty {
            return envVal
        }
        if let plistVal = googleServiceInfoDict?["PROJECT_ID"] as? String, !plistVal.isEmpty {
            return plistVal
        }
        if let secretVal = secretsDict?["FIREBASE_PROJECT_ID"] as? String, !secretVal.isEmpty {
            return secretVal
        }
        return nil
    }
    
    /// Active Firebase Google App ID.
    public var firebaseAppId: String? {
        if let envVal = ProcessInfo.processInfo.environment["FIREBASE_APP_ID"], !envVal.isEmpty {
            return envVal
        }
        if let plistVal = googleServiceInfoDict?["GOOGLE_APP_ID"] as? String, !plistVal.isEmpty {
            return plistVal
        }
        if let secretVal = secretsDict?["FIREBASE_APP_ID"] as? String, !secretVal.isEmpty {
            return secretVal
        }
        return nil
    }
    
    /// Active Firebase GCM Sender ID.
    public var firebaseGCMSenderId: String? {
        if let envVal = ProcessInfo.processInfo.environment["FIREBASE_GCM_SENDER_ID"], !envVal.isEmpty {
            return envVal
        }
        if let plistVal = googleServiceInfoDict?["GCM_SENDER_ID"] as? String, !plistVal.isEmpty {
            return plistVal
        }
        if let secretVal = secretsDict?["FIREBASE_GCM_SENDER_ID"] as? String, !secretVal.isEmpty {
            return secretVal
        }
        return nil
    }
    
    /// Active Firebase Storage Bucket.
    public var firebaseStorageBucket: String? {
        if let envVal = ProcessInfo.processInfo.environment["FIREBASE_STORAGE_BUCKET"], !envVal.isEmpty {
            return envVal
        }
        if let plistVal = googleServiceInfoDict?["STORAGE_BUCKET"] as? String, !plistVal.isEmpty {
            return plistVal
        }
        if let secretVal = secretsDict?["FIREBASE_STORAGE_BUCKET"] as? String, !secretVal.isEmpty {
            return secretVal
        }
        return nil
    }
    
    /// Whether Firebase credentials and configuration are available.
    public var isFirebaseConfigured: Bool {
        if FirebaseApp.app() != nil {
            return true
        }
        return googleServiceInfoPlistFilePath != nil || (firebaseApiKey != nil && firebaseProjectId != nil)
    }
    
    /// Safely configures `FirebaseApp` once if not already initialized.
    @discardableResult
    public func configureFirebaseIfNeeded() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        if FirebaseApp.app() != nil {
            return true
        }
        
        #if DEBUG
        // Local development only.
        // Firebase App Check debug provider allows Simulator/test builds
        // to pass App Check while Firebase AI Logic enforcement is enabled.
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("Firebase App Check Debug Provider enabled")
        #endif
        
        // 1. Try configuration from discovered GoogleService-Info.plist path
        if let plistPath = googleServiceInfoPlistFilePath,
           let options = FirebaseOptions(contentsOfFile: plistPath) {
            FirebaseApp.configure(options: options)
            #if DEBUG
            _ = AppCheck.appCheck()
            #endif  
            return FirebaseApp.app() != nil
        }
        
        // 2. Try configuration from resolved credentials
        if let apiKey = firebaseApiKey,
           let projectId = firebaseProjectId,
           let appId = firebaseAppId,
           let gcmSenderId = firebaseGCMSenderId {
            let options = FirebaseOptions(googleAppID: appId, gcmSenderID: gcmSenderId)
            options.apiKey = apiKey
            options.projectID = projectId
            if let bucket = firebaseStorageBucket {
                options.storageBucket = bucket
            }
            FirebaseApp.configure(options: options)
            #if DEBUG
            _ = AppCheck.appCheck()
            #endif
            return FirebaseApp.app() != nil
        }
        return false
    }
    
    // MARK: - Google Gemini API Key
    
    /// The active Gemini API key if available.
    public var geminiApiKey: String? {
        // 1. Check user-configured override in app settings (highest priority)
        if let savedKey = UserDefaults.standard.string(forKey: userDefaultsKey),
           !savedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return savedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 2. Check Process Environment
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        // 3. Check GoogleService-Info.plist (API_KEY is valid for Gemini / Google Cloud)
        if let plistKey = googleServiceInfoDict?["API_KEY"] as? String, !plistKey.isEmpty, plistKey.count > 10 {
            return plistKey
        }
        
        // 4. Check Secrets.plist
        if let secretKey = secretsDict?["GEMINI_API_KEY"] as? String,
           !secretKey.isEmpty,
           secretKey != "YOUR_GEMINI_API_KEY_HERE" {
            return secretKey
        }
        
        return nil
    }
    
    /// Whether the user explicitly saved a custom API key in the Profile screen.
    public var hasUserCustomGeminiKey: Bool {
        guard let saved = UserDefaults.standard.string(forKey: userDefaultsKey) else { return false }
        return !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Saves or updates the Gemini API key in local user settings.
    public func setGeminiApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: userDefaultsKey)
    }
    
    /// Clears the user-configured API key.
    public func clearGeminiApiKey() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    /// Whether a valid Gemini API key is configured.
    public var isGeminiConfigured: Bool {
        guard let key = geminiApiKey else { return false }
        return !key.isEmpty && key.count > 10
    }
    
    /// Masked string suitable for UI display without exposing full key secret (e.g. "AIzaSy...3F19").
    public var maskedGeminiKey: String {
        guard let key = geminiApiKey, key.count > 10 else {
            return "Not Configured (Using Offline AI Fallback)"
        }
        let prefix = key.prefix(6)
        let suffix = key.suffix(4)
        return "\(prefix)...\(suffix)"
    }
    
    // MARK: - OpenWeather Credentials
    
    private let openWeatherKey = "com.travelpartner.openweather_key"
    
    public var openWeatherApiKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["OPENWEATHER_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        if let userKey = UserDefaults.standard.string(forKey: openWeatherKey), !userKey.isEmpty {
            return userKey
        }
        if let secretKey = secretsDict?["OPENWEATHER_API_KEY"] as? String, !secretKey.isEmpty {
            return secretKey
        }
        return nil
    }
    
    public func setOpenWeatherApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: openWeatherKey)
    }
    
    public var isOpenWeatherConfigured: Bool {
        guard let key = openWeatherApiKey else { return false }
        return key.count > 10
    }
    
    // MARK: - Rail Radar Credentials
    
    private let railRadarKey = "com.travelpartner.rail_radar_key"
    
    public var railRadarApiKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["RAIL_RADAR_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        if let userKey = UserDefaults.standard.string(forKey: railRadarKey), !userKey.isEmpty {
            return userKey
        }
        if let secretKey = secretsDict?["RAIL_RADAR_API_KEY"] as? String, !secretKey.isEmpty {
            return secretKey
        }
        return nil
    }
    
    public func setRailRadarApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: railRadarKey)
    }
    
    public var isRailRadarConfigured: Bool {
        guard let key = railRadarApiKey else { return false }
        return key.count > 10
    }
    
    // MARK: - Engine Settings & Diagnostics
    
    /// Active Search Provider Mode.
    public var searchMode: SearchMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: searchModeKey),
               let mode = SearchMode(rawValue: raw) {
                return mode
            }
            return .mock
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: searchModeKey)
        }
    }
    
    /// Active ML Recommendation Engine Mode.
    public var mlMode: MLEngineMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: mlModeKey),
               let mode = MLEngineMode(rawValue: raw) {
                return mode
            }
            return .hybridCoreML
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: mlModeKey)
        }
    }
    
    /// The active Gemini model name (default: "gemini-2.5-flash").
    public var geminiModelName: String {
        get {
            UserDefaults.standard.string(forKey: geminiModelKey) ?? "gemini-2.5-flash"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: geminiModelKey)
        }
    }
    
    /// Status description of the active Generative AI engine.
    public var aiEngineStatusDescription: String {
        if isGeminiConfigured {
            let project = firebaseProjectId.map { " (Project: \($0))" } ?? ""
            return "Firebase AI SDK [\(geminiModelName)]\(project)"
        }
        return "Offline Deterministic AI Engine"
    }
    
    // MARK: - Layover Settings
    
    private let maxLayoverMinutesKey = "com.travelpartner.max_layover_minutes"
    
    /// Global maximum layover in minutes for connecting train journeys (default: 300 minutes / 5 hours).
    public var maxLayoverMinutes: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: maxLayoverMinutesKey)
            return val > 0 ? val : 300
        }
        set {
            UserDefaults.standard.set(max(60, newValue), forKey: maxLayoverMinutesKey)
        }
    }
}
