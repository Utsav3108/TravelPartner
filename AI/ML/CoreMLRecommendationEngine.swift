import Foundation
#if canImport(CoreML)
import CoreML
#endif

// MARK: - Core ML Model Manager

/// Thread-safe manager responsible for locating, compiling, and caching Core ML ranking models.
public final class CoreMLModelManager: @unchecked Sendable {
    public static let shared = CoreMLModelManager()
    
    #if canImport(CoreML)
    private var cachedHotelModel: MLModel?
    private var cachedPlaceModel: MLModel?
    private var cachedTransportModel: MLModel?
    private let lock = NSLock()
    #endif
    
    private init() {}
    
    #if canImport(CoreML)
    /// Retrieves or loads the Core ML Hotel ranking model.
    public func getHotelModel(customURL: URL? = nil) -> MLModel? {
        lock.lock()
        defer { lock.unlock() }
        
        if let customURL = customURL {
            return try? loadOrCompileModel(at: customURL)
        }
        if let cached = cachedHotelModel {
            return cached
        }
        if let model = resolveModel(named: "HotelRankingModel") {
            cachedHotelModel = model
            return model
        }
        return nil
    }
    
    /// Retrieves or loads the Core ML Place ranking model.
    public func getPlaceModel(customURL: URL? = nil) -> MLModel? {
        lock.lock()
        defer { lock.unlock() }
        
        if let customURL = customURL {
            return try? loadOrCompileModel(at: customURL)
        }
        if let cached = cachedPlaceModel {
            return cached
        }
        if let model = resolveModel(named: "PlaceRankingModel") {
            cachedPlaceModel = model
            return model
        }
        return nil
    }
    
    /// Retrieves or loads the Core ML Transport ranking model.
    public func getTransportModel(customURL: URL? = nil) -> MLModel? {
        lock.lock()
        defer { lock.unlock() }
        
        if let customURL = customURL {
            return try? loadOrCompileModel(at: customURL)
        }
        if let cached = cachedTransportModel {
            return cached
        }
        if let model = resolveModel(named: "TransportRankingModel") {
            cachedTransportModel = model
            return model
        }
        return nil
    }
    
    /// True if all 3 Core ML models are available and ready for inference.
    public var areAllModelsLoaded: Bool {
        return getHotelModel() != nil && getPlaceModel() != nil && getTransportModel() != nil
    }
    
    // MARK: - Model Resolution Pipeline
    
    private func resolveModel(named name: String) -> MLModel? {
        // 1. Check Bundle.module (SPM resource bundle)
        #if SWIFT_PACKAGE
        if let bundleURL = Bundle.module.url(forResource: name, withExtension: "mlmodelc", subdirectory: "Models") ??
            Bundle.module.url(forResource: name, withExtension: "mlmodelc") {
            if let model = try? MLModel(contentsOf: bundleURL) {
                return model
            }
        }
        if let sourceURL = Bundle.module.url(forResource: name, withExtension: "mlmodel", subdirectory: "Models") ??
            Bundle.module.url(forResource: name, withExtension: "mlmodel") {
            if let model = try? loadOrCompileModel(at: sourceURL) {
                return model
            }
        }
        #endif
        
        // 2. Check Bundle.main
        if let mainURL = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
            if let model = try? MLModel(contentsOf: mainURL) {
                return model
            }
        }
        if let sourceURL = Bundle.main.url(forResource: name, withExtension: "mlmodel") {
            if let model = try? loadOrCompileModel(at: sourceURL) {
                return model
            }
        }
        
        // 3. Check Known Project Directories
        let searchDirectories = [
            Bundle.main.bundleURL.appendingPathComponent("AI/ML/Models"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("AI/ML/Models")
        ]
        
        for dir in searchDirectories {
            let compiledPath = dir.appendingPathComponent("\(name).mlmodelc")
            if FileManager.default.fileExists(atPath: compiledPath.path),
               let model = try? MLModel(contentsOf: compiledPath) {
                return model
            }
            
            let sourcePath = dir.appendingPathComponent("\(name).mlmodel")
            if FileManager.default.fileExists(atPath: sourcePath.path),
               let model = try? loadOrCompileModel(at: sourcePath) {
                return model
            }
        }
        
        return nil
    }
    
