import Foundation

/// Geographical coordinate representation with Haversine distance calculation.
public struct GeoLocation: Codable, Equatable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    /// Computes great-circle distance in kilometers using the Haversine formula.
    public func distance(to other: GeoLocation) -> Double {
        let earthRadiusKm = 6371.0
        let dLat = (other.latitude - latitude) * .pi / 180.0
        let dLon = (other.longitude - longitude) * .pi / 180.0
        let lat1 = latitude * .pi / 180.0
        let lat2 = other.latitude * .pi / 180.0
        
        let a = sin(dLat / 2.0) * sin(dLat / 2.0) +
                sin(dLon / 2.0) * sin(dLon / 2.0) * cos(lat1) * cos(lat2)
        let c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
        return earthRadiusKm * c
    }
}

/// Mode of transportation.
public enum TransportMode: String, Codable, CaseIterable, Sendable {
    case flight = "Flight"
    case train = "Train"
    case cab = "Private Cab / Road"
    
    public var iconName: String {
        switch self {
        case .flight: return "airplane"
        case .train: return "tram.fill"
        case .cab: return "car.fill"
        }
    }
}

/// A flight option retrieved from real-time flight search.
@available(*, deprecated, message: "Flight search is out of scope. Use TrainCandidate instead.")
public struct FlightCandidate: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let airline: String
    public let flightNumber: String
    public let origin: String
    public let destination: String
    public let departureTime: Date
    public let arrivalTime: Date
    public let durationMinutes: Int
    public let pricePerPerson: Double
    public let cabinClass: String
    public let stops: Int
    public let bookingUrl: String?
    public let isRefundable: Bool
    public let metadata: CandidateMetadata
    
    public init(
        id: UUID = UUID(),
        airline: String,
        flightNumber: String,
        origin: String,
        destination: String,
        departureTime: Date,
        arrivalTime: Date,
        durationMinutes: Int,
        pricePerPerson: Double,
        cabinClass: String = "Economy",
        stops: Int = 0,
        bookingUrl: String? = nil,
        isRefundable: Bool = true,
        metadata: CandidateMetadata
    ) {
        self.id = id
        self.airline = airline
        self.flightNumber = flightNumber
        self.origin = origin
        self.destination = destination
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.durationMinutes = durationMinutes
        self.pricePerPerson = pricePerPerson
        self.cabinClass = cabinClass
        self.stops = stops
        self.bookingUrl = bookingUrl
        self.isRefundable = isRefundable
        self.metadata = metadata
    }
}

/// Structured Indian Railways coach class fare details retrieved from PRS API.
public struct TrainClassFare: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: String { classCode }
    public let classCode: String // e.g. "3A", "2A", "3E", "CC", "EC"
    public let className: String
    public let totalFare: Double
    public let baseFare: Double?
    public let gst: Double?
    public let superfastCharge: Double?
    public let reservationCharge: Double?
    public let tatkalFare: Double?
    public let cateringCharge: Double?
    public let dynamicFare: Double?
    
    public init(
        classCode: String,
        className: String? = nil,
        totalFare: Double,
        baseFare: Double? = nil,
        gst: Double? = nil,
        superfastCharge: Double? = nil,
        reservationCharge: Double? = nil,
        tatkalFare: Double? = nil,
        cateringCharge: Double? = nil,
        dynamicFare: Double? = nil
    ) {
        self.classCode = classCode
        self.className = className ?? TrainClassFare.defaultClassName(for: classCode)
        self.totalFare = totalFare
        self.baseFare = baseFare
        self.gst = gst
        self.superfastCharge = superfastCharge
        self.reservationCharge = reservationCharge
        self.tatkalFare = tatkalFare
        self.cateringCharge = cateringCharge
        self.dynamicFare = dynamicFare
    }
    
    public static func defaultClassName(for code: String) -> String {
        switch code.uppercased() {
        case "1A": return "AC First Class (1A)"
        case "2A": return "AC 2-Tier (2A)"
        case "3A": return "AC 3-Tier (3A)"
        case "3E": return "AC 3-Economy (3E)"
        case "CC": return "AC Chair Car (CC)"
        case "EC": return "Exec. Chair Car (EC)"
        case "EA": return "Anubhuti Class (EA)"
        case "SL": return "Sleeper (SL)"
        case "2S": return "Second Sitting (2S)"
        case "EV": return "Vistadome AC (EV)"
        default: return code
        }
    }
}

