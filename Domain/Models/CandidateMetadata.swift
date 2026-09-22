import Foundation

/// Freshness lifecycle status of a live travel candidate.
public enum FreshnessStatus: String, Codable, Sendable {
    case liveFresh = "Live Fresh"
    case cachedFresh = "Cached (Fresh)"
    case staleNeedsRevalidation = "Stale (Needs Revalidation)"
    case expired = "Expired"
}

/// Provenance and volatility metadata attached to all live travel candidates.
/// Ensures live prices and availability are distinguished from authoritative Firebase state.
public struct CandidateMetadata: Codable, Equatable, Sendable {
    public let source: String
    public let retrievedAt: Date
    public let expiresAt: Date
    public let isMock: Bool
    public let isFareVerified: Bool
    
    public init(
        source: String,
        retrievedAt: Date = Date(),
        expiresInSeconds: TimeInterval = 1800, // 30 minutes default TTL
        isMock: Bool = false,
        isFareVerified: Bool = true
    ) {
        self.source = source
        self.retrievedAt = retrievedAt
        self.expiresAt = retrievedAt.addingTimeInterval(expiresInSeconds)
        self.isMock = isMock
        self.isFareVerified = isFareVerified
    }
    
    public init(source: String, retrievedAt: Date, expiresAt: Date, isMock: Bool = false, isFareVerified: Bool = true) {
        self.source = source
        self.retrievedAt = retrievedAt
        self.expiresAt = expiresAt
        self.isMock = isMock
        self.isFareVerified = isFareVerified
    }
    
    /// Whether the candidate information is currently fresh.
    public var isFresh: Bool {
        return Date() < expiresAt
    }
    
    /// Seconds remaining until candidate becomes stale.
    public var remainingTtlSeconds: TimeInterval {
        return max(0, expiresAt.timeIntervalSince(Date()))
    }
    
    /// Freshness status categorizer.
    public var status: FreshnessStatus {
        let now = Date()
        if now > expiresAt {
            return .expired
        } else if expiresAt.timeIntervalSince(now) < 300 {
            return .staleNeedsRevalidation
        } else if isMock {
            return .liveFresh
        } else {
            return .liveFresh
        }
    }
}
