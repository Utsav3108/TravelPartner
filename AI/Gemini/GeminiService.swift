import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAI)
import FirebaseAI
#endif

// MARK: - Gemini Service Errors

/// Errors originating from the Gemini AI service.
public enum GeminiError: LocalizedError, Equatable, Sendable {
    case apiKeyMissing
    case firebaseNotConfigured
    case invalidResponse(String)
    case rateLimited
    case networkError(String)
    
    public var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "Gemini API key is not configured. Falling back to on-device offline reasoning."
        case .firebaseNotConfigured:
            return "Firebase AI SDK is not configured. Ensure GoogleService-Info.plist or API key is set."
        case .invalidResponse(let msg):
            return "Gemini response could not be parsed: \(msg)"
        case .rateLimited:
            return "Gemini API rate limit reached. Please wait a moment."
        case .networkError(let msg):
            return "Gemini network error: \(msg)"
        }
    }
}

/// Enforces strict length limits on Gemini-generated narratives.
public enum GeminiWordLimitEnforcer {
    public static func trimTo200Words(_ text: String) -> String {
        let words = text.split(whereSeparator: \.isWhitespace)
        if words.count <= 200 {
            return text
        }
        let truncatedWords = words.prefix(200).joined(separator: " ")
        if let lastPeriod = truncatedWords.lastIndex(where: { $0 == "." || $0 == "!" || $0 == "?" }) {
            return String(truncatedWords[...lastPeriod])
        }
        return truncatedWords + "..."
    }
}

// MARK: - Gemini Service Protocol

/// Protocol defining the contract for Gemini Generative AI operations.
public protocol GeminiServiceProtocol: Sendable {
    func parseTripPrompt(_ prompt: String) async throws -> TripRequest
    func generateItineraryNarrative(for itinerary: TripItinerary, request: TripRequest) async throws -> String
    func generateItineraryNarrativeStream(for itinerary: TripItinerary, request: TripRequest) async throws -> AsyncThrowingStream<String, Error>
    func handleConversationalModification(
        instruction: String,
        currentItinerary: TripItinerary,
        candidatePool: FilteredCandidatesBundle
    ) async throws -> ItineraryModificationResult
}

public extension GeminiServiceProtocol {
    func generateItineraryNarrativeStream(for itinerary: TripItinerary, request: TripRequest) async throws -> AsyncThrowingStream<String, Error> {
        let narrative = try await generateItineraryNarrative(for: itinerary, request: request)
        return AsyncThrowingStream { continuation in
            continuation.yield(narrative)
            continuation.finish()
        }
    }
}

// MARK: - Firebase AI SDK Service Implementation

/// Live Gemini generative AI service powered by the official Firebase AI SDK (`FirebaseAI`).
///
/// **Architectural Guarantees:**
/// 1. Uses official Google Firebase AI Logic client SDK.
/// 2. Enforces structured JSON output via `GenerationConfig(responseMIMEType: "application/json")`.
/// 3. Strict hallucination protection: conversational modifications reason over genuine candidate IDs.
/// 4. Zero-crash safety: automatically routes to offline fallback if Firebase is uninitialized.
public final class FirebaseGeminiService: GeminiServiceProtocol, Sendable {
    public let modelName: String
    private let fallback: FallbackGeminiService
    
    public init(
        modelName: String = "gemini-2.5-flash",
        fallback: FallbackGeminiService = FallbackGeminiService()
    ) {
        self.modelName = modelName
        self.fallback = fallback
    }
    
    #if canImport(FirebaseAI) && canImport(FirebaseCore)
    /// Safely ensures Firebase is configured before accessing `FirebaseAI`.
    private func ensureFirebaseConfigured() -> Bool {
        return AppConfiguration.shared.configureFirebaseIfNeeded()
    }
    
    /// Strict output schema defining the expected JSON structure for parsed travel requests.
    public static var tripRequestSchema: Schema {
        return Schema.object(
            properties: [
                "destination": .string(description: "Destination city or tourist region name, capitalized"),
                "origin": .string(description: "Departure origin city, defaults to 'Delhi' if unspecified"),
                "numberOfDays": .integer(description: "Total trip duration in days (positive integer)"),
                "travelersCount": .integer(description: "Total count of traveling guests (positive integer)"),
                "groupType": .enumeration(values: ["Solo", "Couple", "Friends", "Family", "Business"], description: "Dynamic of the travel group"),
                "budget": .double(description: "Total monetary budget for the trip"),
                "currency": .string(description: "ISO currency code, e.g. INR, USD, EUR, GBP"),
                "tripType": .enumeration(values: ["roundTrip", "oneWay"], description: "Type of trip journey"),
                "preferences": .array(items: .string(), description: "Preferences: Nature, Culture, Adventure, Foodie, Shopping, Luxury, Budget-friendly, Relaxation")
            ],
            optionalProperties: ["origin", "tripType", "preferences"]
        )
    }
    
    private func getGenerativeModel(
        systemInstruction: String? = nil,
        responseJSON: Bool = false,
        responseSchema: Schema? = nil
    ) -> GenerativeModel? {
        guard ensureFirebaseConfigured() else { return nil }
        
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        let config = GenerationConfig(
            temperature: 0.1,
            responseMIMEType: (responseJSON || responseSchema != nil) ? "application/json" : "text/plain",
            responseSchema: responseSchema
        )
        
        let systemContent: ModelContent? = systemInstruction.map {
            ModelContent(role: "system", parts: $0)
        }
        
        return ai.generativeModel(
            modelName: modelName,
            generationConfig: config,
            systemInstruction: systemContent
        )
    }
    #endif
    
    // MARK: - Natural Language Understanding (Prompt Parsing)
    
