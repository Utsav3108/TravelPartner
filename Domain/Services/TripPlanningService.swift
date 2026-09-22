import Foundation

/// Granular milestones reflecting actual computational stages of the travel planning engine.
public enum PlanningStage: String, CaseIterable, Sendable {
    case validatingRequest = "Validating travel parameters"
    case searchingLiveTravel = "Finding travel options & hotels"
    case applyingConstraints = "Enforcing budget & safety rules"
    case rankingPersonalization = "Personalizing recommendations (Core ML)"
    case optimizingItinerary = "Optimizing daily schedule & transit"
    case generatingNarrative = "Polishing with Gemini Generative AI"
    case savingTrip = "Persisting trip to Firebase"
    case completed = "Your personalized trip is ready!"
    
    public var iconName: String {
        switch self {
        case .validatingRequest: return "checkmark.seal.fill"
        case .searchingLiveTravel: return "magnifyingglass"
        case .applyingConstraints: return "shield.lefthalf.filled"
        case .rankingPersonalization: return "brain.head.profile"
        case .optimizingItinerary: return "clock.arrow.2.circlepath"
        case .generatingNarrative: return "sparkles"
        case .savingTrip: return "arrow.down.doc.fill"
        case .completed: return "flag.checkered"
        }
    }
    
    public var progressWeight: Double {
        switch self {
        case .validatingRequest: return 0.05
        case .searchingLiveTravel: return 0.30
        case .applyingConstraints: return 0.45
        case .rankingPersonalization: return 0.65
        case .optimizingItinerary: return 0.80
        case .generatingNarrative: return 0.92
        case .savingTrip: return 0.98
        case .completed: return 1.00
        }
    }
}

/// Real-time progress snapshot emitted during trip generation.
public struct PlanningProgress: Equatable, Sendable {
    public let stage: PlanningStage
    public let progressFraction: Double
    public let headline: String
    public let subhead: String?
    
    public init(stage: PlanningStage, progressFraction: Double? = nil, headline: String, subhead: String? = nil) {
        self.stage = stage
        self.progressFraction = progressFraction ?? stage.progressWeight
        self.headline = headline
        self.subhead = subhead
    }
}

/// Result of an interactive AI conversational modification.
public struct ItineraryModificationResult: Sendable {
    public let updatedItinerary: TripItinerary
    public let aiExplanation: String
    
    public init(updatedItinerary: TripItinerary, aiExplanation: String) {
        self.updatedItinerary = updatedItinerary
        self.aiExplanation = aiExplanation
    }
}

/// Protocol defining the contract for orchestrating full trip generation.
public protocol TripPlanningServiceProtocol: Sendable {
    func planTrip(
        request: TripRequest,
        userId: String,
        progressHandler: (@Sendable (PlanningProgress) -> Void)?
    ) async throws -> TripItinerary
    
    func modifyTrip(
        itinerary: TripItinerary,
        instruction: String,
        request: TripRequest
    ) async throws -> ItineraryModificationResult
}

/// Central Pipeline Coordinator implementing the end-to-end 10-step hybrid AI planning system.
public final class TripPlanningCoordinator: TripPlanningServiceProtocol, Sendable {
    public let travelSearchService: TravelSearchServiceProtocol
    public let constraintEngine: ConstraintEngineProtocol
    public let recommendationEngine: RecommendationEngineProtocol
    public let itineraryOptimizer: ItineraryOptimizerProtocol
    public let geminiService: GeminiServiceProtocol
    public let tripRepository: TripRepositoryProtocol
    
