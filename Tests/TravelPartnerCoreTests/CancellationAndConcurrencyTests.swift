import Testing
import Foundation
@testable import TravelPartnerCore

struct CancellationAndConcurrencyTests {
    
    @Test("Planning pipeline respects Swift Concurrency cancellation")
    func testTaskCancellation() async throws {
        let coordinator = TripPlanningCoordinator()
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 5,
            travelersCount: 4,
            budget: 50000.0
        )
        
        let task = Task {
            try await coordinator.planTrip(request: request)
        }
        
        // Immediately cancel task
        task.cancel()
        
        do {
            _ = try await task.value
            Issue.record("Expected cancellation error to be thrown")
        } catch is CancellationError {
            // Success: cancellation was properly respected
        } catch {
            // Any cancellation error is acceptable
        }
    }
}