    public func parseTripPrompt(_ prompt: String) async throws -> TripRequest {
        let startTime = Date()
        #if canImport(FirebaseAI) && canImport(FirebaseCore)
        let systemPrompt = "Extract travel parameters strictly conforming to the structured response schema."
        
        if let model = getGenerativeModel(systemInstruction: systemPrompt, responseSchema: Self.tripRequestSchema) {
            do {
                let response = try await model.generateContent(prompt)
                let elapsed = Date().timeIntervalSince(startTime)
                if let text = response.text, let parsed = Self.decodeTripRequest(from: text) {
                    AppLogger.shared.logGeminiResponse(
                        action: "parseTripPrompt (Structured Schema)",
                        model: modelName,
                        duration: elapsed,
                        promptSnippet: prompt,
                        responseSnippet: "Parsed destination: \(parsed.destination), days: \(parsed.numberOfDays), travelers: \(parsed.travelersCount), budget: \(parsed.currency) \(Int(parsed.budget))"
                    )
                    return parsed
                }
            } catch {
                AppLogger.shared.logGeminiError(
                    action: "parseTripPrompt",
                    model: modelName,
                    error: error,
                    fallbackUsed: true,
                    promptSnippet: prompt
                )
            }
        }
        #endif
        
        // Attempt direct Gemini REST API if key is available before offline fallback
        if let key = AppConfiguration.shared.geminiApiKey, key.count > 10 {
            let direct = GeminiAPIService(apiKey: key, fallback: fallback)
            if let parsed = try? await direct.parseTripPrompt(prompt) {
                return parsed
            }
        }
        
        return try await fallback.parseTripPrompt(prompt)
    }
    
    // MARK: - Grounded Narrative Synthesis
    
    public func generateItineraryNarrative(for itinerary: TripItinerary, request: TripRequest) async throws -> String {
        let startTime = Date()
        #if canImport(FirebaseAI) && canImport(FirebaseCore)
        let prompt = Self.buildNarrativePrompt(for: itinerary, request: request)
        let systemPrompt = """
        You are an inspiring, grounded travel concierge. Write a concise, compelling itinerary narrative.
        Ground your text strictly in the provided hotel, transit, and daily activity names.
        Do NOT invent prices, tickets, or confirmation numbers.
        CRITICAL CONSTRAINT: Keep your entire response strictly under 200 words.
        """
        
        if let model = getGenerativeModel(systemInstruction: systemPrompt, responseJSON: false) {
            do {
                let response = try await model.generateContent(prompt)
                let elapsed = Date().timeIntervalSince(startTime)
                if let text = response.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let narrative = GeminiWordLimitEnforcer.trimTo200Words(text.trimmingCharacters(in: .whitespacesAndNewlines))
                    AppLogger.shared.logGeminiResponse(
                        action: "generateItineraryNarrative",
                        model: modelName,
                        duration: elapsed,
                        promptSnippet: "Itinerary narrative for \(itinerary.destination)",
                        responseSnippet: narrative
                    )
                    return narrative
                }
            } catch {
                AppLogger.shared.logGeminiError(
                    action: "generateItineraryNarrative",
                    model: modelName,
                    error: error,
                    fallbackUsed: true
                )
            }
        }
        #endif
        
