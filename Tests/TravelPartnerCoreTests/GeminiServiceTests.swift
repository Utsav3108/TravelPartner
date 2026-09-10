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
}