/// A train option retrieved from railway APIs.
public struct TrainCandidate: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let trainNumber: String
    public let trainName: String
    public let originStation: String
    public let destinationStation: String
    public let departureTime: Date
    public let arrivalTime: Date
    public let durationMinutes: Int
    public var pricePerPerson: Double
    public var seatClass: String
    public let availabilityStatus: String
    public var classFares: [TrainClassFare]
    public var selectedClassCode: String?
    public var availableClasses: [String]
    public var geminiSelectionRationale: String?
    public var isRecommended: Bool
    public let metadata: CandidateMetadata
    
    public init(
        id: UUID = UUID(),
        trainNumber: String,
        trainName: String,
        originStation: String,
        destinationStation: String,
        departureTime: Date,
        arrivalTime: Date,
        durationMinutes: Int,
        pricePerPerson: Double,
        seatClass: String = "3A",
        availabilityStatus: String = "Available",
        classFares: [TrainClassFare] = [],
        selectedClassCode: String? = nil,
        availableClasses: [String] = [],
        geminiSelectionRationale: String? = nil,
        isRecommended: Bool = false,
        metadata: CandidateMetadata = CandidateMetadata(source: "RailRadar")
    ) {
        self.id = id
        self.trainNumber = trainNumber
        self.trainName = trainName
        self.originStation = originStation
        self.destinationStation = destinationStation
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.durationMinutes = durationMinutes
        self.pricePerPerson = pricePerPerson
        self.seatClass = seatClass
        self.availabilityStatus = availabilityStatus
        if classFares.isEmpty {
            let isChair = seatClass.contains("CC") || seatClass.contains("Chair") || trainName.lowercased().contains("shatabdi") || trainName.lowercased().contains("vande bharat")
            if isChair {
                let ccFare = TrainClassFare(classCode: "CC", totalFare: pricePerPerson, baseFare: (pricePerPerson * 0.8).rounded(), gst: (pricePerPerson * 0.05).rounded(), superfastCharge: 45, reservationCharge: 40)
                let ecFare = TrainClassFare(classCode: "EC", totalFare: (pricePerPerson * 1.8).rounded(), baseFare: (pricePerPerson * 1.5).rounded(), gst: (pricePerPerson * 0.09).rounded(), superfastCharge: 75, reservationCharge: 60)
                self.classFares = [ccFare, ecFare]
                self.selectedClassCode = "CC"
                self.availableClasses = ["CC", "EC"]
            } else {
                let fare3A = TrainClassFare(classCode: "3A", totalFare: pricePerPerson, baseFare: (pricePerPerson * 0.8).rounded(), gst: (pricePerPerson * 0.05).rounded(), superfastCharge: 45, reservationCharge: 40)
                let fare2A = TrainClassFare(classCode: "2A", totalFare: (pricePerPerson * 1.35).rounded(), baseFare: (pricePerPerson * 1.15).rounded(), gst: (pricePerPerson * 0.07).rounded(), superfastCharge: 45, reservationCharge: 50)
                self.classFares = [fare3A, fare2A]
                self.selectedClassCode = "3A"
                self.availableClasses = ["3A", "2A"]
            }
        } else {
            self.classFares = classFares
            self.selectedClassCode = selectedClassCode ?? classFares.first?.classCode ?? seatClass
            self.availableClasses = availableClasses.isEmpty ? classFares.map(\.classCode) : availableClasses
        }
        self.geminiSelectionRationale = geminiSelectionRationale
        self.isRecommended = isRecommended
        self.metadata = metadata
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.trainNumber = try container.decode(String.self, forKey: .trainNumber)
        self.trainName = try container.decode(String.self, forKey: .trainName)
        self.originStation = try container.decode(String.self, forKey: .originStation)
        self.destinationStation = try container.decode(String.self, forKey: .destinationStation)
        self.departureTime = try container.decode(Date.self, forKey: .departureTime)
        self.arrivalTime = try container.decode(Date.self, forKey: .arrivalTime)
        self.durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        self.pricePerPerson = try container.decode(Double.self, forKey: .pricePerPerson)
        self.seatClass = try container.decodeIfPresent(String.self, forKey: .seatClass) ?? "3A"
        self.availabilityStatus = try container.decodeIfPresent(String.self, forKey: .availabilityStatus) ?? "Available"
        self.classFares = try container.decodeIfPresent([TrainClassFare].self, forKey: .classFares) ?? []
        self.selectedClassCode = try container.decodeIfPresent(String.self, forKey: .selectedClassCode)
        self.availableClasses = try container.decodeIfPresent([String].self, forKey: .availableClasses) ?? []
        self.geminiSelectionRationale = try container.decodeIfPresent(String.self, forKey: .geminiSelectionRationale)
        self.isRecommended = try container.decodeIfPresent(Bool.self, forKey: .isRecommended) ?? false
        self.metadata = try container.decode(CandidateMetadata.self, forKey: .metadata)
    }
}