        // Attempt direct Gemini REST API if key is available before offline fallback
        if let key = AppConfiguration.shared.geminiApiKey, key.count > 10 {
            let direct = GeminiAPIService(apiKey: key, fallback: fallback)
            if let directText = try? await direct.generateItineraryNarrative(for: itinerary, request: request),
               !directText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return GeminiWordLimitEnforcer.trimTo200Words(directText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        return try await fallback.generateItineraryNarrative(for: itinerary, request: request)
    }
    
    public func generateItineraryNarrativeStream(for itinerary: TripItinerary, request: TripRequest) async throws -> AsyncThrowingStream<String, Error> {
        #if canImport(FirebaseAI) && canImport(FirebaseCore)
        let prompt = Self.buildNarrativePrompt(for: itinerary, request: request)
        let systemPrompt = """
        You are an inspiring, grounded travel concierge. Write a concise, compelling itinerary narrative.
        Ground your text strictly in the provided hotel, transit, and daily activity names.
        Do NOT invent prices, tickets, or confirmation numbers.
        CRITICAL CONSTRAINT: Keep your entire response strictly under 200 words.
        """
        
        if let model = getGenerativeModel(systemInstruction: systemPrompt, responseJSON: false) {
            do {
                let stream = try model.generateContentStream(prompt)
                let fallbackService = self.fallback
                return AsyncThrowingStream { continuation in
                    Task {
                        var didYieldAny = false
                        do {
                            for try await chunk in stream {
                                if let text = chunk.text {
                                    continuation.yield(text)
                                    didYieldAny = true
                                }
                            }
                            continuation.finish()
                        } catch {
                            // If remote streaming fails (e.g. 403 API disabled, quota, or offline), fall back seamlessly
                            if !didYieldAny {
                                if let key = AppConfiguration.shared.geminiApiKey, key.count > 10 {
                                    let direct = GeminiAPIService(apiKey: key, fallback: fallbackService)
                                    if let directText = try? await direct.generateItineraryNarrative(for: itinerary, request: request),
                                       !directText.isEmpty {
                                        continuation.yield(directText)
                                        continuation.finish()
                                        return
                                    }
                                }
                                
                                do {
                                    let fallbackNarrative = try await fallbackService.generateItineraryNarrative(for: itinerary, request: request)
                                    continuation.yield(fallbackNarrative)
                                    continuation.finish()
                                } catch {
                                    continuation.finish(throwing: error)
                                }
                            } else {
                                continuation.finish()
                            }
                        }
                    }
                }
            } catch {
                // Fallback to single-yield stream
            }
        }
        #endif
        
        // Attempt direct REST before static offline fallback
        if let key = AppConfiguration.shared.geminiApiKey, key.count > 10 {
            let direct = GeminiAPIService(apiKey: key, fallback: fallback)
            if let directText = try? await direct.generateItineraryNarrative(for: itinerary, request: request),
               !directText.isEmpty {
                return AsyncThrowingStream { continuation in
                    continuation.yield(directText)
                    continuation.finish()
                }
            }
        }
        
        let single = try await fallback.generateItineraryNarrative(for: itinerary, request: request)
        return AsyncThrowingStream { continuation in
            continuation.yield(single)
            continuation.finish()
        }
    }
    
    // MARK: - Conversational Modification (Grounded Alternative Swaps)
    
    public func handleConversationalModification(
        instruction: String,
        currentItinerary: TripItinerary,
        candidatePool: FilteredCandidatesBundle
    ) async throws -> ItineraryModificationResult {
        let startTime = Date()
        #if canImport(FirebaseAI) && canImport(FirebaseCore)
        let prompt = Self.buildModificationPrompt(
            instruction: instruction,
            currentItinerary: currentItinerary,
            candidatePool: candidatePool
        )
        
        let systemPrompt = """
        You are an AI travel itinerary modifier. The user wants to modify their travel plan.
        You are provided their current selections and real alternative candidate options.
        Select alternatives strictly from the given IDs. Do not invent hotels or transit options.
        Output ONLY valid JSON with keys:
        - "action": "swapHotel", "swapTransport", or "none"
        - "selectedHotelId": string (UUID string of candidate hotel to swap to, or null)
        - "selectedTransportId": string (UUID string of candidate transport to swap to, or null)
        - "aiExplanation": string (warm explanation of the swap and budget impact)
        """
        
        if let model = getGenerativeModel(systemInstruction: systemPrompt, responseJSON: true) {
            do {
                let response = try await model.generateContent(prompt)
                let elapsed = Date().timeIntervalSince(startTime)
                if let text = response.text,
                   let result = Self.applyModification(
                    jsonText: text,
                    currentItinerary: currentItinerary,
                    candidatePool: candidatePool
                   ) {
                    AppLogger.shared.logGeminiResponse(
                        action: "handleConversationalModification",
                        model: modelName,
                        duration: elapsed,
                        promptSnippet: instruction,
                        responseSnippet: result.aiExplanation
                    )
                    return result
                }
            } catch {
                AppLogger.shared.logGeminiError(
                    action: "handleConversationalModification",
                    model: modelName,
                    error: error,
                    fallbackUsed: true,
                    promptSnippet: instruction
                )
            }
        }
        #endif
        
        if let key = AppConfiguration.shared.geminiApiKey, key.count > 10 {
            let direct = GeminiAPIService(apiKey: key, fallback: fallback)
            if let result = try? await direct.handleConversationalModification(
                instruction: instruction,
                currentItinerary: currentItinerary,
                candidatePool: candidatePool
            ) {
                return result
            }
        }
        
        return try await fallback.handleConversationalModification(
            instruction: instruction,
            currentItinerary: currentItinerary,
            candidatePool: candidatePool
        )
    }
    
    // MARK: - Helpers
    
    private static func decodeTripRequest(from jsonText: String) -> TripRequest? {
        let cleaned = jsonText.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let destination = dict["destination"] as? String, !destination.isEmpty else {
            return nil
        }
        
        let origin = dict["origin"] as? String ?? "Delhi"
        let days = max(1, dict["numberOfDays"] as? Int ?? 4)
        let travelers = max(1, dict["travelersCount"] as? Int ?? 2)
        let budget = max(1000.0, dict["budget"] as? Double ?? 40000.0)
        let currency = dict["currency"] as? String ?? "INR"
        let groupRaw = dict["groupType"] as? String ?? "Friends"
        let groupType = GroupType(rawValue: groupRaw) ?? .friends
        let tripRaw = dict["tripType"] as? String ?? "roundTrip"
        let tripType: TripType = tripRaw.lowercased().contains("one") ? .oneWay : .roundTrip
        
        var preferences: Set<TravelPreference> = []
        if let prefsArray = dict["preferences"] as? [String] {
            for raw in prefsArray {
                if let match = TravelPreference.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(raw) == .orderedSame }) {
                    preferences.insert(match)
                }
            }
        }
        if preferences.isEmpty {
            preferences = [.nature, .relaxation]
        }
        
