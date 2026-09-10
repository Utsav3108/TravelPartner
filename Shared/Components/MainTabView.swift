import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: Int = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Explore", systemImage: "sparkles")
                }
                .tag(0)
            
            TripWizardView { _ in
                selectedTab = 0
            }
            .tabItem {
                Label("Plan", systemImage: "slider.horizontal.3")
            }
            .tag(1)
            
            SavedTripsView()
                .tabItem {
                    Label("My Trips", systemImage: "bookmark.fill")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("Settings", systemImage: "person.crop.circle")
                }
                .tag(3)
        }
    }
}
