import Foundation

/// Orchestrator for concurrent live travel searches across independent providers.
///
/// **Concurrency Architecture:**
/// Uses Swift Concurrency structured tasks (`TaskGroup`) to dispatch independent travel queries
/// (flights, trains, hotels, places, weather) concurrently rather than waiting sequentially.
/// Automatically handles cancellation (`Task.isCancelled`) and tolerates partial failures.
public final class LiveTravelSearchService: TravelSearchServiceProtocol, @unchecked Sendable {
    @available(*, deprecated, message: "Flight search is out of scope. Use trainProvider instead.")
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
        
        // Use structured concurrency to search trains, hotels, places, and weather in parallel
        // Note: Flight search has been deprecated as it is out of scope for this railway-centric project.
        bundle.flights = []
        
        enum SubSearchResult: Sendable {
            case trains(Result<[TrainCandidate], Error>)
            case hotels(Result<[HotelCandidate], Error>)
            case places(Result<[PlaceCandidate], Error>)
            case weather(Result<[WeatherForecast], Error>)
        }
        
        try await withThrowingTaskGroup(of: SubSearchResult.self) { group in
            // Task 1: Trains (Rail Radar Live API / Mock fallback)
            group.addTask {
                do {
                    let originQuery = request.originStationCode ?? request.origin
                    let destQuery = request.destinationStationCode ?? request.destination
                    let trains = try await self.trainProvider.searchTrains(
                        origin: originQuery,
                        destination: destQuery,
                        date: request.startDate,
                        travelers: request.travelersCount,
                        maxLayoverMinutes: request.maxLayoverMinutes
                    )
                    let isMock = trains.first?.metadata.isMock ?? true
                    let source = trains.first?.metadata.source ?? "MockTrainSearchProvider"
                    if isMock {
                        AppLogger.shared.info("[Simulator] Trains: evaluated \(trains.count) rail candidate(s) from in-memory \(source)", category: .pipeline)
                    } else {
                        AppLogger.shared.success("[Live API] Trains: retrieved \(trains.count) live rail schedules from \(source)", category: .pipeline)
                    }
                    return .trains(.success(trains))
                } catch {
                    AppLogger.shared.error("Train search error: \(error.localizedDescription)", category: .pipeline)
                    return .trains(.failure(error))
                }
            }
            
            // Task 2: Hotels
            group.addTask {
                do {
                    let hotels = try await self.hotelProvider.searchHotels(
                        destination: request.destination,
                        checkIn: request.startDate,
                        checkOut: request.endDate,
                        guests: request.travelersCount
                    )
                    let isMock = hotels.first?.metadata.isMock ?? true
                    let source = hotels.first?.metadata.source ?? "MockHotelSearchProvider"
                    if isMock {
                        AppLogger.shared.info("[Simulator] Hotels: evaluated \(hotels.count) properties from in-memory \(source)", category: .pipeline)
                    } else {
                        AppLogger.shared.success("[Live API] Hotels: retrieved \(hotels.count) properties from \(source)", category: .pipeline)
                    }
                    return .hotels(.success(hotels))
                } catch {
                    AppLogger.shared.error("Hotel search error: \(error.localizedDescription)", category: .pipeline)
                    return .hotels(.failure(error))
                }
            }
            
            // Task 3: Places
            group.addTask {
                do {
                    let places = try await self.placeProvider.searchPlaces(
                        destination: request.destination,
                        preferences: request.preferences
                    )
                    let isMock = places.first?.metadata.isMock ?? true
                    let source = places.first?.metadata.source ?? "DestinationCatalog"
                    if isMock {
                        AppLogger.shared.info("[Catalog] Places: retrieved \(places.count) sights from destination catalog", category: .pipeline)
                    } else {
                        AppLogger.shared.success("[Live API] Places: retrieved \(places.count) sights from \(source)", category: .pipeline)
                    }
                    return .places(.success(places))
                } catch {
                    AppLogger.shared.error("Places search error: \(error.localizedDescription)", category: .pipeline)
                    return .places(.failure(error))
                }
            }
            
            // Task 4: Weather (OpenWeather / OpenMeteo)
            group.addTask {
                do {
                    let weather = try await self.weatherProvider.getForecast(
                        destination: request.destination,
                        startDate: request.startDate,
                        days: request.numberOfDays
                    )
                    AppLogger.shared.info("Weather forecast resolved: \(weather.count) day(s) for '\(request.destination)'", category: .pipeline)
                    return .weather(.success(weather))
                } catch {
                    AppLogger.shared.error("Weather forecast error: \(error.localizedDescription)", category: .pipeline)
                    return .weather(.failure(error))
                }
            }
            
            // Collect all parallel results
            for try await result in group {
                try Task.checkCancellation()
                switch result {
                case .trains(let res):
                    switch res {
                    case .success(let trains):
                        bundle.trains = trains
                        print("Trains Data Fetched: ", trains)
                    case .failure(let err):
                        if let searchErr = err as? TravelSearchError,
                           case .excessiveLayoverRequired = searchErr {
                            throw searchErr
                        }
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
        
        // Convert trains into unified transport options
        bundle.transportOptions = bundle.trains.map { TransportOption(from: $0) }
        
        // If critical domains (both transport AND hotels) are empty due to catastrophic failure, throw
        if bundle.hotels.isEmpty && bundle.transportOptions.isEmpty {
            throw TravelSearchError.noCandidatesFound(category: "accommodation or transportation options")
        }
        
        return bundle
    }
}