/// Unified transportation candidate for recommendation and itinerary inclusion.
public struct TransportOption: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let mode: TransportMode
    public let title: String
    public let routeCode: String
    public let departureStation: String
    public let arrivalStation: String
    public let departureTime: Date
    public let arrivalTime: Date
    public let durationMinutes: Int
    public var pricePerPerson: Double
    public let stops: Int
    public var classFares: [TrainClassFare]
    public var selectedClassCode: String?
    public var alternativeOptions: [TransportOption]
    public var geminiSelectionRationale: String?
    public var isRecommended: Bool
    public let metadata: CandidateMetadata
    
    public init(from flight: FlightCandidate) {
        self.id = flight.id
        self.mode = .flight
        self.title = "\(flight.airline) \(flight.flightNumber)"
        self.routeCode = "\(flight.origin) → \(flight.destination)"
        self.departureStation = flight.origin
        self.arrivalStation = flight.destination
        self.departureTime = flight.departureTime
        self.arrivalTime = flight.arrivalTime
        self.durationMinutes = flight.durationMinutes
        self.pricePerPerson = flight.pricePerPerson
        self.stops = flight.stops
        self.classFares = []
        self.selectedClassCode = nil
        self.alternativeOptions = []
        self.geminiSelectionRationale = nil
        self.isRecommended = false
        self.metadata = flight.metadata
    }
    
    public init(from train: TrainCandidate) {
        self.id = train.id
        self.mode = .train
        self.title = "\(train.trainName) (\(train.trainNumber))"
        self.routeCode = "\(train.originStation) → \(train.destinationStation)"
        self.departureStation = train.originStation
        self.arrivalStation = train.destinationStation
        self.departureTime = train.departureTime
        self.arrivalTime = train.arrivalTime
        self.durationMinutes = train.durationMinutes
        self.pricePerPerson = train.pricePerPerson
        self.stops = 0
        self.classFares = train.classFares
        self.selectedClassCode = train.selectedClassCode ?? train.seatClass
        self.alternativeOptions = []
        self.geminiSelectionRationale = train.geminiSelectionRationale
        self.isRecommended = train.isRecommended
        self.metadata = train.metadata
    }
    
    public init(
        id: UUID = UUID(),
        mode: TransportMode,
        title: String,
        routeCode: String,
        departureStation: String,
        arrivalStation: String,
        departureTime: Date,
        arrivalTime: Date,
        durationMinutes: Int,
        pricePerPerson: Double,
        stops: Int = 0,
        classFares: [TrainClassFare] = [],
        selectedClassCode: String? = nil,
        alternativeOptions: [TransportOption] = [],
        geminiSelectionRationale: String? = nil,
        isRecommended: Bool = false,
        metadata: CandidateMetadata
    ) {
        self.id = id
        self.mode = mode
        self.title = title
        self.routeCode = routeCode
        self.departureStation = departureStation
        self.arrivalStation = arrivalStation
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.durationMinutes = durationMinutes
        self.pricePerPerson = pricePerPerson
        self.stops = stops
        self.classFares = classFares
        self.selectedClassCode = selectedClassCode ?? classFares.first?.classCode
        self.alternativeOptions = alternativeOptions
        self.geminiSelectionRationale = geminiSelectionRationale
        self.isRecommended = isRecommended
        self.metadata = metadata
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.mode = try container.decode(TransportMode.self, forKey: .mode)
        self.title = try container.decode(String.self, forKey: .title)
        self.routeCode = try container.decode(String.self, forKey: .routeCode)
        self.departureStation = try container.decode(String.self, forKey: .departureStation)
        self.arrivalStation = try container.decode(String.self, forKey: .arrivalStation)
        self.departureTime = try container.decode(Date.self, forKey: .departureTime)
        self.arrivalTime = try container.decode(Date.self, forKey: .arrivalTime)
        self.durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        self.pricePerPerson = try container.decode(Double.self, forKey: .pricePerPerson)
        self.stops = try container.decodeIfPresent(Int.self, forKey: .stops) ?? 0
        self.classFares = try container.decodeIfPresent([TrainClassFare].self, forKey: .classFares) ?? []
        self.selectedClassCode = try container.decodeIfPresent(String.self, forKey: .selectedClassCode)
        self.alternativeOptions = try container.decodeIfPresent([TransportOption].self, forKey: .alternativeOptions) ?? []
        self.geminiSelectionRationale = try container.decodeIfPresent(String.self, forKey: .geminiSelectionRationale)
        self.isRecommended = try container.decodeIfPresent(Bool.self, forKey: .isRecommended) ?? false
        self.metadata = try container.decode(CandidateMetadata.self, forKey: .metadata)
    }
    
    public mutating func updateSelectedClass(code: String) {
        guard let fare = classFares.first(where: { $0.classCode.uppercased() == code.uppercased() }) else { return }
        self.selectedClassCode = fare.classCode
        self.pricePerPerson = fare.totalFare
    }
    
    public var selectedClassFare: TrainClassFare? {
        if let code = selectedClassCode {
            return classFares.first(where: { $0.classCode.uppercased() == code.uppercased() })
        }
        return classFares.first
    }
    
    public func totalPrice(for travelers: Int) -> Double {
        return pricePerPerson * Double(travelers)
    }
    
    public var formattedDuration: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Hotel or accommodation candidate retrieved from live hotel inventory.
