import Testing
import Foundation
@testable import TravelPartnerCore

struct RecommendationEngineTests {
    
    @Test("Recommendation engine ranks candidates and generates transparent rationales")
    func testRecommendationRankingAndRationales() async throws {
        let engine = DeterministicRankingEngine()
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 5,
            travelersCount: 4,
            groupType: .friends,
            budget: 50000.0,
            preferences: [.adventure, .nature]
        )
        
        let searchService = LiveTravelSearchService()
        let searchResults = try await searchService.searchAll(for: request)
        
        // Rank Hotels
        let rankedHotels = try await engine.rankHotels(candidates: searchResults.hotels, request: request)
        #expect(!rankedHotels.isEmpty)
        
        let topHotel = rankedHotels.first!
        #expect(topHotel.score > 0.5)
        #expect(!topHotel.rationale.bullets.isEmpty)
        #expect(topHotel.rationale.itemType == "hotel")
        
        // Rank Places
        let rankedPlaces = try await engine.rankPlaces(candidates: searchResults.places, request: request)
        #expect(!rankedPlaces.isEmpty)
        
        // Adventure/nature places should receive high preference scoring
        let adventurePlace = rankedPlaces.first(where: { $0.candidate.category == .adventure })
        #expect(adventurePlace != nil)
    }
    
    @Test("Core ML engine with fallback executes seamlessly")
    func testCoreMLEngineFallback() async throws {
        let coreMLEngine = CoreMLRecommendationEngine()
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 3,
            travelersCount: 2,
            budget: 25000.0
        )
        
        let hotelSearch = MockHotelSearchProvider()
        let hotels = try await hotelSearch.searchHotels(destination: "Shimla", checkIn: Date(), checkOut: Date(), guests: 2)
        
        let ranked = try await coreMLEngine.rankHotels(candidates: hotels, request: request)
        #expect(!ranked.isEmpty)
        #expect(ranked.first?.score != nil)
    }
}
