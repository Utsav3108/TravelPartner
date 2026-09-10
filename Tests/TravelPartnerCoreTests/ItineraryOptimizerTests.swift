import Testing
import Foundation
@testable import TravelPartnerCore

struct ItineraryOptimizerTests {
    
    @Test("Itinerary optimizer builds accurate daily schedule and cost allocations")
    func testItineraryOptimization() async throws {
        let coordinator = TripPlanningCoordinator()
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 5,
            travelersCount: 4,
            groupType: .friends,
            budget: 50000.0,
            currency: "INR",
            tripType: .roundTrip,
            preferences: [.nature, .culture, .adventure]
        )
        
        let itinerary = try await coordinator.planTrip(request: request)
        
        #expect(itinerary.days.count == 5)
        #expect(itinerary.destination == "Shimla")
        #expect(itinerary.totalBudget == 50000.0)
        #expect(itinerary.totalEstimatedCost > 0)
        #expect(itinerary.selectedHotel != nil)
        #expect(itinerary.selectedTransportation != nil)
        
        // Check that each day has structured activities with scheduled times
        for day in itinerary.days {
            #expect(!day.activities.isEmpty)
            for activity in day.activities {
                #expect(!activity.scheduledTimeString.isEmpty)
                #expect(activity.durationMinutes > 0)
                #expect(!activity.transitSummary.isEmpty)
            }
        }
        
        // Verify budget calculation consistency
        #expect(itinerary.budgetRemaining == itinerary.totalBudget - itinerary.totalEstimatedCost)
    }
}
