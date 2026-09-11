import Foundation
import SwiftUI

@Observable
@MainActor
public final class ProfileViewModel {
    public var profile: UserProfile = UserProfile()
    public var newGeminiApiKey: String = ""
    public var isKeyConfigured: Bool = false
    public var maskedKeyString: String = ""
    public var searchMode: AppConfiguration.SearchMode = .mock
    public var mlMode: AppConfiguration.MLEngineMode = .hybridCoreML
    public var saveFeedback: String? = nil
    public var aiEngineStatus: String = ""
    public var coreMLStatus: String = ""
    
    private let config = AppConfiguration.shared
    private let userRepository: UserRepositoryProtocol
    
    public init(userRepository: UserRepositoryProtocol = AppContainer.shared.userRepository) {
        self.userRepository = userRepository
        refreshConfig()
    }
    
    public func refreshConfig() {
        self.isKeyConfigured = config.isGeminiConfigured
        self.maskedKeyString = config.maskedGeminiKey
        self.searchMode = config.searchMode
        self.mlMode = config.mlMode
        self.aiEngineStatus = config.aiEngineStatusDescription
        #if canImport(CoreML)
        let manager = CoreMLModelManager.shared
        self.coreMLStatus = manager.areAllModelsLoaded ? "3 Core ML Models Active (Hotels, Places, Transit)" : "Core ML Ready (On-Demand Loading)"
        #else
        self.coreMLStatus = "Core ML Not Supported on this Platform"
        #endif
    }
    
    public func saveGeminiKey() {
        guard !newGeminiApiKey.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        config.setGeminiApiKey(newGeminiApiKey)
        newGeminiApiKey = ""
        refreshConfig()
        saveFeedback = "Gemini API key updated successfully!"
    }
    
    public var isTestingConnection: Bool = false
    public var connectionTestMessage: String? = nil
    public var connectionTestIsSuccess: Bool = false
    
    public func testCloudConnection() async {
        isTestingConnection = true
        connectionTestMessage = nil
        let hybrid = HybridGeminiService()
        let (isLive, title, message) = await hybrid.testCloudConnection()
        self.connectionTestIsSuccess = isLive
        self.connectionTestMessage = "\(title): \(message)"
        self.isTestingConnection = false
        refreshConfig()
    }
    
    public func clearGeminiKey() {
        config.clearGeminiApiKey()
        refreshConfig()
        saveFeedback = "Gemini key removed. Offline AI fallback is active."
        connectionTestMessage = nil
    }
    
    public func updateSearchMode(_ mode: AppConfiguration.SearchMode) {
        config.searchMode = mode
        self.searchMode = mode
    }
    
    public func updateMLMode(_ mode: AppConfiguration.MLEngineMode) {
        config.mlMode = mode
        self.mlMode = mode
    }
    
    public func loadProfile() async {
        do {
            self.profile = try await userRepository.fetchProfile(for: "demo_user")
        } catch {
            // Keep default
        }
    }
    
    public func saveProfile() async {
        do {
            try await userRepository.updateProfile(profile)
            self.saveFeedback = "Profile preferences saved!"
        } catch {
            self.saveFeedback = "Failed to save profile."
        }
    }
}
