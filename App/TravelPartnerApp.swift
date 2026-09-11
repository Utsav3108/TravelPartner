import SwiftUI
#if canImport(TravelPartnerCore)
import TravelPartnerCore
#endif

@main
struct TravelPartnerApp: App {
    // AppContainer holds all dependency instances
    private let container = AppContainer.shared
    
    public init() {
        AppConfiguration.shared.configureFirebaseIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
