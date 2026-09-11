import Testing
import Foundation
@testable import TravelPartnerCore

struct GeminiServiceTests {
    
    @Test("Gemini Service accurately parses user natural-language prompt into structured TripRequest")
    func testNaturalLanguagePromptParsing() async throws {
        let gemini = FallbackGeminiService()
        let userPrompt = "I want to go to Shimla for 5 days with 4 friends. My total budget is ₹50,000. I want a round trip."
        
        let request = try await gemini.parseTripPrompt(userPrompt)
        
        #expect(request.destination == "Shimla")
        #expect(request.numberOfDays == 5)
        #expect(request.travelersCount == 4)
        #expect(request.groupType == .friends)
        #expect(request.budget == 50000.0)
        #expect(request.currency == "INR")
        #expect(request.tripType == .roundTrip)
    }
    
    @Test("Gemini Service accurately parses diverse currencies, international destinations, and solo traveler")
    func testDiversePromptParsing() async throws {
        let gemini = FallbackGeminiService()
        let prompt = "Planning a solo trip to Paris for a week. Budget is $2,500 under adventure and culture."
        
        let request = try await gemini.parseTripPrompt(prompt)
        #expect(request.destination == "Paris")
        #expect(request.numberOfDays == 7)
        #expect(request.travelersCount == 1)
        #expect(request.groupType == .solo)
        #expect(request.currency == "USD")
        #expect(request.budget == 2500.0)
        #expect(request.preferences.contains(.adventure))
        #expect(request.preferences.contains(.culture))
    }
    
    @Test("FirebaseGeminiService initializes with model name and falls back gracefully when offline")
    func testFirebaseGeminiServiceFallback() async throws {
        let service = FirebaseGeminiService(modelName: "gemini-1.5-flash")
        #expect(service.modelName == "gemini-1.5-flash")
        
        let prompt = "Family trip to Goa for 4 days with budget ₹60,000"
        let request = try await service.parseTripPrompt(prompt)
        
        #expect(request.destination == "Goa")
        #expect(request.numberOfDays == 4)
        #expect(request.groupType == .family)
    }
    
    @Test("HybridGeminiService supports streaming narrative generation")
    func testHybridGeminiServiceStreaming() async throws {
        let hybrid = HybridGeminiService()
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 3,
            travelersCount: 2,
            groupType: .couple,
            budget: 30000.0
        )
        
        let coordinator = TripPlanningCoordinator()
        let itinerary = try await coordinator.planTrip(request: request)
        
        let stream = try await hybrid.generateItineraryNarrativeStream(for: itinerary, request: request)
        var receivedChunks = 0
        var fullText = ""
        for try await chunk in stream {
            receivedChunks += 1
            fullText += chunk
        }
        
        #expect(receivedChunks > 0)
        #expect(!fullText.isEmpty)
        #expect(fullText.contains("Shimla"))
    }
    
    @Test("Conversational modification adjusts itinerary using grounded candidate alternatives")
    func testConversationalModificationCheaper() async throws {
        let coordinator = TripPlanningCoordinator()
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 5,
            travelersCount: 4,
            budget: 50000.0
        )
        
        let itinerary = try await coordinator.planTrip(request: request)
        let initialHotel = itinerary.selectedHotel
        
        // User asks for cheaper alternative
        let modification = try await coordinator.modifyTrip(
            itinerary: itinerary,
            instruction: "This hotel is too expensive. Give me something cheaper.",
            request: request
        )
        
        #expect(!modification.aiExplanation.isEmpty)
        #expect(modification.updatedItinerary.days.count == 5)
        // If an alternative was swapped, verify
        if let newHotel = modification.updatedItinerary.selectedHotel, let initial = initialHotel {
            #expect(newHotel.pricePerNight <= initial.pricePerNight)
        }
    }
    
    @Test("Conversational modification switches transit to scenic train")
    func testConversationalModificationTrain() async throws {
        let coordinator = TripPlanningCoordinator()
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 4,
            travelersCount: 2,
            budget: 35000.0
        )
        
        let itinerary = try await coordinator.planTrip(request: request)
        
        let modification = try await coordinator.modifyTrip(
            itinerary: itinerary,
            instruction: "I want to switch to a scenic train ride.",
            request: request
        )
        
        #expect(!modification.aiExplanation.isEmpty)
        if let transit = modification.updatedItinerary.selectedTransportation {
            #expect(transit.mode == .train)
        }
    }
}
