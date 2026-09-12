import Foundation

/// Real-world Live Weather Provider using the free, open Open-Meteo API.
///
/// **Open-Meteo Features:**
/// - 100% Free, no API key or credit card required
/// - Live geocoding for any destination worldwide
/// - 7-14 day daily forecasts including max/min temperatures, precipitation probabilities, and WMO weather codes
/// - Authentic HTTP requests with live status code and payload logging
public final class OpenMeteoWeatherSearchProvider: WeatherSearchProviderProtocol, Sendable {
    private let session: URLSession
    private let fallback: MockWeatherSearchProvider
    
    public init(
        session: URLSession = .shared,
        fallback: MockWeatherSearchProvider = MockWeatherSearchProvider()
    ) {
        self.session = session
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
        
        let geocodeStart = Date()
        var latitude: Double?
        var longitude: Double?
        
        do {
            var geoRequest = URLRequest(url: geocodeUrl)
            geoRequest.timeoutInterval = 6.0
            let (data, response) = try await session.data(for: geoRequest)
            let duration = Date().timeIntervalSince(geocodeStart)
            
            if let http = response as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    AppLogger.shared.logAPISuccess(
                        endpoint: "geocoding-api.open-meteo.com/v1/search?name=\(cleanDest)",
                        method: "GET",
                        statusCode: http.statusCode,
                        duration: duration,
                        payloadSummary: "Geocoding resolved for '\(cleanDest)': \(data.count) bytes"
                    )
                    
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let results = json["results"] as? [[String: Any]],
                       let first = results.first {
                        latitude = first["latitude"] as? Double
                        longitude = first["longitude"] as? Double
                    }
                } else {
                    AppLogger.shared.logAPIError(
                        endpoint: "geocoding-api.open-meteo.com/v1/search?name=\(cleanDest)",
                        method: "GET",
                        statusCode: http.statusCode,
                        error: TravelSearchError.providerFailed(provider: "Open-Meteo Geocode", reason: "HTTP status \(http.statusCode)"),
                        duration: duration
                    )
                }
            }
        } catch {
            let duration = Date().timeIntervalSince(geocodeStart)
            AppLogger.shared.logAPIError(
                endpoint: "geocoding-api.open-meteo.com/v1/search?name=\(cleanDest)",
                method: "GET",
                error: error,
                duration: duration
            )
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
        
        let forecastStart = Date()
        do {
            var forecastRequest = URLRequest(url: forecastUrl)
            forecastRequest.timeoutInterval = 7.0
            let (data, response) = try await session.data(for: forecastRequest)
            let duration = Date().timeIntervalSince(forecastStart)
            
            guard let http = response as? HTTPURLResponse else {
                return try await fallback.getForecast(destination: destination, startDate: startDate, days: days)
            }
            
            if (200...299).contains(http.statusCode) {
                AppLogger.shared.logAPISuccess(
                    endpoint: "api.open-meteo.com/v1/forecast?lat=\(String(format: "%.2f", lat))&lon=\(String(format: "%.2f", lon))",
                    method: "GET",
                    statusCode: http.statusCode,
                    duration: duration,
                    payloadSummary: "Retrieved \(forecastDays) days live forecast for '\(cleanDest)'"
                )
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let daily = json["daily"] as? [String: Any],
                   let maxTemps = daily["temperature_2m_max"] as? [Double],
                   let minTemps = daily["temperature_2m_min"] as? [Double],
                   let weatherCodes = daily["weather_code"] as? [Int] {
                    
                    let rainProbs = daily["precipitation_probability_max"] as? [Int] ?? Array(repeating: 10, count: maxTemps.count)
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
            } else {
                AppLogger.shared.logAPIError(
                    endpoint: "api.open-meteo.com/v1/forecast",
                    method: "GET",
                    statusCode: http.statusCode,
                    error: TravelSearchError.providerFailed(provider: "Open-Meteo Forecast", reason: "HTTP status \(http.statusCode)"),
                    duration: duration
                )
            }
        } catch {
            let duration = Date().timeIntervalSince(forecastStart)
            AppLogger.shared.logAPIError(
                endpoint: "api.open-meteo.com/v1/forecast",
                method: "GET",
                error: error,
                duration: duration
            )
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
