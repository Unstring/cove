import SwiftUI
import AppKit

// MARK: - CoveTheme
//
// Thin namespace that maps semantic role names to the active AppTheme.
// Views always reference CoveTheme.* — never hardcode colors directly.
// Changing a theme only requires editing AppTheme.swift.

@MainActor
enum CoveTheme {
    // Backgrounds
    static var bgPrimary:   Color { ThemeManager.shared.current.bgPrimary }
    static var bgSecondary: Color { ThemeManager.shared.current.bgSecondary }
    static var bgTertiary:  Color { ThemeManager.shared.current.bgTertiary }
    static var bgElevated:  Color { ThemeManager.shared.current.bgElevated }
    static var bgSelected:  Color { ThemeManager.shared.current.bgSelected }

    // Legacy aliases so existing call sites keep working
    static var bg:          Color { bgPrimary }
    static var bgAlt:       Color { bgSecondary }
    static var bgSubtle:    Color { bgTertiary }
    static var bgHover:     Color { Color(nsColor: .quaternaryLabelColor) }
    static var bgPending:   Color { .green.opacity(0.1) }
    static var bgDeleted:   Color { .red.opacity(0.1) }

    // Foregrounds
    static var fgPrimary:   Color { ThemeManager.shared.current.fgPrimary }
    static var fgSecondary: Color { ThemeManager.shared.current.fgSecondary }

    // Legacy aliases
    static var fg:          Color { fgPrimary }
    static var fgDim:       Color { fgSecondary }

    // Borders & accents
    static var border:      Color { ThemeManager.shared.current.border }
    static var accent:      Color { .accentColor }
    static var error:       Color { .red }
    static var overlayBg:   Color { .black.opacity(0.5) }

    // SQL syntax
    static var sqlKeyword:  Color { ThemeManager.shared.current.sqlKeyword }
    static var sqlString:   Color { ThemeManager.shared.current.sqlString }
    static var sqlNumber:   Color { ThemeManager.shared.current.sqlNumber }
    static var sqlComment:  Color { ThemeManager.shared.current.sqlComment }

    // Accent hex for connection color picker
    static var accentHex:   String { Color.accentColor.hexString }
}

// MARK: - Color helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }

    var hexString: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        return String(format: "#%02x%02x%02x",
            Int(round(c.redComponent   * 255)),
            Int(round(c.greenComponent * 255)),
            Int(round(c.blueComponent  * 255))
        )
    }
}
