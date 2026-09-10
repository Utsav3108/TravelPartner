import Foundation

// MARK: - Mock Flight Search Provider

public final class MockFlightSearchProvider: FlightSearchProviderProtocol, @unchecked Sendable {
    public var shouldSimulateError: Bool = false
    public var networkLatencyMs: UInt64 = 150
    
    public init() {}
    
    public func searchFlights(origin: String, destination: String, date: Date, travelers: Int) async throws -> [FlightCandidate] {
        if shouldSimulateError {
            throw TravelSearchError.providerFailed(provider: "MockFlightProvider", reason: "Simulated carrier API timeout")
        }
        
        if networkLatencyMs > 0 {
            try await Task.sleep(nanoseconds: networkLatencyMs * 1_000_000)
        }
        
        let cal = Calendar.current
        let baseDate = cal.startOfDay(for: date)
        
        let dep1 = cal.date(bySettingHour: 6, minute: 30, second: 0, of: baseDate) ?? date
        let arr1 = cal.date(bySettingHour: 8, minute: 15, second: 0, of: baseDate) ?? date
        
        let dep2 = cal.date(bySettingHour: 11, minute: 45, second: 0, of: baseDate) ?? date
        let arr2 = cal.date(bySettingHour: 13, minute: 30, second: 0, of: baseDate) ?? date
        
        let dep3 = cal.date(bySettingHour: 17, minute: 10, second: 0, of: baseDate) ?? date
        let arr3 = cal.date(bySettingHour: 19, minute: 05, second: 0, of: baseDate) ?? date
        
        let meta = CandidateMetadata(source: "MockAviationGDS", expiresInSeconds: 1200, isMock: true)
        
        return [
            FlightCandidate(
                airline: "IndiGo",
                flightNumber: "6E-2041",
                origin: origin.uppercased(),
                destination: destination.uppercased(),
                departureTime: dep1,
                arrivalTime: arr1,
                durationMinutes: 105,
                pricePerPerson: 4200.0,
                cabinClass: "Economy",
                stops: 0,
                isRefundable: true,
                metadata: meta
            ),
            FlightCandidate(
                airline: "Air India",
                flightNumber: "AI-465",
                origin: origin.uppercased(),
                destination: destination.uppercased(),
                departureTime: dep2,
                arrivalTime: arr2,
                durationMinutes: 105,
                pricePerPerson: 4850.0,
                cabinClass: "Economy",
                stops: 0,
                isRefundable: true,
                metadata: meta
            ),
            FlightCandidate(
                airline: "SpiceJet",
                flightNumber: "SG-8114",
                origin: origin.uppercased(),
                destination: destination.uppercased(),
                departureTime: dep3,
                arrivalTime: arr3,
                durationMinutes: 115,
                pricePerPerson: 3650.0,
                cabinClass: "Economy",
                stops: 0,
                isRefundable: false,
                metadata: meta
            )
        ]
    }
}

// MARK: - Mock Train Search Provider

public final class MockTrainSearchProvider: TrainSearchProviderProtocol, @unchecked Sendable {
    public var shouldSimulateError: Bool = false
    public var networkLatencyMs: UInt64 = 120
    
    public init() {}
    
