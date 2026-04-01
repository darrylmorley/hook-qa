import SwiftUI

struct HookTab: View {
    @Environment(SettingsManager.self) private var settings

    private let installer = HookInstaller.shared

    @State private var showUninstallConfirmation = false
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: Status section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        StatusRow(
                            label: "Hook script",
                            active: installer.hookScriptInstalled,
                            activeText: "Installed",
                            inactiveText: "Not installed"
                        )
                        Divider()
                        StatusRow(
                            label: "Settings.json",
                            active: installer.hookRegistered,
                            activeText: "Registered",
                            inactiveText: "Not registered"
                        )
                        Divider()
                        BunStatusRow(bunAvailable: installer.bunAvailable)
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                }

                // MARK: Error display
                if let error = installer.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // MARK: Action buttons
                VStack(spacing: 8) {
                    if !installer.hookScriptInstalled {
                        ActionButton(
                            title: "Install Hook",
                            systemImage: "arrow.down.circle",
                            isLoading: isWorking
                        ) {
                            await performAction {
                                await installer.install(timeout: settings.config.connection.timeout)
                            }
                        }
                    }

                    if installer.hookScriptInstalled {
                        if installer.updateAvailable {
                            ActionButton(
                                title: "Update Hook",
                                systemImage: "arrow.triangle.2.circlepath",
                                isLoading: isWorking,
                                badge: versionBadgeText
                            ) {
                                await performAction {
                                    await installer.update(timeout: settings.config.connection.timeout)
                                }
                            }
                        }

                        ActionButton(
                            title: "Reinstall Hook",
                            systemImage: "arrow.clockwise",
                            isLoading: isWorking
                        ) {
                            await performAction {
                                await installer.install(timeout: settings.config.connection.timeout)
                            }
                        }

                        ActionButton(
                            title: "Uninstall Hook",
                            systemImage: "trash",
                            isLoading: isWorking,
                            isDestructive: true
                        ) {
                            showUninstallConfirmation = true
                        }
                    }
                }

                // MARK: Info section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Info")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        InfoRow(label: "Bundled version", value: installer.bundledVersion)
                        Divider()
                        InfoRow(label: "Installed version", value: installer.installedVersion ?? "—")
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )

                    if installer.hookScriptInstalled {
                        Button {
                            let url = FileManager.default.homeDirectoryForCurrentUser
                                .appendingPathComponent(".claude/hooks/hookqa-hook.ts")
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("Open Hook Script", systemImage: "arrow.up.forward.square")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }
                }

                Spacer()
            }
            .padding(12)
        }
        .task {
            installer.refreshStatus()
        }
        .alert("Uninstall Hook?", isPresented: $showUninstallConfirmation) {
            Button("Uninstall", role: .destructive) {
                Task {
                    await performAction {
                        await installer.uninstall()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the hook script from ~/.claude/hooks/ and deregister it from settings.json.")
        }
    }

    // MARK: - Helpers

    private var versionBadgeText: String? {
        guard let installed = installer.installedVersion else { return nil }
        return "\(installed) → \(installer.bundledVersion)"
    }

    private func performAction(_ action: @escaping () async -> Void) async {
        isWorking = true
        await action()
        installer.refreshStatus()
        isWorking = false
    }
}

// MARK: - StatusRow

private struct StatusRow: View {
    let label: String
    let active: Bool
    let activeText: String
    let inactiveText: String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(active ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(active ? activeText : inactiveText)
                    .font(.caption)
                    .foregroundStyle(active ? .green : .red)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

// MARK: - BunStatusRow

private struct BunStatusRow: View {
    let bunAvailable: Bool

    var body: some View {
        HStack {
            Text("Bun")
                .font(.body)
            Spacer()
            if bunAvailable {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Available")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } else {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Not found")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Link("Install Bun →", destination: URL(string: "https://bun.sh")!)
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

// MARK: - InfoRow

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

// MARK: - ActionButton

private struct ActionButton: View {
    let title: String
    let systemImage: String
    let isLoading: Bool
    var badge: String? = nil
    var isDestructive: Bool = false
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                }
                Text(title)
                if let badge {
                    Text(badge)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(isLoading)
        .tint(isDestructive ? .red : .accentColor)
    }
}

#Preview {
    HookTab()
        .environment(SettingsManager.shared)
        .frame(width: 380, height: 500)
}
