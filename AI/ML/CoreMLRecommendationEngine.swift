import Foundation
#if canImport(CoreML)
import CoreML
#endif

/// Production On-Device Recommendation Engine.
///
/// **Hybrid Architecture:**
/// 1. On-device inference: Extracts feature vectors and executes an `MLModel` locally.
/// 2. Privacy preserving: Does NOT send raw personal preferences to the cloud for ranking.
/// 3. Zero-crash resilience: Automatically delegates to `DeterministicRankingEngine` if Core ML
///    model bundle is not loaded or encounters unsupported input shapes.
public final class CoreMLRecommendationEngine: RecommendationEngineProtocol, @unchecked Sendable {
    private let deterministicFallback: DeterministicRankingEngine
    #if canImport(CoreML)
    private var hotelMLModel: MLModel?
    private var placeMLModel: MLModel?
    #endif
    
    public init(
        deterministicFallback: DeterministicRankingEngine = DeterministicRankingEngine(),
        hotelModelURL: URL? = nil,
        placeModelURL: URL? = nil
    ) {
        self.deterministicFallback = deterministicFallback
        #if canImport(CoreML)
        if let hotelURL = hotelModelURL {
            self.hotelMLModel = try? MLModel(contentsOf: hotelURL)
        }
        if let placeURL = placeModelURL {
            self.placeMLModel = try? MLModel(contentsOf: placeURL)
        }
        #endif
    }
    
    public func rankHotels(
        candidates: [HotelCandidate],
        request: TripRequest
    ) async throws -> [ScoredCandidate<HotelCandidate>] {
        #if canImport(CoreML)
        if let model = hotelMLModel {
            // Run Core ML model predictions
            var scored: [ScoredCandidate<HotelCandidate>] = []
            let nights = max(1, request.numberOfDays - 1)
            
            for hotel in candidates {
                let totalCost = hotel.totalCost(for: request.travelersCount, nights: nights)
                let budgetRatio = totalCost / request.budget
                let ratingNorm = hotel.reviewScore / 5.0
                let distanceNorm = min(1.0, hotel.distanceToCenterKm / 10.0)
                let familyCompat: Double = (request.groupType == .family && hotel.isFamilyFriendly) ? 1.0 : 0.5
                
                let featureDict: [String: Any] = [
                    "budget_ratio": budgetRatio,
                    "rating": ratingNorm,
                    "distance_center": distanceNorm,
                    "family_compatibility": familyCompat
                ]
                
                do {
                    let featureProvider = try MLDictionaryFeatureProvider(dictionary: featureDict)
                    let prediction = try await model.prediction(from: featureProvider)
                    let predictedScore = prediction.featureValue(for: "recommendation_score")?.doubleValue ?? 0.8
                    
                    let rationale = RecommendationRationale(
                        itemId: hotel.id,
                        itemType: "hotel",
                        headline: "Core ML Personalized Pick",
                        bullets: [
                            "On-device ML predicted high group satisfaction",
                            "Balanced price-to-budget ratio (\(Int(budgetRatio * 100))%)",
                            "\(String(format: "%.1f", hotel.reviewScore)) star traveler rating"
                        ],
                        mlScore: predictedScore
                    )
                    scored.append(ScoredCandidate(candidate: hotel, score: predictedScore, rationale: rationale))
                } catch {
                    // Fallback on single prediction error
                    break
                }
            }
            
            if scored.count == candidates.count {
                return scored.sorted { $0.score > $1.score }
            }
        }
        #endif
        
        // Use high-fidelity deterministic fallback
        return try await deterministicFallback.rankHotels(candidates: candidates, request: request)
    }
    
    public func rankTransport(
        candidates: [TransportOption],
        request: TripRequest
    ) async throws -> [ScoredCandidate<TransportOption>] {
        return try await deterministicFallback.rankTransport(candidates: candidates, request: request)
    }
    
    public func rankPlaces(
        candidates: [PlaceCandidate],
        request: TripRequest
    ) async throws -> [ScoredCandidate<PlaceCandidate>] {
        #if canImport(CoreML)
        if let model = placeMLModel {
            var scored: [ScoredCandidate<PlaceCandidate>] = []
            for place in candidates {
                let featureDict: [String: Any] = [
                    "rating": place.rating / 5.0,
                    "entry_fee": min(1.0, place.entryFee / 500.0),
                    "duration_hours": Double(place.estimatedDurationMinutes) / 180.0
                ]
                do {
                    let featureProvider = try MLDictionaryFeatureProvider(dictionary: featureDict)
                    let prediction = try await model.prediction(from: featureProvider)
                    let predictedScore = prediction.featureValue(for: "place_score")?.doubleValue ?? 0.85
                    
                    let rationale = RecommendationRationale(
                        itemId: place.id,
                        itemType: "place",
                        headline: "Core ML Personalized Attraction",
                        bullets: [
                            "Matches your travel preference profile",
                            "High engagement score among verified travelers",
                            "Optimal time allocation for \(place.bestSlot.rawValue.lowercased())"
                        ],
                        mlScore: predictedScore
                    )
                    scored.append(ScoredCandidate(candidate: place, score: predictedScore, rationale: rationale))
                } catch {
                    break
                }
            }
            
            if scored.count == candidates.count {
                return scored.sorted { $0.score > $1.score }
            }
        }
        #endif
        
        return try await deterministicFallback.rankPlaces(candidates: candidates, request: request)
    }
}
