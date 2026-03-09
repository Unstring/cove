import Foundation

@Observable
final class DialogState {
    var name = ""
    var backend: BackendType = .postgres
    var host = "localhost"
    var port = BackendType.postgres.defaultPort
    var user = ""
    var password = ""
    var database = ""
    var error = ""
    var connecting = false
    var visible = false
    var editingConnectionId: UUID?
    var colorHex: String = MorfeoTheme.accentHex

    var isEditing: Bool { editingConnectionId != nil }

    func reset() {
        name = ""
        backend = .postgres
        host = "localhost"
        port = backend.defaultPort
        user = ""
        password = ""
        database = ""
        error = ""
        connecting = false
        editingConnectionId = nil
        colorHex = MorfeoTheme.accentHex
    }
}
