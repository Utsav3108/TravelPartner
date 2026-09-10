import Foundation

/// Container holding candidates that survived deterministic hard business rule filtering.
public struct FilteredCandidatesBundle: Sendable, Equatable {
    public let hotels: [HotelCandidate]
    public let transportOptions: [TransportOption]
    public let places: [PlaceCandidate]
    public let weather: [WeatherForecast]
    public let filteredLogs: [String]
    public let discardedHotelsCount: Int
    public let discardedTransportCount: Int
    public let discardedPlacesCount: Int
    
    public init(
        hotels: [HotelCandidate],
        transportOptions: [TransportOption],
        places: [PlaceCandidate],
        weather: [WeatherForecast],
        filteredLogs: [String] = [],
        discardedHotelsCount: Int = 0,
        discardedTransportCount: Int = 0,
        discardedPlacesCount: Int = 0
    ) {
        self.hotels = hotels
        self.transportOptions = transportOptions
        self.places = places
        self.weather = weather
        self.filteredLogs = filteredLogs
        self.discardedHotelsCount = discardedHotelsCount
        self.discardedTransportCount = discardedTransportCount
        self.discardedPlacesCount = discardedPlacesCount
    }
}

/// Errors occurring when hard deterministic constraints cannot be satisfied.
public enum ConstraintViolationError: LocalizedError, Equatable, Sendable {
    case budgetInsufficientForEssentialNeeds(required: Double, allocated: Double, currency: String)
    case noEligibleAccommodationsFound(reason: String)
    case noEligibleTransportationFound(reason: String)
    case noEligiblePlacesFound(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .budgetInsufficientForEssentialNeeds(let required, let allocated, let currency):
            return "Total budget of \(currency) \(Int(allocated)) is below the essential minimum requirement of \(currency) \(Int(required)) for accommodation, transit, and meals."
        case .noEligibleAccommodationsFound(let reason):
            return "No hotels satisfied hard constraints: \(reason)"
        case .noEligibleTransportationFound(let reason):
            return "No transport options satisfied hard constraints: \(reason)"
        case .noEligiblePlacesFound(let reason):
            return "No attractions or places satisfied group suitability rules: \(reason)"
        }
    }
}

/// Protocol defining the contract for hard constraint evaluation.
public protocol ConstraintEngineProtocol: Sendable {
    func applyConstraints(
        to searchResults: SearchResultsBundle,
        for request: TripRequest
    ) throws -> FilteredCandidatesBundle
}

/// Deterministic Business Constraint Engine coordinating domain rules.
public final class ConstraintEngine: ConstraintEngineProtocol, Sendable {
    private let budgetEvaluator: BudgetRuleEvaluator
    private let groupEvaluator: GroupRuleEvaluator
    
    public init(
        budgetEvaluator: BudgetRuleEvaluator = BudgetRuleEvaluator(),
        groupEvaluator: GroupRuleEvaluator = GroupRuleEvaluator()
    ) {
        self.budgetEvaluator = budgetEvaluator
        self.groupEvaluator = groupEvaluator
    }
    
