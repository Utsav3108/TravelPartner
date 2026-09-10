import Testing
import Foundation
@testable import TravelPartnerCore

struct PartialFailureTests {
    
    @Test("Partial search failure in flight provider does not abort planning when trains and hotels succeed")
    func testGracefulPartialFailureHandling() async throws {
        let failingFlightProvider = MockFlightSearchProvider()
        failingFlightProvider.shouldSimulateError = true // simulate carrier API failure
        
        let liveSearch = LiveTravelSearchService(
            flightProvider: failingFlightProvider,
            trainProvider: MockTrainSearchProvider(),
            hotelProvider: MockHotelSearchProvider(),
            placeProvider: MockPlaceSearchProvider(),
            weatherProvider: MockWeatherSearchProvider()
        )
        
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 4,
            travelersCount: 2,
            budget: 35000.0
        )
        
        let bundle = try await liveSearch.searchAll(for: request)
        
        // Flights should be empty and logged in partialFailures
        #expect(bundle.flights.isEmpty)
        #expect(!bundle.partialFailures.isEmpty)
        
        // But trains, hotels, and places must have succeeded!
        #expect(!bundle.trains.isEmpty)
        #expect(!bundle.hotels.isEmpty)
        #expect(!bundle.places.isEmpty)
        
        // The coordinator can still build a complete trip using trains!
        let coordinator = TripPlanningCoordinator(travelSearchService: liveSearch)
        let itinerary = try await coordinator.planTrip(request: request)
        
        #expect(itinerary.selectedTransportation?.mode == .train)
        #expect(itinerary.selectedHotel != nil)
    }
}
