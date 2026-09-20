import SwiftUI

@main
struct TravelPartnerApp: App {
    // AppContainer holds all dependency instances
    private let container: AppContainer
    
    public init() {
        AppConfiguration.shared.configureFirebaseIfNeeded()
        self.container = AppContainer.shared
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
