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
    public var isParsing: Bool = false
    public var parsedRequest: TripRequest? = nil
    public var errorMessage: String? = nil
    public var recentTrips: [TripItinerary] = []
    
    private let geminiService: GeminiServiceProtocol
    private let tripRepository: TripRepositoryProtocol
    
    public let featuredDestinations: [FeaturedDestination] = [
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
            name: "Goa",
            subtitle: "Coastal Sunsets, Beaches & Portuguese Architecture",
            defaultOrigin: "Mumbai",
            suggestedBudget: 45000.0,
            suggestedDays: 4,
            tags: ["Beaches", "Nightlife", "Cuisine"],
            iconName: "sun.max.fill"
        ),
        FeaturedDestination(
            name: "Jaipur",
            subtitle: "The Pink City • Majestic Forts & Royal Palaces",
            defaultOrigin: "Delhi",
            suggestedBudget: 35000.0,
            suggestedDays: 3,
            tags: ["Palaces", "Culture", "Handicrafts"],
            iconName: "crown.fill"
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
            let request = try await geminiService.parseTripPrompt(promptText)
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
        let req = TripRequest(
            origin: destination.defaultOrigin,
            destination: destination.name,
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
