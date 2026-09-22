import Foundation

// MARK: - HTTP Methods

/// Standard HTTP request methods supported by the TravelPartner networking layer.
public enum HTTPMethod: String, Sendable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
}

// MARK: - Network Request

/// Strongly-typed network request descriptor.
///
/// Can be constructed directly or converted from/to Foundation's `URLRequest`.
///
/// Example:
/// ```swift
/// let req = Request(url: apiURL, method: .get, headers: ["x-api-key": apiKey])
/// let places: [PlaceCandidate] = try await network.perform(request: req)
/// ```
public struct Request: Sendable {
    public var url: URL
    public var method: HTTPMethod
    public var headers: [String: String]
    public var body: Data?
    public var timeoutInterval: TimeInterval
    public var cachePolicy: URLRequest.CachePolicy
    
    public init(
        url: URL,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeoutInterval: TimeInterval = 10.0,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
        self.cachePolicy = cachePolicy
    }
    
    public init(
        urlString: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeoutInterval: TimeInterval = 10.0,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) throws {
        guard let parsedURL = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }
        self.url = parsedURL
        self.method = method
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
        self.cachePolicy = cachePolicy
    }
    
    public init<B: Encodable>(
        url: URL,
        method: HTTPMethod = .post,
        jsonBody: B,
        encoder: JSONEncoder = JSONEncoder(),
        headers: [String: String] = [:],
        timeoutInterval: TimeInterval = 10.0
    ) throws {
        self.url = url
        self.method = method
        var allHeaders = headers
        if allHeaders["Content-Type"] == nil {
            allHeaders["Content-Type"] = "application/json"
        }
        self.headers = allHeaders
        self.body = try encoder.encode(jsonBody)
        self.timeoutInterval = timeoutInterval
        self.cachePolicy = .useProtocolCachePolicy
    }
    
    public init(urlRequest: URLRequest) {
        self.url = urlRequest.url ?? URL(string: "about:blank")!
        self.method = HTTPMethod(rawValue: urlRequest.httpMethod ?? "GET") ?? .get
        self.headers = urlRequest.allHTTPHeaderFields ?? [:]
        self.body = urlRequest.httpBody
        self.timeoutInterval = urlRequest.timeoutInterval > 0 ? urlRequest.timeoutInterval : 10.0
        self.cachePolicy = urlRequest.cachePolicy
    }
    
    public func asURLRequest() -> URLRequest {
        var req = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
        req.httpMethod = method.rawValue
        for (key, value) in headers {
            req.setValue(value, forHTTPHeaderField: key)
        }
        req.httpBody = body
        return req
    }
    
    public func settingHeader(_ name: String, _ value: String) -> Request {
        var copy = self
        copy.headers[name] = value
        return copy
    }
}

public typealias NetworkRequest = Request

// MARK: - Network Errors

/// Granular errors emitted by the unified networking client.
public enum NetworkError: LocalizedError, Sendable {
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int, data: Data, message: String?)
    case decodingError(underlyingError: Error, typeName: String, data: Data)
    case networkError(underlyingError: Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let urlString):
            return "Invalid URL: '\(urlString)'"
        case .invalidResponse:
            return "Invalid non-HTTP response received from server."
        case .httpError(let statusCode, _, let message):
            if let msg = message, !msg.isEmpty {
                return "HTTP \(statusCode) Error: \(msg)"
            }
            return "HTTP request failed with status code \(statusCode)."
        case .decodingError(let underlying, let typeName, _):
            return "Failed to decode response as \(typeName): \(underlying.localizedDescription)"
        case .networkError(let underlying):
            return "Network connection failed: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - Network Response Container

/// Container carrying the parsed response, raw bytes, HTTP headers, and duration.
public struct NetworkResponse<T>: Sendable {
    public let value: T
    public let data: Data
    public let httpResponse: HTTPURLResponse
    public let duration: TimeInterval
    
    public var statusCode: Int { httpResponse.statusCode }
    
    public init(value: T, data: Data, httpResponse: HTTPURLResponse, duration: TimeInterval) {
        self.value = value
        self.data = data
        self.httpResponse = httpResponse
        self.duration = duration
    }
}

// MARK: - Network Protocol

