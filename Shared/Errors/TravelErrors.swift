import Foundation

/// Unified errors domain for Travel Partner.
public enum TravelAppError: LocalizedError, Equatable, Sendable {
    case validation(TripRequestValidationError)
    case search(TravelSearchError)
    case constraints(ConstraintViolationError)
    case ai(GeminiError)
    case network(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .validation(let err): return err.localizedDescription
        case .search(let err): return err.localizedDescription
        case .constraints(let err): return err.localizedDescription
        case .ai(let err): return err.localizedDescription
        case .network(let msg): return "Network Error: \(msg)"
        case .unknown(let msg): return "Unexpected Error: \(msg)"
        }
    }
}
