import Foundation

/// Orchestrator for concurrent live travel searches across independent providers.
///
/// **Concurrency Architecture:**
/// Uses Swift Concurrency structured tasks (`TaskGroup`) to dispatch independent travel queries
/// (flights, trains, hotels, places, weather) concurrently rather than waiting sequentially.
/// Automatically handles cancellation (`Task.isCancelled`) and tolerates partial failures.
public final class LiveTravelSearchService: TravelSearchServiceProtocol, @unchecked Sendable {
    private let flightProvider: FlightSearchProviderProtocol
    private let trainProvider: TrainSearchProviderProtocol
    private let hotelProvider: HotelSearchProviderProtocol
    private let placeProvider: PlaceSearchProviderProtocol
    private let weatherProvider: WeatherSearchProviderProtocol
    private let cache: TravelDataCacheActor
    
    public init(
        flightProvider: FlightSearchProviderProtocol = MockFlightSearchProvider(),
        trainProvider: TrainSearchProviderProtocol = MockTrainSearchProvider(),
        hotelProvider: HotelSearchProviderProtocol = MockHotelSearchProvider(),
        placeProvider: PlaceSearchProviderProtocol = MockPlaceSearchProvider(),
        weatherProvider: WeatherSearchProviderProtocol = MockWeatherSearchProvider(),
        cache: TravelDataCacheActor = .shared
    ) {
        self.flightProvider = flightProvider
        self.trainProvider = trainProvider
        self.hotelProvider = hotelProvider
        self.placeProvider = placeProvider
        self.weatherProvider = weatherProvider
        self.cache = cache
    }
    
    /// Concurrently executes all independent live travel searches with cancellation checks and partial failure handling.
    public func searchAll(for request: TripRequest) async throws -> SearchResultsBundle {
        try Task.checkCancellation()
        
        var bundle = SearchResultsBundle()
        
        // Use structured concurrency to search flights, trains, hotels, places, and weather in parallel
        enum SubSearchResult: Sendable {
            case flights(Result<[FlightCandidate], Error>)
            case trains(Result<[TrainCandidate], Error>)
            case hotels(Result<[HotelCandidate], Error>)
            case places(Result<[PlaceCandidate], Error>)
            case weather(Result<[WeatherForecast], Error>)
        }
        
        try await withThrowingTaskGroup(of: SubSearchResult.self) { group in
            // Task 1: Flights
            group.addTask {
                do {
                    let flights = try await self.flightProvider.searchFlights(
                        origin: request.origin,
                        destination: request.destination,
                        date: request.startDate,
                        travelers: request.travelersCount
                    )
                    return .flights(.success(flights))
                } catch {
                    return .flights(.failure(error))
                }
            }
            
            // Task 2: Trains
            group.addTask {
                do {
                    let trains = try await self.trainProvider.searchTrains(
                        origin: request.origin,
                        destination: request.destination,
                        date: request.startDate,
                        travelers: request.travelersCount
                    )
                    return .trains(.success(trains))
                } catch {
                    return .trains(.failure(error))
                }
            }
            
            // Task 3: Hotels
            group.addTask {
                do {
                    let hotels = try await self.hotelProvider.searchHotels(
                        destination: request.destination,
                        checkIn: request.startDate,
                        checkOut: request.endDate,
                        guests: request.travelersCount
                    )
                    return .hotels(.success(hotels))
                } catch {
                    return .hotels(.failure(error))
                }
            }
            
            // Task 4: Places
            group.addTask {
                do {
                    let places = try await self.placeProvider.searchPlaces(
                        destination: request.destination,
                        preferences: request.preferences
                    )
                    return .places(.success(places))
                } catch {
                    return .places(.failure(error))
                }
            }
            
            // Task 5: Weather
            group.addTask {
                do {
                    let weather = try await self.weatherProvider.getForecast(
                        destination: request.destination,
                        startDate: request.startDate,
                        days: request.numberOfDays
                    )
                    return .weather(.success(weather))
                } catch {
                    return .weather(.failure(error))
                }
            }
            
            // Collect all parallel results
            for try await result in group {
                try Task.checkCancellation()
                switch result {
                case .flights(let res):
                    switch res {
                    case .success(let flights):
                        bundle.flights = flights
                    case .failure(let err):
                        bundle.partialFailures.append("Flights: \(err.localizedDescription)")
                    }
                    
                case .trains(let res):
                    switch res {
                    case .success(let trains):
                        bundle.trains = trains
                    case .failure(let err):
                        bundle.partialFailures.append("Trains: \(err.localizedDescription)")
                    }
                    
                case .hotels(let res):
                    switch res {
                    case .success(let hotels):
                        bundle.hotels = hotels
                    case .failure(let err):
                        bundle.partialFailures.append("Hotels: \(err.localizedDescription)")
                    }
                    
                case .places(let res):
                    switch res {
                    case .success(let places):
                        bundle.places = places
                    case .failure(let err):
                        bundle.partialFailures.append("Places: \(err.localizedDescription)")
                    }
                    
                case .weather(let res):
                    switch res {
                    case .success(let weather):
                        bundle.weather = weather
                    case .failure(let err):
                        bundle.partialFailures.append("Weather: \(err.localizedDescription)")
                    }
                }
            }
        }
        
        try Task.checkCancellation()
        
        // Convert flights and trains into unified transport options
        var transportOptions: [TransportOption] = []
        for flight in bundle.flights {
            transportOptions.append(TransportOption(from: flight))
        }
        for train in bundle.trains {
            transportOptions.append(TransportOption(from: train))
        }
        bundle.transportOptions = transportOptions
        
        // If critical domains (both transport AND hotels) are empty due to catastrophic failure, throw
        if bundle.hotels.isEmpty && bundle.transportOptions.isEmpty {
            throw TravelSearchError.noCandidatesFound(category: "accommodation or transportation options")
        }
        
        return bundle
    }
}
