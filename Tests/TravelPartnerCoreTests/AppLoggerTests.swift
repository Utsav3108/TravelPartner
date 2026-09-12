import Testing
import Foundation
@testable import TravelPartnerCore

struct AppLoggerTests {
    
    @Test("AppLogger records API success and error operations accurately")
    func testAPILogging() {
        let logger = AppLogger()
        logger.isConsolePrintEnabled = false
        logger.clearLogs()
        
        // Log API Success
        logger.logAPISuccess(
            endpoint: "/api/v1/flights",
            method: "GET",
            statusCode: 200,
            duration: 0.125,
            payloadSummary: "Found 4 flights"
        )
        
        let successLogs = logger.logs(for: .api)
        #expect(successLogs.count == 1)
        #expect(successLogs.first?.level == .success)
        #expect(successLogs.first?.category == .api)
        #expect(successLogs.first?.message.contains("/api/v1/flights") == true)
        #expect(successLogs.first?.message.contains("200 OK") == true)
        #expect(successLogs.first?.metadata["statusCode"] == "200")
        #expect(successLogs.first?.metadata["method"] == "GET")
        
        // Log API Error
        enum TestAPIError: LocalizedError {
            case serverUnavailable
            var errorDescription: String? { "503 Service Unavailable" }
        }
        
        logger.logAPIError(
            endpoint: "/api/v1/hotels",
            method: "POST",
            statusCode: 503,
            error: TestAPIError.serverUnavailable,
            duration: 0.350,
            details: "Hotel provider timed out"
        )
        
        let allApiLogs = logger.logs(for: .api)
        #expect(allApiLogs.count == 2)
        let errorLog = allApiLogs.last
        #expect(errorLog?.level == .error)
        #expect(errorLog?.message.contains("503") == true)
        #expect(errorLog?.message.contains("503 Service Unavailable") == true)
        #expect(errorLog?.metadata["statusCode"] == "503")
    }
    
    @Test("AppLogger records Core ML inferences and fallbacks")
    func testCoreMLLogging() {
        let logger = AppLogger()
        logger.isConsolePrintEnabled = false
        logger.clearLogs()
        
        // Log Core ML inference response
        logger.logCoreMLResponse(
            modelName: "HotelRankingModel",
            candidateCount: 10,
            topCandidate: "Grand Heritage Resort",
            topScore: 0.96,
            duration: 0.018,
            isFallback: false,
            details: "Ranked against user preferences"
        )
        
        let coreMLLogs = logger.logs(for: .coreML)
        #expect(coreMLLogs.count == 1)
        #expect(coreMLLogs.first?.level == .success)
        #expect(coreMLLogs.first?.message.contains("HotelRankingModel") == true)
        #expect(coreMLLogs.first?.message.contains("Grand Heritage Resort") == true)
        #expect(coreMLLogs.first?.metadata["topScore"] == "0.9600")
        #expect(coreMLLogs.first?.metadata["isFallback"] == "false")
        
        // Log Core ML fallback activation
        logger.logCoreMLResponse(
            modelName: "PlaceRankingModel",
            candidateCount: 8,
            topCandidate: "Mall Road",
            topScore: 0.88,
            duration: 0.003,
            isFallback: true,
            details: "Fallback MCDA scorer"
        )
        
        let updatedCoreMLLogs = logger.logs(for: .coreML)
        #expect(updatedCoreMLLogs.count == 2)
        #expect(updatedCoreMLLogs.last?.level == .warning)
        #expect(updatedCoreMLLogs.last?.message.contains("Deterministic MCDA Fallback") == true)
        
        // Log Core ML inference error
        enum MockMLError: LocalizedError {
            case modelCompilationFailed
            var errorDescription: String? { "Model file corrupted" }
        }
        
        logger.logCoreMLError(
            modelName: "TransportRankingModel",
            error: MockMLError.modelCompilationFailed,
            fallbackUsed: true
        )
        
        #expect(logger.logs(for: .coreML).count == 3)
        #expect(logger.logs(for: .error).count == 1)
    }
    
    @Test("AppLogger records Gemini AI responses, streaming chunks, and errors")
    func testGeminiLogging() {
        let logger = AppLogger()
        logger.isConsolePrintEnabled = false
        logger.clearLogs()
        
        // Log Gemini prompt parsing response
        logger.logGeminiResponse(
            action: "parseTripPrompt",
            model: "gemini-2.5-flash",
            duration: 0.85,
            promptSnippet: "Plan 5 days in Manali for 2",
            responseSnippet: "Parsed destination: Manali, 5 days, 2 travelers",
            isFallback: false
        )
        
        let geminiLogs = logger.logs(for: .gemini)
        #expect(geminiLogs.count == 1)
        #expect(geminiLogs.first?.level == .success)
        #expect(geminiLogs.first?.message.contains("gemini-2.5-flash") == true)
        #expect(geminiLogs.first?.message.contains("parseTripPrompt") == true)
        
        // Log stream chunks
        logger.logGeminiStreamChunk(action: "generateNarrative", chunkIndex: 0, textSnippet: "Welcome to Manali")
        logger.logGeminiStreamChunk(action: "generateNarrative", chunkIndex: 1, textSnippet: " where the mountains meet the clouds")
        
        #expect(logger.logs(for: .gemini).count == 3)
        #expect(logger.logs(for: .debug).count == 2)
        
        // Log Gemini Error
        logger.logGeminiError(
            action: "generateNarrative",
            model: "gemini-2.5-flash",
            error: GeminiError.rateLimited,
            fallbackUsed: true,
            promptSnippet: "Trip narrative prompt"
        )
        
        #expect(logger.logs(for: .gemini).count == 4)
        #expect(logger.logs(for: .error).count == 1)
    }
    
    @Test("AppLogger in-memory buffer, exports and observer notifications")
    func testLogBufferAndObservers() {
        let logger = AppLogger()
        logger.isConsolePrintEnabled = false
        logger.clearLogs()
        
        final class LogCollector: @unchecked Sendable {
            private let lock = NSLock()
            var entries: [LogEntry] = []
            func append(_ entry: LogEntry) {
                lock.lock()
                defer { lock.unlock() }
                entries.append(entry)
            }
            var count: Int {
                lock.lock()
                defer { lock.unlock() }
                return entries.count
            }
        }
        
        let collector = LogCollector()
        let observerId = logger.observe { entry in
            collector.append(entry)
        }
        
        logger.info("Starting pipeline", category: .pipeline)
        logger.logAPISuccess(endpoint: "/test", method: "GET", statusCode: 200)
        logger.success("Pipeline finished", category: .pipeline)
        
        #expect(collector.count == 3)
        #expect(logger.recentLogs(limit: 10).count == 3)
        
        // Test export string
        let exported = logger.exportLogsAsString()
        #expect(exported.contains("TRAVEL PARTNER SYSTEM LOGS"))
        #expect(exported.contains("Starting pipeline"))
        #expect(exported.contains("/test"))
        
        // Test observer unregistration
        logger.removeObserver(id: observerId)
        logger.info("Unobserved entry", category: .general)
        #expect(collector.count == 3) // Did not increase
        #expect(logger.recentLogs(limit: 10).count == 4)
        
        // Test clear
        logger.clearLogs()
        #expect(logger.recentLogs().isEmpty)
    }
}
