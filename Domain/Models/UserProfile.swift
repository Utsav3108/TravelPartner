import Foundation

/// Application user profile stored persistently in Firebase.
public struct UserProfile: Identifiable, Codable, Equatable, Sendable {
    public let id: String // Firebase Auth UID
    public var email: String
    public var displayName: String
    public var preferredCurrency: String
    public var defaultGroupType: GroupType
    public var defaultPace: PacePreference
    public var savedPreferences: Set<TravelPreference>
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        email: String = "traveler@example.com",
        displayName: String = "Adventurous Explorer",
        preferredCurrency: String = "INR",
        defaultGroupType: GroupType = .friends,
        defaultPace: PacePreference = .moderate,
        savedPreferences: Set<TravelPreference> = [.nature, .relaxation, .adventure],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.preferredCurrency = preferredCurrency
        self.defaultGroupType = defaultGroupType
        self.defaultPace = defaultPace
        self.savedPreferences = savedPreferences
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// User feedback signal persisted in Firebase to personalize future ML recommendations.
public struct UserFeedback: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let tripId: UUID
    public let rating: Int // 1 to 5 stars
    public let comment: String
    public let likedItemIds: [String]
    public let dislikedItemIds: [String]
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        tripId: UUID,
        rating: Int,
        comment: String,
        likedItemIds: [String] = [],
        dislikedItemIds: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.tripId = tripId
        self.rating = max(1, min(5, rating))
        self.comment = comment
        self.likedItemIds = likedItemIds
        self.dislikedItemIds = dislikedItemIds
        self.createdAt = createdAt
    }
}

/// Lightweight snapshot of a saved trip for browsing in Firebase collections.
public struct SavedTripSummary: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let destination: String
    public let origin: String
    public let startDate: Date
    public let numberOfDays: Int
    public let travelersCount: Int
    public let groupType: GroupType
    public let totalCost: Double
    public let currency: String
    public let hotelName: String?
    public let transportMode: TransportMode?
    public let savedAt: Date
    
    public init(from itinerary: TripItinerary) {
        self.id = itinerary.id
        self.destination = itinerary.destination
        self.origin = itinerary.origin
        self.startDate = itinerary.startDate
        self.numberOfDays = itinerary.numberOfDays
        self.travelersCount = itinerary.travelersCount
        self.groupType = itinerary.groupType
        self.totalCost = itinerary.totalEstimatedCost
        self.currency = itinerary.currency
        self.hotelName = itinerary.selectedHotel?.name
        self.transportMode = itinerary.selectedTransportation?.mode
        self.savedAt = Date()
    }
}
