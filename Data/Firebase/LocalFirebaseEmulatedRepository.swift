import Foundation

/// Thread-safe local persistence repository emulating Firebase Firestore document storage.
///
/// **Why an actor is used:**
/// Multiple background Tasks may concurrently save trips, write user feedback, and read cached profiles.
/// An `actor` provides safe mutable isolation and serializes disk writes without locks or deadlocks.
public actor LocalFirebaseEmulatedRepository: TripRepositoryProtocol, UserRepositoryProtocol, FeedbackRepositoryProtocol {
    public static let shared = LocalFirebaseEmulatedRepository()
    
    private var trips: [UUID: (itinerary: TripItinerary, userId: String)] = [:]
    private var profiles: [String: UserProfile] = [:]
    private var feedbackStore: [UUID: [UserFeedback]] = [:]
    
    private let storageUrl: URL?
    
    public init(useDiskPersistence: Bool = true) {
        if useDiskPersistence {
            let fileManager = FileManager.default
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            let dir = appSupport?.appendingPathComponent("TravelPartner", isDirectory: true)
            if let dir = dir {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
                self.storageUrl = dir.appendingPathComponent("saved_trips_store.json")
            } else {
                self.storageUrl = nil
            }
        } else {
            self.storageUrl = nil
        }
        
        // Populate default demo profile
        let defaultUser = UserProfile()
        self.profiles[defaultUser.id] = defaultUser
        
        // Load initial data from disk if available
        if let url = self.storageUrl, FileManager.default.fileExists(atPath: url.path) {
            struct SerializedTripRecord: Codable {
                let itinerary: TripItinerary
                let userId: String
            }
            if let data = try? Data(contentsOf: url),
               let records = try? JSONDecoder().decode([SerializedTripRecord].self, from: data) {
                for rec in records {
                    self.trips[rec.itinerary.id] = (itinerary: rec.itinerary, userId: rec.userId)
                }
            }
        }
    }
    
    // MARK: - Trip Repository
    
    public func saveTrip(_ itinerary: TripItinerary, for userId: String) async throws {
        var saved = itinerary
        saved.isSavedToFirebase = true
        saved.updatedAt = Date()
        trips[saved.id] = (itinerary: saved, userId: userId)
        persistToDisk()
    }
    
    public func fetchTrips(for userId: String) async throws -> [TripItinerary] {
        return trips.values
            .filter { $0.userId == userId }
            .map { $0.itinerary }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    public func fetchTrip(byId id: UUID) async throws -> TripItinerary? {
        return trips[id]?.itinerary
    }
    
    public func deleteTrip(byId id: UUID) async throws {
        trips.removeValue(forKey: id)
        persistToDisk()
    }
    
    // MARK: - User Repository
    
    public func fetchProfile(for userId: String) async throws -> UserProfile {
        if let profile = profiles[userId] {
            return profile
        }
        let newProfile = UserProfile(id: userId)
        profiles[userId] = newProfile
        return newProfile
    }
    
    public func updateProfile(_ profile: UserProfile) async throws {
        var updated = profile
        updated.updatedAt = Date()
        profiles[profile.id] = updated
    }
    
    // MARK: - Feedback Repository
    
    public func submitFeedback(_ feedback: UserFeedback) async throws {
        var list = feedbackStore[feedback.tripId] ?? []
        list.append(feedback)
        feedbackStore[feedback.tripId] = list
    }
    
    public func fetchFeedback(for tripId: UUID) async throws -> [UserFeedback] {
        return feedbackStore[tripId] ?? []
    }
    
    // MARK: - Disk Persistence
    
    private func persistToDisk() {
        guard let url = storageUrl else { return }
        struct SerializedTripRecord: Codable {
            let itinerary: TripItinerary
            let userId: String
        }
        let records = trips.values.map { SerializedTripRecord(itinerary: $0.itinerary, userId: $0.userId) }
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