    public func searchTrains(origin: String, destination: String, date: Date, travelers: Int) async throws -> [TrainCandidate] {
        if shouldSimulateError {
            throw TravelSearchError.providerFailed(provider: "MockTrainProvider", reason: "Railway reservation gateway unreachable")
        }
        
        if networkLatencyMs > 0 {
            try await Task.sleep(nanoseconds: networkLatencyMs * 1_000_000)
        }
        
        let cal = Calendar.current
        let baseDate = cal.startOfDay(for: date)
        let dep1 = cal.date(bySettingHour: 5, minute: 45, second: 0, of: baseDate) ?? date
        let arr1 = cal.date(bySettingHour: 9, minute: 55, second: 0, of: baseDate) ?? date
        let dep2 = cal.date(bySettingHour: 7, minute: 40, second: 0, of: baseDate) ?? date
        let arr2 = cal.date(bySettingHour: 11, minute: 50, second: 0, of: baseDate) ?? date
        let dep3 = cal.date(bySettingHour: 12, minute: 10, second: 0, of: baseDate) ?? date
        let arr3 = cal.date(bySettingHour: 17, minute: 20, second: 0, of: baseDate) ?? date
        
        let meta = CandidateMetadata(source: "MockNationalRailAPI", expiresInSeconds: 900, isMock: true)
        
        if destination.lowercased().contains("shimla") {
            return [
                TrainCandidate(
                    trainNumber: "12005",
                    trainName: "Kalka Shatabdi Express + Connecting Toy Train",
                    originStation: "\(origin) (NDLS)",
                    destinationStation: "Shimla (SML)",
                    departureTime: dep1,
                    arrivalTime: arr1,
                    durationMinutes: 250,
                    pricePerPerson: 1150.0,
                    seatClass: "CC",
                    availabilityStatus: "Available (48)",
                    metadata: meta
                ),
                TrainCandidate(
                    trainNumber: "22447",
                    trainName: "Vande Bharat Superfast Express",
                    originStation: "\(origin) (NDLS)",
                    destinationStation: "Chandigarh / Kalka",
                    departureTime: dep2,
                    arrivalTime: arr2,
                    durationMinutes: 210,
                    pricePerPerson: 1450.0,
                    seatClass: "Executive Chair Car",
                    availabilityStatus: "Available (22)",
                    metadata: meta
                ),
                TrainCandidate(
                    trainNumber: "52455",
                    trainName: "Himalayan Queen Heritage Toy Train",
                    originStation: "Kalka Junction",
                    destinationStation: "Shimla Hill Station",
                    departureTime: dep3,
                    arrivalTime: arr3,
                    durationMinutes: 310,
                    pricePerPerson: 470.0,
                    seatClass: "First Class",
                    availabilityStatus: "Available (16)",
                    metadata: meta
                )
            ]
        } else {
            return [
                TrainCandidate(
                    trainNumber: "12431",
                    trainName: "Rajdhani Superfast Express",
                    originStation: "\(origin) Central",
                    destinationStation: "\(destination) Terminal",
                    departureTime: dep1,
                    arrivalTime: arr1,
                    durationMinutes: 360,
                    pricePerPerson: 1650.0,
                    seatClass: "3A",
                    availabilityStatus: "Available (35)",
                    metadata: meta
                ),
                TrainCandidate(
                    trainNumber: "20901",
                    trainName: "Vande Bharat Express",
                    originStation: "\(origin) Junction",
                    destinationStation: "\(destination) City",
                    departureTime: dep2,
                    arrivalTime: arr2,
                    durationMinutes: 240,
                    pricePerPerson: 1350.0,
                    seatClass: "CC",
                    availabilityStatus: "Available (60)",
                    metadata: meta
                )
            ]
        }
    }
}

// MARK: - Mock Hotel Search Provider

public final class MockHotelSearchProvider: HotelSearchProviderProtocol, @unchecked Sendable {
    public var shouldSimulateError: Bool = false
    public var networkLatencyMs: UInt64 = 180
    
    public init() {}
    
