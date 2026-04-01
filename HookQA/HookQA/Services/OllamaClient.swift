import Foundation

enum OllamaError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "Invalid Ollama URL"
        case .httpError(let c): return "HTTP \(c)"
        case .decodingError:    return "Failed to decode response"
        case .networkError(let e): return e.localizedDescription
        case .timeout:          return "Request timed out"
        }
    }
}

actor OllamaClient {

    // MARK: - Shared

    static let shared = OllamaClient()

    // MARK: - Private helpers

    private func makeSession(timeout: TimeInterval) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        return URLSession(configuration: config)
    }

    private func baseURL(from settings: SettingsManager) async -> String {
        await MainActor.run { settings.config.connection.ollamaUrl }
    }

    private func apiKey(from settings: SettingsManager) async -> String? {
        await MainActor.run { settings.config.connection.apiKey }
    }

    // MARK: - fetchModels

    /// Hits GET /api/tags and returns the list of locally available models.
    func fetchModels(settings: SettingsManager) async throws -> [OllamaModel] {
        let base = await baseURL(from: settings)
        let key = await apiKey(from: settings)

        guard let url = URL(string: "\(base)/api/tags") else {
            throw OllamaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let key {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let session = makeSession(timeout: 10)

        do {
            let (data, response) = try await session.data(for: request)

            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw OllamaError.httpError(http.statusCode)
            }

            do {
                let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
                return decoded.models
            } catch {
                throw OllamaError.decodingError(error)
            }
        } catch let error as OllamaError {
            throw error
        } catch {
            throw OllamaError.networkError(error)
        }
    }

    // MARK: - testConnection

    /// Sends a minimal chat request to verify the model is responsive.
    /// Returns the round-trip time in milliseconds on success.
    func testConnection(model: String, settings: SettingsManager) async throws -> Int {
        let base = await baseURL(from: settings)
        let key = await apiKey(from: settings)

        guard let url = URL(string: "\(base)/api/chat") else {
            throw OllamaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        // Minimal prompt to keep the health check fast
        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [
                ["role": "user", "content": "Hi"]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let session = makeSession(timeout: 5)

        let start = Date()

        do {
            let (_, response) = try await session.data(for: request)

            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw OllamaError.httpError(http.statusCode)
            }

            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            return elapsed
        } catch let error as OllamaError {
            throw error
        } catch {
            throw OllamaError.networkError(error)
        }
    }
}