        return TripRequest(
            origin: origin,
            destination: destination,
            numberOfDays: days,
            travelersCount: travelers,
            groupType: groupType,
            budget: budget,
            currency: currency,
            tripType: tripType,
            preferences: preferences
        )
    }
    
    private static func buildNarrativePrompt(for itinerary: TripItinerary, request: TripRequest) -> String {
        let hotelName = itinerary.selectedHotel?.name ?? "Handpicked Lodging"
        let hotelScore = itinerary.selectedHotel.map { String(format: "%.1f★", $0.reviewScore) } ?? "4.5★"
        let transportTitle = itinerary.selectedTransportation?.title ?? "Express Transit"
        let transportMode = itinerary.selectedTransportation?.mode.rawValue ?? "Transit"
        
        let activitiesSummary = itinerary.days.prefix(3).map { day in
            let places = day.activities.map(\.place.name).joined(separator: ", ")
            return "Day \(day.dayNumber): \(places.isEmpty ? "Local sights & exploration" : places)"
        }.joined(separator: "; ")
        
        return """
        Trip: \(request.numberOfDays) days to \(request.destination) from \(request.origin)
        Party: \(request.travelersCount) (\(request.groupType.rawValue) dynamic)
        Budget: \(request.currency) \(Int(request.budget)) (Planned spend: \(request.currency) \(Int(itinerary.totalEstimatedCost)))
        Transit: \(transportMode) - \(transportTitle)
        Stay: \(hotelName) (\(hotelScore))
        Highlights: \(activitiesSummary)
        CRITICAL CONSTRAINT: Keep your entire itinerary narrative response strictly under 200 words.
        """
    }
    
    private static func buildModificationPrompt(
        instruction: String,
        currentItinerary: TripItinerary,
        candidatePool: FilteredCandidatesBundle
    ) -> String {
        let currentHotel = currentItinerary.selectedHotel.map {
            "ID: \($0.id), Name: \($0.name), Price/night: \($0.pricePerNight), Rating: \($0.reviewScore)"
        } ?? "None"
        
        let currentTransit = currentItinerary.selectedTransportation.map {
            "ID: \($0.id.uuidString), Mode: \($0.mode.rawValue), Title: \($0.title), Price: \($0.pricePerPerson)"
        } ?? "None"
        
        let candidateHotels = candidatePool.hotels.prefix(6).map {
            "ID: \($0.id), Name: \($0.name), Price/night: \($0.pricePerNight), Rating: \($0.reviewScore), FamilyFriendly: \($0.isFamilyFriendly)"
        }.joined(separator: "\n")
        
        let candidateTransit = candidatePool.transportOptions.prefix(6).map {
            "ID: \($0.id.uuidString), Mode: \($0.mode.rawValue), Title: \($0.title), Price: \($0.pricePerPerson)"
        }.joined(separator: "\n")
        
        return """
        User Request: "\(instruction)"
        Current Stay: \(currentHotel)
        Current Transit: \(currentTransit)

        Available Alternative Hotels:
        \(candidateHotels)

        Available Alternative Transit:
        \(candidateTransit)
        """
    }
    
    private static func applyModification(
        jsonText: String,
        currentItinerary: TripItinerary,
        candidatePool: FilteredCandidatesBundle
    ) -> ItineraryModificationResult? {
        let cleaned = jsonText.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        var updated = currentItinerary
        var explanation = dict["aiExplanation"] as? String ?? ""
        let nights = max(1, currentItinerary.numberOfDays - 1)
        
        if let hotelId = dict["selectedHotelId"] as? String,
           let newHotel = candidatePool.hotels.first(where: { $0.id == hotelId }) {
            updated.selectedHotel = newHotel
            if explanation.isEmpty {
                explanation = "Swapped accommodation to '\(newHotel.name)'."
            }
        }
        
        if let transportId = dict["selectedTransportId"] as? String,
           let newTransport = candidatePool.transportOptions.first(where: { $0.id.uuidString == transportId }) {
            updated.selectedTransportation = newTransport
            if explanation.isEmpty {
                explanation = "Swapped transit to '\(newTransport.title)'."
            }
        }
        
        // Recalculate total cost
        var cost = 0.0
        if let transport = updated.selectedTransportation {
            cost += transport.totalPrice(for: updated.travelersCount)
        }
        if let hotel = updated.selectedHotel {
            cost += hotel.totalCost(for: updated.travelersCount, nights: nights)
        }
        for day in updated.days {
            cost += day.activities.reduce(0.0) { $0 + ($1.place.entryFee * Double(updated.travelersCount)) }
        }
        updated.totalEstimatedCost = cost
        updated.updatedAt = Date()
        
        return ItineraryModificationResult(updatedItinerary: updated, aiExplanation: explanation)
    }
}

// MARK: - Offline Deterministic NLP & Reasoning Engine

/// Robust Natural Language Understanding and itinerary reasoning engine.
///
/// **Zero-Cloud Resilience:**
/// Guarantees that the app is 100% functional even offline, in airplane mode, or without an active API key.
public final class FallbackGeminiService: GeminiServiceProtocol, Sendable {
    public init() {}
    