    public func searchHotels(destination: String, checkIn: Date, checkOut: Date, guests: Int) async throws -> [HotelCandidate] {
        if shouldSimulateError {
            throw TravelSearchError.providerFailed(provider: "MockHotelProvider", reason: "Hotel distribution channel timeout")
        }
        
        if networkLatencyMs > 0 {
            try await Task.sleep(nanoseconds: networkLatencyMs * 1_000_000)
        }
        
        let meta = CandidateMetadata(source: "MockHospitalityNetwork", expiresInSeconds: 1800, isMock: true)
        let isShimla = destination.lowercased().contains("shimla")
        
        if isShimla {
            return [
                HotelCandidate(
                    id: "htl-sml-001",
                    name: "Hotel Willow Banks",
                    address: "Near Tourism Lift, The Mall Road",
                    city: "Shimla",
                    coordinates: GeoLocation(latitude: 31.1048, longitude: 77.1734),
                    starRating: 4.0,
                    reviewScore: 4.5,
                    reviewCount: 1840,
                    pricePerNight: 4200.0,
                    roomType: "Deluxe Valley View Room",
                    maxCapacityPerRoom: 2,
                    amenities: ["Free WiFi", "Mountain View", "Restaurant", "Heating", "Room Service", "Bar"],
                    isFamilyFriendly: true,
                    photoUrls: ["willow_banks_1.jpg", "willow_banks_2.jpg"],
                    distanceToCenterKm: 0.3,
                    metadata: meta
                ),
                HotelCandidate(
                    id: "htl-sml-002",
                    name: "Snow Valley Resorts Shimla",
                    address: "Ghandal, Kachi Ghatti",
                    city: "Shimla",
                    coordinates: GeoLocation(latitude: 31.0965, longitude: 77.1298),
                    starRating: 4.0,
                    reviewScore: 4.3,
                    reviewCount: 2210,
                    pricePerNight: 3200.0,
                    roomType: "Executive Family Suite",
                    maxCapacityPerRoom: 3,
                    amenities: ["Free WiFi", "Breakfast Included", "Free Parking", "Children Play Area", "Mountain View"],
                    isFamilyFriendly: true,
                    photoUrls: ["snow_valley_1.jpg"],
                    distanceToCenterKm: 3.8,
                    metadata: meta
                ),
                HotelCandidate(
                    id: "htl-sml-003",
                    name: "Clarkes Hotel (Heritage by Oberoi)",
                    address: "The Mall Road, Near High Court",
                    city: "Shimla",
                    coordinates: GeoLocation(latitude: 31.1030, longitude: 77.1762),
                    starRating: 5.0,
                    reviewScore: 4.7,
                    reviewCount: 950,
                    pricePerNight: 7800.0,
                    roomType: "Heritage Superior Room",
                    maxCapacityPerRoom: 2,
                    amenities: ["Free WiFi", "Heritage Architecture", "Fine Dining", "Bar", "Concierge"],
                    isFamilyFriendly: true,
                    photoUrls: ["clarkes_1.jpg"],
                    distanceToCenterKm: 0.5,
                    metadata: meta
                ),
                HotelCandidate(
                    id: "htl-sml-004",
                    name: "The Oberoi Cecil",
                    address: "Chaura Maidan, Ambedkar Chowk",
                    city: "Shimla",
                    coordinates: GeoLocation(latitude: 31.1038, longitude: 77.1511),
                    starRating: 5.0,
                    reviewScore: 4.9,
                    reviewCount: 1420,
                    pricePerNight: 16500.0,
                    roomType: "Luxury Suite with Balcony",
                    maxCapacityPerRoom: 2,
                    amenities: ["Indoor Heated Pool", "Luxury Spa", "Kid's Activity Center", "Free WiFi", "Fine Dining"],
                    isFamilyFriendly: true,
                    photoUrls: ["oberoi_cecil_1.jpg"],
                    distanceToCenterKm: 1.8,
                    metadata: meta
                ),
                HotelCandidate(
                    id: "htl-sml-005",
                    name: "The Ridge Pine Haven Guest House",
                    address: "Circular Road, Below Lakkar Bazaar",
                    city: "Shimla",
                    coordinates: GeoLocation(latitude: 31.1082, longitude: 77.1780),
                    starRating: 3.0,
                    reviewScore: 4.1,
                    reviewCount: 680,
                    pricePerNight: 1850.0,
                    roomType: "Standard 4-Bed Dorm/Family Room",
                    maxCapacityPerRoom: 4,
                    amenities: ["Free WiFi", "Hot Water", "Scenic Terrace", "Locker"],
                    isFamilyFriendly: false,
                    photoUrls: ["pine_haven_1.jpg"],
                    distanceToCenterKm: 0.8,
                    metadata: meta
                )
            ]
        } else {
            // General dynamic destination fallback
            return [
                HotelCandidate(
                    id: "htl-gen-001",
                    name: "\(destination) City Central Hotel",
                    address: "Central Square",
                    city: destination,
                    coordinates: GeoLocation(latitude: 28.6139, longitude: 77.2090),
                    starRating: 4.0,
                    reviewScore: 4.4,
                    reviewCount: 1100,
                    pricePerNight: 3500.0,
                    roomType: "Standard Double Room",
                    maxCapacityPerRoom: 2,
                    amenities: ["Free WiFi", "Breakfast Included", "City View"],
                    isFamilyFriendly: true,
                    distanceToCenterKm: 1.0,
                    metadata: meta
                ),
                HotelCandidate(
                    id: "htl-gen-002",
                    name: "\(destination) Grand Heritage Resort",
                    address: "Lake View Boulevard",
                    city: destination,
                    coordinates: GeoLocation(latitude: 28.6200, longitude: 77.2150),
                    starRating: 5.0,
                    reviewScore: 4.8,
                    reviewCount: 850,
                    pricePerNight: 8200.0,
                    roomType: "Deluxe Suite",
                    maxCapacityPerRoom: 2,
                    amenities: ["Swimming Pool", "Spa", "Free WiFi", "Restaurant"],
                    isFamilyFriendly: true,
                    distanceToCenterKm: 2.5,
                    metadata: meta
                ),
                HotelCandidate(
                    id: "htl-gen-003",
                    name: "\(destination) Travelers Pod & Suites",
                    address: "Station Road",
                    city: destination,
                    coordinates: GeoLocation(latitude: 28.6100, longitude: 77.2050),
                    starRating: 3.0,
                    reviewScore: 4.1,
                    reviewCount: 520,
                    pricePerNight: 1700.0,
                    roomType: "Group Quad Room",
                    maxCapacityPerRoom: 4,
                    amenities: ["Free WiFi", "Shared Lounge", "Lockers"],
                    isFamilyFriendly: false,
                    distanceToCenterKm: 0.5,
                    metadata: meta
                )
            ]
        }
    }
    
