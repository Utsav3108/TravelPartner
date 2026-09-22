import Foundation

/// Errors that can occur during real-time live travel data searches.
public enum TravelSearchError: LocalizedError, Equatable, Sendable {
    case networkUnavailable
    case timeout
    case providerFailed(provider: String, reason: String)
    case rateLimited
    case noCandidatesFound(category: String)
    case excessiveLayoverRequired(shortestLayoverMinutes: Int, maxAllowedMinutes: Int)
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Internet connection is unavailable. Cannot retrieve live travel prices."
        case .timeout:
            return "Live travel search provider timed out."
        case .providerFailed(let provider, let reason):
            return "Provider '\(provider)' failed: \(reason)"
        case .rateLimited:
            return "Travel API rate limit reached. Please wait a moment."
        case .noCandidatesFound(let category):
            return "No available \(category) found matching your criteria."
        case .excessiveLayoverRequired(let shortest, let maxAllowed):
            let hours = shortest / 60
            let mins = shortest % 60
            let durationStr = mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
            return "No connecting trains found under \(maxAllowed / 60) hours of layover. Shortest available connection requires \(durationStr)."
        case .cancelled:
            return "Travel search was cancelled."
        }
    }
}

/// Aggregate result container bundling all live travel candidates with partial failure records.
public struct SearchResultsBundle: Equatable, Sendable {
    public var flights: [FlightCandidate]
    public var trains: [TrainCandidate]
    public var transportOptions: [TransportOption]
    public var hotels: [HotelCandidate]
    public var places: [PlaceCandidate]
    public var weather: [WeatherForecast]
    public var partialFailures: [String]
    public let retrievedAt: Date
    
    public init(
        flights: [FlightCandidate] = [],
        trains: [TrainCandidate] = [],
        transportOptions: [TransportOption] = [],
        hotels: [HotelCandidate] = [],
        places: [PlaceCandidate] = [],
        weather: [WeatherForecast] = [],
        partialFailures: [String] = [],
        retrievedAt: Date = Date()
    ) {
        self.flights = flights
        self.trains = trains
        self.transportOptions = transportOptions
        self.hotels = hotels
        self.places = places
        self.weather = weather
        self.partialFailures = partialFailures
        self.retrievedAt = retrievedAt
    }
    
    /// True if all core search domains succeeded without partial failure.
    public var isCompleteSuccess: Bool {
        return partialFailures.isEmpty && !hotels.isEmpty && !places.isEmpty
    }
}

// MARK: - Provider Protocols

@available(*, deprecated, message: "Flight search is out of scope. Use TrainSearchProviderProtocol instead.")
public protocol FlightSearchProviderProtocol: Sendable {
    func searchFlights(origin: String, destination: String, date: Date, travelers: Int) async throws -> [FlightCandidate]
}

public protocol TrainSearchProviderProtocol: Sendable {
    func searchTrains(origin: String, destination: String, date: Date, travelers: Int) async throws -> [TrainCandidate]
    func searchTrains(origin: String, destination: String, date: Date, travelers: Int, maxLayoverMinutes: Int) async throws -> [TrainCandidate]
}

public extension TrainSearchProviderProtocol {
    func searchTrains(origin: String, destination: String, date: Date, travelers: Int, maxLayoverMinutes: Int) async throws -> [TrainCandidate] {
        return try await searchTrains(origin: origin, destination: destination, date: date, travelers: travelers)
    }
}

public protocol HotelSearchProviderProtocol: Sendable {
    func searchHotels(destination: String, checkIn: Date, checkOut: Date, guests: Int) async throws -> [HotelCandidate]
    func revalidateHotel(hotel: HotelCandidate, checkIn: Date, checkOut: Date) async throws -> HotelCandidate
}

public protocol PlaceSearchProviderProtocol: Sendable {
    func searchPlaces(destination: String, preferences: Set<TravelPreference>) async throws -> [PlaceCandidate]
}

public protocol WeatherSearchProviderProtocol: Sendable {
    func getForecast(destination: String, startDate: Date, days: Int) async throws -> [WeatherForecast]
}

public protocol TravelSearchServiceProtocol: Sendable {
    func searchAll(for request: TripRequest) async throws -> SearchResultsBundle
}