/// Abstract interface for executing network requests and parsing into Codable structs.
public protocol NetworkProtocol: Sendable {
    /// Performs an HTTP request and decodes the response body into the generic type `T`.
    ///
    /// Example:
    /// ```swift
    /// let places: [PlaceCandidate] = try await network.perform(request: request)
    /// ```
    func perform<T: Decodable>(
        request: Request,
        decoder: JSONDecoder
    ) async throws -> T
    
    func perform<T: Decodable>(
        request: Request,
        decoder: JSONDecoder,
        limiter: RateLimiter?
    ) async throws -> T
    
    /// Overload for `perform` accepting a Foundation `URLRequest`.
    func perform<T: Decodable>(
        request: URLRequest,
        decoder: JSONDecoder
    ) async throws -> T
    
    /// Performs an HTTP request and returns a `NetworkResponse<T>` with full metadata and duration.
    func performWithResponse<T: Decodable>(
        request: Request,
        decoder: JSONDecoder,
        limiter: RateLimiter?
    ) async throws -> NetworkResponse<T>
    
    /// Overload for `performWithResponse` accepting a Foundation `URLRequest`.
    func performWithResponse<T: Decodable>(
        request: URLRequest,
        decoder: JSONDecoder,
        limiter: RateLimiter?
    ) async throws -> NetworkResponse<T>
    
    /// Performs an HTTP request and returns the raw `Data`.
    func perform(request: Request) async throws -> Data
    func perform(request: URLRequest) async throws -> Data
    
    /// Performs a low-level HTTP request returning raw data, response headers, and duration without throwing on non-2xx codes.
    func performRaw(request: Request) async throws -> (data: Data, response: HTTPURLResponse, duration: TimeInterval)
    func performRaw(request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse, duration: TimeInterval)
}

// Default parameter extensions for NetworkProtocol
extension NetworkProtocol {
    public func perform<T: Decodable>(request: Request) async throws -> T {
        try await perform(request: request, decoder: JSONDecoder())
    }
    public func perform<T: Decodable>(request: Request, limiter: RateLimiter? = nil) async throws -> T {
        try await perform(request: request, decoder: JSONDecoder(), limiter: limiter)
    }
    
    public func perform<T: Decodable>(request: URLRequest) async throws -> T {
        try await perform(request: request, decoder: JSONDecoder())
    }
    
    public func performWithResponse<T: Decodable>(request: Request) async throws -> NetworkResponse<T> {
        try await performWithResponse(request: request, decoder: JSONDecoder(), limiter: nil)
    }
    
    public func performWithResponse<T: Decodable>(request: URLRequest) async throws -> NetworkResponse<T> {
        try await performWithResponse(request: request, decoder: JSONDecoder(), limiter: nil)
    }
}

// MARK: - Network Implementation

/// Centralized, production-grade network client.
///
/// **Architecture & Guarantees:**
/// - Strictly encapsulates `URLSession` data tasks.
/// - Automatically logs all outgoing calls, response latencies, and payload counts via `AppLogger`.
/// - Generic parsing into any `Decodable` type using standard or custom `JSONDecoder`.
/// - Thread-safe (`Sendable`) and built for modern Swift structured concurrency (`async/await`).
public final class Network: NetworkProtocol, Sendable {
    
    public static let shared = Network()
    
    private let session: URLSession
    private let logger: AppLogger
    
    public init(session: URLSession = .shared, logger: AppLogger = .shared) {
        self.session = session
        self.logger = logger
    }
    
    // MARK: - Raw Execution
    
    public func performRaw(request: Request) async throws -> (data: Data, response: HTTPURLResponse, duration: TimeInterval) {
        let urlReq = request.asURLRequest()
        let urlString = urlReq.url?.absoluteString ?? "unknown_url"
        let endpoint = (urlReq.url?.host ?? "") + (urlReq.url?.path ?? "")
        let method = urlReq.httpMethod ?? request.method.rawValue
        let startTime = Date()
        
        do {
            let (data, response) = try await session.data(for: urlReq)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let http = response as? HTTPURLResponse else {
                let err = NetworkError.invalidResponse
                logger.logAPIError(
                    endpoint: endpoint.isEmpty ? urlString : endpoint,
                    method: method,
                    error: err,
                    duration: duration
                )
                throw err
            }
            
            return (data, http, duration)
        } catch let err as NetworkError {
            throw err
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let wrapped = NetworkError.networkError(underlyingError: error)
            logger.logAPIError(
                endpoint: endpoint.isEmpty ? urlString : endpoint,
                method: method,
                error: wrapped,
                duration: duration
            )
            throw wrapped
        }
    }
    
