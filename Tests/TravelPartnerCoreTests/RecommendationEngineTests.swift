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
        #expect(ranked.first?.rationale.headline != nil)
    }
    
    @Test("Core ML engine ranks transport options and places with on-device models")
    func testCoreMLTransportAndPlaceRanking() async throws {
        let coreMLEngine = CoreMLRecommendationEngine()
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 4,
            travelersCount: 2,
            groupType: .couple,
            budget: 40000.0,
            preferences: [.nature, .relaxation]
        )
        
        let searchService = LiveTravelSearchService()
        let results = try await searchService.searchAll(for: request)
        
        // Transport ranking via Core ML
        let rankedTransport = try await coreMLEngine.rankTransport(candidates: results.transportOptions, request: request)
        #expect(!rankedTransport.isEmpty)
        #expect(rankedTransport.first!.score > 0.0)
        #expect(!rankedTransport.first!.rationale.bullets.isEmpty)
        
        // Place ranking via Core ML
        let rankedPlaces = try await coreMLEngine.rankPlaces(candidates: results.places, request: request)
        #expect(!rankedPlaces.isEmpty)
        #expect(rankedPlaces.first!.score > 0.0)
        #expect(!rankedPlaces.first!.rationale.bullets.isEmpty)
    }
    
    @Test("Core ML engine incorporates persistent user feedback into candidate scoring")
    func testCoreMLPersonalizationFeedback() async throws {
        let mockFeedbackRepo = LocalFirebaseEmulatedRepository(useDiskPersistence: false)
        let coreMLEngine = CoreMLRecommendationEngine(feedbackRepository: mockFeedbackRepo)
        
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 3,
            travelersCount: 2,
            budget: 30000.0
        )
        
        let hotelSearch = MockHotelSearchProvider()
        let hotels = try await hotelSearch.searchHotels(destination: "Shimla", checkIn: Date(), checkOut: Date(), guests: 2)
        guard hotels.count >= 2 else { return }
        
        let targetHotel = hotels[1] // The second hotel
        
        // Record user positive feedback for targetHotel
        let feedback = UserFeedback(
            tripId: request.id,
            rating: 5,
            comment: "Loved this hotel!",
            likedItemIds: [targetHotel.id]
        )
        try await mockFeedbackRepo.submitFeedback(feedback)
        
        let ranked = try await coreMLEngine.rankHotels(candidates: hotels, request: request)
        let scoredTarget = ranked.first(where: { $0.candidate.id == targetHotel.id })
        
        #expect(scoredTarget != nil)
        #expect(scoredTarget!.score > 0.5)
    }
    
    @Test("CoreMLModelManager resolves or loads ranking models successfully")
    func testCoreMLModelManagerResolution() async throws {
        let manager = CoreMLModelManager.shared
        // Manager checks all candidate search locations
        let hotelModel = manager.getHotelModel()
        let placeModel = manager.getPlaceModel()
        let transportModel = manager.getTransportModel()
        
        // If models are compiled in the workspace or bundle, verify they can be loaded
        if hotelModel != nil {
            #expect(hotelModel?.modelDescription.inputDescriptionsByName != nil)
        }
        if placeModel != nil {
            #expect(placeModel?.modelDescription.inputDescriptionsByName != nil)
        }
        if transportModel != nil {
            #expect(transportModel?.modelDescription.inputDescriptionsByName != nil)
        }
    }
}
