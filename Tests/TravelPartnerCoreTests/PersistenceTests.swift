import Testing
import Foundation
@testable import TravelPartnerCore

struct PersistenceTests {
    
    @Test("Emulated Firebase repository saves and retrieves trips")
    func testSaveAndRetrieveTrip() async throws {
        let repo = LocalFirebaseEmulatedRepository(useDiskPersistence: false)
        let coordinator = TripPlanningCoordinator(tripRepository: repo)
        
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 3,
            travelersCount: 2,
            budget: 25000.0
        )
        
        let itinerary = try await coordinator.planTrip(request: request, userId: "test_user_42")
        
        let retrievedTrips = try await repo.fetchTrips(for: "test_user_42")
        #expect(retrievedTrips.count == 1)
        #expect(retrievedTrips.first?.id == itinerary.id)
        #expect(retrievedTrips.first?.destination == "Shimla")
        #expect(retrievedTrips.first?.isSavedToFirebase == true)
        
        // Test single trip fetch
        let single = try await repo.fetchTrip(byId: itinerary.id)
        #expect(single != nil)
        #expect(single?.id == itinerary.id)
        
        // Test deletion
        try await repo.deleteTrip(byId: itinerary.id)
        let afterDelete = try await repo.fetchTrips(for: "test_user_42")
        #expect(afterDelete.isEmpty)
    }
    
    @Test("Feedback repository records user ratings and signals")
    func testFeedbackSubmission() async throws {
        let repo = LocalFirebaseEmulatedRepository(useDiskPersistence: false)
        let tripId = UUID()
        let feedback = UserFeedback(
            tripId: tripId,
            rating: 5,
            comment: "Exceptional planning, loved the Ridge walk!",
            likedItemIds: ["plc-sml-001"]
        )
        
        try await repo.submitFeedback(feedback)
        let list = try await repo.fetchFeedback(for: tripId)
        #expect(list.count == 1)
        #expect(list.first?.rating == 5)
        #expect(list.first?.comment.contains("Exceptional") == true)
    }
    
    @Test("FirebaseTripRepository saves, fetches, and deletes trips with fallback resilience")
    func testFirebaseTripRepositoryRoundtrip() async throws {
        let fallback = LocalFirebaseEmulatedRepository(useDiskPersistence: false)
        let firebaseRepo = FirebaseTripRepository(fallbackRepository: fallback)
        let coordinator = TripPlanningCoordinator(tripRepository: firebaseRepo)
        
        let request = TripRequest(
            origin: "Mumbai",
            destination: "Goa",
            numberOfDays: 2,
            travelersCount: 2,
            budget: 18000.0
        )
        
        let itinerary = try await coordinator.planTrip(request: request, userId: "firestore_test_user")
        
        let trips = try await firebaseRepo.fetchTrips(for: "firestore_test_user")
        #expect(trips.count >= 1)
        #expect(trips.first?.destination == "Goa")
        #expect(trips.first?.isSavedToFirebase == true)
        
        let single = try await firebaseRepo.fetchTrip(byId: itinerary.id)
        #expect(single?.id == itinerary.id)
        #expect(single?.destination == "Goa")
        
        try await firebaseRepo.deleteTrip(byId: itinerary.id)
        let afterDelete = try await firebaseRepo.fetchTrips(for: "firestore_test_user")
        #expect(afterDelete.isEmpty)
    }
}