public struct HotelCandidate: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let address: String
    public let city: String
    public let coordinates: GeoLocation
    public let starRating: Double
    public let reviewScore: Double // 0.0 - 5.0
    public let reviewCount: Int
    public let pricePerNight: Double
    public let roomType: String
    public let maxCapacityPerRoom: Int
    public let amenities: Set<String>
    public let isFamilyFriendly: Bool
    public let photoUrls: [String]
    public let distanceToCenterKm: Double
    public let metadata: CandidateMetadata
    
    public init(
        id: String,
        name: String,
        address: String,
        city: String,
        coordinates: GeoLocation,
        starRating: Double,
        reviewScore: Double,
        reviewCount: Int,
        pricePerNight: Double,
        roomType: String,
        maxCapacityPerRoom: Int = 2,
        amenities: Set<String>,
        isFamilyFriendly: Bool = true,
        photoUrls: [String] = [],
        distanceToCenterKm: Double = 1.5,
        metadata: CandidateMetadata
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.city = city
        self.coordinates = coordinates
        self.starRating = starRating
        self.reviewScore = reviewScore
        self.reviewCount = reviewCount
        self.pricePerNight = pricePerNight
        self.roomType = roomType
        self.maxCapacityPerRoom = max(1, maxCapacityPerRoom)
        self.amenities = amenities
        self.isFamilyFriendly = isFamilyFriendly
        self.photoUrls = photoUrls
        self.distanceToCenterKm = distanceToCenterKm
        self.metadata = metadata
    }
    
    /// Deterministic calculation of rooms needed for a given traveler headcount.
    public func roomsRequired(for travelers: Int) -> Int {
        return Int(ceil(Double(travelers) / Double(maxCapacityPerRoom)))
    }
    
    /// Total accommodation cost for the group over N nights.
    public func totalCost(for travelers: Int, nights: Int) -> Double {
        let rooms = roomsRequired(for: travelers)
        return pricePerNight * Double(rooms) * Double(max(1, nights))
    }
}