    public func revalidateHotel(hotel: HotelCandidate, checkIn: Date, checkOut: Date) async throws -> HotelCandidate {
        // Simulates revalidating hotel availability and price right before booking or confirmation
        try await Task.sleep(nanoseconds: 50 * 1_000_000)
        let freshMeta = CandidateMetadata(source: "RevalidatedDirectConnect", expiresInSeconds: 1800, isMock: true)
        return HotelCandidate(
            id: hotel.id,
            name: hotel.name,
            address: hotel.address,
            city: hotel.city,
            coordinates: hotel.coordinates,
            starRating: hotel.starRating,
            reviewScore: hotel.reviewScore,
            reviewCount: hotel.reviewCount,
            pricePerNight: hotel.pricePerNight, // confirmed live price
            roomType: hotel.roomType,
            maxCapacityPerRoom: hotel.maxCapacityPerRoom,
            amenities: hotel.amenities,
            isFamilyFriendly: hotel.isFamilyFriendly,
            photoUrls: hotel.photoUrls,
            distanceToCenterKm: hotel.distanceToCenterKm,
            metadata: freshMeta
        )
    }
}

// MARK: - Mock Place Search Provider

public final class MockPlaceSearchProvider: PlaceSearchProviderProtocol, @unchecked Sendable {
    public var shouldSimulateError: Bool = false
    public var networkLatencyMs: UInt64 = 140
    
    public init() {}
    
