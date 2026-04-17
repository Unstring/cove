import SwiftUI
import AppKit

// MARK: - AppTheme
//
// Each theme defines a palette of semantic color roles.
// To add a new theme: add a case, then fill in each computed property.
// Every view uses these roles — no hardcoded colors anywhere.
//
// Color roles (like CSS custom properties):
//   bgPrimary    — main window / page background
//   bgSecondary  — panels, sidebars, inspectors
//   bgTertiary   — cards, code blocks, input backgrounds
//   bgElevated   — toolbar, titlebar area
//   bgSelected   — selected row / item highlight
//   fgPrimary    — main text
//   fgSecondary  — dimmed / secondary text
//   border       — dividers and strokes
//   sqlKeyword / sqlString / sqlNumber / sqlComment — syntax highlight

enum AppTheme: String, CaseIterable, Codable {
    case system    = "System"
    case light     = "Light"
    case dark      = "Dark"
    case midnight  = "Midnight"
    case nord      = "Nord"
    case solarized = "Solarized"
    case oled      = "OLED"

    var displayName: String { rawValue }

    // MARK: - SwiftUI color scheme (nil = follow system)
    var colorScheme: ColorScheme? {
        switch self {
        case .system:                        return nil
        case .light, .solarized:             return .light
        case .dark, .midnight, .nord, .oled: return .dark
        }
    }

    // MARK: - Background roles

    /// Main window background
    var bgPrimary: Color {
        switch self {
        case .system:    return Color(nsColor: .windowBackgroundColor)
        case .light:     return Color(white: 0.97)
        case .dark:      return Color(red: 0.13, green: 0.14, blue: 0.18)
        case .midnight:  return Color(red: 0.07, green: 0.07, blue: 0.13)
        case .nord:      return Color(red: 0.18, green: 0.20, blue: 0.25)
        case .solarized: return Color(red: 0.99, green: 0.96, blue: 0.89)
        case .oled:      return .black
        }
    }

    /// Panels, sidebars, inspectors
    var bgSecondary: Color {
        switch self {
        case .system:    return Color(nsColor: .controlBackgroundColor)
        case .light:     return Color(white: 0.93)
        case .dark:      return Color(red: 0.17, green: 0.18, blue: 0.23)
        case .midnight:  return Color(red: 0.10, green: 0.10, blue: 0.18)
        case .nord:      return Color(red: 0.21, green: 0.24, blue: 0.30)
        case .solarized: return Color(red: 0.93, green: 0.91, blue: 0.84)
        case .oled:      return Color(white: 0.04)
        }
    }

    /// Code blocks, input fields, subtle inset areas
    var bgTertiary: Color {
        switch self {
        case .system:    return Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
        case .light:     return Color(white: 0.90)
        case .dark:      return Color(red: 0.20, green: 0.21, blue: 0.27)
        case .midnight:  return Color(red: 0.12, green: 0.12, blue: 0.22)
        case .nord:      return Color(red: 0.23, green: 0.26, blue: 0.32)
        case .solarized: return Color(red: 0.88, green: 0.86, blue: 0.79)
        case .oled:      return Color(white: 0.07)
        }
    }

    /// Toolbar / titlebar area
    var bgElevated: Color {
        switch self {
        case .system:    return Color(nsColor: .windowBackgroundColor).opacity(0.8)
        case .light:     return Color(white: 0.95)
        case .dark:      return Color(red: 0.11, green: 0.12, blue: 0.16)
        case .midnight:  return Color(red: 0.05, green: 0.05, blue: 0.10)
        case .nord:      return Color(red: 0.16, green: 0.18, blue: 0.23)
        case .solarized: return Color(red: 0.96, green: 0.94, blue: 0.87)
        case .oled:      return .black
        }
    }

    /// Selected row / active item
    var bgSelected: Color {
        switch self {
        case .system:    return Color(nsColor: .selectedContentBackgroundColor)
        case .light:     return Color.accentColor.opacity(0.18)
        case .dark:      return Color.accentColor.opacity(0.25)
        case .midnight:  return Color(red: 0.25, green: 0.30, blue: 0.55).opacity(0.6)
        case .nord:      return Color(red: 0.36, green: 0.51, blue: 0.71).opacity(0.35)
        case .solarized: return Color(red: 0.15, green: 0.55, blue: 0.82).opacity(0.20)
        case .oled:      return Color(white: 0.12)
        }
    }

    // MARK: - Foreground roles