    public func applyConstraints(
        to searchResults: SearchResultsBundle,
        for request: TripRequest
    ) throws -> FilteredCandidatesBundle {
        var logs: [String] = []
        let nights = max(1, request.numberOfDays - 1)
        let travelers = request.travelersCount
        
        // 1. Minimum Baseline Reserve Calculation via BudgetRuleEvaluator
        let essentialMealsReserve = budgetEvaluator.calculateEssentialReserve(travelers: travelers, days: request.numberOfDays)
        let maxAvailableForTransportAndStay = budgetEvaluator.availableForTransportAndStay(
            totalBudget: request.budget,
            travelers: travelers,
            days: request.numberOfDays
        )
        
        if maxAvailableForTransportAndStay <= 0 {
            throw ConstraintViolationError.budgetInsufficientForEssentialNeeds(
                required: essentialMealsReserve + 2000,
                allocated: request.budget,
                currency: request.currency
            )
        }
        
        logs.append("Reserved \(request.currency) \(Int(essentialMealsReserve)) for essential meals/local transit.")
        
        // 2. Filter Accommodations (Hotels)
        var eligibleHotels: [HotelCandidate] = []
        var discardedHotels = 0
        
        for hotel in searchResults.hotels {
            // Group Dynamic Rule
            if !groupEvaluator.isHotelEligible(hotel: hotel, groupType: request.groupType) {
                discardedHotels += 1
                logs.append("Filtered hotel '\(hotel.name)': Not certified family-friendly for family group.")
                continue
            }
            
            // Budget Ceiling Rule
            let stayCost = hotel.totalCost(for: travelers, nights: nights)
            if !budgetEvaluator.isStayWithinCeiling(stayCost: stayCost, availablePool: maxAvailableForTransportAndStay) && searchResults.hotels.count > 1 {
                discardedHotels += 1
                logs.append("Filtered hotel '\(hotel.name)': Total cost \(request.currency) \(Int(stayCost)) exceeds stay ceiling.")
                continue
            }
            
            eligibleHotels.append(hotel)
        }
        
        // Safety Fallback: If budget filter eliminated all hotels, keep the cheapest available
        if eligibleHotels.isEmpty && !searchResults.hotels.isEmpty {
            let sortedByPrice = searchResults.hotels.sorted {
                $0.totalCost(for: travelers, nights: nights) < $1.totalCost(for: travelers, nights: nights)
            }
            eligibleHotels = Array(sortedByPrice.prefix(3))
            logs.append("Warning: Strict budget ceiling exceeded. Retained \(eligibleHotels.count) most economical hotels.")
        }
        
        guard !eligibleHotels.isEmpty else {
            throw ConstraintViolationError.noEligibleAccommodationsFound(reason: "No accommodations available within destination capacity constraints.")
        }
        
        // 3. Filter Transportation Options
        var eligibleTransport: [TransportOption] = []
        var discardedTransport = 0
        
        for transport in searchResults.transportOptions {
            let totalTransportCost = transport.totalPrice(for: travelers)
            if !budgetEvaluator.isTransportWithinCeiling(transportCost: totalTransportCost, availablePool: maxAvailableForTransportAndStay) && searchResults.transportOptions.count > 1 {
                discardedTransport += 1
                logs.append("Filtered transport '\(transport.title)': Cost \(request.currency) \(Int(totalTransportCost)) exceeds transport ceiling.")
                continue
            }
            
            eligibleTransport.append(transport)
        }
        
        // Safety fallback for transport
        if eligibleTransport.isEmpty && !searchResults.transportOptions.isEmpty {
            let sortedByPrice = searchResults.transportOptions.sorted {
                $0.totalPrice(for: travelers) < $1.totalPrice(for: travelers)
            }
            eligibleTransport = Array(sortedByPrice.prefix(2))
            logs.append("Warning: Strict transport ceiling exceeded. Retained \(eligibleTransport.count) most economical transport options.")
        }
        
        // 4. Filter Places / Attractions by Group Suitability
        var eligiblePlaces: [PlaceCandidate] = []
        var discardedPlaces = 0
        
        for place in searchResults.places {
            if !groupEvaluator.isPlaceEligible(place: place, groupType: request.groupType) {
                discardedPlaces += 1
                logs.append("Filtered place '\(place.name)': Not suitable for \(request.groupType.rawValue) dynamic.")
                continue
            }
            eligiblePlaces.append(place)
        }
        
        // Fallback for places
        if eligiblePlaces.count < request.numberOfDays * 2 {
            eligiblePlaces = searchResults.places
            logs.append("Expanded place candidates to ensure sufficient itinerary variety.")
        }
        
        guard !eligiblePlaces.isEmpty else {
            throw ConstraintViolationError.noEligiblePlacesFound(reason: "No attractions or places available matching group parameters.")
        }
        
        return FilteredCandidatesBundle(
            hotels: eligibleHotels,
            transportOptions: eligibleTransport,
            places: eligiblePlaces,
            weather: searchResults.weather,
            filteredLogs: logs,
            discardedHotelsCount: discardedHotels,
            discardedTransportCount: discardedTransport,
            discardedPlacesCount: discardedPlaces
        )
    }
}