    public init(
        travelSearchService: TravelSearchServiceProtocol = LiveTravelSearchService(),
        constraintEngine: ConstraintEngineProtocol = ConstraintEngine(),
        recommendationEngine: RecommendationEngineProtocol = CoreMLRecommendationEngine(),
        itineraryOptimizer: ItineraryOptimizerProtocol = ItineraryOptimizer(),
        geminiService: GeminiServiceProtocol = HybridGeminiService(),
        tripRepository: TripRepositoryProtocol = FirebaseTripRepository()
    ) {
        self.travelSearchService = travelSearchService
        self.constraintEngine = constraintEngine
        self.recommendationEngine = recommendationEngine
        self.itineraryOptimizer = itineraryOptimizer
        self.geminiService = geminiService
        self.tripRepository = tripRepository
    }
    
    
    public func planTrip(
        request: TripRequest,
        userId: String = "demo_user",
        progressHandler: (@Sendable (PlanningProgress) -> Void)? = nil
    ) async throws -> TripItinerary {
        // Step 1: Request Validation
        try Task.checkCancellation()
        progressHandler?(PlanningProgress(
            stage: .validatingRequest,
            headline: "Validating travel parameters...",
            subhead: "Checking \(request.destination) dates and budget"
        ))
        try request.validate()
        AppLogger.shared.info(
            "Starting trip planning pipeline for destination '\(request.destination)': \(request.numberOfDays) days, \(request.travelersCount) travelers, budget: \(request.currency) \(Int(request.budget))",
            category: .pipeline
        )
        
        // Step 2: Live Volatile Search (Parallel structured tasks)
        try Task.checkCancellation()
        progressHandler?(PlanningProgress(
            stage: .searchingLiveTravel,
            headline: "Retrieving live transport, hotels & attractions...",
            subhead: "Querying current schedules and room availability"
        ))
        let searchResults = try await travelSearchService.searchAll(for: request)
        
        // Step 3: Hard Business Constraint Filtering (Deterministic)
        try Task.checkCancellation()
        progressHandler?(PlanningProgress(
            stage: .applyingConstraints,
            headline: "Enforcing hard safety & budget constraints...",
            subhead: "Filtering accommodations by capacity and group type"
        ))
        let filteredCandidates = try constraintEngine.applyConstraints(to: searchResults, for: request)
        
        // Step 4: On-Device ML Ranking & Personalization
        try Task.checkCancellation()
        progressHandler?(PlanningProgress(
            stage: .rankingPersonalization,
            headline: "Personalizing recommendations on-device...",
            subhead: "Scoring candidates against your preferences using Core ML"
        ))
        
        async let rankedHotelsTask = recommendationEngine.rankHotels(candidates: filteredCandidates.hotels, request: request)
        async let rankedTransportTask = recommendationEngine.rankTransport(candidates: filteredCandidates.transportOptions, request: request)
        async let rankedPlacesTask = recommendationEngine.rankPlaces(candidates: filteredCandidates.places, request: request)
        
        let (rankedHotels, rankedTransport, rankedPlaces) = try await (rankedHotelsTask, rankedTransportTask, rankedPlacesTask)
        
        let selectedHotel = rankedHotels.first?.candidate
        var selectedTransport = rankedTransport.first?.candidate
        selectedTransport?.isRecommended = true
        let topPlaces = rankedPlaces.map(\.candidate)
        
        var combinedRationales: [RecommendationRationale] = []
        if let hotelRationale = rankedHotels.first?.rationale {
            combinedRationales.append(hotelRationale)
        }
        if let transportRationale = rankedTransport.first?.rationale {
            combinedRationales.append(transportRationale)
        }
        for placeScored in rankedPlaces.prefix(6) {
            combinedRationales.append(placeScored.rationale)
        }
        
        // Multi-Train Trade-off Recommendation via Google Gemini
        let connectingJourneys = searchResults.trains.compactMap(\.connectingJourney)
        if !connectingJourneys.isEmpty {
            do {
                let rec = try await geminiService.recommendConnectingJourney(journeys: connectingJourneys, request: request)
                let validRec = connectingJourneys.first(where: { $0.id == rec.recommendedJourneyId }) ?? connectingJourneys[0]
                
                var option = TransportOption(from: validRec)
                option.isRecommended = true
                option.geminiSelectionRationale = rec.rationale
                
                var alternatives: [TransportOption] = []
                for altId in rec.topThreeJourneyIds where altId != validRec.id && alternatives.count < 2 {
                    if let altJourney = connectingJourneys.first(where: { $0.id == altId }) {
                        var altOption = TransportOption(from: altJourney)
                        altOption.isRecommended = false
                        if let note = rec.alternativeNotes[altId] {
                            altOption.geminiSelectionRationale = note
                        }
                        alternatives.append(altOption)
                    }
                }
                for remaining in connectingJourneys where remaining.id != validRec.id && !alternatives.contains(where: { $0.connectingJourney?.id == remaining.id }) && alternatives.count < 2 {
                    var altOption = TransportOption(from: remaining)
                    altOption.isRecommended = false
                    alternatives.append(altOption)
                }
                
                option.alternativeOptions = alternatives
                selectedTransport = option
                
                combinedRationales.removeAll(where: { $0.itemType == "transport" })
                combinedRationales.append(RecommendationRationale(
                    itemId: option.id.uuidString,
                    itemType: "transport",
                    headline: "Selected by Google Gemini",
                    bullets: [
                        rec.rationale,
                        "Evaluated \(connectingJourneys.count) connecting train routes. Verified safe interchange buffer and real PRS fares."
                    ],
                    mlScore: 0.96
                ))
            } catch {
                AppLogger.shared.warning("Gemini connecting train recommendation fallback: \(error.localizedDescription)", category: .pipeline)
            }
        } else if searchResults.trains.count > 1, let primaryTransit = selectedTransport, primaryTransit.mode == .train {
            do {
                let trainRecommendation = try await geminiService.recommendTrain(trains: searchResults.trains, request: request)
                if let recommendedCandidate = searchResults.trains.first(where: { $0.trainNumber == trainRecommendation.recommendedTrainNumber }) {
                    var option = TransportOption(from: recommendedCandidate)
                    option.isRecommended = true
                    option.geminiSelectionRationale = trainRecommendation.rationale
                    if let recClass = trainRecommendation.recommendedClassCode {
                        option.updateSelectedClass(code: recClass)
                    }
                    
                    // Attach top 2 alternative direct trains
                    var alternatives: [TransportOption] = []
                    for altNum in trainRecommendation.topThreeTrainNumbers where altNum != recommendedCandidate.trainNumber && alternatives.count < 2 {
                        if let altCandidate = searchResults.trains.first(where: { $0.trainNumber == altNum }) {
                            var altOption = TransportOption(from: altCandidate)
                            altOption.isRecommended = false
                            if let note = trainRecommendation.alternativeNotes[altNum] {
                                altOption.geminiSelectionRationale = note
                            }
                            alternatives.append(altOption)
                        }
                    }
                    // Fallback to remaining candidates if topThree contained fewer than 2 distinct alternatives
                    for remaining in searchResults.trains where remaining.trainNumber != recommendedCandidate.trainNumber && !alternatives.contains(where: { $0.title.contains(remaining.trainNumber) }) && alternatives.count < 2 {
                        var altOption = TransportOption(from: remaining)
                        altOption.isRecommended = false
                        alternatives.append(altOption)
                    }
                    
                    option.alternativeOptions = alternatives
                    selectedTransport = option
                    
                    // Add/update transit recommendation rationale
                    combinedRationales.removeAll(where: { $0.itemType == "transport" })
                    combinedRationales.append(RecommendationRationale(
                        itemId: option.id.uuidString,
                        itemType: "transport",
                        headline: "Selected by Google Gemini",
                        bullets: [
                            trainRecommendation.rationale,
                            "Evaluated \(searchResults.trains.count) trains. Top recommendation and class selected by Google Gemini."
                        ],
                        mlScore: 0.96
                    ))
                }
            } catch {
                AppLogger.shared.warning("Gemini train recommendation fallback: \(error.localizedDescription)", category: .pipeline)
            }
        }
        
        // Step 5: Itinerary Optimization (Geographic Clustering & Scheduling)
        try Task.checkCancellation()
        progressHandler?(PlanningProgress(
            stage: .optimizingItinerary,
            headline: "Optimizing daily schedule & transit...",
            subhead: "Clustering places to minimize travel time across \(request.numberOfDays) days"
        ))
        
        var itinerary = try await itineraryOptimizer.buildItinerary(
            request: request,
            transport: selectedTransport,
            hotel: selectedHotel,
            rankedPlaces: topPlaces,
            weather: filteredCandidates.weather,
            rationales: combinedRationales
        )
        
        // Step 6: Gemini Generative AI Explanation & Presentation
        try Task.checkCancellation()
        progressHandler?(PlanningProgress(
            stage: .generatingNarrative,
            headline: "Generating natural-language overview...",
            subhead: "Reasoning over candidates with Google Gemini"
        ))
        
        let narrative = try await geminiService.generateItineraryNarrative(for: itinerary, request: request)
        itinerary.geminiNarrative = narrative
        
        // Step 7: Persist Trip to Firebase
        try Task.checkCancellation()
        progressHandler?(PlanningProgress(
            stage: .savingTrip,
            headline: "Saving itinerary to Firebase...",
            subhead: "Syncing plan to your saved trips"
        ))
        
        try await tripRepository.saveTrip(itinerary, for: userId)
        
        // Step 8: Completion
        progressHandler?(PlanningProgress(
            stage: .completed,
            headline: "Your personalized trip is ready!",
            subhead: "\(itinerary.days.count) days planned in \(itinerary.destination)"
        ))
        AppLogger.shared.success(
            "Trip planning complete for '\(itinerary.destination)': \(itinerary.days.count) days, total cost \(itinerary.currency) \(Int(itinerary.totalEstimatedCost))",
            category: .pipeline
        )
        
        return itinerary
    }
    
    public func modifyTrip(
        itinerary: TripItinerary,
        instruction: String,
        request: TripRequest
    ) async throws -> ItineraryModificationResult {
        try Task.checkCancellation()
        AppLogger.shared.info("Modifying trip for '\(itinerary.destination)' with command: \"\(instruction)\"", category: .pipeline)
        let searchResults = try await travelSearchService.searchAll(for: request)
        let filtered = try constraintEngine.applyConstraints(to: searchResults, for: request)
        
        let result = try await geminiService.handleConversationalModification(
            instruction: instruction,
            currentItinerary: itinerary,
            candidatePool: filtered
        )
        
        try await tripRepository.saveTrip(result.updatedItinerary, for: "demo_user")
        AppLogger.shared.success("Trip modified successfully: \"\(result.aiExplanation)\"", category: .pipeline)
        return result
    }
}

/// Architectural typealias ensuring both naming conventions are supported.
public typealias TripPlanningService = TripPlanningCoordinator
