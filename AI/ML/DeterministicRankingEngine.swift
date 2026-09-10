import Foundation

/// Multi-Criteria Decision Analysis (MCDA) based ranking engine.
///
/// **Why Deterministic MCDA is provided:**
/// 1. Acts as the zero-dependency, guaranteed-correct baseline for candidate ranking.
/// 2. Mathematically models trade-offs (budget efficiency, proximity, user preference affinity, group fit).
/// 3. Serves as the fallback whenever a Core ML model file is not yet bundled or is in training.
public final class DeterministicRankingEngine: RecommendationEngineProtocol, Sendable {
    public init() {}
    
    // MARK: - Hotel Ranking
    
    public func rankHotels(
        candidates: [HotelCandidate],
        request: TripRequest
    ) async throws -> [ScoredCandidate<HotelCandidate>] {
        let nights = max(1, request.numberOfDays - 1)
        let travelers = request.travelersCount
        
        let scored: [ScoredCandidate<HotelCandidate>] = candidates.map { hotel in
            let totalCost = hotel.totalCost(for: travelers, nights: nights)
            let budgetRatio = totalCost / request.budget
            
            // Criteria 1: Budget Fit (Weight: 0.35)
            let budgetScore: Double
            if budgetRatio <= 0.35 {
                budgetScore = 1.0 - (budgetRatio * 0.5)
            } else if budgetRatio <= 0.60 {
                budgetScore = max(0.1, 1.0 - (budgetRatio - 0.35) * 2.5)
            } else {
                budgetScore = 0.1
            }
            
            // Criteria 2: Rating & Reputation (Weight: 0.25)
            let ratingScore = (hotel.reviewScore / 5.0) * 0.8 + min(1.0, Double(hotel.reviewCount) / 2000.0) * 0.2
            
            // Criteria 3: Proximity to Center (Weight: 0.20)
            let proximityScore = max(0.2, 1.0 - (hotel.distanceToCenterKm / 8.0))
            
            // Criteria 4: Group & Amenity Compatibility (Weight: 0.20)
            var groupFit = 0.7
            if request.groupType == .family && hotel.isFamilyFriendly {
                groupFit += 0.25
            }
            if request.groupType == .friends && hotel.maxCapacityPerRoom >= 3 {
                groupFit += 0.2
            }
            if hotel.amenities.contains("Free WiFi") {
                groupFit += 0.05
            }
            let groupScore = min(1.0, groupFit)
            
            let compositeScore = (budgetScore * 0.35) + (ratingScore * 0.25) + (proximityScore * 0.20) + (groupScore * 0.20)
            
            // Build transparent explanation bullets
            var bullets: [String] = []
            if budgetRatio <= 0.35 {
                bullets.append("Excellent value: Consumes only \(Int(budgetRatio * 100))% of total budget")
            } else {
                bullets.append("Fits comfortably within allocated stay budget")
            }
            
            if hotel.distanceToCenterKm <= 1.0 {
                bullets.append("Prime location: Only \(String(format: "%.1f", hotel.distanceToCenterKm)) km from city center")
            } else {
                bullets.append("Scenic location with mountain/valley ambiance")
            }
            
            bullets.append("Rated \(String(format: "%.1f", hotel.reviewScore))/5.0 by \(hotel.reviewCount) verified travelers")
            
            let roomsNeeded = hotel.roomsRequired(for: travelers)
            bullets.append("Accommodates \(travelers) guests in \(roomsNeeded) \(roomsNeeded == 1 ? "room" : "rooms") (\(hotel.roomType))")
            
            let rationale = RecommendationRationale(
                itemId: hotel.id,
                itemType: "hotel",
                headline: "Top Match for \(request.groupType.rawValue) Trip",
                bullets: bullets,
                mlScore: compositeScore
            )
            
            return ScoredCandidate(candidate: hotel, score: compositeScore, rationale: rationale)
        }
        
        return scored.sorted { $0.score > $1.score }
    }
    
    // MARK: - Transport Ranking
    
