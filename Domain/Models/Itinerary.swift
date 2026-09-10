import Foundation

/// A scheduled activity within a single day of travel.
public struct ItineraryActivity: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let place: PlaceCandidate
    public let timeSlot: TimeOfDaySlot
    public let scheduledTimeString: String
    public let durationMinutes: Int
    public let estimatedCost: Double
    public let transitFromPreviousMinutes: Int
    public let transitSummary: String
    public let localTip: String
    
    public init(
        id: UUID = UUID(),
        place: PlaceCandidate,
        timeSlot: TimeOfDaySlot,
        scheduledTimeString: String,
        durationMinutes: Int = 90,
        estimatedCost: Double = 0.0,
        transitFromPreviousMinutes: Int = 15,
        transitSummary: String = "15m walk / short taxi ride",
        localTip: String = "Best experienced in the morning before crowds arrive."
    ) {
        self.id = id
        self.place = place
        self.timeSlot = timeSlot
        self.scheduledTimeString = scheduledTimeString
        self.durationMinutes = durationMinutes
        self.estimatedCost = estimatedCost
        self.transitFromPreviousMinutes = transitFromPreviousMinutes
        self.transitSummary = transitSummary
        self.localTip = localTip
    }
}

/// A day-by-day container holding geographically and temporally optimized activities.
public struct DailyItinerary: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let dayNumber: Int
    public let date: Date
    public let themeTitle: String
    public let narrative: String
    public var activities: [ItineraryActivity]
    public let weather: WeatherForecast?
    public let tips: [String]
    
    public init(
        id: UUID = UUID(),
        dayNumber: Int,
        date: Date,
        themeTitle: String,
        narrative: String,
        activities: [ItineraryActivity],
        weather: WeatherForecast? = nil,
        tips: [String] = []
    ) {
        self.id = id
        self.dayNumber = dayNumber
        self.date = date
        self.themeTitle = themeTitle
        self.narrative = narrative
        self.activities = activities
        self.weather = weather
        self.tips = tips
    }
    
    /// Estimated total expense for this day (entry fees, activities, meals allowance).
    public var totalDayCost: Double {
        return activities.reduce(0.0) { $0 + $1.estimatedCost }
    }
}

/// The complete structured travel plan combining live transport, accommodation, and optimized itinerary.
public struct TripItinerary: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let tripRequestId: UUID
    public let destination: String
    public let origin: String
    public let startDate: Date
    public let endDate: Date
    public let numberOfDays: Int
    public let travelersCount: Int
    public let groupType: GroupType
    public let totalBudget: Double
    public let currency: String
    public var selectedTransportation: TransportOption?
    public var selectedHotel: HotelCandidate?
    public let roomsBooked: Int
    public var days: [DailyItinerary]
    public var totalEstimatedCost: Double
    public var budgetRemaining: Double
    public var geminiNarrative: String?
    public var recommendationRationales: [RecommendationRationale]
    public var isSavedToFirebase: Bool
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        tripRequestId: UUID,
        destination: String,
        origin: String,
        startDate: Date,
        endDate: Date,
        numberOfDays: Int,
        travelersCount: Int,
        groupType: GroupType,
        totalBudget: Double,
        currency: String = "INR",
        selectedTransportation: TransportOption?,
        selectedHotel: HotelCandidate?,
        roomsBooked: Int,
        days: [DailyItinerary],
        geminiNarrative: String? = nil,
        recommendationRationales: [RecommendationRationale] = [],
        isSavedToFirebase: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.tripRequestId = tripRequestId
        self.destination = destination
        self.origin = origin
        self.startDate = startDate
        self.endDate = endDate
        self.numberOfDays = numberOfDays
        self.travelersCount = travelersCount
        self.groupType = groupType
        self.totalBudget = totalBudget
        self.currency = currency
        self.selectedTransportation = selectedTransportation
        self.selectedHotel = selectedHotel
        self.roomsBooked = roomsBooked
        self.days = days
        self.geminiNarrative = geminiNarrative
        self.recommendationRationales = recommendationRationales
        self.isSavedToFirebase = isSavedToFirebase
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        
        // Compute costs
        var computedCost: Double = 0
        if let transport = selectedTransportation {
            computedCost += transport.totalPrice(for: travelersCount)
        }
        if let hotel = selectedHotel {
            computedCost += hotel.totalCost(for: travelersCount, nights: max(1, numberOfDays - 1))
        }
        for day in days {
            computedCost += day.totalDayCost
        }
        // Add nominal meal/local allowance per traveler per day (e.g. 500 INR/day/person)
        let mealAllowancePerDayPerPerson = 600.0
        computedCost += mealAllowancePerDayPerPerson * Double(travelersCount) * Double(numberOfDays)
        
        self.totalEstimatedCost = computedCost
        self.budgetRemaining = totalBudget - computedCost
    }
    
    /// Returns the rationale matching an item ID.
    public func rationale(for itemId: String) -> RecommendationRationale? {
        return recommendationRationales.first(where: { $0.itemId == itemId })
    }
    
    /// Whether the trip cost fits inside the user's allocated budget.
    public var isWithinBudget: Bool {
        return totalEstimatedCost <= totalBudget
    }
    
    /// Percentage of budget utilized.
    public var budgetUtilizationPercentage: Double {
        guard totalBudget > 0 else { return 100 }
        return min(100.0, (totalEstimatedCost / totalBudget) * 100.0)
    }
}
