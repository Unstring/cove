import SwiftUI
import AppKit

// MARK: - ThemePickerView
//
// VS Code-style theme picker presented via CoveDialogHost.
// Arrow keys navigate with live preview, Enter confirms, Escape cancels.

struct ThemePickerView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.coveDialogDismiss) private var dismiss

    private let originalTheme: AppTheme
    @State private var highlighted: AppTheme

    init(originalTheme: AppTheme) {
        self.originalTheme = originalTheme
        self._highlighted = State(initialValue: originalTheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(CoveTheme.border)
            themeList
            Divider().background(CoveTheme.border)
            footer
        }
        .frame(width: 320)
        .background(
            KeyCaptureView(
                onUp:     { navigate(-1) },
                onDown:   { navigate(+1) },
                onReturn: { confirm() },
                onEscape: { cancel() }
            )
            .frame(width: 0, height: 0)
        )
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Color Theme")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CoveTheme.fgPrimary)
            Text("↑↓ navigate  ↵ select  ⎋ cancel")
                .font(.system(size: 11))
                .foregroundStyle(CoveTheme.fgSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var themeList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        themeRow(theme).id(theme)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: 300)
            .onChange(of: highlighted) { _, new in
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { cancel() }
            Button("Select") { confirm() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func themeRow(_ theme: AppTheme) -> some View {
        let isHighlighted = highlighted == theme
        let isCurrent = originalTheme == theme

        return HStack(spacing: 10) {
            // Color swatch
            HStack(spacing: 2) {
                theme.bgPrimary.frame(width: 12, height: 20)
                theme.bgSecondary.frame(width: 12, height: 20)
                theme.sqlKeyword.frame(width: 6, height: 20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3)
                .strokeBorder(CoveTheme.border, lineWidth: 0.5))

            Text(theme.displayName)
                .font(.system(size: 13))
                .foregroundStyle(CoveTheme.fgPrimary)

            Spacer()

            if isCurrent {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(CoveTheme.accent)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            isHighlighted ? CoveTheme.bgSelected : Color.clear,
            in: RoundedRectangle(cornerRadius: 5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            highlighted = theme
            themeManager.current = theme
        }
    }

    // MARK: - Actions

    private func navigate(_ direction: Int) {
        let all = AppTheme.allCases
        guard let idx = all.firstIndex(of: highlighted) else { return }
        highlighted = all[(idx + direction + all.count) % all.count]
        themeManager.current = highlighted
    }

    private func confirm() { dismiss() }

    private func cancel() {
        themeManager.current = originalTheme
        dismiss()
    }
}

// MARK: - KeyCaptureView

struct KeyCaptureView: NSViewRepresentable {
    var onUp:     () -> Void
    var onDown:   () -> Void
    var onReturn: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onUp = onUp; view.onDown = onDown
        view.onReturn = onReturn; view.onEscape = onEscape
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onUp = onUp; nsView.onDown = onDown
        nsView.onReturn = onReturn; nsView.onEscape = onEscape
    }
}

final class KeyCaptureNSView: NSView {
    var onUp: (() -> Void)?
    var onDown: (() -> Void)?
    var onReturn: (() -> Void)?
    var onEscape: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: onUp?()
        case 125: onDown?()
        case 36:  onReturn?()
        case 53:  onEscape?()
        default:  super.keyDown(with: event)
        }
    }
}
