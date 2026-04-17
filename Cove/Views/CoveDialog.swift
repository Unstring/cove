import SwiftUI
import AppKit

// MARK: - CoveDialogHost

@MainActor
enum CoveDialogHost {
    private static var panels: [String: NSPanel] = [:]

    /// Programmatically dismiss a dialog by key.
    static func dismiss(key: String) {
        panels[key]?.orderOut(nil)
        panels.removeValue(forKey: key)
    }

    static func present<Content: View>(
        key: String = UUID().uuidString,
        onDismiss: (@Sendable () -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        if let existing = panels[key], existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let dismiss: @Sendable () -> Void = {
            Task { @MainActor in
                panels[key]?.orderOut(nil)
                panels.removeValue(forKey: key)
                onDismiss?()
            }
        }

        let theme = ThemeManager.shared

        let surface = CoveDialogSurface {
            content()
                .environment(\.coveDialogDismiss, dismiss)
        }
        .environment(theme)
        // Force correct color scheme so SwiftUI controls render right
        .preferredColorScheme(theme.current.colorScheme)

        let hosting = NSHostingController(rootView: surface)
        hosting.sizingOptions = .preferredContentSize

        // Force NSAppearance to match theme so AppKit controls are correct
        hosting.view.appearance = theme.current.colorScheme == .dark
            ? NSAppearance(named: .darkAqua)
            : theme.current.colorScheme == .light
                ? NSAppearance(named: .aqua)
                : nil

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.contentViewController = hosting
        panel.layoutIfNeeded()

        // Clip the panel's own contentView to match the rounded corners
        if let cv = panel.contentView {
            cv.wantsLayer = true
            cv.layer?.cornerRadius = 12
            cv.layer?.cornerCurve = .continuous
            cv.layer?.masksToBounds = true
        }

        panels[key] = panel

        let parent = NSApp.windows.first { $0.isVisible && !($0 is NSPanel) }
        if let parent {
            let pf = parent.frame
            let ps = panel.frame.size
            panel.setFrameOrigin(NSPoint(
                x: pf.midX - ps.width / 2,
                y: pf.midY - ps.height / 2 + 40
            ))
        } else {
            panel.center()
        }

        panel.makeKeyAndOrderFront(nil)
    }
}

// MARK: - CoveDialogSurface
//
// Single visual container for all dialogs.
// The panel window is fully transparent — this view owns all chrome:
//   - Background color from active theme
//   - Rounded corners (continuous squircle, r=12)
//   - Hairline border
//   - Drop shadow (rendered outside the clip via padding)

struct CoveDialogSurface<Content: View>: View {
    @Environment(ThemeManager.self) private var themeManager
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(themeManager.current.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 28, x: 0, y: 12)
            // No padding — shadow comes from the NSPanel, not SwiftUI
    }
}

// MARK: - Dismiss environment key

private struct CoveDialogDismissKey: EnvironmentKey {
    static let defaultValue: @Sendable () -> Void = {}
}

extension EnvironmentValues {
    var coveDialogDismiss: @Sendable () -> Void {
        get { self[CoveDialogDismissKey.self] }
        set { self[CoveDialogDismissKey.self] = newValue }
    }
}

// MARK: - Theme change notification

extension Notification.Name {
    static let coveThemeChanged = Notification.Name("cove.themeChanged")
}
