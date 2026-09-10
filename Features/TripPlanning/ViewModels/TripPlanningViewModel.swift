import Foundation
import SwiftUI

@Observable
@MainActor
public final class TripPlanningViewModel {
    public var isPlanning: Bool = false
    public var currentProgress: PlanningProgress = PlanningProgress(
        stage: .validatingRequest,
        progressFraction: 0.05,
        headline: "Preparing planning engine...",
        subhead: "Initializing live search pipelines"
    )
    public var completedStages: Set<PlanningStage> = []
    public var generatedItinerary: TripItinerary? = nil
    public var errorMessage: String? = nil
    
    private var planningTask: Task<Void, Never>? = nil
    private let coordinator: TripPlanningCoordinator
    
    public init(coordinator: TripPlanningCoordinator = AppContainer.shared.tripPlanningService) {
        self.coordinator = coordinator
    }
    
    public func startPlanning(request: TripRequest, userId: String = "demo_user") {
        // Cancel any active running planning task first
        planningTask?.cancel()
        
        isPlanning = true
        errorMessage = nil
        generatedItinerary = nil
        completedStages.removeAll()
        
        planningTask = Task {
            do {
                let itinerary = try await coordinator.planTrip(request: request, userId: userId) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self = self, !Task.isCancelled else { return }
                        self.currentProgress = progress
                        self.completedStages.insert(progress.stage)
                    }
                }
                
                guard !Task.isCancelled else { return }
                self.generatedItinerary = itinerary
                self.isPlanning = false
            } catch is CancellationError {
                self.isPlanning = false
                self.errorMessage = "Trip generation was cancelled."
            } catch {
                guard !Task.isCancelled else { return }
                self.isPlanning = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    public func cancel() {
        planningTask?.cancel()
        planningTask = nil
        isPlanning = false
        errorMessage = "Trip generation cancelled by user."
    }
}
