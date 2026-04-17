import SwiftUI

struct SQLPreviewSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.coveDialogDismiss) private var dismiss

    var body: some View {
        let sql = state.generateSQLPreview()

        VStack(alignment: .leading, spacing: 0) {
            Text("Review Changes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CoveTheme.fgPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView {
                Text(sql)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(CoveTheme.fgPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(CoveTheme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 16)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Execute") {
                    dismiss()
                    state.commitEdits()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 520, height: 360)
        // Auto-close when there's nothing left to preview
        .onChange(of: state.table?.hasPendingEdits) { _, hasPending in
            if hasPending == false { dismiss() }
        }
    }
}