    public func searchPlaces(destination: String, preferences: Set<TravelPreference>) async throws -> [PlaceCandidate] {
        if shouldSimulateError {
            throw TravelSearchError.providerFailed(provider: "MockPlaceProvider", reason: "Places directory temporarily unavailable")
        }
        
        if networkLatencyMs > 0 {
            try await Task.sleep(nanoseconds: networkLatencyMs * 1_000_000)
        }
        
        let meta = CandidateMetadata(source: "MockPlacesDirectory", expiresInSeconds: 3600, isMock: true)
        let isShimla = destination.lowercased().contains("shimla")
        
        if isShimla {
            return [
                PlaceCandidate(
                    id: "plc-sml-001",
                    name: "The Ridge & Christ Church",
                    category: .historical,
                    description: "Iconic open-air esplanade in the heart of Shimla offering panoramic views of the snowy Himalayan peaks and the historic 1857 neo-Gothic Christ Church.",
                    coordinates: GeoLocation(latitude: 31.1044, longitude: 77.1741),
                    rating: 4.8,
                    reviewCount: 8400,
                    entryFee: 0.0,
                    estimatedDurationMinutes: 75,
                    openingHour: 8,
                    closingHour: 21,
                    bestSlot: .evening,
                    suitableForGroups: [.friends, .family, .couple, .solo],
                    metadata: meta
                ),
                PlaceCandidate(
                    id: "plc-sml-002",
                    name: "Mall Road Cultural Promenade",
                    category: .market,
                    description: "Bustling pedestrian-only shopping and culinary street filled with colonial architecture, cafes, handicraft emporiums, and bookshops.",
                    coordinates: GeoLocation(latitude: 31.1032, longitude: 77.1728),
                    rating: 4.7,
                    reviewCount: 9200,
                    entryFee: 0.0,
                    estimatedDurationMinutes: 120,
                    openingHour: 10,
                    closingHour: 22,
                    bestSlot: .evening,
                    suitableForGroups: [.friends, .family, .couple, .solo],
                    metadata: meta
                ),
                PlaceCandidate(
                    id: "plc-sml-003",
                    name: "Jakhoo Hill & Hanuman Temple",
                    category: .religious,
                    description: "Highest peak in Shimla (2,455m) featuring the giant 108-foot Hanuman statue with breathtaking alpine forest views and Jakhoo Ropeway cable car.",
                    coordinates: GeoLocation(latitude: 31.1011, longitude: 77.1852),
                    rating: 4.6,
                    reviewCount: 5600,
                    entryFee: 50.0,
                    estimatedDurationMinutes: 90,
                    openingHour: 6,
                    closingHour: 19,
                    bestSlot: .morning,
                    suitableForGroups: [.friends, .family, .couple, .solo],
                    metadata: meta
                ),
                PlaceCandidate(
                    id: "plc-sml-004",
                    name: "Kufri Adventure Park & Snow Point",
                    category: .adventure,
                    description: "Thrilling hill-top destination situated at 2,720m altitude, famous for horse riding, yak rides, tobogganing, go-karting, and panoramic valley views.",
                    coordinates: GeoLocation(latitude: 31.0979, longitude: 77.2678),
                    rating: 4.4,
                    reviewCount: 7100,
                    entryFee: 250.0,
                    estimatedDurationMinutes: 180,
                    openingHour: 9,
                    closingHour: 18,
                    bestSlot: .morning,
                    suitableForGroups: [.friends, .family],
                    metadata: meta
                ),
                PlaceCandidate(
                    id: "plc-sml-005",
                    name: "Viceregal Lodge & Botanical Gardens",
                    category: .historical,
                    description: "Magnificent English Renaissance mansion situated on Observatory Hill, former summer residence of British viceroys with historic conference halls.",
                    coordinates: GeoLocation(latitude: 31.1042, longitude: 77.1418),
                    rating: 4.7,
                    reviewCount: 4300,
                    entryFee: 100.0,
                    estimatedDurationMinutes: 120,
                    openingHour: 10,
                    closingHour: 17,
                    bestSlot: .afternoon,
                    suitableForGroups: [.friends, .family, .couple, .solo],
                    metadata: meta
                ),
                PlaceCandidate(
                    id: "plc-sml-006",
                    name: "Annandale Army Heritage Museum & Grounds",
                    category: .sightseeing,
                    description: "Lush green plateau featuring historic golf course, military museum showcasing Indian Army history, and serene pine forests.",
                    coordinates: GeoLocation(latitude: 31.1118, longitude: 77.1554),
                    rating: 4.5,
                    reviewCount: 2800,
                    entryFee: 0.0,
                    estimatedDurationMinutes: 90,
                    openingHour: 10,
                    closingHour: 17,
                    bestSlot: .afternoon,
                    suitableForGroups: [.friends, .family, .couple],
                    metadata: meta
                ),
                PlaceCandidate(
                    id: "plc-sml-007",
                    name: "Chadwick Falls Forest Walk",
                    category: .nature,
                    description: "Picturesque cascading waterfall tucked inside dense Glen deodar forest, perfect for quiet nature treks and photography.",
                    coordinates: GeoLocation(latitude: 31.1165, longitude: 77.1350),
                    rating: 4.2,
                    reviewCount: 1950,
                    entryFee: 0.0,
                    estimatedDurationMinutes: 90,
                    openingHour: 7,
                    closingHour: 18,
                    bestSlot: .morning,
                    suitableForGroups: [.friends, .couple, .solo],
                    metadata: meta
                ),
                PlaceCandidate(
                    id: "plc-sml-008",
                    name: "Lakkar Bazaar Wooden Crafts & Street Food",
                    category: .market,
                    description: "Quaint Himalayan market famous for traditional carved deodar wood crafts, cane walking sticks, and steaming hot Kullu siddu and momos.",
                    coordinates: GeoLocation(latitude: 31.1060, longitude: 77.1765),
                    rating: 4.5,
                    reviewCount: 3400,
                    entryFee: 0.0,
                    estimatedDurationMinutes: 75,
                    openingHour: 11,
                    closingHour: 21,
                    bestSlot: .evening,
                    suitableForGroups: [.friends, .family, .couple, .solo],
                    metadata: meta
                ),
                PlaceCandidate(
                    id: "plc-sml-009",
                    name: "Tara Devi Temple Hilltop",
                    category: .religious,
                    description: "Serene 250-year-old temple situated on Tara Devi peak with 360-degree vistas of Shimla town and dense oak woodlands.",
                    coordinates: GeoLocation(latitude: 31.0664, longitude: 77.1292),
                    rating: 4.6,
                    reviewCount: 2200,
                    entryFee: 0.0,
                    estimatedDurationMinutes: 110,
                    openingHour: 7,
                    closingHour: 18,
                    bestSlot: .morning,
                    suitableForGroups: [.friends, .family, .couple],
                    metadata: meta
                )
            ]
        } else {
            // Dynamic destination fallback
            return [
                PlaceCandidate(
                    id: "plc-gen-001",
                    name: "\(destination) Historic Fort & Museum",
                    category: .historical,
                    description: "Grand historical citadel representing the architectural zenith of \(destination) with sprawling gardens and royal galleries.",
                    coordinates: GeoLocation(latitude: 28.6562, longitude: 77.2410),
                    rating: 4.6,
                    reviewCount: 5000,
                    entryFee: 150.0,
                    estimatedDurationMinutes: 120,
                    openingHour: 9,
                    closingHour: 18,
                    bestSlot: .morning,
                    suitableForGroups: [.friends, .family, .couple, .solo],
                    metadata: meta
                ),
                PlaceCandidate(
                    id: "plc-gen-002",
                    name: "\(destination) Botanic Gardens & Waterfront",
                    category: .nature,
                    description: "Tranquil botanical gardens featuring century-old trees, scenic walking paths, and musical fountains.",
                    coordinates: GeoLocation(latitude: 28.6200, longitude: 77.2100),
                    rating: 4.5,
                    reviewCount: 3800,
                    entryFee: 50.0,
                    estimatedDurationMinutes: 90,
                    openingHour: 8,
                    closingHour: 20,
                    bestSlot: .afternoon,
                    suitableForGroups: [.friends, .family, .couple, .solo],
                    metadata: meta
                ),
                PlaceCandidate(
                    id: "plc-gen-003",
                    name: "\(destination) Heritage Street Market",
                    category: .market,
                    description: "Vibrant marketplace with traditional crafts, spice stalls, artisan textiles, and authentic regional street food.",
                    coordinates: GeoLocation(latitude: 28.6500, longitude: 77.2300),
                    rating: 4.7,
                    reviewCount: 6200,
                    entryFee: 0.0,
                    estimatedDurationMinutes: 90,
                    openingHour: 11,
                    closingHour: 22,
                    bestSlot: .evening,
                    suitableForGroups: [.friends, .family, .couple, .solo],
                    metadata: meta
                )
            ]
        }
    }
}

