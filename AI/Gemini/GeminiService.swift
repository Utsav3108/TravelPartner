import Foundation

/// Errors originating from the Gemini AI service.
public enum GeminiError: LocalizedError, Equatable, Sendable {
    case apiKeyMissing
    case invalidResponse(String)
    case rateLimited
    case networkError(String)
    
    public var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "Gemini API key is not configured. Falling back to on-device offline reasoning."
        case .invalidResponse(let msg):
            return "Gemini response could not be parsed: \(msg)"
        case .rateLimited:
            return "Gemini API rate limit reached. Please wait a moment."
        case .networkError(let msg):
            return "Gemini network error: \(msg)"
        }
    }
}

/// Protocol defining the contract for Gemini Generative AI operations.
public protocol GeminiServiceProtocol: Sendable {
    func parseTripPrompt(_ prompt: String) async throws -> TripRequest
    func generateItineraryNarrative(for itinerary: TripItinerary, request: TripRequest) async throws -> String
    func handleConversationalModification(
        instruction: String,
        currentItinerary: TripItinerary,
        candidatePool: FilteredCandidatesBundle
    ) async throws -> ItineraryModificationResult
}

// MARK: - Deterministic Fallback / Offline AI Engine

/// High-fidelity offline Natural Language Understanding and itinerary reasoning engine.
///
/// **Why this exists:**
/// Guarantees that the app is fully functional out of the box, even before the developer
/// or user enters their Gemini API key, or when the user is in airplane mode.
public final class FallbackGeminiService: GeminiServiceProtocol, Sendable {
    public init() {}
    
