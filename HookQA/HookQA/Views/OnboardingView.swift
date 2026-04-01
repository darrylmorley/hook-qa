import SwiftUI

/// Four-step onboarding flow shown to new users on first launch.
struct OnboardingView: View {
    /// Called when the user completes or skips onboarding.
    let onComplete: () -> Void

    @State private var currentStep = 0

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentStep)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)

            Divider()

            // Step content
            Group {
                switch currentStep {
                case 0: stepWelcome
                case 1: stepConnection
                case 2: stepHookInstall
                case 3: stepComplete
                default: stepWelcome
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)

            Divider()

            // Navigation buttons
            HStack {
                // Skip always available except on last step
                if currentStep < totalSteps - 1 {
                    Button("Skip") {
                        onComplete()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .buttonStyle(.bordered)
                }

                if currentStep < totalSteps - 1 {
                    Button("Next") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Done") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 380)
    }

    // MARK: - Step 1: Welcome

    private var stepWelcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)
                Text("Welcome to HookQA")
                    .font(.title2)
                    .bold()
            }

            Text("HookQA adds a quality-assurance stop hook to Claude Code that automatically reviews its work before completing each task.")
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(
                    icon: "stop.circle.fill",
                    color: .orange,
                    text: "Intercepts Claude's Stop hook on every task completion"
                )
                FeatureRow(
                    icon: "brain.head.profile",
                    color: .blue,
                    text: "Sends the transcript to a local Ollama model for review"
                )
                FeatureRow(
                    icon: "checkmark.seal.fill",
                    color: .green,
                    text: "Approves good work or flags issues for Claude to fix"
                )
            }

            Text("Setup takes about 30 seconds. Let's get started.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Step 2: Connection

    private var stepConnection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect to Ollama")
                .font(.title3)
                .bold()

            Text("HookQA uses a locally-running Ollama model to review Claude's work. Make sure Ollama is running and you have at least one model pulled.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Simplified connection fields
            OnboardingConnectionFields()

            Spacer()
        }
    }

    // MARK: - Step 3: Hook Installation

    private var stepHookInstall: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Install the Hook")
                .font(.title3)
                .bold()

            Text("HookQA installs a TypeScript script into ~/.claude/hooks/ and registers it in Claude Code's settings.json.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            OnboardingHookStatus()

            Spacer()
        }
    }

    // MARK: - Step 4: Complete

    private var stepComplete: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.green)

            Text("You're all set!")
                .font(.title2)
                .bold()

            Text("HookQA is now active. It will appear in your menu bar and automatically review Claude Code's output before each task completes.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.callout)

            VStack(alignment: .leading, spacing: 6) {
                SummaryRow(icon: "menubar.rectangle", text: "Click the shield icon in your menu bar to access settings")
                SummaryRow(icon: "arrow.clockwise", text: "Use the Hook tab to update or reinstall the hook script")
                SummaryRow(icon: "doc.text", text: "The Logs tab shows all recent QA decisions")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
    }
}

// MARK: - Supporting Views

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(.callout)
        }
    }
}

private struct SummaryRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Simplified connection configuration for use within onboarding.
private struct OnboardingConnectionFields: View {
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ollama Endpoint")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("http://localhost:11434", text: Binding(
                get: { settings.config.connection.ollamaUrl },
                set: { settings.config.connection.ollamaUrl = $0; settings.scheduleSave() }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))

            Text("Model")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("e.g. qwen3:30b-coder", text: Binding(
                get: { settings.config.connection.model },
                set: { settings.config.connection.model = $0; settings.scheduleSave() }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))

            Text("You can change these later in the Connection tab.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

/// Simplified hook status + install button for use within onboarding.
private struct OnboardingHookStatus: View {
    @Environment(SettingsManager.self) private var settings

    private let installer = HookInstaller.shared
    @State private var isInstalling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Status indicators
            VStack(spacing: 0) {
                HStack {
                    Text("Hook script")
                        .font(.body)
                    Spacer()
                    HStack(spacing: 5) {
                        Circle()
                            .fill(installer.hookScriptInstalled ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(installer.hookScriptInstalled ? "Installed" : "Not installed")
                            .font(.caption)
                            .foregroundStyle(installer.hookScriptInstalled ? .green : .orange)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                Divider()

                HStack {
                    Text("Registered in settings.json")
                        .font(.body)
                    Spacer()
                    HStack(spacing: 5) {
                        Circle()
                            .fill(installer.hookRegistered ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(installer.hookRegistered ? "Yes" : "No")
                            .font(.caption)
                            .foregroundStyle(installer.hookRegistered ? .green : .orange)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )

            if let error = installer.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !installer.hookScriptInstalled || !installer.hookRegistered {
                Button {
                    Task {
                        isInstalling = true
                        await installer.install(timeout: settings.config.connection.timeout)
                        installer.refreshStatus()
                        isInstalling = false
                    }
                } label: {
                    HStack {
                        if isInstalling {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.circle")
                        }
                        Text(isInstalling ? "Installing…" : "Install Hook")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isInstalling)
            }
        }
        .task {
            installer.refreshStatus()
        }
    }
}

#Preview {
    let logWatcher = LogWatcher()
    OnboardingView { }
        .environment(SettingsManager.shared)
        .environment(logWatcher)
        .environment(StatusMonitor(settings: SettingsManager.shared, logWatcher: logWatcher))
}
