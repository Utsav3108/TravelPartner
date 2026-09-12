import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var activeRequest: TripRequest? = nil
    @State private var showingPlanning: Bool = false
    @State private var selectedItinerary: TripItinerary? = nil
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Explore", systemImage: "sparkles")
                }
                .tag(0)
            
            TripWizardView(isPresentedModally: false) { request in
                self.activeRequest = request
                self.showingPlanning = true
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
        .sheet(isPresented: $showingPlanning) {
            if let req = activeRequest {
                PlanningProgressView(request: req) { itinerary in
                    self.showingPlanning = false
                    self.selectedItinerary = itinerary
                } onCancel: {
                    self.showingPlanning = false
                }
            }
        }
        .sheet(item: $selectedItinerary) { itinerary in
            TripResultView(itinerary: itinerary)
        }
    }
}