// MARK: - Mock Weather Search Provider

public final class MockWeatherSearchProvider: WeatherSearchProviderProtocol, @unchecked Sendable {
    public var shouldSimulateError: Bool = false
    
    public init() {}
    
    public func getForecast(destination: String, startDate: Date, days: Int) async throws -> [WeatherForecast] {
        if shouldSimulateError {
            throw TravelSearchError.providerFailed(provider: "MockWeatherProvider", reason: "Meteorological service offline")
        }
        
        let cal = Calendar.current
        var forecasts: [WeatherForecast] = []
        
        for i in 0..<days {
            let dayDate = cal.date(byAdding: .day, value: i, to: startDate) ?? startDate
            let isShimla = destination.lowercased().contains("shimla")
            
            if isShimla {
                if i == 0 {
                    forecasts.append(WeatherForecast(
                        date: dayDate,
                        condition: "Pleasant & Sunny",
                        iconName: "sun.max.fill",
                        minTempC: 12.0,
                        maxTempC: 21.0,
                        rainChancePct: 10,
                        advisory: "Pleasant mountain weather. Light jacket recommended for evenings."
                    ))
                } else if i == 1 {
                    forecasts.append(WeatherForecast(
                        date: dayDate,
                        condition: "Partly Cloudy with Alpine Breeze",
                        iconName: "cloud.sun.fill",
                        minTempC: 11.0,
                        maxTempC: 19.0,
                        rainChancePct: 20,
                        advisory: "Ideal conditions for outdoor sight-seeing and Kufri exploration."
                    ))
                } else {
                    forecasts.append(WeatherForecast(
                        date: dayDate,
                        condition: "Clear Mountain Skies",
                        iconName: "sun.haze.fill",
                        minTempC: 10.0,
                        maxTempC: 18.0,
                        rainChancePct: 5,
                        advisory: "Great visibility for valley photography."
                    ))
                }
            } else {
                forecasts.append(WeatherForecast(
                    date: dayDate,
                    condition: "Warm & Clear",
                    iconName: "sun.max.fill",
                    minTempC: 22.0,
                    maxTempC: 31.0,
                    rainChancePct: 15,
                    advisory: "Stay hydrated during afternoon walking tours."
                ))
            }
        }
        
        return forecasts
    }
}