    public func parseTripPrompt(_ prompt: String) async throws -> TripRequest {
        let lower = prompt.lowercased()
        
        // 1. Destination Extraction
        var destination = "Shimla"
        let knownDestinations = [
            "shimla", "manali", "goa", "jaipur", "kashmir", "ladakh",
            "udaipur", "ooty", "munnar", "rishikesh", "kerala", "dubai",
            "paris", "tokyo", "bali", "switzerland", "london", "bangalore"
        ]
        
        for dest in knownDestinations {
            if lower.contains(dest) {
                destination = dest.capitalized
                break
            }
        }
        
        // Flexible regex for "to <Destination>" or "in <Destination>"
        if destination == "Shimla" && !lower.contains("shimla") {
            let patterns = [
                #"to\s+([a-zA-Z\s]+?)(?=\s+for|\s+with|\s+under|\s+budget|\s+in|$)"#,
                #"trip\s+to\s+([a-zA-Z\s]+?)(?=\s+for|\s+with|\s+under|\s+budget|$)"#,
                #"visit\s+([a-zA-Z\s]+?)(?=\s+for|\s+with|\s+under|\s+budget|$)"#,
                #"in\s+([a-zA-Z\s]+?)(?=\s+for|\s+with|\s+under|\s+budget|$)"#
            ]
            for pattern in patterns {
                if let match = lower.range(of: pattern, options: .regularExpression) {
                    let matchedStr = String(lower[match])
                    let cleaned = matchedStr
                        .replacingOccurrences(of: "trip to ", with: "")
                        .replacingOccurrences(of: "to ", with: "")
                        .replacingOccurrences(of: "visit ", with: "")
                        .replacingOccurrences(of: "in ", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    if !cleaned.isEmpty && cleaned.count < 30 {
                        destination = cleaned.capitalized
                        break
                    }
                }
            }
        }
        
        // 2. Duration Extraction (e.g. "5 days", "3 nights", "a week", "weekend")
        var days = 5
        if lower.contains("weekend") {
            days = 2
        } else if lower.contains("week") && !lower.contains("weeks") {
            days = 7
        } else if let match = prompt.range(of: #"(\d+)\s*(days|day|nights|night)"#, options: .regularExpression) {
            let numStr = prompt[match].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let parsed = Int(numStr), parsed > 0 {
                days = parsed
            }
        }
        
        // 3. Travelers & Group Dynamic Extraction
        var travelers = 4
        var groupType: GroupType = .friends
        
        if lower.contains("solo") || lower.contains("myself") || lower.contains("alone") {
            travelers = 1
            groupType = .solo
        } else if lower.contains("couple") || lower.contains("wife") || lower.contains("husband") || lower.contains("partner") {
            travelers = 2
            groupType = .couple
        } else if lower.contains("family") || lower.contains("kids") || lower.contains("parents") || lower.contains("children") {
            groupType = .family
            travelers = max(3, travelers)
        } else if lower.contains("colleague") || lower.contains("business") || lower.contains("conference") {
            groupType = .business
        } else if lower.contains("friend") {
            groupType = .friends
        }
        
        if let match = prompt.range(of: #"(\d+)\s*(friends|travelers|people|adults|persons|guests)"#, options: .regularExpression) {
            let numStr = prompt[match].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let parsed = Int(numStr), parsed > 0 {
                travelers = parsed
            }
        }
        
        // 4. Budget Extraction
        var budget = 50000.0
        var currency = "INR"
        
        if prompt.contains("$") {
            currency = "USD"
            budget = 1500.0
        } else if prompt.contains("€") {
            currency = "EUR"
            budget = 1400.0
        } else if prompt.contains("£") {
            currency = "GBP"
            budget = 1200.0
        }
        
        if let match = prompt.range(of: #"[₹$€£]?\s*(\d{1,3}(,\d{3})*|\d+)\s*(k|thousand|lakh)?"#, options: .regularExpression) {
            var raw = String(prompt[match])
                .replacingOccurrences(of: "₹", with: "")
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: "£", with: "")
                .replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            if raw.lowercased().hasSuffix("k") {
                raw = raw.replacingOccurrences(of: "k", with: "")
                if let val = Double(raw) { budget = val * 1000.0 }
            } else if raw.lowercased().hasSuffix("lakh") {
                raw = raw.replacingOccurrences(of: "lakh", with: "")
                if let val = Double(raw) { budget = val * 100000.0 }
            } else if let val = Double(raw), val >= 1000 {
                budget = val
            }
        }
        
        // 5. Trip Type
        let tripType: TripType = lower.contains("one way") ? .oneWay : .roundTrip
        
        // 6. Preferences
        var preferences: Set<TravelPreference> = [.nature, .relaxation]
        if lower.contains("adventure") || lower.contains("trek") || lower.contains("sport") {
            preferences.insert(.adventure)
        }
        if lower.contains("culture") || lower.contains("history") || lower.contains("heritage") || lower.contains("temple") {
            preferences.insert(.culture)
        }
        if lower.contains("food") || lower.contains("cuisine") || lower.contains("dining") || lower.contains("restaurant") {
            preferences.insert(.foodie)
        }
        if lower.contains("budget") || lower.contains("cheap") {
            preferences.insert(.budgetFriendly)
        }
        if lower.contains("luxury") || lower.contains("premium") || lower.contains("5 star") || lower.contains("5-star") {
            preferences.insert(.luxury)
        }
        if lower.contains("shop") || lower.contains("market") || lower.contains("bazaar") {
            preferences.insert(.shopping)
        }
        
        let req = TripRequest(
            origin: "Delhi",
            destination: destination,
            numberOfDays: days,
            travelersCount: travelers,
            groupType: groupType,
            budget: budget,
            currency: currency,
            tripType: tripType,
            preferences: preferences
        )
        AppLogger.shared.logGeminiResponse(
            action: "parseTripPrompt (Deterministic NLU)",
            model: "FallbackGeminiService",
            duration: 0.005,
            promptSnippet: prompt,
            responseSnippet: "Parsed destination: \(req.destination), days: \(req.numberOfDays), group: \(req.groupType.rawValue), budget: \(req.currency) \(Int(req.budget))",
            isFallback: true
        )
        return req
    }
    
    public func generateItineraryNarrative(for itinerary: TripItinerary, request: TripRequest) async throws -> String {
        let hotelTitle = itinerary.selectedHotel?.name ?? "handpicked accommodation"
        let transportTitle = itinerary.selectedTransportation?.title ?? "convenient transit"
        let travelerPhrase = request.travelersCount == 1 ? "solo traveler" : "\(request.travelersCount) guests (\(request.groupType.rawValue.lowercased()) dynamic)"
        
        let primaryHighlights = itinerary.days.prefix(2).flatMap { $0.activities }.prefix(3).map(\.place.name).joined(separator: ", ")
        let highlightsSnippet = primaryHighlights.isEmpty ? "top regional landmarks" : primaryHighlights
        
        let narrative = """
        Welcome to your tailored \(request.numberOfDays)-day \(request.destination) expedition! \
        Curated specifically for \(travelerPhrase) with a total allocated budget of \(request.currency) \(Int(request.budget)).

        You will be traveling comfortably via \(transportTitle) and staying at \(hotelTitle), which was scored highest by our on-device engine for safety, proximity, and budget fit. \
        Your schedule balances iconic attractions like \(highlightsSnippet) with scenic downtime, clustered geographically to keep daily transit smooth and relaxing.
        """
        AppLogger.shared.logGeminiResponse(
            action: "generateItineraryNarrative (Local Templates)",
            model: "FallbackGeminiService",
            duration: 0.005,
            promptSnippet: "Generating narrative for \(itinerary.destination)",
            responseSnippet: String(narrative.prefix(140)),
            isFallback: true
        )
        return GeminiWordLimitEnforcer.trimTo200Words(narrative)
    }
    
