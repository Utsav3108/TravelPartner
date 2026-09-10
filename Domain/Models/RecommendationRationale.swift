import Foundation

/// Transparent rationale explaining why an item was chosen by the ML / ranking pipeline.
/// Ensures recommendations provide explainability without exposing raw numeric scores directly to the user.
public struct RecommendationRationale: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let itemId: String
    public let itemType: String // "hotel", "transport", "place"
    public let headline: String
    public let bullets: [String]
    public let mlScore: Double
    
    public init(
        id: UUID = UUID(),
        itemId: String,
        itemType: String,
        headline: String,
        bullets: [String],
        mlScore: Double = 0.95
    ) {
        self.id = id
        self.itemId = itemId
        self.itemType = itemType
        self.headline = headline
        self.bullets = bullets
        self.mlScore = mlScore
    }
}
