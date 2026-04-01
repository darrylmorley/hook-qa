import SwiftUI

enum MenuBarTab: String, CaseIterable {
    case connection = "Connection"
    case behaviour = "Behaviour"
    case review = "Review"
    case hook = "Hook"
    case logs = "Logs"

    var icon: String {
        switch self {
        case .connection: return "wifi"
        case .behaviour:  return "gearshape"
        case .review:     return "checkmark.seal"
        case .hook:       return "wrench.and.screwdriver"
        case .logs:       return "doc.text"
        }
    }
}

struct MenuBarView: View {
    @Environment(SettingsManager.self) private var settings

    @State private var selectedTab: MenuBarTab = .connection
    @State private var connectionStatus: ConnectionStatus = .checking

    var body: some View {
        VStack(spacing: 0) {
            // Status bar always visible at top
            StatusBarView(connectionStatus: connectionStatus)

            Divider()

            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(MenuBarTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .connection:
                    ConnectionTab()
                        .onPreferenceChange(ConnectionStatusPreferenceKey.self) { status in
                            if let status { connectionStatus = status }
                        }
                case .behaviour:
                    BehaviourTab()
                case .review:
                    ReviewTab()
                case .hook:
                    HookTab()
                case .logs:
                    PlaceholderTabView(title: "Logs")
                }
            }
            .frame(minHeight: 300)

            Divider()

            // Quit button
            HStack {
                Spacer()
                Button("Quit HookQA") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .frame(width: 380)
    }
}

// MARK: - Placeholder

private struct PlaceholderTabView: View {
    let title: String

    var body: some View {
        VStack {
            Spacer()
            Text(title)
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preference key so ConnectionTab can bubble status up

struct ConnectionStatusPreferenceKey: PreferenceKey {
    static let defaultValue: ConnectionStatus? = nil
    static func reduce(value: inout ConnectionStatus?, nextValue: () -> ConnectionStatus?) {
        value = nextValue() ?? value
    }
}

#Preview {
    MenuBarView()
        .environment(SettingsManager.shared)
}
