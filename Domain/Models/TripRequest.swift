import Foundation

/// Defines the traveler group dynamic, influencing accommodation capacity and activity filtering.
public enum GroupType: String, Codable, CaseIterable, Sendable {
    case solo = "Solo"
    case couple = "Couple"
    case friends = "Friends"
    case family = "Family"
    case business = "Business"
    
    public var iconName: String {
        switch self {
        case .solo: return "person.fill"
        case .couple: return "person.2.fill"
        case .friends: return "person.3.fill"
        case .family: return "figure.2.and.child.holdinghands"
        case .business: return "briefcase.fill"
        }
    }
}

/// Directionality of the transport requirements.
public enum TripType: String, Codable, CaseIterable, Sendable {
    case roundTrip = "Round Trip"
    case oneWay = "One Way"
}

/// Granular travel interests for personalized recommendation.
public enum TravelPreference: String, Codable, CaseIterable, Hashable, Sendable {
    case nature = "Nature & Scenic"
    case culture = "Culture & Heritage"
    case adventure = "Adventure & Sports"
    case relaxation = "Relaxation & Wellness"
    case foodie = "Food & Culinary"
    case shopping = "Shopping & Markets"
    case religious = "Spiritual & Temples"
    case budgetFriendly = "Budget Conscious"
    case luxury = "Luxury & Comfort"
    
    public var iconName: String {
        switch self {
        case .nature: return "leaf.fill"
        case .culture: return "building.columns.fill"
        case .adventure: return "figure.hiking"
        case .relaxation: return "sparkles"
        case .foodie: return "fork.knife"
        case .shopping: return "bag.fill"
        case .religious: return "sun.max.fill"
        case .budgetFriendly: return "banknote.fill"
        case .luxury: return "crown.fill"
        }
    }
}

/// Daily pace of activities.
public enum PacePreference: String, Codable, CaseIterable, Sendable {
    case relaxed = "Relaxed"   // ~2 activities/day
    case moderate = "Moderate" // ~3 activities/day
    case packed = "Packed"     // 4+ activities/day
    
    public var maxActivitiesPerDay: Int {
        switch self {
        case .relaxed: return 2
        case .moderate: return 3
        case .packed: return 5
        }
    }
}

/// Dietary constraints for restaurant and meal planning.
public enum DietaryPreference: String, Codable, CaseIterable, Sendable {
    case none = "No Restrictions"
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case halal = "Halal"
    case jain = "Jain (Strict Veg)"
    case glutenFree = "Gluten-Free"
}

/// Validation errors that can be thrown when constructing or processing a `TripRequest`.
public enum TripRequestValidationError: LocalizedError, Equatable, Sendable {
    case emptyDestination
    case emptyOrigin
    case invalidDuration(Int)
    case invalidTravelersCount(Int)
    case insufficientBudget(Double, String)
    case invalidDates(start: Date, end: Date)
    
    public var errorDescription: String? {
        switch self {
        case .emptyDestination:
            return "Destination cannot be empty."
        case .emptyOrigin:
            return "Starting origin cannot be empty."
        case .invalidDuration(let days):
            return "Trip duration must be at least 1 day (received \(days))."
        case .invalidTravelersCount(let count):
            return "Travelers count must be at least 1 person (received \(count))."
        case .insufficientBudget(let amount, let currency):
            return "Total budget of \(currency) \(Int(amount)) is insufficient for the requested trip parameters."
        case .invalidDates(let start, let end):
            return "End date (\(end)) must be on or after start date (\(start))."
        }
    }
}

/// Immutable, thread-safe specification of a user's travel requirements.
public struct TripRequest: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let origin: String
    public let destination: String
    public let originStationCode: String?
    public let destinationStationCode: String?
    public var startDate: Date
    public var endDate: Date
    public let numberOfDays: Int
    public let travelersCount: Int
    public let groupType: GroupType
    public let budget: Double
    public let currency: String
    public let tripType: TripType
    public let preferences: Set<TravelPreference>
    public let pace: PacePreference
    public let dietary: DietaryPreference
    public let customNotes: String?
    public var maxLayoverMinutes: Int
    
    public var maxLayoverHours: Int {
        return maxLayoverMinutes / 60
    }
    
    public init(
        id: UUID = UUID(),
        origin: String,
        destination: String,
        originStationCode: String? = nil,
        destinationStationCode: String? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        numberOfDays: Int,
        travelersCount: Int,
        groupType: GroupType = .friends,
        budget: Double,
        currency: String = "INR",
        tripType: TripType = .roundTrip,
        preferences: Set<TravelPreference> = [.nature, .relaxation],
        pace: PacePreference = .moderate,
        dietary: DietaryPreference = .none,
        customNotes: String? = nil,
        maxLayoverMinutes: Int = 300
    ) {
        self.id = id
        self.origin = origin.trimmingCharacters(in: .whitespacesAndNewlines)
        self.destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        self.originStationCode = originStationCode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? originStationCode?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        self.destinationStationCode = destinationStationCode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? destinationStationCode?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        self.startDate = startDate
        self.numberOfDays = max(1, numberOfDays)
        
        let calculatedEnd = Calendar.current.date(byAdding: .day, value: numberOfDays, to: startDate) ?? startDate
        self.endDate = endDate ?? calculatedEnd
        self.travelersCount = max(1, travelersCount)
        self.groupType = groupType
        self.budget = budget
        self.currency = currency
        self.tripType = tripType
        self.preferences = preferences
        self.pace = pace
        self.dietary = dietary
        self.customNotes = customNotes
        self.maxLayoverMinutes = max(60, maxLayoverMinutes)
    }
    
    /// Validates business invariants on the trip request.
    public func validate() throws {
        guard !destination.isEmpty else {
            throw TripRequestValidationError.emptyDestination
        }
        guard !origin.isEmpty else {
            throw TripRequestValidationError.emptyOrigin
        }
        guard numberOfDays >= 1 else {
            throw TripRequestValidationError.invalidDuration(numberOfDays)
        }
        guard travelersCount >= 1 else {
            throw TripRequestValidationError.invalidTravelersCount(travelersCount)
        }
        guard budget >= 1000 else {
            throw TripRequestValidationError.insufficientBudget(budget, currency)
        }
        guard endDate >= startDate else {
            throw TripRequestValidationError.invalidDates(start: startDate, end: endDate)
        }
    }
    
    /// Estimated budget per traveler.
    public var budgetPerTraveler: Double {
        return budget / Double(travelersCount)
    }
    
    /// Estimated budget per day.
    public var budgetPerDay: Double {
        return budget / Double(numberOfDays)
    }
    
    /// Human-friendly summary string.
    public var summaryDescription: String {
        return "\(numberOfDays) days in \(destination) from \(origin) for \(travelersCount) (\(groupType.rawValue)) with budget \(currency) \(Int(budget))"
    }
}