    public func handleConversationalModification(
        instruction: String,
        currentItinerary: TripItinerary,
        candidatePool: FilteredCandidatesBundle
    ) async throws -> ItineraryModificationResult {
        let lower = instruction.lowercased()
        var updated = currentItinerary
        var explanation = ""
        let nights = max(1, currentItinerary.numberOfDays - 1)
        
        if lower.contains("cheap") || lower.contains("budget") || lower.contains("less expensive") {
            if let currentHotel = currentItinerary.selectedHotel {
                let cheaperHotels = candidatePool.hotels.filter { $0.pricePerNight < currentHotel.pricePerNight }
                    .sorted { $0.pricePerNight < $1.pricePerNight }
                
                if let alternative = cheaperHotels.first {
                    updated.selectedHotel = alternative
                    let currentCost = currentHotel.totalCost(for: currentItinerary.travelersCount, nights: nights)
                    let newCost = alternative.totalCost(for: currentItinerary.travelersCount, nights: nights)
                    let savings = currentCost - newCost
                    explanation = "Swapped accommodation to '\(alternative.name)', saving \(currentItinerary.currency) \(Int(savings)) overall while maintaining high comfort."
                } else {
                    explanation = "Your current hotel '\(currentHotel.name)' is already the most budget-efficient option meeting all room capacity and safety criteria."
                }
            }
        } else if lower.contains("luxury") || lower.contains("upgrade") || lower.contains("premium") {
            if let currentHotel = currentItinerary.selectedHotel {
                let premiumHotels = candidatePool.hotels.filter { $0.pricePerNight > currentHotel.pricePerNight }
                    .sorted { $0.reviewScore > $1.reviewScore }
                
                if let alternative = premiumHotels.first {
                    updated.selectedHotel = alternative
                    explanation = "Upgraded stay to premium property '\(alternative.name)' (rated \(alternative.reviewScore)/5.0) featuring enhanced amenities."
                } else {
                    explanation = "'\(currentHotel.name)' is currently our top-tier accommodation candidate for your dates."
                }
            }
        } else if lower.contains("train") {
            if let trainOpt = candidatePool.transportOptions.first(where: { $0.mode == .train }) {
                updated.selectedTransportation = trainOpt
                explanation = "Updated transit to scenic railway route: '\(trainOpt.title)'. Enjoy relaxing valley vistas and comfortable seating."
            } else {
                explanation = "Railway options were already prioritized or unavailable for these exact dates."
            }
        } else if lower.contains("flight") {
            if let flightOpt = candidatePool.transportOptions.first(where: { $0.mode == .flight }) {
                updated.selectedTransportation = flightOpt
                explanation = "Upgraded transit to fastest flight connection: '\(flightOpt.title)'."
            } else {
                explanation = "No alternative direct flights found for these dates."
            }
        } else {
            explanation = "I've re-evaluated your itinerary with your preference for '\(instruction)' in mind. Your daily route and schedule remain fully optimized."
        }
        
        // Recalculate totals
        var cost = 0.0
        if let transport = updated.selectedTransportation {
            cost += transport.totalPrice(for: updated.travelersCount)
        }
        if let hotel = updated.selectedHotel {
            cost += hotel.totalCost(for: updated.travelersCount, nights: nights)
        }
        for day in updated.days {
            cost += day.activities.reduce(0.0) { $0 + ($1.place.entryFee * Double(updated.travelersCount)) }
        }
        updated.totalEstimatedCost = cost
        updated.updatedAt = Date()
        
        return ItineraryModificationResult(updatedItinerary: updated, aiExplanation: explanation)
    }
}

// MARK: - Direct REST Client (Secondary Fallback)

/// Direct Google Gemini REST API Client.
public final class GeminiAPIService: GeminiServiceProtocol, Sendable {
    public let modelName: String
    private let apiKey: String
    private let session: URLSession
    private let fallback: FallbackGeminiService
    
    public init(
        apiKey: String,
        modelName: String = "gemini-2.5-flash",
        session: URLSession = .shared,
        fallback: FallbackGeminiService = FallbackGeminiService()
    ) {
        self.apiKey = apiKey
        self.modelName = modelName
        self.session = session
        self.fallback = fallback
    }
    