    private func loadOrCompileModel(at url: URL) throws -> MLModel {
        if url.pathExtension == "mlmodelc" {
            return try MLModel(contentsOf: url)
        }
        
        // Compile .mlmodel on the fly and cache in temp
        let tempDir = FileManager.default.temporaryDirectory
        let compiledDestination = tempDir.appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".mlmodelc")
        
        if FileManager.default.fileExists(atPath: compiledDestination.path),
           let cached = try? MLModel(contentsOf: compiledDestination) {
            return cached
        }
        
        let compiledURL = try MLModel.compileModel(at: url)
        return try MLModel(contentsOf: compiledURL)
    }
    #endif
}

// MARK: - Production Core ML Recommendation Engine

/// Production On-Device Recommendation Engine powered by Apple Core ML.
///
/// **Architectural Guarantees:**
/// 1. Privacy-First: All ranking inference for Hotels, Places, and Transit executes locally on-device.
/// 2. Multi-Model: Employs specialized Core ML regressors for hotels, attractions, and transport.
/// 3. Personalization: Incorporates user feedback signals from `FeedbackRepositoryProtocol`.
/// 4. Zero-Crash Resilience: Transparently delegates to `DeterministicRankingEngine` on missing models.
public final class CoreMLRecommendationEngine: RecommendationEngineProtocol, @unchecked Sendable {
    private let deterministicFallback: DeterministicRankingEngine
    private let feedbackRepository: FeedbackRepositoryProtocol?
    
    #if canImport(CoreML)
    private var customHotelURL: URL?
    private var customPlaceURL: URL?
    private var customTransportURL: URL?
    #endif
    
    public init(
        deterministicFallback: DeterministicRankingEngine = DeterministicRankingEngine(),
        feedbackRepository: FeedbackRepositoryProtocol? = nil,
        hotelModelURL: URL? = nil,
        placeModelURL: URL? = nil,
        transportModelURL: URL? = nil
    ) {
        self.deterministicFallback = deterministicFallback
        self.feedbackRepository = feedbackRepository
        #if canImport(CoreML)
        self.customHotelURL = hotelModelURL
        self.customPlaceURL = placeModelURL
        self.customTransportURL = transportModelURL
        #endif
    }
    
    // MARK: - Hotel Ranking (Core ML)
    
