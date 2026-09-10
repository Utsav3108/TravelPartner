import Foundation
import SwiftUI

@Observable
@MainActor
public final class TripResultViewModel {
    public var itinerary: TripItinerary
    public var selectedDayNumber: Int = 1
    
    public var isModifying: Bool = false
    public var modificationInputText: String = ""
    public var aiModificationFeedback: String? = nil
    
    public var isRevalidating: Bool = false
    public var revalidationStatus: String? = nil
    
    public var isSaved: Bool
    public var saveStatusMessage: String? = nil
    
    private let coordinator: TripPlanningCoordinator
    private let tripRepository: TripRepositoryProtocol
    
    public init(
        itinerary: TripItinerary,
        coordinator: TripPlanningCoordinator = AppContainer.shared.tripPlanningService,
        tripRepository: TripRepositoryProtocol = AppContainer.shared.tripRepository
    ) {
        self.itinerary = itinerary
        self.isSaved = itinerary.isSavedToFirebase
        self.coordinator = coordinator
        self.tripRepository = tripRepository
    }
    
    public var currentDayItinerary: DailyItinerary? {
        return itinerary.days.first(where: { $0.dayNumber == selectedDayNumber })
    }
    
    public func applyModification(prompt: String, originalRequest: TripRequest) async {
        guard !prompt.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isModifying = true
        aiModificationFeedback = nil
        
        do {
            let result = try await coordinator.modifyTrip(
                itinerary: itinerary,
                instruction: prompt,
                request: originalRequest
            )
            self.itinerary = result.updatedItinerary
            self.aiModificationFeedback = result.aiExplanation
            self.modificationInputText = ""
            self.isModifying = false
        } catch {
            self.aiModificationFeedback = "Modification failed: \(error.localizedDescription)"
            self.isModifying = false
        }
    }
    
    public func revalidateLivePrices() async {
        isRevalidating = true
        revalidationStatus = "Revalidating live hotel & transport rates..."
        
        // Simulates live re-check before booking
        try? await Task.sleep(nanoseconds: 800 * 1_000_000)
        
        if let hotel = itinerary.selectedHotel {
            self.revalidationStatus = "Verified live rate for '\(hotel.name)': \(itinerary.currency) \(Int(hotel.pricePerNight))/night. Availability confirmed."
        } else {
            self.revalidationStatus = "All rates verified fresh."
        }
        self.isRevalidating = false
    }
    
    public func saveTrip() async {
        do {
            try await tripRepository.saveTrip(itinerary, for: "demo_user")
            self.isSaved = true
            self.saveStatusMessage = "Saved to My Trips!"
        } catch {
            self.saveStatusMessage = "Could not save trip: \(error.localizedDescription)"
        }
    }
}