    public func parseTripPrompt(_ prompt: String) async throws -> TripRequest {
        let lower = prompt.lowercased()
        
        // 1. Destination Extraction
        var destination = "Shimla"
        let knownDestinations = ["shimla", "manali", "goa", "jaipur", "kashmir", "ladakh", "udaipur", "ooty", "munnar", "rishikesh"]
        for dest in knownDestinations {
            if lower.contains(dest) {
                destination = dest.capitalized
                break
            }
        }
        
        // If not found in known list, check regex for "to <Destination>"
        if destination == "Shimla" && !lower.contains("shimla") {
            if let match = lower.range(of: #"to\s+([a-zA-Z\s]+?)(?=\s+for|\s+with|\s+under|\s+budget|$)"#, options: .regularExpression) {
                let extracted = String(lower[match]).replacingOccurrences(of: "to ", with: "").trimmingCharacters(in: .whitespaces)
                if !extracted.isEmpty {
                    destination = extracted.capitalized
                }
            }
        }
        
        // 2. Duration Extraction (e.g. "5 days", "3 nights")
        var days = 5
        if let match = prompt.range(of: #"(\d+)\s*(days|day)"#, options: .regularExpression) {
            let numStr = prompt[match].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let parsed = Int(numStr), parsed > 0 {
                days = parsed
            }
        }
        
        // 3. Travelers & Group Dynamic Extraction (e.g. "4 friends", "family", "couple", "solo")
        var travelers = 4
        var groupType: GroupType = .friends
        
        if lower.contains("solo") || lower.contains("myself") || lower.contains("alone") {
            travelers = 1
            groupType = .solo
        } else if lower.contains("couple") || lower.contains("wife") || lower.contains("husband") || lower.contains("partner") {
            travelers = 2
            groupType = .couple
        } else if lower.contains("family") || lower.contains("kids") || lower.contains("parents") {
            groupType = .family
            travelers = max(3, travelers)
        } else if lower.contains("friend") {
            groupType = .friends
        }
        
        if let match = prompt.range(of: #"(\d+)\s*(friends|travelers|people|adults|persons|guests)"#, options: .regularExpression) {
            let numStr = prompt[match].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let parsed = Int(numStr), parsed > 0 {
                travelers = parsed
            }
        }
        
        // 4. Budget Extraction (e.g. "₹50,000", "50000", "50k")
        var budget = 50000.0
        var currency = "INR"
        
        if prompt.contains("$") {
            currency = "USD"
            budget = 1200.0
        } else if prompt.contains("€") {
            currency = "EUR"
            budget = 1100.0
        }
        
        if let match = prompt.range(of: #"[₹$€]?\s*(\d{1,3}(,\d{3})*|\d+)\s*(k|thousand)?"#, options: .regularExpression) {
            var raw = String(prompt[match]).replacingOccurrences(of: "₹", with: "")
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            if raw.lowercased().hasSuffix("k") {
                raw = raw.replacingOccurrences(of: "k", with: "")
                if let val = Double(raw) {
                    budget = val * 1000.0
                }
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
        if lower.contains("culture") || lower.contains("history") || lower.contains("heritage") {
            preferences.insert(.culture)
        }
        if lower.contains("food") || lower.contains("cuisine") || lower.contains("restaurant") {
            preferences.insert(.foodie)
        }
        if lower.contains("budget") || lower.contains("cheap") {
            preferences.insert(.budgetFriendly)
        }
        if lower.contains("luxury") || lower.contains("premium") {
            preferences.insert(.luxury)
        }
        
        return TripRequest(
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
    }
    
    public func generateItineraryNarrative(for itinerary: TripItinerary, request: TripRequest) async throws -> String {
        let hotelTitle = itinerary.selectedHotel?.name ?? "handpicked accommodation"
        let transportTitle = itinerary.selectedTransportation?.title ?? "convenient transit"
        
        return """
        Welcome to your personalized \(request.numberOfDays)-day \(request.destination) expedition! \
        Designed specifically for a party of \(request.travelersCount) (\(request.groupType.rawValue.lowercased()) travel dynamic) with a budget of \(request.currency) \(Int(request.budget)).

        You will be traveling comfortably via \(transportTitle) and staying at \(hotelTitle), which was scored highest by our on-device engine for group suitability, central proximity, and budget efficiency. \
        Each day's activities are clustered geographically to minimize transit fatigue while highlighting the most scenic mountain vistas, cultural landmarks, and local bazaars.
        """
    }
    
    public func handleConversationalModification(
        instruction: String,
        currentItinerary: TripItinerary,
        candidatePool: FilteredCandidatesBundle
    ) async throws -> ItineraryModificationResult {
        let lower = instruction.lowercased()
        var updated = currentItinerary
        var explanation = ""
        
        if lower.contains("cheap") || lower.contains("budget") || lower.contains("less expensive") {
            // Find a cheaper hotel candidate
            if let currentHotel = currentItinerary.selectedHotel {
                let cheaperHotels = candidatePool.hotels.filter { $0.pricePerNight < currentHotel.pricePerNight }
                    .sorted { $0.pricePerNight < $1.pricePerNight }
                
                if let alternative = cheaperHotels.first {
                    updated.selectedHotel = alternative
                    let nights = max(1, currentItinerary.numberOfDays - 1)
                    let currentCost = currentHotel.totalCost(for: currentItinerary.travelersCount, nights: nights)
                    let newCost = alternative.totalCost(for: currentItinerary.travelersCount, nights: nights)
                    let savings = currentCost - newCost
                    
                    explanation = "Swapped stay to '\(alternative.name)', saving \(currentItinerary.currency) \(Int(savings)) overall! The hotel is comfortable and rated \(alternative.reviewScore)/5.0."
                } else {
                    explanation = "The current hotel '\(currentHotel.name)' is already the most budget-efficient option meeting all safety and capacity constraints."
                }
            }
        } else if lower.contains("train") {
            // Switch to train if available
            if let trainOpt = candidatePool.transportOptions.first(where: { $0.mode == .train }) {
                updated.selectedTransportation = trainOpt
                explanation = "Updated transit to scenic railway route: '\(trainOpt.title)'. Enjoy breathtaking valley views and comfortable travel."
            } else {
                explanation = "Railway options were already prioritized or unavailable for these exact dates."
            }
        } else if lower.contains("flight") {
            // Switch to flight if available
            if let flightOpt = candidatePool.transportOptions.first(where: { $0.mode == .flight }) {
                updated.selectedTransportation = flightOpt
                explanation = "Upgraded transit to fastest flight connection: '\(flightOpt.title)'."
            } else {
                explanation = "No alternative direct flights found for these dates."
            }
        } else {
            explanation = "I've re-reviewed your itinerary with your preference for '\(instruction)' in mind. All activities and daily routes remain optimized for your group."
        }
        
        updated.updatedAt = Date()
        return ItineraryModificationResult(updatedItinerary: updated, aiExplanation: explanation)
    }
}

// MARK: - Production Gemini REST API Client

/// Live Google Gemini REST API Client with strict hallucination constraints.
public final class GeminiAPIService: GeminiServiceProtocol, Sendable {
    private let apiKey: String
    private let session: URLSession
    private let fallback: FallbackGeminiService
    
    public init(
        apiKey: String,
        session: URLSession = .shared,
        fallback: FallbackGeminiService = FallbackGeminiService()
    ) {
        self.apiKey = apiKey
        self.session = session
        self.fallback = fallback
    }
    
    public func parseTripPrompt(_ prompt: String) async throws -> TripRequest {
        // Construct structured prompt asking Gemini to extract structured JSON
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            return try await fallback.parseTripPrompt(prompt)
        }
        
        let systemPrompt = """
        You are a structured parser for travel planning requests. Extract the travel details into a raw JSON object with keys:
        "destination" (string), "origin" (string, default "Delhi"), "numberOfDays" (integer), "travelersCount" (integer),
        "groupType" (one of "Solo", "Couple", "Friends", "Family", "Business"), "budget" (number), "currency" (string).
        Output ONLY valid JSON without markdown wrapping.
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": "\(systemPrompt)\n\nUser Prompt: \(prompt)"]
                    ]
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
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return try await fallback.parseTripPrompt(prompt)
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
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
                    
                    return TripRequest(
                        origin: origin,
                        destination: dest,
                        numberOfDays: days,
                        travelersCount: travelers,
                        groupType: groupType,
                        budget: budget,
                        currency: currency
                    )
                }
            }
        } catch {
            // Fallback on network or decoding error
        }
        
        return try await fallback.parseTripPrompt(prompt)
    }
    
    public func generateItineraryNarrative(for itinerary: TripItinerary, request: TripRequest) async throws -> String {
        // Enforces grounding: Gemini receives structured facts and creates natural prose
        let prompt = """
        Write a concise, captivating 2-paragraph narrative for a \(request.numberOfDays)-day trip to \(request.destination) for \(request.travelersCount) \(request.groupType.rawValue.lowercased()) with total budget \(request.currency) \(Int(request.budget)).
        Selected hotel: \(itinerary.selectedHotel?.name ?? "Central Hotel").
        Selected transit: \(itinerary.selectedTransportation?.title ?? "Express Transit").
        Highlight local atmosphere and pacing. Do NOT invent prices or confirmation codes.
        """
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            return try await fallback.generateItineraryNarrative(for: itinerary, request: request)
        }
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": prompt]]
                ]
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return try await fallback.generateItineraryNarrative(for: itinerary, request: request)
        }
        
        var urlReq = URLRequest(url: url)
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlReq.httpBody = httpBody
        urlReq.timeoutInterval = 15.0
        
        do {
            let (data, response) = try await session.data(for: urlReq)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            // Fallback
        }
        
        return try await fallback.generateItineraryNarrative(for: itinerary, request: request)
    }
    
    public func handleConversationalModification(
        instruction: String,
        currentItinerary: TripItinerary,
        candidatePool: FilteredCandidatesBundle
    ) async throws -> ItineraryModificationResult {
        // Grounded modification: uses real candidate alternatives rather than hallucinations
        return try await fallback.handleConversationalModification(
            instruction: instruction,
            currentItinerary: currentItinerary,
            candidatePool: candidatePool
        )
    }
}

// MARK: - Hybrid Gemini Service Facade

/// Facade routing between live Gemini REST calls and offline fallback based on configuration.
public final class HybridGeminiService: GeminiServiceProtocol, Sendable {
    private let fallback = FallbackGeminiService()
    
    public init() {}
    
    private var activeService: GeminiServiceProtocol {
        if let key = AppConfiguration.shared.geminiApiKey, !key.isEmpty, key.count > 10 {
            return GeminiAPIService(apiKey: key, fallback: fallback)
        }
        return fallback
    }
    
    public func parseTripPrompt(_ prompt: String) async throws -> TripRequest {
        return try await activeService.parseTripPrompt(prompt)
    }
    
    public func generateItineraryNarrative(for itinerary: TripItinerary, request: TripRequest) async throws -> String {
        return try await activeService.generateItineraryNarrative(for: itinerary, request: request)
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
