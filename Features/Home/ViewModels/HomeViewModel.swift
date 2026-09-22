import Foundation
import SwiftUI

public struct FeaturedDestination: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let subtitle: String
    public let defaultOrigin: String
    public let suggestedBudget: Double
    public let suggestedDays: Int
    public let tags: [String]
    public let iconName: String
}

@Observable
@MainActor
public final class HomeViewModel {
    public var promptText: String = "I want to go to Shimla for 5 days with 4 friends. My total budget is ₹50,000. I want a round trip."
    public var tripDate: Date = Date()
    public var isParsing: Bool = false
    public var parsedRequest: TripRequest? = nil
    public var errorMessage: String? = nil
    public var recentTrips: [TripItinerary] = []
    
    public var currentMonthRange: ClosedRange<Date> {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        guard let range = cal.range(of: .day, in: .month, for: now),
              let endOfMonth = cal.date(bySetting: .day, value: range.count, of: now),
              let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) else {
            return startOfToday...now.addingTimeInterval(86400 * 30)
        }
        return startOfToday...endOfDay
    }
    
    private let geminiService: GeminiServiceProtocol
    private let tripRepository: TripRepositoryProtocol
    
    public struct PromptInspiration: Identifiable, Sendable {
        public let id = UUID()
        public let title: String
        public let prompt: String
        public let icon: String
    }
    
    public let inspirations: [PromptInspiration] = [
        PromptInspiration(
            title: "Goa Beach & Sun",
            prompt: "Plan a 4-day beach vacation to Goa for 4 friends with a budget of ₹45,000. We want water sports, beach shacks, and vibrant sunsets.",
            icon: "sun.max.fill"
        ),
        PromptInspiration(
            title: "Shimla Heritage Train",
            prompt: "I want to go to Shimla for 5 days with 4 friends. My total budget is ₹50,000. Include toy train and mountain walks.",
            icon: "mountain.2.fill"
        ),
        PromptInspiration(
            title: "Royal Jaipur Forts",
            prompt: "3-day royal heritage trip to Jaipur for a couple with ₹35,000 budget. Include Amber Fort, Hawa Mahal, and traditional dining.",
            icon: "crown.fill"
        ),
        PromptInspiration(
            title: "Manali Alpine Snow",
            prompt: "6-day mountain adventure to Manali for 2 travelers with ₹45,000 budget. Looking for Solang Valley snow sports and trekking.",
            icon: "snowflake"
        ),
        PromptInspiration(
            title: "Kerala Backwaters",
            prompt: "5-day family trip to Kerala with ₹52,000 budget. Include Alleppey houseboat, Munnar tea estates, and local seafood.",
            icon: "water.waves"
        ),
        PromptInspiration(
            title: "Paris Art & Romance",
            prompt: "4 days romantic vacation to Paris for 2 with $2,500 budget. Include Eiffel Tower, Louvre, and a Seine river cruise.",
            icon: "sparkles"
        )
    ]
    
    public let featuredDestinations: [FeaturedDestination] = [
        FeaturedDestination(
            name: "Goa",
            subtitle: "Coastal Sunsets, Beaches & Portuguese Architecture",
            defaultOrigin: "Mumbai",
            suggestedBudget: 45000.0,
            suggestedDays: 4,
            tags: ["Beaches", "Nightlife", "Cuisine"],
            iconName: "sun.max.fill"
        ),
        FeaturedDestination(
            name: "Shimla",
            subtitle: "Queen of the Hills • Colonial Heritage & Himalayan Vistas",
            defaultOrigin: "Delhi",
            suggestedBudget: 50000.0,
            suggestedDays: 5,
            tags: ["Mountains", "Toy Train", "Colonial"],
            iconName: "mountain.2.fill"
        ),
        FeaturedDestination(
            name: "Manali",
            subtitle: "Alpine Glaciers & Solang Valley Adventure",
            defaultOrigin: "Delhi",
            suggestedBudget: 55000.0,
            suggestedDays: 6,
            tags: ["Adventure", "Snow", "Trekking"],
            iconName: "snowflake"
        ),
        FeaturedDestination(
            name: "Jaipur",
            subtitle: "The Pink City • Majestic Forts & Royal Palaces",
            defaultOrigin: "Delhi",
            suggestedBudget: 35000.0,
            suggestedDays: 3,
            tags: ["Palaces", "Culture", "Handicrafts"],
            iconName: "crown.fill"
        ),
        FeaturedDestination(
            name: "Kerala",
            subtitle: "God's Own Country • Emerald Backwaters & Misty Tea Hills",
            defaultOrigin: "Bangalore",
            suggestedBudget: 52000.0,
            suggestedDays: 5,
            tags: ["Houseboats", "Tea Gardens", "Ayurveda"],
            iconName: "water.waves"
        ),
        FeaturedDestination(
            name: "Paris",
            subtitle: "City of Light • World-Class Art, History & Haute Cuisine",
            defaultOrigin: "Delhi",
            suggestedBudget: 180000.0,
            suggestedDays: 5,
            tags: ["Museums", "Landmarks", "Romantic"],
            iconName: "sparkles"
        )
    ]
    
    public init(
        geminiService: GeminiServiceProtocol = AppContainer.shared.geminiService,
        tripRepository: TripRepositoryProtocol = AppContainer.shared.tripRepository
    ) {
        self.geminiService = geminiService
        self.tripRepository = tripRepository
    }
    
    public func parsePrompt() async -> TripRequest? {
        guard !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your travel ideas."
            return nil
        }
        
        isParsing = true
        errorMessage = nil
        
        do {
            var request = try await geminiService.parseTripPrompt(promptText)
            let cal = Calendar.current
            request.startDate = tripDate
            request.endDate = cal.date(byAdding: .day, value: request.numberOfDays, to: tripDate) ?? tripDate
            self.parsedRequest = request
            self.isParsing = false
            return request
        } catch {
            self.errorMessage = "Could not parse request: \(error.localizedDescription)"
            self.isParsing = false
            return nil
        }
    }
    
    public func selectFeatured(_ destination: FeaturedDestination) -> TripRequest {
        let cal = Calendar.current
        let req = TripRequest(
            origin: destination.defaultOrigin,
            destination: destination.name,
            startDate: tripDate,
            endDate: cal.date(byAdding: .day, value: destination.suggestedDays, to: tripDate) ?? tripDate,
            numberOfDays: destination.suggestedDays,
            travelersCount: 4,
            groupType: .friends,
            budget: destination.suggestedBudget,
            currency: "INR",
            tripType: .roundTrip,
            preferences: [.nature, .relaxation, .adventure]
        )
        self.parsedRequest = req
        return req
    }
    
    public func loadRecentTrips() async {
        do {
            self.recentTrips = try await tripRepository.fetchTrips(for: "demo_user")
        } catch {
            // Ignore error for initial fetch
        }
    }
}