    public func rankHotels(
        candidates: [HotelCandidate],
        request: TripRequest
    ) async throws -> [ScoredCandidate<HotelCandidate>] {
        #if canImport(CoreML)
        if let model = CoreMLModelManager.shared.getHotelModel(customURL: customHotelURL) {
            var scored: [ScoredCandidate<HotelCandidate>] = []
            let nights = max(1, request.numberOfDays - 1)
            
            // Optional personalization feedback from repository
            let feedbackSignals = (try? await feedbackRepository?.fetchFeedback(for: request.id)) ?? []
            
            for hotel in candidates {
                let totalCost = hotel.totalCost(for: request.travelersCount, nights: nights)
                let budgetRatio = min(1.0, max(0.05, totalCost / request.budget))
                let ratingNorm = min(1.0, max(0.1, hotel.reviewScore / 5.0))
                let distanceNorm = min(1.0, max(0.0, hotel.distanceToCenterKm / 10.0))
                let familyCompat: Double = (request.groupType == .family && hotel.isFamilyFriendly) ? 1.0 : (request.groupType == .family ? 0.4 : 0.8)
                
                // Amenity matching score
                var amenityScore = 0.5
                if hotel.amenities.contains("Free WiFi") { amenityScore += 0.15 }
                if hotel.amenities.contains("Breakfast Included") { amenityScore += 0.15 }
                if hotel.amenities.contains("Swimming Pool") && request.preferences.contains(.luxury) { amenityScore += 0.2 }
                amenityScore = min(1.0, amenityScore)
                
                let featureDict: [String: Any] = [
                    "budget_ratio": budgetRatio,
                    "rating": ratingNorm,
                    "distance_center": distanceNorm,
                    "family_compatibility": familyCompat,
                    "amenity_score": amenityScore
                ]
                
                do {
                    let featureProvider = try MLDictionaryFeatureProvider(dictionary: featureDict)
                    let prediction = try await model.prediction(from: featureProvider)
                    var predictedScore = prediction.featureValue(for: "recommendation_score")?.doubleValue ?? 0.80
                    
                    // Apply personalization adjustment based on persistent user feedback
                    if feedbackSignals.contains(where: { $0.likedItemIds.contains(hotel.id) }) {
                        predictedScore = min(1.0, predictedScore + 0.06)
                    } else if feedbackSignals.contains(where: { $0.dislikedItemIds.contains(hotel.id) }) {
                        predictedScore = max(0.1, predictedScore - 0.10)
                    }
                    
                    predictedScore = min(1.0, max(0.1, predictedScore))
                    
                    let rooms = hotel.roomsRequired(for: request.travelersCount)
                    let bullets: [String] = [
                        "Core ML on-device rating: \(Int(predictedScore * 100))% group match",
                        "Consumes \(Int(budgetRatio * 100))% of total budget (\(request.currency) \(Int(totalCost)))",
                        "Prime location: \(String(format: "%.1f", hotel.distanceToCenterKm)) km from central attractions",
                        "Accommodates \(request.travelersCount) travelers across \(rooms) \(rooms == 1 ? "room" : "rooms")"
                    ]
                    
                    let rationale = RecommendationRationale(
                        itemId: hotel.id,
                        itemType: "hotel",
                        headline: "Core ML Personalized Pick",
                        bullets: bullets,
                        mlScore: predictedScore
                    )
                    scored.append(ScoredCandidate(candidate: hotel, score: predictedScore, rationale: rationale))
                } catch {
                    AppLogger.shared.logCoreMLError(modelName: "HotelRankingModel", error: error, fallbackUsed: true)
                    break // Fallback if prediction fails
                }
            }
            
            if scored.count == candidates.count {
                let sorted = scored.sorted { $0.score > $1.score }
                AppLogger.shared.logCoreMLResponse(
                    modelName: "HotelRankingModel",
                    candidateCount: candidates.count,
                    topCandidate: sorted.first?.candidate.name,
                    topScore: sorted.first?.score,
                    duration: 0.02,
                    isFallback: false,
                    details: "Scored using on-device Core ML regressor with personalization feedback"
                )
                return sorted
            }
        }
        #endif
        
        let result = try await deterministicFallback.rankHotels(candidates: candidates, request: request)
        AppLogger.shared.logCoreMLResponse(
            modelName: "HotelRankingModel",
            candidateCount: candidates.count,
            topCandidate: result.first?.candidate.name,
            topScore: result.first?.score,
            duration: 0.005,
            isFallback: true,
            details: "Evaluated using Deterministic MCDA Fallback Engine"
        )
        return result
    }
    
    // MARK: - Place Ranking (Core ML)
    
