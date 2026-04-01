import Foundation

// Stub — populated in a later phase when log reading/writing is implemented
struct HookQALogEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let project: String
    let model: String
    let verdict: String
    let findings: Int
    let criticals: Int
    let warnings: Int
    let summary: String
    let durationMs: Int

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        project: String,
        model: String,
        verdict: String,
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
}
