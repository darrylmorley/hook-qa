import SwiftUI
import AppKit
import Sparkle

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

    // Sparkle updater controller — handles auto-checking on launch
    private var updaterController: SPUStandardUpdaterController?

    // Observation task for updating the icon when statusMonitor changes
    private var observationTask: Task<Void, Never>?

    // Animation state
    private var rotationTimer: Timer?
    private var rotationAngle: CGFloat = 0
    private var isAnimating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let watcher = LogWatcher()
        let monitor = StatusMonitor(settings: SettingsManager.shared, logWatcher: watcher)
        logWatcher = watcher
        statusMonitor = monitor

        // Initialise Sparkle — it will automatically check for updates on launch
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

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
                let working = monitor.isWorking
                self?.updateIcon(for: status, working: working)
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func updateIcon(for status: MenuBarStatus, working: Bool) {
        if working {
            startRotationAnimation(status: status)
        } else {
            stopRotationAnimation()
            statusItem?.button?.image = makeIcon(for: status)
        }
    }

    private func startRotationAnimation(status: MenuBarStatus) {
        guard !isAnimating else { return }
        isAnimating = true

        rotationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.rotationAngle += 5
            if self.rotationAngle >= 360 { self.rotationAngle = 0 }

            if let image = self.makeIcon(for: status) {
                let rotated = self.rotateImage(image, byDegrees: self.rotationAngle)
                self.statusItem?.button?.image = rotated
            }
        }
    }

    private func stopRotationAnimation() {
        guard isAnimating else { return }
        isAnimating = false
        rotationTimer?.invalidate()
        rotationTimer = nil
        rotationAngle = 0
    }

    private func rotateImage(_ image: NSImage, byDegrees degrees: CGFloat) -> NSImage {
        let size = image.size
        let rotated = NSImage(size: size)
        rotated.lockFocus()

        let transform = NSAffineTransform()
        transform.translateX(by: size.width / 2, yBy: size.height / 2)
        transform.rotate(byDegrees: degrees)
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()

        image.draw(in: NSRect(origin: .zero, size: size))
        rotated.unlockFocus()
        rotated.isTemplate = image.isTemplate
        return rotated
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

    /// Called from HookTab to trigger a manual update check via Sparkle.
    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
}
