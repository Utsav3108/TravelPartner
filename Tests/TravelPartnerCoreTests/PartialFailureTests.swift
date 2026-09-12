import Testing
import Foundation
@testable import TravelPartnerCore

struct PartialFailureTests {
    
    @Test("Partial search failure in weather provider does not abort planning when trains and hotels succeed")
    func testGracefulPartialFailureHandling() async throws {
        let failingWeatherProvider = MockWeatherSearchProvider()
        failingWeatherProvider.shouldSimulateError = true // simulate weather API failure
        
        let liveSearch = LiveTravelSearchService(
            trainProvider: MockTrainSearchProvider(),
            hotelProvider: MockHotelSearchProvider(),
            placeProvider: MockPlaceSearchProvider(),
            weatherProvider: failingWeatherProvider
        )
        
        let request = TripRequest(
            origin: "Delhi",
            destination: "Shimla",
            numberOfDays: 4,
            travelersCount: 2,
            budget: 35000.0
        )
        
        let bundle = try await liveSearch.searchAll(for: request)
        
        // Flights are deprecated and out of scope
        #expect(bundle.flights.isEmpty)
        // Weather failed and logged in partialFailures
        #expect(bundle.weather.isEmpty)
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
    
    @Test("OpenWeatherSearchProvider resolves live forecast or falls back cleanly")
    func testOpenWeatherProvider() async throws {
        let provider = OpenWeatherSearchProvider()
        let forecasts = try await provider.getForecast(destination: "Shimla", startDate: Date(), days: 3)
        #expect(!forecasts.isEmpty)
        #expect(forecasts.first?.condition != nil)
    }
    
    @Test("RailRadarTrainSearchProvider resolves live railway candidates or falls back cleanly")
    func testRailRadarProvider() async throws {
        let provider = RailRadarTrainSearchProvider()
        let trains = try await provider.searchTrains(origin: "Delhi", destination: "Shimla", date: Date(), travelers: 2)
        #expect(!trains.isEmpty)
        #expect(trains.first?.trainNumber != nil)
        #expect(trains.first?.pricePerPerson ?? 0 > 0)
    }
    
    @Test("RailRadarTrainSearchProvider accurately calculates realistic 30+ hour journey time for Viramgam to Patna (1,890+ km)")
    func testViramgamToPatnaRealisticJourney() async throws {
        let provider = RailRadarTrainSearchProvider()
        let trains = try await provider.searchTrains(origin: "Viramgam", destination: "Patna", date: Date(), travelers: 4)
        #expect(!trains.isEmpty)
        let first = trains.first!
        // Viramgam to Patna across 1,890+ km must be over 24 hours (1440 min), never 4 hours (240 min)!
        #expect(first.durationMinutes > 1440)
        #expect(first.originStation.contains("VG") || first.originStation.contains("Viramgam"))
        #expect(first.destinationStation.contains("PNBE") || first.destinationStation.contains("Patna"))
        #expect(first.pricePerPerson > 1000.0)
    }
    
    @Test("RailRadarTrainSearchProvider resolves connecting routes for Puducherry to Dehradun (2,600+ km)")
    func testPuducherryToDehradunConnectingRoute() async throws {
        let provider = RailRadarTrainSearchProvider()
        let trains = try await provider.searchTrains(origin: "Puducherry", destination: "Dehradun", date: Date(), travelers: 2)
        #expect(!trains.isEmpty)
        let first = trains.first!
        // Puducherry to Dehradun is over 2,600 km, journey must take more than 36 hours (2160 min)!
        #expect(first.durationMinutes > 2160)
        #expect(first.originStation.contains("PDY") || first.originStation.contains("Puducherry") || first.originStation.contains("Pondicherry"))
        #expect(first.destinationStation.contains("DDN") || first.destinationStation.contains("Dehradun") || first.destinationStation.contains("Dehra Dun"))
        #expect(first.pricePerPerson > 1800.0)
    }
    
    @Test("GeminiWordLimitEnforcer strictly caps narratives at or below 200 words")
    func testGeminiWordLimitEnforcer() {
        let longText = (1...300).map { "word\($0)" }.joined(separator: " ") + "."
        let trimmed = GeminiWordLimitEnforcer.trimTo200Words(longText)
        let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count
        #expect(wordCount <= 200)
    }
    
    @Test("OpenMeteoWeatherSearchProvider resolves live forecast or falls back cleanly")
    func testOpenMeteoWeatherProvider() async throws {
        let provider = OpenMeteoWeatherSearchProvider()
        let forecasts = try await provider.getForecast(destination: "Shimla", startDate: Date(), days: 3)
        #expect(!forecasts.isEmpty)
        #expect(forecasts.count >= 1)
        #expect(forecasts.first?.condition != nil)
    }
    
    @Test("WikipediaPlaceSearchProvider retrieves live tourist places or falls back cleanly")
    func testWikipediaPlaceSearchProvider() async throws {
        let provider = WikipediaPlaceSearchProvider()
        let places = try await provider.searchPlaces(destination: "Shimla", preferences: [.culture, .nature])
        #expect(!places.isEmpty)
        #expect(places.first?.name != nil)
    }
}
