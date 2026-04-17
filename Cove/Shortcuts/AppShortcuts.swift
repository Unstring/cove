import SwiftUI

// MARK: - AppShortcuts
//
// Single source of truth for all keyboard shortcuts in Cove.
// To add a new shortcut:
//   1. Add a static let here
//   2. Use it in the CommandMenu/CommandGroup in CoveApp.swift
//   3. Optionally handle it in a view via .keyboardShortcut(AppShortcuts.xxx)

enum AppShortcuts {
    // Connections
    static let newConnection    = KeyboardShortcut("n", modifiers: [.command, .control])

    // Theme
    static let openThemePicker  = KeyboardShortcut("t", modifiers: [.command, .shift])

    // Table edits
    static let previewChanges   = KeyboardShortcut("s", modifiers: .command)
    static let executeChanges   = KeyboardShortcut("e", modifiers: [.command, .shift])

    // View toggles
    static let toggleSidebar    = KeyboardShortcut("b", modifiers: .command)
    static let toggleInspector  = KeyboardShortcut("i", modifiers: .command)
    static let toggleQuery      = KeyboardShortcut("'", modifiers: .command)

    // Navigation
    static let newTab           = KeyboardShortcut("t", modifiers: .command)
    static let refresh          = KeyboardShortcut("r", modifiers: .command)
}
