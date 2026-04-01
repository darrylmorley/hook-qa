import Foundation

// MARK: - Top-level config

struct HookQAConfig: Codable {
    var version: Int
    var connection: ConnectionConfig
    var behaviour: BehaviourConfig
    var review: ReviewConfig
    var logging: LoggingConfig

    init() {
        version = 1
        connection = ConnectionConfig()
        behaviour = BehaviourConfig()
        review = ReviewConfig()
        logging = LoggingConfig()
    }
}

// MARK: - Connection

struct ConnectionConfig: Codable {
    var ollamaUrl: String
    var model: String
    var apiKey: String?
    var timeout: Int

    init() {
        ollamaUrl = "http://localhost:11434"
        model = ""
        apiKey = nil
        timeout = 120
    }
}

// MARK: - Behaviour

struct BehaviourConfig: Codable {
    var enabled: Bool
    var blockOnWarnings: Bool
    var maxDiffLines: Int
    var minDiffLines: Int
    var maxRetries: Int
    var temperature: Double

    init() {
        enabled = true
        blockOnWarnings = false
        maxDiffLines = 500
        minDiffLines = 5
        maxRetries = 1
        temperature = 0.1
    }
}

// MARK: - Review

struct ReviewConfig: Codable {
    var weights: WeightsConfig
    var customInstructions: String

    init() {
        weights = WeightsConfig()
        customInstructions = ""
    }
}

struct WeightsConfig: Codable {
    var correctness: Int
    var completeness: Int
    var specAdherence: Int
    var codeQuality: Int

    init() {
        correctness = 10
        completeness = 8
        specAdherence = 6
        codeQuality = 4
    }
}

// MARK: - Logging

struct LoggingConfig: Codable {
    var enabled: Bool
    var logFile: String

    init() {
        enabled = true
        logFile = "~/.claude/hooks/hookqa.log"
    }
}
