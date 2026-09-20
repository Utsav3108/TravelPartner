import Foundation

// MARK: - Open-Meteo Codable Models

public struct OpenMeteoGeocodingResponse: Codable, Sendable {
    public struct ResultItem: Codable, Sendable {
        public let latitude: Double
        public let longitude: Double
        public let name: String?
    }
    public let results: [ResultItem]?
}

public struct OpenMeteoForecastResponse: Codable, Sendable {
    public struct Daily: Codable, Sendable {
        public let weather_code: [Int]?
        public let temperature_2m_max: [Double]?
        public let temperature_2m_min: [Double]?
        public let precipitation_probability_max: [Int]?
    }
    public let daily: Daily?
}

/// Real-world Live Weather Provider using the free, open Open-Meteo API.
///
/// **Open-Meteo Features:**
/// - Strictly uses unified `NetworkProtocol` and `Request` for all API calls.
/// - Parses API payloads cleanly into typed `OpenMeteoGeocodingResponse` and `OpenMeteoForecastResponse` Codable structs.
/// - 100% Free, no API key or credit card required.
/// - Live geocoding for any destination worldwide.
/// - 7-14 day daily forecasts including max/min temperatures, precipitation probabilities, and WMO weather codes.
/// - Authentic HTTP requests with live status code and payload logging.
public final class OpenMeteoWeatherSearchProvider: WeatherSearchProviderProtocol, Sendable {
    private let network: NetworkProtocol
    private let fallback: MockWeatherSearchProvider
    
    public init(
        network: NetworkProtocol = Network.shared,
        fallback: MockWeatherSearchProvider = MockWeatherSearchProvider()
    ) {
        self.network = network
        self.fallback = fallback
    }
    
    public func getForecast(destination: String, startDate: Date, days: Int) async throws -> [WeatherForecast] {
        let cleanDest = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let encodedDest = cleanDest.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              !cleanDest.isEmpty else {
            return try await fallback.getForecast(destination: destination, startDate: startDate, days: days)
        }
        
        // 1. Geocoding: Look up latitude & longitude via Open-Meteo Geocoding API
        let geocodeUrlString = "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedDest)&count=1&language=en&format=json"
        guard let geocodeUrl = URL(string: geocodeUrlString) else {
            return try await fallback.getForecast(destination: destination, startDate: startDate, days: days)
        }
        
        var latitude: Double?
        var longitude: Double?
        
        do {
            let geoRequest = Request(url: geocodeUrl, timeoutInterval: 6.0)
            let geoResponse: OpenMeteoGeocodingResponse = try await network.perform(request: geoRequest)
            
            if let first = geoResponse.results?.first {
                latitude = first.latitude
                longitude = first.longitude
            }
        } catch {
            AppLogger.shared.info("[Open-Meteo Provider] Geocoding request failed (\(error.localizedDescription))", category: .pipeline)
        }
        
        // Fallback to offline forecast if geocoding failed or device is offline
        guard let lat = latitude, let lon = longitude else {
            AppLogger.shared.info("[Offline Fallback] Geocoding unreachable for '\(destination)', using local weather estimate", category: .pipeline)
            return try await fallback.getForecast(destination: destination, startDate: startDate, days: days)
        }
        
        // 2. Weather Forecast: Query daily meteorological variables
        let forecastDays = min(max(days, 1), 14)
        let forecastUrlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=\(forecastDays)"
        guard let forecastUrl = URL(string: forecastUrlString) else {
            return try await fallback.getForecast(destination: destination, startDate: startDate, days: days)
        }
        
        do {
            let forecastRequest = Request(url: forecastUrl, timeoutInterval: 7.0)
            let forecastResponse: OpenMeteoForecastResponse = try await network.perform(request: forecastRequest)
            
            if let daily = forecastResponse.daily,
               let maxTemps = daily.temperature_2m_max,
               let minTemps = daily.temperature_2m_min,
               let weatherCodes = daily.weather_code {
                
                let rainProbs = daily.precipitation_probability_max ?? Array(repeating: 10, count: maxTemps.count)
                let cal = Calendar.current
                var parsedForecasts: [WeatherForecast] = []
                
                for i in 0..<min(maxTemps.count, forecastDays) {
                    let dayDate = cal.date(byAdding: .day, value: i, to: startDate) ?? startDate
                    let maxT = maxTemps[i]
                    let minT = minTemps[i]
                    let wmoCode = weatherCodes[i]
                    let rainPct = rainProbs.indices.contains(i) ? rainProbs[i] : 10
                    
                    let (condition, icon, advisory) = Self.mapWMOCode(wmoCode, maxTemp: maxT, rainChance: rainPct)
                    
                    parsedForecasts.append(WeatherForecast(
                        date: dayDate,
                        condition: condition,
                        iconName: icon,
                        minTempC: minT,
                        maxTempC: maxT,
                        rainChancePct: rainPct,
                        advisory: advisory
                    ))
                }
                
                if !parsedForecasts.isEmpty {
                    return parsedForecasts
                }
            }
        } catch {
            AppLogger.shared.info("[Open-Meteo Provider] Forecast request failed (\(error.localizedDescription))", category: .pipeline)
        }
        
        AppLogger.shared.info("[Offline Fallback] Using local weather estimates for '\(destination)'", category: .pipeline)
        return try await fallback.getForecast(destination: destination, startDate: startDate, days: days)
    }
    
    /// Maps standard World Meteorological Organization (WMO) codes to human-readable labels, icons, and advisories.
    private static func mapWMOCode(_ code: Int, maxTemp: Double, rainChance: Int) -> (condition: String, icon: String, advisory: String) {
        switch code {
        case 0:
            return ("Sunny & Clear Skies", "sun.max.fill", "Clear sunny weather. Great for outdoor panoramic sights.")
        case 1, 2, 3:
            return ("Partly Cloudy", "cloud.sun.fill", "Mild and pleasant conditions. Ideal for walking tours.")
        case 45, 48:
            return ("Foggy & Mist", "cloud.fog.fill", "Reduced morning visibility. Plan mountain drives later in the day.")
        case 51, 53, 55:
            return ("Light Drizzle", "cloud.drizzle.fill", "Intermittent drizzle. Carry light waterproof jackets.")
        case 61, 63, 65:
            return ("Rain Showers", "cloud.rain.fill", "Rain showers expected. Good day for museums, cafes, and indoor cultural visits.")
        case 71, 73, 75, 77:
            return ("Snowfall", "snowflake", "Cold temperatures and snowfall. Warm winter layers and thermal wear required.")
        case 80, 81, 82:
            return ("Heavy Rain Showers", "cloud.heavyrain.fill", "Heavy showers forecast. Check transit and trail advisories.")
        case 95, 96, 99:
            return ("Thunderstorms", "cloud.bolt.rain.fill", "Thunderstorms probable. Exercise caution on elevated trails and open viewpoints.")
        default:
            if maxTemp > 30.0 {
                return ("Warm & Sunny", "sun.max.fill", "Stay hydrated and plan outdoor activities during morning hours.")
            } else if maxTemp < 10.0 {
                return ("Chilly Mountain Air", "thermometer.snowflake", "Cold weather. Layered warm clothing advised.")
            } else {
                return ("Pleasant Weather", "cloud.sun.fill", "Comfortable sightseeing conditions.")
            }
        }
    }
}
