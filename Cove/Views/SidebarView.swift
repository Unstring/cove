import SwiftUI
import AppKit

struct SidebarView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CoveTheme.bgSecondary)
    }

    @ViewBuilder
    private var content: some View {
        if state.connecting {
            ProgressView("Connecting...")
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.connection == nil {
            Text("Connect to a database")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(20)
        } else {
            TreeView()
                .sheet(isPresented: Bindable(state).showCreateSheet) {
                    CreateChildSheet().environment(state)
                }
                .sheet(isPresented: Bindable(state).showTreeAction) {
                    DropConfirmSheet().environment(state)
                }
        }
    }
}

// MARK: - CreateChildSheet

struct CreateChildSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String] = [:]

    private var sqlPreview: String? {
        state.connection?.generateCreateChildSQL(
            path: state.createSheetParentPath,
            values: values
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New \(state.createSheetLabel)")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Form {
                ForEach(state.createSheetFields) { field in
                    if let options = field.options {
                        Picker(field.label, selection: binding(for: field)) {
                            ForEach(options, id: \.self) { Text($0).tag($0) }
                        }
                    } else {
                        TextField(field.label, text: binding(for: field),
                                  prompt: Text(field.placeholder))
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .padding(.horizontal, 4)

            Text("SQL Preview")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            ScrollView {
                Text(sqlPreview ?? "")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(sqlPreview != nil ? .primary : .secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 80)
            .background(CoveTheme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 16)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Execute") { state.executeCreateChild(values: values) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(sqlPreview == nil)
            }
            .padding(16)
        }
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .background()
        .onAppear {
            for field in state.createSheetFields { values[field.id] = field.defaultValue }
        }
    }

    private func binding(for field: CreateField) -> Binding<String> {
        Binding(get: { values[field.id] ?? field.defaultValue },
                set: { values[field.id] = $0 })
    }
}

// MARK: - DropConfirmSheet

struct DropConfirmSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Confirm Drop")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView {
                Text(state.treeActionSQL)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(CoveTheme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 16)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Execute") { state.executeTreeAction() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 520, height: 280)
        .background()
    }
}

// MARK: - VisualEffectBackground
//
// Uses system vibrancy by default.
// Themes that define solidPanelBg (e.g. OLED, Midnight) bypass vibrancy
// and paint a solid color instead — no hardcoded theme checks here.

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    @Environment(ThemeManager.self) private var themeManager

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        apply(to: view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        apply(to: nsView)
    }

    @MainActor
    private func apply(to view: NSVisualEffectView) {
        if let solid = themeManager.current.solidPanelBg {
            view.material = .windowBackground
            view.blendingMode = .withinWindow
            view.state = .active
            view.wantsLayer = true
            view.layer?.backgroundColor = solid.cgColor
        } else {
            view.layer?.backgroundColor = nil
            view.material = material
            view.blendingMode = .withinWindow
            view.state = .followsWindowActiveState
        }
    }
}