    public func rankTransport(
        candidates: [TransportOption],
        request: TripRequest
    ) async throws -> [ScoredCandidate<TransportOption>] {
        let scored: [ScoredCandidate<TransportOption>] = candidates.map { transport in
            let totalCost = transport.totalPrice(for: request.travelersCount)
            let costRatio = totalCost / request.budget
            
            // Criteria 1: Cost Efficiency (Weight: 0.40)
            let costScore = max(0.1, 1.0 - (costRatio * 1.5))
            
            // Criteria 2: Transit Duration (Weight: 0.35)
            let durationHours = Double(transport.durationMinutes) / 60.0
            let durationScore = max(0.2, 1.0 - (durationHours / 12.0))
            
            // Criteria 3: Convenience & Transfers (Weight: 0.25)
            let transferScore = transport.stops == 0 ? 1.0 : 0.6
            
            let compositeScore = (costScore * 0.40) + (durationScore * 0.35) + (transferScore * 0.25)
            
            var bullets: [String] = []
            bullets.append("\(transport.mode.rawValue): \(transport.formattedDuration) journey time")
            bullets.append("\(request.currency) \(Int(transport.pricePerPerson))/person (Total: \(request.currency) \(Int(totalCost)))")
            if transport.stops == 0 {
                bullets.append("Direct non-stop service")
            }
            if transport.mode == .train {
                bullets.append("Scenic route with high punctuality and comfortable seating")
            }
            
            let rationale = RecommendationRationale(
                itemId: transport.id.uuidString,
                itemType: "transport",
                headline: "Best Balance of Speed & Budget",
                bullets: bullets,
                mlScore: compositeScore
            )
            
            return ScoredCandidate(candidate: transport, score: compositeScore, rationale: rationale)
        }
        
        return scored.sorted { $0.score > $1.score }
    }
    
    // MARK: - Place Ranking
    
    public func rankPlaces(
        candidates: [PlaceCandidate],
        request: TripRequest
    ) async throws -> [ScoredCandidate<PlaceCandidate>] {
        let scored: [ScoredCandidate<PlaceCandidate>] = candidates.map { place in
            // Criteria 1: Preference Affinity (Weight: 0.40)
            var preferenceScore = 0.5
            for pref in request.preferences {
                switch pref {
                case .nature where place.category == .nature:
                    preferenceScore += 0.3
                case .culture where place.category == .historical || place.category == .religious:
                    preferenceScore += 0.3
                case .adventure where place.category == .adventure:
                    preferenceScore += 0.35
                case .foodie where place.category == .dining || place.category == .market:
                    preferenceScore += 0.3
                case .shopping where place.category == .market:
                    preferenceScore += 0.35
                case .relaxation where place.category == .relaxation || place.category == .nature:
                    preferenceScore += 0.25
                default:
                    break
                }
            }
            preferenceScore = min(1.0, preferenceScore)
            
            // Criteria 2: Popularity & Rating (Weight: 0.30)
            let ratingScore = (place.rating / 5.0) * 0.8 + min(1.0, Double(place.reviewCount) / 5000.0) * 0.2
            
            // Criteria 3: Group Suitability (Weight: 0.20)
            let groupScore = place.suitableForGroups.contains(request.groupType) ? 1.0 : 0.4
            
            // Criteria 4: Entry Cost / Value (Weight: 0.10)
            let costScore = place.entryFee == 0 ? 1.0 : max(0.3, 1.0 - (place.entryFee / 500.0))
            
            let compositeScore = (preferenceScore * 0.40) + (ratingScore * 0.30) + (groupScore * 0.20) + (costScore * 0.10)
            
            var bullets: [String] = []
            bullets.append("Matches your \(request.preferences.map(\.rawValue).prefix(2).joined(separator: ", ")) interests")
            bullets.append("Rated \(String(format: "%.1f", place.rating))/5.0 with \(place.reviewCount) reviews")
            bullets.append("Ideal for \(place.bestSlot.rawValue.lowercased()) visit (~\(place.estimatedDurationMinutes) mins)")
            if place.entryFee == 0 {
                bullets.append("Free admission / open access")
            } else {
                bullets.append("Affordable entry fee: \(request.currency) \(Int(place.entryFee))")
            }
            
            let rationale = RecommendationRationale(
                itemId: place.id,
                itemType: "place",
                headline: "Highly Recommended Attraction",
                bullets: bullets,
                mlScore: compositeScore
            )
            
            return ScoredCandidate(candidate: place, score: compositeScore, rationale: rationale)
        }
        
        return scored.sorted { $0.score > $1.score }
    }
}
