import Foundation

public protocol TripRepositoryProtocol: Sendable {
    func saveTrip(_ itinerary: TripItinerary, for userId: String) async throws
    func fetchTrips(for userId: String) async throws -> [TripItinerary]
    func fetchTrip(byId id: UUID) async throws -> TripItinerary?
    func deleteTrip(byId id: UUID) async throws
}

public protocol UserRepositoryProtocol: Sendable {
    func fetchProfile(for userId: String) async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws
}

public protocol FeedbackRepositoryProtocol: Sendable {
    func submitFeedback(_ feedback: UserFeedback) async throws
    func fetchFeedback(for tripId: UUID) async throws -> [UserFeedback]
}
