import Testing
import Foundation
@testable import TravelPartnerCore

struct ConstraintEngineTests {
    
    @Test("Hard constraint filtering enforces family friendliness for family trips")
    func testFamilyConstraints() async throws {
        let constraintEngine = ConstraintEngine()
        let searchService = LiveTravelSearchService()
        
        let familyRequest = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 4,
            travelersCount: 4,
            groupType: .family,
            budget: 60000.0
        )
        
        let searchResults = try await searchService.searchAll(for: familyRequest)
        let filtered = try constraintEngine.applyConstraints(to: searchResults, for: familyRequest)
        
        // Every hotel that passed MUST be certified family-friendly
        for hotel in filtered.hotels {
            #expect(hotel.isFamilyFriendly == true)
        }
    }
    
    @Test("Capacity calculations accurately compute rooms needed")
    func testRoomCapacityCalculations() {
        let meta = CandidateMetadata(source: "Test")
        let hotel = HotelCandidate(
            id: "h1",
            name: "Test Hotel",
            address: "Center",
            city: "Shimla",
            coordinates: GeoLocation(latitude: 31.0, longitude: 77.0),
            starRating: 4.0,
            reviewScore: 4.5,
            reviewCount: 100,
            pricePerNight: 3000.0,
            roomType: "Double Room",
            maxCapacityPerRoom: 2,
            amenities: [],
            metadata: meta
        )
        
        // 4 travelers with capacity 2 per room -> 2 rooms
        #expect(hotel.roomsRequired(for: 4) == 2)
        // 5 travelers with capacity 2 per room -> 3 rooms
        #expect(hotel.roomsRequired(for: 5) == 3)
        // 1 traveler -> 1 room
        #expect(hotel.roomsRequired(for: 1) == 1)
        
        // Total cost for 4 travelers for 3 nights: 3000 * 2 rooms * 3 nights = 18000
        #expect(hotel.totalCost(for: 4, nights: 3) == 18000.0)
    }
    
    @Test("Constraint engine rejects budget that cannot cover essential baseline reserve")
    func testImpossibleBudgetFailsConstraints() async throws {
        let constraintEngine = ConstraintEngine()
        let searchService = LiveTravelSearchService()
        
        // 10 travelers for 10 days = 10 * 10 * 500 = 50,000 minimum reserve needed, but budget is only 15,000
        let impossibleRequest = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 10,
            travelersCount: 10,
            budget: 15000.0
        )
        
        let searchResults = try await searchService.searchAll(for: impossibleRequest)
        
        #expect(throws: ConstraintViolationError.self) {
            try constraintEngine.applyConstraints(to: searchResults, for: impossibleRequest)
        }
    }
}
