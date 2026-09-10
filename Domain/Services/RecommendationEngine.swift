import Foundation

/// A travel candidate paired with its normalized machine learning / utility score and human-readable explanation.
public struct ScoredCandidate<T: Sendable>: Sendable {
    public let candidate: T
    public let score: Double // 0.0 - 1.0
    public let rationale: RecommendationRationale
    
    public init(candidate: T, score: Double, rationale: RecommendationRationale) {
        self.candidate = candidate
        self.score = score
        self.rationale = rationale
    }
}

/// Protocol defining the contract for on-device candidate personalization and ranking.
public protocol RecommendationEngineProtocol: Sendable {
    func rankHotels(
        candidates: [HotelCandidate],
        request: TripRequest
    ) async throws -> [ScoredCandidate<HotelCandidate>]
    
    func rankTransport(
        candidates: [TransportOption],
        request: TripRequest
    ) async throws -> [ScoredCandidate<TransportOption>]
    
    func rankPlaces(
        candidates: [PlaceCandidate],
        request: TripRequest
    ) async throws -> [ScoredCandidate<PlaceCandidate>]
}
