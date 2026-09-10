import Foundation

/// Thread-safe in-memory cache for volatile live travel data.
///
/// **Why an actor is used:**
/// In Swift Concurrency, multiple concurrent tasks spawned via `TaskGroup` across background threads
/// may read and write cached travel items simultaneously. An `actor` provides compile-time data race
/// safety and actor-isolated mutable state without relying on manual locks or semaphores.
public actor TravelDataCacheActor {
    public static let shared = TravelDataCacheActor()
    
    private struct CacheEntry<T: Sendable>: Sendable {
        let value: T
        let metadata: CandidateMetadata
    }
    
    private var flightsCache: [String: CacheEntry<[FlightCandidate]>] = [:]
    private var trainsCache: [String: CacheEntry<[TrainCandidate]>] = [:]
    private var hotelsCache: [String: CacheEntry<[HotelCandidate]>] = [:]
    private var placesCache: [String: CacheEntry<[PlaceCandidate]>] = [:]
    private var weatherCache: [String: CacheEntry<[WeatherForecast]>] = [:]
    
    public init() {}
    
    // MARK: - Flights Cache
    
    public func getFlights(key: String) -> [FlightCandidate]? {
        guard let entry = flightsCache[key], entry.metadata.isFresh else {
            return nil
        }
        return entry.value
    }
    
    public func setFlights(key: String, flights: [FlightCandidate], metadata: CandidateMetadata) {
        flightsCache[key] = CacheEntry(value: flights, metadata: metadata)
    }
    
    // MARK: - Trains Cache
    
    public func getTrains(key: String) -> [TrainCandidate]? {
        guard let entry = trainsCache[key], entry.metadata.isFresh else {
            return nil
        }
        return entry.value
    }
    
    public func setTrains(key: String, trains: [TrainCandidate], metadata: CandidateMetadata) {
        trainsCache[key] = CacheEntry(value: trains, metadata: metadata)
    }
    
    // MARK: - Hotels Cache
    
    public func getHotels(key: String) -> [HotelCandidate]? {
        guard let entry = hotelsCache[key], entry.metadata.isFresh else {
            return nil
        }
        return entry.value
    }
    
    public func setHotels(key: String, hotels: [HotelCandidate], metadata: CandidateMetadata) {
        hotelsCache[key] = CacheEntry(value: hotels, metadata: metadata)
    }
    
    // MARK: - Places Cache
    
    public func getPlaces(key: String) -> [PlaceCandidate]? {
        guard let entry = placesCache[key], entry.metadata.isFresh else {
            return nil
        }
        return entry.value
    }
    
    public func setPlaces(key: String, places: [PlaceCandidate], metadata: CandidateMetadata) {
        placesCache[key] = CacheEntry(value: places, metadata: metadata)
    }
    
    // MARK: - Weather Cache
    
    public func getWeather(key: String) -> [WeatherForecast]? {
        guard let entry = weatherCache[key], entry.metadata.isFresh else {
            return nil
        }
        return entry.value
    }
    
    public func setWeather(key: String, weather: [WeatherForecast], metadata: CandidateMetadata) {
        weatherCache[key] = CacheEntry(value: weather, metadata: metadata)
    }
    
    // MARK: - Invalidation & Housekeeping
    
    public func clearAll() {
        flightsCache.removeAll()
        trainsCache.removeAll()
        hotelsCache.removeAll()
        placesCache.removeAll()
        weatherCache.removeAll()
    }
    
    public func purgeExpired() {
        let now = Date()
        flightsCache = flightsCache.filter { $0.value.metadata.expiresAt > now }
        trainsCache = trainsCache.filter { $0.value.metadata.expiresAt > now }
        hotelsCache = hotelsCache.filter { $0.value.metadata.expiresAt > now }
        placesCache = placesCache.filter { $0.value.metadata.expiresAt > now }
        weatherCache = weatherCache.filter { $0.value.metadata.expiresAt > now }
    }
    
    public var totalCachedItemsCount: Int {
        return flightsCache.count + trainsCache.count + hotelsCache.count + placesCache.count + weatherCache.count
    }
}
