import Foundation
import os

// MARK: - Log Categories

/// Logical categories partitioning logs across TravelPartner subsystems.
public enum LogCategory: String, CaseIterable, Sendable, Codable {
    case api = "API"
    case coreML = "CoreML"
    case gemini = "Gemini"
    case pipeline = "Pipeline"
    case general = "General"
    
    public var displayName: String {
        switch self {
        case .api: return "API Networking"
        case .coreML: return "Core ML On-Device"
        case .gemini: return "Google Gemini AI"
        case .pipeline: return "Trip Planner Pipeline"
        case .general: return "App Lifecycle"
        }
    }
    
    public var emoji: String {
        switch self {
        case .api: return "🌐"
        case .coreML: return "🧠"
        case .gemini: return "✨"
        case .pipeline: return "⚡️"
        case .general: return "📋"
        }
    }
}

// MARK: - Log Levels

/// Severity levels for categorizing log output.
public enum LogLevel: String, CaseIterable, Sendable, Codable, Comparable {
    case debug = "DEBUG"
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"
    
    public var severity: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .success: return 2
        case .warning: return 3
        case .error: return 4
        }
    }
    
    public var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.severity < rhs.severity
    }
}

// MARK: - Log Entry

/// An immutable, structured log record.
public struct LogEntry: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let category: LogCategory
    public let level: LogLevel
    public let message: String
    public let details: String?
    public let duration: TimeInterval?
    public let metadata: [String: String]
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: LogCategory,
        level: LogLevel,
        message: String,
        details: String? = nil,
        duration: TimeInterval? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.level = level
        self.message = message
        self.details = details
        self.duration = duration
        self.metadata = metadata
    }
    
    /// Formatted time string: HH:mm:ss.SSS
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    /// Human-readable duration in milliseconds or seconds.
    public var formattedDuration: String? {
        guard let duration = duration else { return nil }
        if duration < 1.0 {
            return String(format: "%.0fms", duration * 1000.0)
        } else {
            return String(format: "%.2fs", duration)
        }
    }
    
    /// Formatted one-line message ideal for terminal or Xcode console output.
    public var consoleDescription: String {
        var parts: [String] = []
        parts.append("[\(formattedTime)]")
        parts.append("[\(category.emoji) \(category.rawValue) \(level.emoji)]")
        if let dur = formattedDuration {
            parts.append("(\(dur))")
        }
        parts.append(message)
        if let details = details, !details.isEmpty {
            parts.append("\n  └─ Details: \(details)")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - AppLogger Class

/// Centralized, thread-safe logging engine for the Travel Partner application.
///
/// **Features:**
/// - **API Logging**: Logs HTTP method, endpoint, status codes, duration, payload summaries, and failures.
/// - **Core ML Logging**: Logs model inference latency, candidate counts, top scores, and on-device ranking metrics.
/// - **Gemini AI Logging**: Logs prompts, model versions, narrative outputs, JSON parse completions, streaming chunks, and fallbacks.
/// - **Dual Delivery**: Emits to Apple Unified OSLog system (`os.Logger`) and formats prints to console.
/// - **In-Memory History**: Thread-safe ring buffer for inspecting, filtering, and debugging recent activity in-app.
public final class AppLogger: @unchecked Sendable {
    public static let shared = AppLogger()
    
    private let lock = NSLock()
    private var entries: [LogEntry] = []
    private var observers: [UUID: @Sendable (LogEntry) -> Void] = [:]
    
    public var maxEntries: Int = 500
    public var isConsolePrintEnabled: Bool = true
    public var minLogLevel: LogLevel = .debug
    
    private let subsystem = "com.travelpartner.app"
    private var osLoggers: [LogCategory: Logger] = [:]
    
    public init() {
        for cat in LogCategory.allCases {
            osLoggers[cat] = Logger(subsystem: subsystem, category: cat.rawValue)
        }
    }
    
    // MARK: - Core Logging Mechanism
    
    /// Records a structured log entry, publishes it to Apple OSLog, logs to console, and alerts observers.
    public func log(
        category: LogCategory,
        level: LogLevel,
        message: String,
        details: String? = nil,
        duration: TimeInterval? = nil,
        metadata: [String: String] = [:]
    ) {
        guard level.severity >= minLogLevel.severity else { return }
        
        let entry = LogEntry(
            category: category,
            level: level,
            message: message,
            details: details,
            duration: duration,
            metadata: metadata
        )
        
        // 1. Thread-safe store update & capture observers
        var activeObservers: [@Sendable (LogEntry) -> Void] = []
        lock.lock()
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        activeObservers = Array(observers.values)
        lock.unlock()
        
        // 2. Apple Unified OSLog
        let osLogger = osLoggers[category] ?? Logger(subsystem: subsystem, category: category.rawValue)
        switch level {
        case .debug:
            osLogger.debug("\(entry.consoleDescription, privacy: .public)")
        case .info, .success:
            osLogger.info("\(entry.consoleDescription, privacy: .public)")
        case .warning:
            osLogger.warning("\(entry.consoleDescription, privacy: .public)")
        case .error:
            osLogger.error("\(entry.consoleDescription, privacy: .public)")
        }
        
        // 3. Console output
        if isConsolePrintEnabled {
            print(entry.consoleDescription)
        }
        
        // 4. Notify observers
        for observer in activeObservers {
            observer(entry)
        }
    }
    
    // MARK: - API Networking Logging
    
    /// Logs successful API operations with status code, endpoint, and duration.
    public func logAPISuccess(
        endpoint: String,
        method: String = "GET",
        statusCode: Int = 200,
        duration: TimeInterval? = nil,
        payloadSummary: String? = nil,
        metadata: [String: String] = [:]
    ) {
        var msg = "\(method) \(endpoint) -> \(statusCode) OK"
        if let summary = payloadSummary {
            msg += " [\(summary)]"
        }
        
        var meta = metadata
        meta["method"] = method
        meta["endpoint"] = endpoint
        meta["statusCode"] = "\(statusCode)"
        
        log(
            category: .api,
            level: .success,
            message: msg,
            details: payloadSummary,
            duration: duration,
            metadata: meta
        )
    }
    
    /// Logs failed API operations with status code, endpoint, and error details.
    public func logAPIError(
        endpoint: String,
        method: String = "GET",
        statusCode: Int? = nil,
        error: Error,
        duration: TimeInterval? = nil,
        details: String? = nil,
        metadata: [String: String] = [:]
    ) {
        let statusString = statusCode.map { "\($0)" } ?? "N/A"
        let msg = "\(method) \(endpoint) -> Status: \(statusString) FAILED: \(error.localizedDescription)"
        
        var meta = metadata
        meta["method"] = method
        meta["endpoint"] = endpoint
        if let sc = statusCode { meta["statusCode"] = "\(sc)" }
        meta["errorDescription"] = error.localizedDescription
        
        log(
            category: .api,
            level: .error,
            message: msg,
            details: details ?? String(describing: error),
            duration: duration,
            metadata: meta
        )
    }
    
    // MARK: - Core ML On-Device Logging
    
    /// Logs on-device Core ML model inference results.
    public func logCoreMLResponse(
        modelName: String,
        candidateCount: Int,
        topCandidate: String? = nil,
        topScore: Double? = nil,
        duration: TimeInterval,
        isFallback: Bool = false,
        details: String? = nil,
        metadata: [String: String] = [:]
    ) {
        var msg = "\(modelName) evaluated \(candidateCount) candidates"
        if isFallback {
            msg += " (Deterministic MCDA Fallback Engine)"
        }
        if let top = topCandidate {
            if let score = topScore {
                msg += " -> Top: '\(top)' (score: \(String(format: "%.2f", score)))"
            } else {
                msg += " -> Top: '\(top)'"
            }
        }
        
        var meta = metadata
        meta["modelName"] = modelName
        meta["candidateCount"] = "\(candidateCount)"
        meta["isFallback"] = "\(isFallback)"
        if let top = topCandidate { meta["topCandidate"] = top }
        if let score = topScore { meta["topScore"] = String(format: "%.4f", score) }
        
        log(
            category: .coreML,
            level: isFallback ? .warning : .success,
            message: msg,
            details: details,
            duration: duration,
            metadata: meta
        )
    }
    
    /// Logs Core ML errors and records whether deterministic fallback was activated.
    public func logCoreMLError(
        modelName: String,
        error: Error,
        fallbackUsed: Bool = true,
        details: String? = nil,
        metadata: [String: String] = [:]
    ) {
        let msg = "\(modelName) inference failure: \(error.localizedDescription)\(fallbackUsed ? " [Engaging Fallback]" : "")"
        var meta = metadata
        meta["modelName"] = modelName
        meta["fallbackUsed"] = "\(fallbackUsed)"
        meta["error"] = error.localizedDescription
        
        log(
            category: .coreML,
            level: .error,
            message: msg,
            details: details ?? String(describing: error),
            metadata: meta
        )
    }
    
    // MARK: - Google Gemini Generative AI Logging
    
    /// Logs Google Gemini AI inference responses (narratives, prompt parsing, conversational edits).
    public func logGeminiResponse(
        action: String,
        model: String,
        duration: TimeInterval,
        promptSnippet: String? = nil,
        responseSnippet: String,
        isFallback: Bool = false,
        tokenCountEstimate: Int? = nil,
        metadata: [String: String] = [:]
    ) {
        var msg = "[\(model)] \(action)"
        if isFallback {
            msg += " (Offline Deterministic NLU)"
        }
        
        var detailsList: [String] = []
        if let prompt = promptSnippet, !prompt.isEmpty {
            let snippet = prompt.count > 120 ? "\(prompt.prefix(120))..." : prompt
            detailsList.append("Prompt: \"\(snippet)\"")
        }
        let cleanResponse = responseSnippet.replacingOccurrences(of: "\n", with: " ")
        let resSnippet = cleanResponse.count > 160 ? "\(cleanResponse.prefix(160))..." : cleanResponse
        detailsList.append("Response: \"\(resSnippet)\"")
        
        if let tokens = tokenCountEstimate {
            detailsList.append("Tokens ~\(tokens)")
        }
        
        var meta = metadata
        meta["action"] = action
        meta["model"] = model
        meta["isFallback"] = "\(isFallback)"
        
        log(
            category: .gemini,
            level: isFallback ? .info : .success,
            message: msg,
            details: detailsList.joined(separator: "\n  └─ "),
            duration: duration,
            metadata: meta
        )
    }
    
    /// Logs Gemini AI errors and records whether offline fallback was activated.
    public func logGeminiError(
        action: String,
        model: String = "gemini-2.5-flash",
        error: Error,
        fallbackUsed: Bool = true,
        promptSnippet: String? = nil,
        metadata: [String: String] = [:]
    ) {
        let msg = "[\(model)] \(action) Error: \(error.localizedDescription)\(fallbackUsed ? " [Switching to Fallback NLU]" : "")"
        var meta = metadata
        meta["action"] = action
        meta["model"] = model
        meta["fallbackUsed"] = "\(fallbackUsed)"
        meta["error"] = error.localizedDescription
        
        log(
            category: .gemini,
            level: .error,
            message: msg,
            details: promptSnippet != nil ? "Prompt: \"\(promptSnippet!)\"\nError: \(error)" : String(describing: error),
            metadata: meta
        )
    }
    
    /// Logs individual streaming chunks received from Gemini.
    public func logGeminiStreamChunk(
        action: String,
        chunkIndex: Int,
        textSnippet: String
    ) {
        let clean = textSnippet.replacingOccurrences(of: "\n", with: " ")
        let snippet = clean.count > 60 ? "\(clean.prefix(60))..." : clean
        log(
            category: .gemini,
            level: .debug,
            message: "Stream chunk #\(chunkIndex) for \(action): \"\(snippet)\""
        )
    }
    
    // MARK: - General Purpose Log Convenience
    
    public func debug(_ message: String, category: LogCategory = .general, details: String? = nil, metadata: [String: String] = [:]) {
        log(category: category, level: .debug, message: message, details: details, metadata: metadata)
    }
    
    public func info(_ message: String, category: LogCategory = .general, details: String? = nil, metadata: [String: String] = [:]) {
        log(category: category, level: .info, message: message, details: details, metadata: metadata)
    }
    
    public func warning(_ message: String, category: LogCategory = .general, details: String? = nil, metadata: [String: String] = [:]) {
        log(category: category, level: .warning, message: message, details: details, metadata: metadata)
    }
    
    public func error(_ message: String, category: LogCategory = .general, error: Error? = nil, details: String? = nil, metadata: [String: String] = [:]) {
        let combined = details ?? error?.localizedDescription
        log(category: category, level: .error, message: message, details: combined, metadata: metadata)
    }
    
    public func success(_ message: String, category: LogCategory = .general, details: String? = nil, metadata: [String: String] = [:]) {
        log(category: category, level: .success, message: message, details: details, metadata: metadata)
    }
    
    // MARK: - History, Inspection & Export
    
    /// Retrieves the most recent log records up to `limit`.
    public func recentLogs(limit: Int = 100) -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        let start = max(0, entries.count - limit)
        return Array(entries[start..<entries.count])
    }
    
    /// Returns all buffered logs matching a specific category.
    public func logs(for category: LogCategory) -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries.filter { $0.category == category }
    }
    
    /// Returns all buffered logs matching a specific severity level.
    public func logs(for level: LogLevel) -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries.filter { $0.level == level }
    }
    
    /// Clears the in-memory log buffer.
    public func clearLogs() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }
    
    /// Exports all buffered log entries formatted as plain text for diagnostic sharing.
    public func exportLogsAsString() -> String {
        lock.lock()
        let snapshot = entries
        lock.unlock()
        
        var output = "=== TRAVEL PARTNER SYSTEM LOGS ===\n"
        output += "Exported At: \(Date())\n"
        output += "Total Entries: \(snapshot.count)\n\n"
        for entry in snapshot {
            output += entry.consoleDescription + "\n"
        }
        return output
    }
    
    // MARK: - Observer Pattern (Async / UI Subscriptions)
    
    /// Subscribes an observer to real-time log emissions.
    @discardableResult
    public func observe(onLog: @escaping @Sendable (LogEntry) -> Void) -> UUID {
        let id = UUID()
        lock.lock()
        observers[id] = onLog
        lock.unlock()
        return id
    }
    
    /// Removes a previously registered observer.
    public func removeObserver(id: UUID) {
        lock.lock()
        observers.removeValue(forKey: id)
        lock.unlock()
    }
}
