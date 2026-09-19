import Foundation
import FirebaseCore
import FirebaseFirestore

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
public final class FirebaseTripRepository: TripRepositoryProtocol, @unchecked Sendable {
    private let fallbackRepository: LocalFirebaseEmulatedRepository
    private let lock = NSLock()
    private var _lastActiveUserId: String = "demo_user"
    
    public var lastActiveUserId: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _lastActiveUserId
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _lastActiveUserId = newValue
        }
    }
    
    private var isFirebaseReady: Bool {
        AppConfiguration.shared.configureFirebaseIfNeeded()
        return FirebaseApp.app() != nil
    }
    
    private var firestore: Firestore? {
        guard isFirebaseReady else { return nil }
        return Firestore.firestore()
    }
    
    public init(fallbackRepository: LocalFirebaseEmulatedRepository = .shared) {
        self.fallbackRepository = fallbackRepository
        AppConfiguration.shared.configureFirebaseIfNeeded()
    }
    
    public func saveTrip(_ itinerary: TripItinerary, for userId: String) async throws {
        self.lastActiveUserId = userId
        
        var saved = itinerary
        saved.isSavedToFirebase = true
        saved.updatedAt = Date()
        
        let tripIdString = saved.id.uuidString
        
        if let firestore = self.firestore {
            let docRef = firestore
                .collection("users")
                .document(userId)
                .collection("saved_trips")
                .document(tripIdString)
            
            do {
                try docRef.setData(from: saved)
                AppLogger.shared.logAPISuccess(
                    endpoint: "firestore/users/\(userId)/saved_trips/\(tripIdString)",
                    method: "SET",
                    statusCode: 200,
                    payloadSummary: "Saved trip to \(saved.destination) in Firestore"
                )
            } catch {
                AppLogger.shared.error(
                    "Firestore setData failed for trip \(tripIdString): \(error.localizedDescription)",
                    category: .api
                )
            }
        }
        
        // Mirror write to fallback repository for immediate offline/cached availability
        try await fallbackRepository.saveTrip(saved, for: userId)
    }
    
    public func fetchTrips(for userId: String) async throws -> [TripItinerary] {
        self.lastActiveUserId = userId
        
        if let firestore = self.firestore {
            do {
                let snapshot = try await firestore
                    .collection("users")
                    .document(userId)
                    .collection("saved_trips")
                    .order(by: "createdAt", descending: true)
                    .getDocuments()
                
                let trips: [TripItinerary] = snapshot.documents.compactMap { doc in
                    do {
                        return try doc.data(as: TripItinerary.self)
                    } catch {
                        AppLogger.shared.error(
                            "Failed decoding trip \(doc.documentID) from Firestore: \(error)",
                            category: .api
                        )
                        return nil
                    }
                }
                
                AppLogger.shared.logAPISuccess(
                    endpoint: "firestore/users/\(userId)/saved_trips",
                    method: "GET",
                    statusCode: 200,
                    payloadSummary: "Retrieved \(trips.count) trip(s) from Firestore"
                )
                
                if !trips.isEmpty {
                    for trip in trips {
                        try? await fallbackRepository.saveTrip(trip, for: userId)
                    }
                    return trips
                }
            } catch {
                AppLogger.shared.error(
                    "Firestore fetchTrips failed: \(error.localizedDescription). Falling back to local store.",
                    category: .api
                )
            }
        }
        
        return try await fallbackRepository.fetchTrips(for: userId)
    }
    
    public func fetchTrip(byId id: UUID) async throws -> TripItinerary? {
        let tripIdString = id.uuidString
        let userId = self.lastActiveUserId
        
        if let firestore = self.firestore {
            // 1. Try active user's saved_trips collection first
            let userDoc = firestore
                .collection("users")
                .document(userId)
                .collection("saved_trips")
                .document(tripIdString)
            
            if let snapshot = try? await userDoc.getDocument(), snapshot.exists {
                if let trip = try? snapshot.data(as: TripItinerary.self) {
                    AppLogger.shared.logAPISuccess(
                        endpoint: "firestore/users/\(userId)/saved_trips/\(tripIdString)",
                        method: "GET",
                        statusCode: 200,
                        payloadSummary: "Found itinerary for \(trip.destination)"
                    )
                    return trip
                }
            }
            
            // 2. Try collectionGroup if not found in active user's collection
            do {
                let query = try await firestore
                    .collectionGroup("saved_trips")
                    .whereField("id", isEqualTo: tripIdString)
                    .limit(to: 1)
                    .getDocuments()
                
                if let doc = query.documents.first, let trip = try? doc.data(as: TripItinerary.self) {
                    AppLogger.shared.logAPISuccess(
                        endpoint: "firestore/saved_trips/\(tripIdString)",
                        method: "GET",
                        statusCode: 200,
                        payloadSummary: "Found itinerary for \(trip.destination) via collectionGroup"
                    )
                    return trip
                }
            } catch {
                AppLogger.shared.info(
                    "CollectionGroup lookup skipped or failed: \(error.localizedDescription)",
                    category: .api
                )
            }
        }
        
        return try await fallbackRepository.fetchTrip(byId: id)
    }
    
    public func deleteTrip(byId id: UUID) async throws {
        let tripIdString = id.uuidString
        let userId = self.lastActiveUserId
        
        if let firestore = self.firestore {
            // 1. Delete from active user's saved_trips collection
            let userDoc = firestore
                .collection("users")
                .document(userId)
                .collection("saved_trips")
                .document(tripIdString)
            
            do {
                try await userDoc.delete()
                AppLogger.shared.logAPISuccess(
                    endpoint: "firestore/users/\(userId)/saved_trips/\(tripIdString)",
                    method: "DELETE",
                    statusCode: 200,
                    payloadSummary: "Deleted trip from Firestore user collection"
                )
            } catch {
                AppLogger.shared.error(
                    "Failed deleting trip \(tripIdString) from Firestore: \(error.localizedDescription)",
                    category: .api
                )
            }
            
            // 2. Also try collectionGroup to catch document if stored under a different userId
            do {
                let query = try await firestore
                    .collectionGroup("saved_trips")
                    .whereField("id", isEqualTo: tripIdString)
                    .getDocuments()
                
                for doc in query.documents {
                    try await doc.reference.delete()
                }
            } catch {
                // Ignore collection group indexing errors if already deleted
            }
        }
        
        try await fallbackRepository.deleteTrip(byId: id)
    }
}
