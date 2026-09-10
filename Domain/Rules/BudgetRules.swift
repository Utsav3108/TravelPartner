import Foundation

/// Pure deterministic budget rules evaluator.
///
/// **Zero ML / Zero LLM Guarantee:**
/// Ensures essential living expenses (meals + local transit) are reserved and that
/// neither stay nor transport consumes an unsustainable proportion of the budget.
public struct BudgetRuleEvaluator: Sendable {
    public static let minimumDailyReservePerTraveler: Double = 500.0
    public static let maxStayShare: Double = 0.75
    public static let maxTransportShare: Double = 0.65
    
    public init() {}
    
    /// Calculates minimum reserve required for baseline meals and local transit.
    public func calculateEssentialReserve(travelers: Int, days: Int) -> Double {
        return Self.minimumDailyReservePerTraveler * Double(max(1, travelers)) * Double(max(1, days))
    }
    
    /// Calculates available budget for fixed costs (transportation + accommodation).
    public func availableForTransportAndStay(totalBudget: Double, travelers: Int, days: Int) -> Double {
        let reserve = calculateEssentialReserve(travelers: travelers, days: days)
        return totalBudget - reserve
    }
    
    /// Evaluates whether an accommodation cost is within safe budget limits.
    public func isStayWithinCeiling(stayCost: Double, availablePool: Double) -> Bool {
        return stayCost <= (availablePool * Self.maxStayShare)
    }
    
    /// Evaluates whether a transportation cost is within safe budget limits.
    public func isTransportWithinCeiling(transportCost: Double, availablePool: Double) -> Bool {
        return transportCost <= (availablePool * Self.maxTransportShare)
    }
}