    var fgPrimary: Color {
        switch self {
        case .system:    return .primary
        case .light:     return Color(white: 0.10)
        case .dark:      return Color(white: 0.92)
        case .midnight:  return Color(red: 0.85, green: 0.87, blue: 0.95)
        case .nord:      return Color(red: 0.85, green: 0.87, blue: 0.91)
        case .solarized: return Color(red: 0.40, green: 0.48, blue: 0.51)
        case .oled:      return .white
        }
    }

    var fgSecondary: Color {
        switch self {
        case .system:    return .secondary
        case .light:     return Color(white: 0.45)
        case .dark:      return Color(white: 0.55)
        case .midnight:  return Color(red: 0.50, green: 0.52, blue: 0.65)
        case .nord:      return Color(red: 0.56, green: 0.60, blue: 0.67)
        case .solarized: return Color(red: 0.51, green: 0.58, blue: 0.59)
        case .oled:      return Color(white: 0.55)
        }
    }

    var border: Color {
        switch self {
        case .system:    return Color(nsColor: .separatorColor)
        case .light:     return Color(white: 0.80)
        case .dark:      return Color(white: 0.28)
        case .midnight:  return Color(red: 0.20, green: 0.20, blue: 0.35)
        case .nord:      return Color(red: 0.27, green: 0.30, blue: 0.37)
        case .solarized: return Color(red: 0.79, green: 0.77, blue: 0.70)
        case .oled:      return Color(white: 0.14)
        }
    }

    // MARK: - SQL syntax colors

    var sqlKeyword: Color {
        switch self {
        case .system:    return Color(nsColor: .systemBlue)
        case .light:     return Color(red: 0.00, green: 0.40, blue: 0.85)
        case .dark:      return Color(red: 0.40, green: 0.70, blue: 1.00)
        case .midnight:  return Color(red: 0.50, green: 0.75, blue: 1.00)
        case .nord:      return Color(red: 0.53, green: 0.75, blue: 0.98)
        case .solarized: return Color(red: 0.15, green: 0.55, blue: 0.82)
        case .oled:      return Color(red: 0.20, green: 0.80, blue: 1.00)
        }
    }

    var sqlString: Color {
        switch self {
        case .system:    return Color(nsColor: .systemOrange)
        case .light:     return Color(red: 0.80, green: 0.40, blue: 0.00)
        case .dark:      return Color(red: 1.00, green: 0.65, blue: 0.30)
        case .midnight:  return Color(red: 1.00, green: 0.70, blue: 0.40)
        case .nord:      return Color(red: 0.92, green: 0.60, blue: 0.42)
        case .solarized: return Color(red: 0.80, green: 0.29, blue: 0.09)
        case .oled:      return Color(red: 1.00, green: 0.45, blue: 0.20)
        }
    }

    var sqlNumber: Color {
        switch self {
        case .system:    return Color(nsColor: .systemGreen)
        case .light:     return Color(red: 0.10, green: 0.55, blue: 0.20)
        case .dark:      return Color(red: 0.35, green: 0.85, blue: 0.45)
        case .midnight:  return Color(red: 0.40, green: 0.90, blue: 0.55)
        case .nord:      return Color(red: 0.64, green: 0.83, blue: 0.60)
        case .solarized: return Color(red: 0.52, green: 0.60, blue: 0.00)
        case .oled:      return Color(red: 0.20, green: 1.00, blue: 0.40)
        }
    }

    var sqlComment: Color {
        switch self {
        case .system:    return Color(nsColor: .systemGray)
        case .light:     return Color(white: 0.55)
        case .dark:      return Color(white: 0.45)
        case .midnight:  return Color(red: 0.40, green: 0.42, blue: 0.55)
        case .nord:      return Color(red: 0.46, green: 0.52, blue: 0.60)
        case .solarized: return Color(red: 0.58, green: 0.63, blue: 0.63)
        case .oled:      return Color(white: 0.38)
        }
    }

    // MARK: - NSColor equivalents for AppKit surfaces

    /// NSColor for NSWindow.backgroundColor
    var windowBg: NSColor { NSColor(bgPrimary) }

    /// NSColor for panels that need solid override (bypasses vibrancy)
    /// nil = use system NSVisualEffectView material
    var solidPanelBg: NSColor? {
        switch self {
        case .oled:     return NSColor(bgSecondary)
        case .midnight: return NSColor(bgSecondary)
        default:        return nil
        }
    }
}