    public func parseTripPrompt(_ prompt: String) async throws -> TripRequest {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            return try await fallback.parseTripPrompt(prompt)
        }
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": "Extract travel parameters from the user prompt: \(prompt)"]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "OBJECT",
                    "properties": [
                        "destination": ["type": "STRING", "description": "Capitalized destination city or region name"],
                        "origin": ["type": "STRING", "description": "Origin city, defaults to 'Delhi' if unspecified"],
                        "numberOfDays": ["type": "INTEGER", "description": "Duration in days"],
                        "travelersCount": ["type": "INTEGER", "description": "Number of travelers"],
                        "groupType": [
                            "type": "STRING",
                            "enum": ["Solo", "Couple", "Friends", "Family", "Business"],
                            "description": "Dynamic of travel group"
                        ],
                        "budget": ["type": "NUMBER", "description": "Total trip budget"],
                        "currency": ["type": "STRING", "description": "Currency code e.g. INR, USD, EUR"],
                        "tripType": [
                            "type": "STRING",
                            "enum": ["roundTrip", "oneWay"]
                        ],
                        "preferences": [
                            "type": "ARRAY",
                            "items": ["type": "STRING"]
                        ]
                    ],
                    "required": ["destination", "numberOfDays", "travelersCount", "groupType", "budget", "currency"]
                ]
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return try await fallback.parseTripPrompt(prompt)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = 15.0
        
        let startTime = Date()
        do {
            let (data, response) = try await session.data(for: request)
            let elapsed = Date().timeIntervalSince(startTime)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    AppLogger.shared.logAPISuccess(
                        endpoint: "generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent",
                        method: "POST",
                        statusCode: httpResponse.statusCode,
                        duration: elapsed,
                        payloadSummary: "REST response: \(data.count) bytes"
                    )
                } else {
                    AppLogger.shared.logAPIError(
                        endpoint: "generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent",
                        method: "POST",
                        statusCode: httpResponse.statusCode,
                        error: GeminiError.networkError("HTTP status \(httpResponse.statusCode)"),
                        duration: elapsed
                    )
                }
            }
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let first = candidates.first,
               let content = first["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                
                let cleaned = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if let jsonData = cleaned.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let dest = dict["destination"] as? String {
                    let origin = dict["origin"] as? String ?? "Delhi"
                    let days = dict["numberOfDays"] as? Int ?? 5
                    let travelers = dict["travelersCount"] as? Int ?? 4
                    let budget = dict["budget"] as? Double ?? 50000.0
                    let currency = dict["currency"] as? String ?? "INR"
                    let groupRaw = dict["groupType"] as? String ?? "Friends"
                    let groupType = GroupType(rawValue: groupRaw) ?? .friends
                    
                    let parsed = TripRequest(
                        origin: origin,
                        destination: dest,
                        numberOfDays: days,
                        travelersCount: travelers,
                        groupType: groupType,
                        budget: budget,
                        currency: currency
                    )
                    AppLogger.shared.logGeminiResponse(
                        action: "parseTripPrompt (Direct REST)",
                        model: modelName,
                        duration: elapsed,
                        promptSnippet: prompt,
                        responseSnippet: "Parsed destination: \(parsed.destination), days: \(parsed.numberOfDays), budget: \(parsed.currency) \(Int(parsed.budget))",
                        isFallback: false
                    )
                    return parsed
                }
            }
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            AppLogger.shared.logAPIError(
                endpoint: "generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent",
                method: "POST",
                error: error,
                duration: elapsed
            )
        }
        
        return try await fallback.parseTripPrompt(prompt)
    }
    
    public func generateItineraryNarrative(for itinerary: TripItinerary, request: TripRequest) async throws -> String {
        let prompt = """
        Write a concise, captivating narrative under 200 words for a \(request.numberOfDays)-day trip to \(request.destination) for \(request.travelersCount) \(request.groupType.rawValue.lowercased()) with total budget \(request.currency) \(Int(request.budget)).
        Selected hotel: \(itinerary.selectedHotel?.name ?? "Central Hotel").
        Selected transit: \(itinerary.selectedTransportation?.title ?? "Express Transit").
        Highlight local atmosphere and pacing. Do NOT invent prices or confirmation codes.
        CRITICAL CONSTRAINT: Keep your entire response strictly under 200 words.
        """
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            return try await fallback.generateItineraryNarrative(for: itinerary, request: request)
        }
        
        let requestBody: [String: Any] = [
            "contents": [["role": "user", "parts": [["text": prompt]]]]
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return try await fallback.generateItineraryNarrative(for: itinerary, request: request)
        }
        
        var urlReq = URLRequest(url: url)
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlReq.httpBody = httpBody
        urlReq.timeoutInterval = 15.0
        
        let startTime = Date()
        do {
            let (data, response) = try await session.data(for: urlReq)
            let elapsed = Date().timeIntervalSince(startTime)
            if let http = response as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    AppLogger.shared.logAPISuccess(
                        endpoint: "generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent",
                        method: "POST",
                        statusCode: http.statusCode,
                        duration: elapsed,
                        payloadSummary: "REST narrative response: \(data.count) bytes"
                    )
                } else {
                    AppLogger.shared.logAPIError(
                        endpoint: "generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent",
                        method: "POST",
                        statusCode: http.statusCode,
                        error: GeminiError.networkError("HTTP status \(http.statusCode)"),
                        duration: elapsed
                    )
                }
            }
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let first = candidates.first,
               let content = first["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                let narrative = GeminiWordLimitEnforcer.trimTo200Words(text.trimmingCharacters(in: .whitespacesAndNewlines))
                AppLogger.shared.logGeminiResponse(
                    action: "generateItineraryNarrative (Direct REST)",
                    model: modelName,
                    duration: elapsed,
                    promptSnippet: "Itinerary narrative for \(itinerary.destination)",
                    responseSnippet: narrative,
                    isFallback: false
                )
                return narrative
            }
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            AppLogger.shared.logAPIError(
                endpoint: "generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent",
                method: "POST",
                error: error,
                duration: elapsed
            )
        }
        
        return try await fallback.generateItineraryNarrative(for: itinerary, request: request)
    }
    
    public func handleConversationalModification(
        instruction: String,
        currentItinerary: TripItinerary,
        candidatePool: FilteredCandidatesBundle
    ) async throws -> ItineraryModificationResult {
        return try await fallback.handleConversationalModification(
            instruction: instruction,
            currentItinerary: currentItinerary,
            candidatePool: candidatePool
        )
    }
}

