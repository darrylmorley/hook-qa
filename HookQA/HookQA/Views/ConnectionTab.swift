import SwiftUI

struct ConnectionTab: View {
    @Environment(SettingsManager.self) private var settings

    @State private var models: [OllamaModel] = []
    @State private var connectionStatus: ConnectionStatus = .checking
    @State private var isLoadingModels = false
    @State private var testResult: String? = nil
    @State private var isTesting = false
    @State private var manualModelName = ""
    @State private var apiKey = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: Endpoint field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ollama Endpoint")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("http://localhost:11434", text: Binding(
                            get: { settings.config.connection.ollamaUrl },
                            set: { settings.config.connection.ollamaUrl = $0; settings.scheduleSave() }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                        Button {
                            Task { await refreshModels() }
                        } label: {
                            if isLoadingModels {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isLoadingModels)
                        .help("Refresh model list")
                    }
                }

                // MARK: Model list
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Available Models")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(connectionStatus.displayText)
                            .font(.caption2)
                            .foregroundStyle(statusColor)
                    }

                    if models.isEmpty && !isLoadingModels {
                        Text("No models found — check the endpoint or pull a model in Ollama.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(models) { model in
                                ModelRow(
                                    model: model,
                                    isSelected: settings.config.connection.model == model.name
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    settings.config.connection.model = model.name
                                    settings.scheduleSave()
                                }

                                if model.id != models.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    }
                }

                // MARK: Manual model fallback
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manual Model Name (fallback)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("e.g. qwen3:30b-coder", text: Binding(
                        get: { settings.config.connection.model },
                        set: { settings.config.connection.model = $0; settings.scheduleSave() }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                }

                // MARK: API Key
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SecureField("For cloud Ollama endpoints", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: apiKey) { _, newValue in
                            if newValue.isEmpty {
                                KeychainHelper.delete()
                                settings.config.connection.apiKey = nil
                            } else {
                                KeychainHelper.save(key: newValue)
                                settings.config.connection.apiKey = newValue
                            }
                            settings.scheduleSave()
                        }
                }

                // MARK: Test connection button
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Testing…")
                            } else {
                                Image(systemName: "bolt.fill")
                                Text("Test Connection")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isTesting)

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.hasPrefix("Error") ? .red : .green)
                    }
                }

                Spacer()
            }
            .padding(12)
        }
        .task { await refreshModels() }
        .onAppear {
            apiKey = KeychainHelper.read() ?? ""
        }
    }

    // MARK: - Actions

    private func refreshModels() async {
        isLoadingModels = true
        connectionStatus = .checking

        do {
            let fetched = try await OllamaClient.shared.fetchModels(settings: settings)
            models = fetched
            connectionStatus = .connected(fetched.count)
        } catch {
            models = []
            connectionStatus = .unreachable
        }

        isLoadingModels = false
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil

        let model = await MainActor.run { settings.config.connection.model }

        do {
            let ms = try await OllamaClient.shared.testConnection(model: model, settings: settings)
            testResult = "Connected in \(ms) ms"
        } catch {
            testResult = "Error: \(error.localizedDescription)"
        }

        isTesting = false
    }

    private var statusColor: Color {
        switch connectionStatus {
        case .connected:   return .green
        case .unreachable: return .red
        case .checking:    return .yellow
        }
    }
}

// MARK: - ModelRow

private struct ModelRow: View {
    let model: OllamaModel
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let params = model.details?.parameter_size {
                        badge(params)
                    }
                    if let quant = model.details?.quantization_level {
                        badge(quant)
                    }
                }
            }

            Spacer()

            Text(formattedSize(model.size))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.08) : .clear)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
    }

    private func formattedSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}

#Preview {
    ConnectionTab()
        .environment(SettingsManager.shared)
        .frame(width: 380, height: 500)
}
