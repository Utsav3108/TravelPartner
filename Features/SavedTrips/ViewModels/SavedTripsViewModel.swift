import Foundation
import SwiftUI

@Observable
@MainActor
public final class SavedTripsViewModel {
    public var savedTrips: [TripItinerary] = []
    public var isLoading: Bool = false
    public var searchText: String = ""
    public var errorMessage: String? = nil
    
    private let repository: TripRepositoryProtocol
    
    public init(repository: TripRepositoryProtocol = AppContainer.shared.tripRepository) {
        self.repository = repository
    }
    
    public var filteredTrips: [TripItinerary] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return savedTrips
        }
        return savedTrips.filter {
            $0.destination.localizedCaseInsensitiveContains(searchText) ||
            $0.origin.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    public func loadTrips() async {
        isLoading = true
        errorMessage = nil
        do {
            self.savedTrips = try await repository.fetchTrips(for: "demo_user")
            self.isLoading = false
        } catch {
            self.errorMessage = "Could not load saved trips: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    public func deleteTrip(id: UUID) async {
        do {
            try await repository.deleteTrip(byId: id)
            self.savedTrips.removeAll(where: { $0.id == id })
        } catch {
            self.errorMessage = "Failed to delete trip: \(error.localizedDescription)"
        }
    }
}
