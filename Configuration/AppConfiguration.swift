import Foundation

/// Centralized configuration management for API keys and cloud services.
///
/// **Security Guarantee:**
/// Never hardcodes API keys or private tokens inside source code.
/// Checks runtime sources in hierarchical order:
/// 1. Environment variables (`GEMINI_API_KEY`, `FIREBASE_PROJECT_ID`)
/// 2. Optional unversioned `Secrets.plist` or Bundle dictionary
/// 3. Secure in-app settings configured via the Profile / Settings screen
public final class AppConfiguration: @unchecked Sendable {
    public static let shared = AppConfiguration()
    
    private let userDefaultsKey = "com.travelpartner.gemini_api_key"
    private let searchModeKey = "com.travelpartner.search_mode"
    private let mlModeKey = "com.travelpartner.ml_mode"
    
    public enum SearchMode: String, CaseIterable, Sendable {
        case mock = "Simulated Real-Time"
        case production = "Live Web API Providers"
    }
    
    public enum MLEngineMode: String, CaseIterable, Sendable {
        case hybridCoreML = "Core ML On-Device"
        case deterministicMCDA = "Deterministic Utility (MCDA)"
    }
    
    private init() {}
    
    /// The active Gemini API key if available.
    public var geminiApiKey: String? {
        // 1. Check Process Environment
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        // 2. Check Bundle Secrets.plist
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let key = dict["GEMINI_API_KEY"] as? String, !key.isEmpty, key != "YOUR_GEMINI_API_KEY_HERE" {
            return key
        }
        
        // 3. Check App UserDefaults setting
        if let savedKey = UserDefaults.standard.string(forKey: userDefaultsKey), !savedKey.isEmpty {
            return savedKey
        }
        
        return nil
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
}
