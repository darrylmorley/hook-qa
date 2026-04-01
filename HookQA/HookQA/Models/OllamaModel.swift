import Foundation

struct OllamaModel: Codable, Identifiable, Sendable {
    var id: String { name }

    let name: String
    let size: Int64
    let modified_at: String
    let details: OllamaModelDetails?
}

struct OllamaModelDetails: Codable, Sendable {
    let parameter_size: String?
    let quantization_level: String?
    let family: String?
}

// MARK: - API response wrapper

struct OllamaTagsResponse: Codable, Sendable {
    let models: [OllamaModel]
}