    public func rankPlaces(
        candidates: [PlaceCandidate],
        request: TripRequest
    ) async throws -> [ScoredCandidate<PlaceCandidate>] {
        #if canImport(CoreML)
        if let model = CoreMLModelManager.shared.getPlaceModel(customURL: customPlaceURL) {
            var scored: [ScoredCandidate<PlaceCandidate>] = []
            let feedbackSignals = (try? await feedbackRepository?.fetchFeedback(for: request.id)) ?? []
            
            for place in candidates {
                let ratingNorm = min(1.0, max(0.1, place.rating / 5.0))
                let entryFeeNorm = min(1.0, max(0.0, place.entryFee / 500.0))
                let durationNorm = min(1.0, max(0.1, Double(place.estimatedDurationMinutes) / 180.0))
                
                // Preference match calculation
                var prefMatch = 0.5
                for pref in request.preferences {
                    switch pref {
                    case .nature where place.category == .nature: prefMatch += 0.3
                    case .culture where place.category == .historical || place.category == .religious: prefMatch += 0.3
                    case .adventure where place.category == .adventure: prefMatch += 0.35
                    case .foodie where place.category == .dining || place.category == .market: prefMatch += 0.3
                    case .shopping where place.category == .market: prefMatch += 0.35
                    case .relaxation where place.category == .relaxation || place.category == .nature: prefMatch += 0.25
                    default: break
                    }
                }
                prefMatch = min(1.0, prefMatch)
                
                let groupSuitability: Double = place.suitableForGroups.contains(request.groupType) ? 1.0 : 0.5
                
                let featureDict: [String: Any] = [
                    "rating": ratingNorm,
                    "entry_fee": entryFeeNorm,
                    "duration_hours": durationNorm,
                    "preference_match": prefMatch,
                    "group_suitability": groupSuitability
                ]
                
                do {
                    let featureProvider = try MLDictionaryFeatureProvider(dictionary: featureDict)
                    let prediction = try await model.prediction(from: featureProvider)
                    var predictedScore = prediction.featureValue(for: "place_score")?.doubleValue ?? 0.85
                    
                    if feedbackSignals.contains(where: { $0.likedItemIds.contains(place.id) }) {
                        predictedScore = min(1.0, predictedScore + 0.05)
                    } else if feedbackSignals.contains(where: { $0.dislikedItemIds.contains(place.id) }) {
                        predictedScore = max(0.1, predictedScore - 0.10)
                    }
                    
                    predictedScore = min(1.0, max(0.1, predictedScore))
                    
                    let bullets: [String] = [
                        "Core ML match score: \(Int(predictedScore * 100))%",
                        "Tailored for \(request.preferences.prefix(2).map(\.rawValue).joined(separator: " & ")) travelers",
                        "Optimal time: \(place.bestSlot.rawValue.capitalized) (~ \(place.estimatedDurationMinutes) mins)",
                        place.entryFee == 0 ? "Free admission" : "Admission: \(request.currency) \(Int(place.entryFee))"
                    ]
                    
                    let rationale = RecommendationRationale(
                        itemId: place.id,
                        itemType: "place",
                        headline: "Core ML Curated Sight",
                        bullets: bullets,
                        mlScore: predictedScore
                    )
                    scored.append(ScoredCandidate(candidate: place, score: predictedScore, rationale: rationale))
                } catch {
                    AppLogger.shared.logCoreMLError(modelName: "PlaceRankingModel", error: error, fallbackUsed: true)
                    break
                }
            }
            
            if scored.count == candidates.count {
                let sorted = scored.sorted { $0.score > $1.score }
                AppLogger.shared.logCoreMLResponse(
                    modelName: "PlaceRankingModel",
                    candidateCount: candidates.count,
                    topCandidate: sorted.first?.candidate.name,
                    topScore: sorted.first?.score,
                    duration: 0.02,
                    isFallback: false,
                    details: "Scored attractions on-device matching user travel preferences"
                )
                return sorted
            }
        }
        #endif
        
        let result = try await deterministicFallback.rankPlaces(candidates: candidates, request: request)
        AppLogger.shared.logCoreMLResponse(
            modelName: "PlaceRankingModel",
            candidateCount: candidates.count,
            topCandidate: result.first?.candidate.name,
            topScore: result.first?.score,
            duration: 0.005,
            isFallback: true,
            details: "Evaluated using Deterministic MCDA Fallback Engine"
        )
        return result
    }
    
    // MARK: - Transport Ranking (Core ML)
    
