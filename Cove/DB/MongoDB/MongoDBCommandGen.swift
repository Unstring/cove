import Foundation

extension MongoDBBackend {

    func generateUpdateSQL(
        tablePath: [String],
        primaryKey: [(column: String, value: String)],
        column: String,
        newValue: String?
    ) -> String {
        guard tablePath.count >= 3 else { return "// invalid path" }
        let coll = tablePath[2]
        let idStr = primaryKey.first(where: { $0.column == "_id" })?.value ?? ""
        let idFilter = formatIdFilter(idStr)
        let val = formatValue(newValue)

        return "db.\(coll).updateOne(\(idFilter), {\"$set\": {\"\(column)\": \(val)}})"
    }

    func generateInsertSQL(
        tablePath: [String],
        columns: [String],
        values: [String?]
    ) -> String {
        guard tablePath.count >= 3 else { return "// invalid path" }
        let coll = tablePath[2]

        var fields: [String] = []
        for (col, val) in zip(columns, values) where col != "_id" {
            fields.append("\"\(col)\": \(formatValue(val))")
        }

        return "db.\(coll).insertOne({\(fields.joined(separator: ", "))})"
    }

    func generateDeleteSQL(
        tablePath: [String],
        primaryKey: [(column: String, value: String)]
    ) -> String {
        guard tablePath.count >= 3 else { return "// invalid path" }
        let coll = tablePath[2]
        let idStr = primaryKey.first(where: { $0.column == "_id" })?.value ?? ""
        let idFilter = formatIdFilter(idStr)

        return "db.\(coll).deleteOne(\(idFilter))"
    }

    func generateDropElementSQL(path: [String], elementName: String) -> String {
        guard path.count >= 3 else { return "// invalid path" }
        let coll = path[2]

        if path.count >= 4, path[3] == "Indexes" {
            return "db.\(coll).dropIndex(\"\(elementName)\")"
        }

        return "db.\(coll).drop()"
    }

    // MARK: - Formatting helpers

    private func formatIdFilter(_ idStr: String) -> String {
        if idStr.count == 24, idStr.allSatisfy(\.isHexDigit) {
            return "{\"_id\": ObjectId(\"\(idStr)\")}"
        }
        return "{\"_id\": \(formatValue(idStr))}"
    }

    private func formatValue(_ value: String?) -> String {
        guard let value else { return "null" }
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        if trimmed == "null" || trimmed == "true" || trimmed == "false" {
            return trimmed
        }
        if Int(trimmed) != nil || Double(trimmed) != nil {
            return trimmed
        }
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            return trimmed
        }

        return "\"\(trimmed.replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}