/// Place / Attraction category.
public enum PlaceCategory: String, Codable, CaseIterable, Sendable {
    case sightseeing = "Sightseeing"
    case historical = "Historical Landmark"
    case nature = "Nature & Viewpoint"
    case adventure = "Adventure & Outdoor"
    case religious = "Temple & Heritage"
    case dining = "Dining & Local Flavors"
    case market = "Local Bazaar & Shopping"
    case relaxation = "Park & Promenade"
    
    public var iconName: String {
        switch self {
        case .sightseeing: return "binoculars.fill"
        case .historical: return "building.columns.fill"
        case .nature: return "mountain.2.fill"
        case .adventure: return "figure.hiking"
        case .religious: return "flame.fill"
        case .dining: return "fork.knife"
        case .market: return "cart.fill"
        case .relaxation: return "tree.fill"
        }
    }
}

/// Time slot of the day for itinerary scheduling.
public enum TimeOfDaySlot: String, Codable, CaseIterable, Sendable {
    case morning = "Morning"     // 09:00 - 12:30
    case afternoon = "Afternoon" // 14:00 - 17:30
    case evening = "Evening"     // 18:30 - 21:00
    
    public var timeRangeString: String {
        switch self {
        case .morning: return "09:00 AM - 12:30 PM"
        case .afternoon: return "02:00 PM - 05:30 PM"
        case .evening: return "06:30 PM - 09:00 PM"
        }
    }
    
    public var startHour: Int {
        switch self {
        case .morning: return 9
        case .afternoon: return 14
        case .evening: return 18
        }
    }
}

/// Place or activity candidate retrieved from live destination guides.
public struct PlaceCandidate: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let category: PlaceCategory
    public let description: String
    public let coordinates: GeoLocation
    public let rating: Double
    public let reviewCount: Int
    public let entryFee: Double
    public let estimatedDurationMinutes: Int
    public let openingHour: Int
    public let closingHour: Int
    public let bestSlot: TimeOfDaySlot
    public let suitableForGroups: Set<GroupType>
    public let metadata: CandidateMetadata
    
    public init(
        id: String,
        name: String,
        category: PlaceCategory,
        description: String,
        coordinates: GeoLocation,
        rating: Double,
        reviewCount: Int,
        entryFee: Double = 0.0,
        estimatedDurationMinutes: Int = 90,
        openingHour: Int = 9,
        closingHour: Int = 18,
        bestSlot: TimeOfDaySlot = .morning,
        suitableForGroups: Set<GroupType> = Set(GroupType.allCases),
        metadata: CandidateMetadata
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.coordinates = coordinates
        self.rating = rating
        self.reviewCount = reviewCount
        self.entryFee = entryFee
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.openingHour = openingHour
        self.closingHour = closingHour
        self.bestSlot = bestSlot
        self.suitableForGroups = suitableForGroups
        self.metadata = metadata
    }
    
    /// Checks if place is open during a specific hour of the day.
    public func isOpen(at hour: Int) -> Bool {
        return hour >= openingHour && hour < closingHour
    }
}

/// Live weather forecast for trip planning.
public struct WeatherForecast: Codable, Equatable, Sendable {
    public let date: Date
    public let condition: String
    public let iconName: String
    public let minTempC: Double
    public let maxTempC: Double
    public let rainChancePct: Int
    public let advisory: String?
    
    public init(
        date: Date,
        condition: String,
        iconName: String,
        minTempC: Double,
        maxTempC: Double,
        rainChancePct: Int,
        advisory: String? = nil
    ) {
        self.date = date
        self.condition = condition
        self.iconName = iconName
        self.minTempC = minTempC
        self.maxTempC = maxTempC
        self.rainChancePct = rainChancePct
        self.advisory = advisory
    }
    
    public var tempSummary: String {
        return "\(Int(minTempC))°C - \(Int(maxTempC))°C"
    }
}