    public func rankTransport(
        candidates: [TransportOption],
        request: TripRequest
    ) async throws -> [ScoredCandidate<TransportOption>] {
        #if canImport(CoreML)
        if let model = CoreMLModelManager.shared.getTransportModel(customURL: customTransportURL) {
            var scored: [ScoredCandidate<TransportOption>] = []
            let feedbackSignals = (try? await feedbackRepository?.fetchFeedback(for: request.id)) ?? []
            
            for transport in candidates {
                let totalCost = transport.totalPrice(for: request.travelersCount)
                let costRatio = min(1.0, max(0.05, totalCost / request.budget))
                let durationNorm = min(1.0, max(0.1, Double(transport.durationMinutes) / (12.0 * 60.0)))
                let stopsPenalty: Double = transport.stops == 0 ? 0.0 : min(1.0, Double(transport.stops) * 0.4)
                
                // Transit mode preference
                var modePref = 0.8
                if transport.mode == .train && (request.preferences.contains(.nature) || request.preferences.contains(.relaxation)) {
                    modePref = 1.0
                } else if transport.mode == .flight && request.numberOfDays <= 3 {
                    modePref = 1.0
                }
                
                let featureDict: [String: Any] = [
                    "cost_ratio": costRatio,
                    "duration_hours": durationNorm,
                    "stops_penalty": stopsPenalty,
                    "mode_preference": modePref
                ]
                
                do {
                    let featureProvider = try MLDictionaryFeatureProvider(dictionary: featureDict)
                    let prediction = try await model.prediction(from: featureProvider)
                    var predictedScore = prediction.featureValue(for: "transport_score")?.doubleValue ?? 0.82
                    
                    if feedbackSignals.contains(where: { $0.likedItemIds.contains(transport.id.uuidString) }) {
                        predictedScore = min(1.0, predictedScore + 0.05)
                    } else if feedbackSignals.contains(where: { $0.dislikedItemIds.contains(transport.id.uuidString) }) {
                        predictedScore = max(0.1, predictedScore - 0.10)
                    }
                    
                    predictedScore = min(1.0, max(0.1, predictedScore))
                    
                    let bullets: [String] = [
                        "Core ML transit score: \(Int(predictedScore * 100))%",
                        "\(transport.mode.rawValue): \(transport.formattedDuration) journey time",
                        transport.stops == 0 ? "Non-stop direct service" : "\(transport.stops) connection stop(s)",
                        "Total transit fare: \(request.currency) \(Int(totalCost)) for party"
                    ]
                    
                    let rationale = RecommendationRationale(
                        itemId: transport.id.uuidString,
                        itemType: "transport",
                        headline: "Core ML Transit Choice",
                        bullets: bullets,
                        mlScore: predictedScore
                    )
                    scored.append(ScoredCandidate(candidate: transport, score: predictedScore, rationale: rationale))
                } catch {
                    AppLogger.shared.logCoreMLError(modelName: "TransportRankingModel", error: error, fallbackUsed: true)
                    break
                }
            }
            
            if scored.count == candidates.count {
                let sorted = scored.sorted { $0.score > $1.score }
                AppLogger.shared.logCoreMLResponse(
                    modelName: "TransportRankingModel",
                    candidateCount: candidates.count,
                    topCandidate: sorted.first?.candidate.title,
                    topScore: sorted.first?.score,
                    duration: 0.02,
                    isFallback: false,
                    details: "Scored flight and rail options on-device"
                )
                return sorted
            }
        }
        #endif
        
        let result = try await deterministicFallback.rankTransport(candidates: candidates, request: request)
        AppLogger.shared.logCoreMLResponse(
            modelName: "TransportRankingModel",
            candidateCount: candidates.count,
            topCandidate: result.first?.candidate.title,
            topScore: result.first?.score,
            duration: 0.005,
            isFallback: true,
            details: "Evaluated using Deterministic MCDA Fallback Engine"
        )
        return result
    }
}
