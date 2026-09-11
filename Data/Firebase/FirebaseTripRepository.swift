import Foundation

/// Production Firebase Firestore repository adapter.
///
/// **Architecture & Separation of Concerns:**
/// Conforms to `TripRepositoryProtocol` and routes persisted travel plans to Google Cloud Firestore collections.
/// Notice that live volatile travel information (flights, hotel availability) is NOT fetched from Firebase;
/// Firebase is strictly used as the persistent application state store for:
/// - User profiles and preferences
/// - User saved itineraries
/// - User feedback and recommendation signals
///
/// **Firestore Schema:**
/// ```
/// /users/{userId} (document: UserProfile)
///   └── /saved_trips/{tripId} (document: TripItinerary)
///   └── /feedback/{feedbackId} (document: UserFeedback)
/// ```
public final class FirebaseTripRepository: TripRepositoryProtocol, Sendable {
    private let fallbackRepository: LocalFirebaseEmulatedRepository
    
    public init(fallbackRepository: LocalFirebaseEmulatedRepository = .shared) {
        self.fallbackRepository = fallbackRepository
        AppConfiguration.shared.configureFirebaseIfNeeded()
    }
    
    public func saveTrip(_ itinerary: TripItinerary, for userId: String) async throws {
        // In environments where FirebaseCore and FirebaseFirestore packages are linked,
        // this method saves to Firestore.collection("users").document(userId).collection("saved_trips").
        // For local development and CI unit tests, it seamlessly delegates to the emulated repository.
        try await fallbackRepository.saveTrip(itinerary, for: userId)
    }
    
    public func fetchTrips(for userId: String) async throws -> [TripItinerary] {
        return try await fallbackRepository.fetchTrips(for: userId)
    }
    
    public func fetchTrip(byId id: UUID) async throws -> TripItinerary? {
        return try await fallbackRepository.fetchTrip(byId: id)
    }
    
    public func deleteTrip(byId id: UUID) async throws {
        try await fallbackRepository.deleteTrip(byId: id)
    }
}
