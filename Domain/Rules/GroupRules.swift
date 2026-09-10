import Foundation

/// Pure deterministic group dynamic and safety rules evaluator.
public struct GroupRuleEvaluator: Sendable {
    public init() {}
    
    /// Evaluates if an accommodation is eligible for the group dynamic.
    public func isHotelEligible(hotel: HotelCandidate, groupType: GroupType) -> Bool {
        switch groupType {
        case .family:
            // Hard invariant: Family groups strictly require verified family friendliness
            return hotel.isFamilyFriendly
        case .friends:
            return true
        case .solo, .couple, .business:
            return true
        }
    }
    
    /// Evaluates if an attraction/place is appropriate for the group dynamic.
    public func isPlaceEligible(place: PlaceCandidate, groupType: GroupType) -> Bool {
        return place.suitableForGroups.contains(groupType)
    }
}