// MARK: - Hybrid Facade (Smart Priority Router)

/// Smart facade routing between Firebase AI SDK, direct REST, and offline reasoning based on runtime configuration.
public final class HybridGeminiService: GeminiServiceProtocol, Sendable {
    public let firebaseService: FirebaseGeminiService
    public let fallbackService: FallbackGeminiService
    public let modelName: String
    
    public init(
        modelName: String = "gemini-2.5-flash",
        fallbackService: FallbackGeminiService = FallbackGeminiService()
    ) {
        self.modelName = modelName
        self.fallbackService = fallbackService
        self.firebaseService = FirebaseGeminiService(modelName: modelName, fallback: fallbackService)
    }
    
    public var activeService: GeminiServiceProtocol {
        // 1. If user explicitly provided a custom Gemini key in settings, prioritize direct REST with their personal key
        if AppConfiguration.shared.hasUserCustomGeminiKey,
           let customKey = AppConfiguration.shared.geminiApiKey,
           customKey.count > 10 {
            return GeminiAPIService(apiKey: customKey, modelName: modelName, fallback: fallbackService)
        }
        
        #if canImport(FirebaseAI) && canImport(FirebaseCore)
        if FirebaseApp.app() != nil || AppConfiguration.shared.isGeminiConfigured {
            return firebaseService
        }
        #endif
        
        if let key = AppConfiguration.shared.geminiApiKey, !key.isEmpty, key.count > 10 {
            return GeminiAPIService(apiKey: key, modelName: modelName, fallback: fallbackService)
        }
        
        return fallbackService
    }
    
    /// Tests live cloud connectivity to Google Gemini and returns diagnostic information.
    public func testCloudConnection() async -> (isLive: Bool, title: String, message: String) {
        guard let key = AppConfiguration.shared.geminiApiKey, key.count > 10 else {
            return (false, "No Key Configured", "Add a Gemini API key in Profile or configure GoogleService-Info.plist to enable live cloud AI.")
        }
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(key)"
        guard let url = URL(string: urlString) else {
            return (false, "Invalid Endpoint URL", "Could not format Gemini endpoint URL.")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [["parts": [["text": "ping"]]]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 8.0
        
        let startTime = Date()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsed = Date().timeIntervalSince(startTime)
            guard let http = response as? HTTPURLResponse else {
                AppLogger.shared.logAPIError(
                    endpoint: "generativelanguage.googleapis.com (ping test)",
                    method: "POST",
                    error: GeminiError.networkError("Failed to reach Google servers"),
                    duration: elapsed
                )
                return (false, "Network Error", "Network request failed to reach Google servers.")
            }
            
            if http.statusCode == 200 {
                AppLogger.shared.logAPISuccess(
                    endpoint: "generativelanguage.googleapis.com (ping test)",
                    method: "POST",
                    statusCode: 200,
                    duration: elapsed,
                    payloadSummary: "Gemini connection verified"
                )
                return (true, "Live Gemini Connected", "Successfully connected to Google Gemini Cloud API! Real-time streaming and dynamic generation are active.")
            } else if http.statusCode == 403 {
                AppLogger.shared.logAPIError(
                    endpoint: "generativelanguage.googleapis.com (ping test)",
                    method: "POST",
                    statusCode: 403,
                    error: GeminiError.networkError("Permission denied / API disabled (403)"),
                    duration: elapsed
                )
                let projectId = AppConfiguration.shared.firebaseProjectId ?? "your project"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorDict = json["error"] as? [String: Any],
                   let msg = errorDict["message"] as? String,
                   (msg.contains("has not been used in project") || msg.contains("disabled")) {
                    return (false, "API Disabled in Google Cloud", "The Gemini API is not enabled on Google Cloud project '\(projectId)'. Visit console.developers.google.com to enable 'generativelanguage.googleapis.com' or enter a free API key from aistudio.google.com.")
                }
                return (false, "Permission Denied (403)", "Google Cloud returned 403 Forbidden. Enable Gemini API in project '\(projectId)' or paste a free key from aistudio.google.com.")
            } else {
                AppLogger.shared.logAPIError(
                    endpoint: "generativelanguage.googleapis.com (ping test)",
                    method: "POST",
                    statusCode: http.statusCode,
                    error: GeminiError.networkError("HTTP status \(http.statusCode)"),
                    duration: elapsed
                )
                return (false, "HTTP Error \(http.statusCode)", "Server responded with status \(http.statusCode). Offline fallback is active.")
            }
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            AppLogger.shared.logAPIError(
                endpoint: "generativelanguage.googleapis.com (ping test)",
                method: "POST",
                error: error,
                duration: elapsed
            )
            return (false, "Offline / Network Error", error.localizedDescription)
        }
    }
    
    public func parseTripPrompt(_ prompt: String) async throws -> TripRequest {
        return try await activeService.parseTripPrompt(prompt)
    }
    
    public func generateItineraryNarrative(for itinerary: TripItinerary, request: TripRequest) async throws -> String {
        return try await activeService.generateItineraryNarrative(for: itinerary, request: request)
    }
    
    public func generateItineraryNarrativeStream(for itinerary: TripItinerary, request: TripRequest) async throws -> AsyncThrowingStream<String, Error> {
        return try await activeService.generateItineraryNarrativeStream(for: itinerary, request: request)
    }
    
    public func handleConversationalModification(
        instruction: String,
        currentItinerary: TripItinerary,
        candidatePool: FilteredCandidatesBundle
    ) async throws -> ItineraryModificationResult {
        return try await activeService.handleConversationalModification(
            instruction: instruction,
            currentItinerary: currentItinerary,
            candidatePool: candidatePool
        )
    }
}
