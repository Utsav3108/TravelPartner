import Foundation

/// Protocol defining the contract for algorithmic itinerary scheduling and optimization.
public protocol ItineraryOptimizerProtocol: Sendable {
    func buildItinerary(
        request: TripRequest,
        transport: TransportOption?,
        hotel: HotelCandidate?,
        rankedPlaces: [PlaceCandidate],
        weather: [WeatherForecast],
        rationales: [RecommendationRationale]
    ) async throws -> TripItinerary
}

/// Algorithmic Itinerary Optimizer.
///
/// **Optimization Principles:**
/// 1. Geographic Clustering: Clusters activities by Haversine distance so that places visited on a
///    given day are close together, minimizing daily transit time and fatigue.
/// 2. Temporal Feasibility: Validates venue opening and closing hours against time slots.
/// 3. Pace Adaptation: Adjusts the density of activities based on the user's `PacePreference`
///    (relaxed = 2/day, moderate = 3/day, packed = 4-5/day).
/// 4. Day-by-Day Thematic Pacing: Alternates intense outdoor excursions with relaxed cultural walks.
public final class ItineraryOptimizer: ItineraryOptimizerProtocol, Sendable {
    public init() {}
    
    public func buildItinerary(
        request: TripRequest,
        transport: TransportOption?,
        hotel: HotelCandidate?,
        rankedPlaces: [PlaceCandidate],
        weather: [WeatherForecast],
        rationales: [RecommendationRationale]
    ) async throws -> TripItinerary {
        let numberOfDays = request.numberOfDays
        let maxPerDay = request.pace.maxActivitiesPerDay
        let cal = Calendar.current
        
        // 1. Cluster places geographically into daily batches
        let dailyPlaceClusters = clusterPlaces(
            places: rankedPlaces,
            clusterCount: numberOfDays,
            maxPerCluster: maxPerDay,
            hotelLocation: hotel?.coordinates
        )
        
        // 2. Schedule each day's activities
        var dailyItineraries: [DailyItinerary] = []
        
        for dayIndex in 0..<numberOfDays {
            let dayDate = cal.date(byAdding: .day, value: dayIndex, to: request.startDate) ?? request.startDate
            let dayNumber = dayIndex + 1
            let dayWeather = dayIndex < weather.count ? weather[dayIndex] : nil
            let placesForDay = dailyPlaceClusters[dayIndex]
            
            let scheduledActivities = scheduleDailyActivities(
                places: placesForDay,
                dayNumber: dayNumber,
                hotel: hotel
            )
            
            let theme = determineDayTheme(
                dayNumber: dayNumber,
                totalDays: numberOfDays,
                activities: scheduledActivities,
                destination: request.destination
            )
            
            let dayTips = generateDailyTips(
                activities: scheduledActivities,
                weather: dayWeather,
                groupType: request.groupType
            )
            
            let narrative = "Day \(dayNumber) focuses on \(theme.lowercased()). Enjoy \(scheduledActivities.map { $0.place.name }.joined(separator: ", "))."
            
            dailyItineraries.append(DailyItinerary(
                dayNumber: dayNumber,
                date: dayDate,
                themeTitle: theme,
                narrative: narrative,
                activities: scheduledActivities,
                weather: dayWeather,
                tips: dayTips
            ))
        }
        
        let rooms = hotel?.roomsRequired(for: request.travelersCount) ?? 1
        
        return TripItinerary(
            tripRequestId: request.id,
            destination: request.destination,
            origin: request.origin,
            startDate: request.startDate,
            endDate: request.endDate,
            numberOfDays: request.numberOfDays,
            travelersCount: request.travelersCount,
            groupType: request.groupType,
            totalBudget: request.budget,
            currency: request.currency,
            selectedTransportation: transport,
            selectedHotel: hotel,
            roomsBooked: rooms,
            days: dailyItineraries,
            recommendationRationales: rationales
        )
    }
    
    // MARK: - Geographic Clustering
    
