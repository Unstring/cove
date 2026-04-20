import SwiftUI
import AppKit

// MARK: - ThemeManager
//
// Singleton that persists the selected theme and applies it to all windows.
// Inject into the SwiftUI environment so views re-render on theme change:
//   .environment(ThemeManager.shared)

@Observable
@MainActor
final class ThemeManager {
    static let shared = ThemeManager()

    private static let defaultsKey = "cove.selectedTheme"

    var current: AppTheme {
        didSet {
            guard current != oldValue else { return }
            UserDefaults.standard.set(current.rawValue, forKey: Self.defaultsKey)
            applyToAllWindows()
            NotificationCenter.default.post(name: .coveThemeChanged, object: nil)
        }
    }

    /// Set to true to present the theme picker sheet
    var showThemePicker = false

    func openThemePicker() {
        let original = current
        CoveDialogHost.present(key: "theme-picker", title: "Theme", onDismiss: nil) {
            ThemePickerView(originalTheme: original)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? ""
        self.current = AppTheme(rawValue: saved) ?? .system
    }

    func applyToAllWindows() {
        NSApp.windows.forEach { applyWindowStyle($0) }
    }

    /// Applies the current theme to a single NSWindow.
    /// Called on launch, on new window creation, and on theme change.
    func applyWindowStyle(_ window: NSWindow) {
        window.backgroundColor          = current.windowBg
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle   = .none
        // Opaque windows prevent vibrancy from bleeding through chrome.
        // Themes with solid windowBg (no alpha) should be opaque.
        window.isOpaque = current.windowBg.alphaComponent >= 0.99
    }
}