    public func perform<T>(request: Request, decoder: JSONDecoder, limiter: RateLimiter?) async throws -> T where T : Decodable {
        let response: NetworkResponse<T> = try await performWithResponse(request: request, decoder: decoder, limiter: limiter)
        return response.value
    }
    
    public func performRaw(request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse, duration: TimeInterval) {
        try await performRaw(request: Request(urlRequest: request))
    }
    
    // MARK: - Decodable Execution with Full Response
    
    public func performWithResponse<T: Decodable>(
        request: Request,
        decoder: JSONDecoder = JSONDecoder(),
        limiter: RateLimiter? = nil
    ) async throws -> NetworkResponse<T> {
        let urlReq = request.asURLRequest()
        let urlString = urlReq.url?.absoluteString ?? "unknown_url"
        let endpoint = (urlReq.url?.host ?? "") + (urlReq.url?.path ?? "")
        let method = urlReq.httpMethod ?? request.method.rawValue
        
        await limiter?.acquire()
        
        let (data, http, duration) = try await performRaw(request: request)
        
        guard (200...299).contains(http.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8)
            let httpErr = NetworkError.httpError(
                statusCode: http.statusCode,
                data: data,
                message: errorMsg
            )
            logger.logAPIError(
                endpoint: endpoint.isEmpty ? urlString : endpoint,
                method: method,
                statusCode: http.statusCode,
                error: httpErr,
                duration: duration,
                details: errorMsg
            )
            throw httpErr
        }
        
        logger.logAPISuccess(
            endpoint: endpoint.isEmpty ? urlString : endpoint,
            method: method,
            statusCode: http.statusCode,
            duration: duration,
            payloadSummary: "HTTP \(http.statusCode) OK (\(data.count) bytes)"
        )
        
        // If caller requested raw Data as T, bypass JSON decoding
        if let rawData = data as? T {
            return NetworkResponse(value: rawData, data: data, httpResponse: http, duration: duration)
        }
        
        do {
            let decoded = try decoder.decode(T.self, from: data)
            return NetworkResponse(value: decoded, data: data, httpResponse: http, duration: duration)
        } catch {
            let decodeErr = NetworkError.decodingError(
                underlyingError: error,
                typeName: String(describing: T.self),
                data: data
            )
            logger.logAPIError(
                endpoint: endpoint.isEmpty ? urlString : endpoint,
                method: method,
                statusCode: http.statusCode,
                error: decodeErr,
                duration: duration,
                details: "Failed to decode \(T.self): \(error.localizedDescription)"
            )
            throw decodeErr
        }
    }
    
    public func performWithResponse<T: Decodable>(
        request: URLRequest,
        decoder: JSONDecoder = JSONDecoder(),
        limiter: RateLimiter? = nil
    ) async throws -> NetworkResponse<T> {
        try await performWithResponse(request: Request(urlRequest: request), decoder: decoder)
    }
    
    // MARK: - Decodable Execution
    
    public func perform<T: Decodable>(
        request: Request,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let response: NetworkResponse<T> = try await performWithResponse(request: request, decoder: decoder)
        return response.value
    }
    
    public func perform<T: Decodable>(
        request: URLRequest,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        try await perform(request: Request(urlRequest: request), decoder: decoder)
    }
    
    // MARK: - Raw Data Execution
    
    public func perform(request: Request) async throws -> Data {
        let resp: NetworkResponse<Data> = try await performWithResponse(request: request)
        return resp.data
    }
    
    public func perform(request: URLRequest) async throws -> Data {
        let resp: NetworkResponse<Data> = try await performWithResponse(request: Request(urlRequest: request))
        return resp.data
    }
}

// MARK: - Type Aliases

public typealias NetworkService = Network
public typealias NetworkClient = Network
