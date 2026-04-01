import Foundation

// MARK: - Verdict

enum Verdict: String, Codable, Sendable {
    case pass     = "PASS"
    case fail     = "FAIL"
    case error    = "ERROR"
    case skipped  = "SKIPPED"
}

// MARK: - HookQALogEntry

struct HookQALogEntry: Identifiable, Codable, Sendable {
    // Generated locally — not stored in the JSONL
    let id: UUID

    let timestamp: Date
    let project: String
    let model: String
    let verdict: Verdict
    let findings: Int
    let criticals: Int
    let warnings: Int
    let summary: String
    let durationMs: Int

    // MARK: CodingKeys — excludes `id` so it isn't expected in JSON
    enum CodingKeys: String, CodingKey {
        case timestamp, project, model, verdict, findings, criticals, warnings, summary, durationMs
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        project: String,
        model: String,
        verdict: Verdict,
        findings: Int,
        criticals: Int,
        warnings: Int,
        summary: String,
        durationMs: Int
    ) {
        self.id = id
        self.timestamp = timestamp
        self.project = project
        self.model = model
        self.verdict = verdict
        self.findings = findings
        self.criticals = criticals
        self.warnings = warnings
        self.summary = summary
        self.durationMs = durationMs
    }

    // MARK: - Decodable
    // Generates a fresh UUID on decode since `id` isn't in the JSONL source.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        project = try container.decode(String.self, forKey: .project)
        model = try container.decode(String.self, forKey: .model)
        verdict = try container.decode(Verdict.self, forKey: .verdict)
        findings = try container.decode(Int.self, forKey: .findings)
        criticals = try container.decode(Int.self, forKey: .criticals)
        warnings = try container.decode(Int.self, forKey: .warnings)
        summary = try container.decode(String.self, forKey: .summary)
        durationMs = try container.decode(Int.self, forKey: .durationMs)
    }
}

// MARK: - Shared decoder for JSONL parsing

extension HookQALogEntry {
    static var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        // The hook script writes ISO 8601 timestamps with fractional seconds, e.g.
        // "2026-04-01T10:30:00.000Z"
        // Both formatters are created inside the closure to avoid capturing non-Sendable types.
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFractional.date(from: string) { return date }

            // Fallback: without fractional seconds
            let plain = ISO8601DateFormatter()
            if let date = plain.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot parse date: \(string)")
        }
        return decoder
    }
}
