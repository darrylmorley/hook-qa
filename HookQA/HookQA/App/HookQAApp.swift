import SwiftUI
import AppKit

@main
struct HookQAApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        // We use AppDelegate for the status item — no window scenes needed.
        Settings {
            EmptyView()
        }
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    private var logWatcher: LogWatcher?
    private var statusMonitor: StatusMonitor?

    // Observation task for updating the icon when statusMonitor changes
    private var observationTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let watcher = LogWatcher()
        let monitor = StatusMonitor(settings: SettingsManager.shared, logWatcher: watcher)
        logWatcher = watcher
        statusMonitor = monitor

        setupStatusItem(logWatcher: watcher, statusMonitor: monitor)
        observeStatus(monitor: monitor)
    }

    private func setupStatusItem(logWatcher: LogWatcher, statusMonitor: StatusMonitor) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = makeIcon(for: .disabled)
        item.button?.action = #selector(togglePopover)
        item.button?.target = self
        statusItem = item

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 380, height: 520)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environment(SettingsManager.shared)
                .environment(logWatcher)
                .environment(statusMonitor)
        )
        popover = pop
    }

    /// Watches MenuBarStatus and updates the status item icon accordingly.
    private func observeStatus(monitor: StatusMonitor) {
        observationTask = Task { [weak self] in
            // Poll for changes — withObservationTracking fires once per change
            while !Task.isCancelled {
                let status = monitor.menuBarStatus
                self?.updateIcon(for: status)
                // Yield briefly so we don't spin; observation will re-schedule us
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func updateIcon(for status: MenuBarStatus) {
        statusItem?.button?.image = makeIcon(for: status)
    }

    private func makeIcon(for status: MenuBarStatus) -> NSImage? {
        let (symbolName, color): (String, NSColor) = {
            switch status {
            case .disabled:     return ("checkmark.shield", .secondaryLabelColor)
            case .connected:    return ("checkmark.shield.fill", .systemGreen)
            case .unreachable:  return ("exclamationmark.shield.fill", .systemRed)
            case .lastFailed:   return ("checkmark.shield.fill", .systemOrange)
            }
        }()

        let config = NSImage.SymbolConfiguration(paletteColors: [color])
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "HookQA"
        )
        return image?.withSymbolConfiguration(config)
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let pop = popover else { return }
        if pop.isShown {
            pop.performClose(nil)
        } else {
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            pop.contentViewController?.view.window?.makeKey()
        }
    }
}
