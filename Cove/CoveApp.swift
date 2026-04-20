import SwiftUI
import AppKit

@main
struct CoveApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @FocusedValue(\.appState) private var focusedTab
    @State private var themeManager = ThemeManager.shared

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        UserDefaults.standard.set("WhenScrolling", forKey: "AppleShowScrollBars")
        UserDefaults.standard.set(0, forKey: "NSInitialToolTipDelay")
    }

    var body: some Scene {
        WindowGroup {
            TabRootWrapper()
                .preferredColorScheme(themeManager.current.colorScheme)
        }
        .defaultSize(width: 1200, height: 800)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    guard let current = NSApp.keyWindow,
                          let wc = current.windowController else { return }
                    wc.newWindowForTab(nil)
                    if let new = NSApp.keyWindow, current != new {
                        current.addTabbedWindow(new, ordered: .above)
                    }
                }
                .keyboardShortcut(AppShortcuts.newTab)

                Button("New Connection...") {
                    if let tab = focusedTab {
                        tab.dialog.reset()
                        tab.dialog.environment = tab.selectedEnvironment
                        CoveDialogHost.present(key: "connection-dialog", title: "New Connection", onDismiss: { @Sendable in Task { @MainActor in tab.dialogCancel() } }) {
                            ConnectionDialog().environment(tab)
                        }
                    }
                }
                .keyboardShortcut(AppShortcuts.newConnection)
            }

            CommandMenu("Theme") {
                Button("Color Theme...") {
                    ThemeManager.shared.openThemePicker()
                }
                .keyboardShortcut(AppShortcuts.openThemePicker)

                Divider()

                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button {
                        themeManager.current = theme
                    } label: {
                        Text((themeManager.current == theme ? "✓  " : "    ") + theme.displayName)
                    }
                }
            }

            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    focusedTab?.refreshCurrentScope()
                }
                .keyboardShortcut(AppShortcuts.refresh)
                .disabled(focusedTab?.connection == nil)

                Divider()

                Button("Toggle Sidebar") {
                    focusedTab?.showSidebar.toggle()
                }
                .keyboardShortcut(AppShortcuts.toggleSidebar)
                .disabled(focusedTab?.connection == nil)

                Button("Toggle Inspector") {
                    focusedTab?.showInspector.toggle()
                }
                .keyboardShortcut(AppShortcuts.toggleInspector)
                .disabled(focusedTab?.connection == nil)

                Button("Toggle Query Editor") {
                    focusedTab?.toggleQuery()
                }
                .keyboardShortcut(AppShortcuts.toggleQuery)
                .disabled(focusedTab?.connection == nil)
            }
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private var windowObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.windows.forEach { styleWindow($0) }

        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let window = note.object as? NSWindow else { return }
            Task { @MainActor [weak self] in self?.styleWindow(window) }
        }

        let count = SharedStore.shared.savedTabCount
        guard count > 1 else { return }
        DispatchQueue.main.async {
            guard let current = NSApp.keyWindow,
                  let wc = current.windowController else { return }
            for _ in 1..<count {
                wc.newWindowForTab(nil)
                if let new = NSApp.keyWindow, current != new {
                    current.addTabbedWindow(new, ordered: .above)
                }
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        SharedStore.shared.saveAllTabSessions()
        SharedStore.shared.isTerminating = true
        return .terminateNow
    }

    @MainActor
    private func styleWindow(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.tabbingMode = .automatic
        ThemeManager.shared.applyWindowStyle(window)
    }
}