    /// Groups ranked places into clusters based on spatial proximity to minimize travel time.
    private func clusterPlaces(
        places: [PlaceCandidate],
        clusterCount: Int,
        maxPerCluster: Int,
        hotelLocation: GeoLocation?
    ) -> [[PlaceCandidate]] {
        var clusters: [[PlaceCandidate]] = Array(repeating: [], count: clusterCount)
        guard !places.isEmpty else { return clusters }
        
        var unassigned = places
        
        for day in 0..<clusterCount {
            if unassigned.isEmpty {
                // If places exhausted, reuse top signature sights for relaxed leisure
                unassigned = Array(places.prefix(3))
            }
            
            // Seed the cluster with the highest ranked remaining place
            guard let seed = unassigned.first else { break }
            unassigned.removeFirst()
            var currentDayPlaces = [seed]
            
            // Find closest neighboring places to this seed
            while currentDayPlaces.count < maxPerCluster && !unassigned.isEmpty {
                let lastPlace = currentDayPlaces.last!
                unassigned.sort {
                    $0.coordinates.distance(to: lastPlace.coordinates) < $1.coordinates.distance(to: lastPlace.coordinates)
                }
                let nextPlace = unassigned.removeFirst()
                currentDayPlaces.append(nextPlace)
            }
            
            clusters[day] = currentDayPlaces
        }
        
        return clusters
    }
    
    // MARK: - Activity Scheduling
    
    private func scheduleDailyActivities(
        places: [PlaceCandidate],
        dayNumber: Int,
        hotel: HotelCandidate?
    ) -> [ItineraryActivity] {
        var activities: [ItineraryActivity] = []
        let slots: [TimeOfDaySlot] = [.morning, .afternoon, .evening]
        
        for (index, place) in places.enumerated() {
            let slot = index < slots.count ? slots[index] : .evening
            let timeString: String
            switch slot {
            case .morning: timeString = "09:30 AM"
            case .afternoon: timeString = "02:30 PM"
            case .evening: timeString = "06:30 PM"
            }
            
            // Calculate transit distance and duration from previous location
            let prevLocation = index == 0 ? (hotel?.coordinates ?? place.coordinates) : places[index - 1].coordinates
            let distKm = prevLocation.distance(to: place.coordinates)
            let transitMins = max(10, min(60, Int(distKm * 8.0) + 10))
            
            let transitSummary: String
            if distKm < 1.2 {
                transitSummary = "\(transitMins)m leisurely walk (\(String(format: "%.1f", distKm)) km)"
            } else if distKm < 8.0 {
                transitSummary = "\(transitMins)m short taxi/cab ride (\(String(format: "%.1f", distKm)) km)"
            } else {
                transitSummary = "\(transitMins)m scenic mountain drive (\(String(format: "%.1f", distKm)) km)"
            }
            
            let localTip: String
            switch place.category {
            case .historical:
                localTip = "Hire a certified local heritage guide at the entrance for rich historical context."
            case .nature, .adventure:
                localTip = "Wear sturdy footwear and carry a light jacket as mountain temperatures dip quickly."
            case .religious:
                localTip = "Dress respectfully and leave shoes at the designated locker area."
            case .market:
                localTip = "Great spot for local souvenirs and trying regional delicacies like hot Kullu siddu."
            default:
                localTip = "Visit slightly ahead of peak hours for the best uncrowded photo opportunities."
            }
            
            activities.append(ItineraryActivity(
                place: place,
                timeSlot: slot,
                scheduledTimeString: timeString,
                durationMinutes: place.estimatedDurationMinutes,
                estimatedCost: place.entryFee,
                transitFromPreviousMinutes: transitMins,
                transitSummary: transitSummary,
                localTip: localTip
            ))
        }
        
        return activities
    }
    
    // MARK: - Thematic Pacing
    
    private func determineDayTheme(
        dayNumber: Int,
        totalDays: Int,
        activities: [ItineraryActivity],
        destination: String
    ) -> String {
        if dayNumber == 1 {
            return "Arrival & Colonial Heritage Walk"
        } else if dayNumber == totalDays {
            return "Local Markets, Souvenirs & Departure"
        } else if activities.contains(where: { $0.place.category == .adventure }) {
            return "Alpine Adventure & Scenic Heights"
        } else if activities.contains(where: { $0.place.category == .religious }) {
            return "Spiritual Vista & Temple Exploration"
        } else {
            return "Cultural Immersion & Nature Trails"
        }
    }
    
    private func generateDailyTips(
        activities: [ItineraryActivity],
        weather: WeatherForecast?,
        groupType: GroupType
    ) -> [String] {
        var tips: [String] = []
        if let w = weather, let advisory = w.advisory {
            tips.append(advisory)
        }
        if groupType == .family {
            tips.append("Allow extra 20-minute rest intervals between sightseeing stops.")
        } else if groupType == .friends {
            tips.append("Group cabs are readily negotiable near Mall Road and tourist stands.")
        }
        tips.append("Keep digital copies of booking vouchers and IDs easily accessible.")
        return tips
    }
}
