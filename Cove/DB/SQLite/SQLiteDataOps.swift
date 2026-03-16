import Foundation

extension SQLiteBackend {

    func fetchTableData(
        path: [String],
        limit: UInt32,
        offset: UInt32,
        sort: (column: String, direction: SortDirection)?
    ) async throws -> QueryResult {
        guard path.count == 3 else {
            throw DbError.invalidPath(expected: 3, got: path.count)
        }

        let table = path[2]
        let quotedTable = quoteIdentifier(table)
        let columns = try fetchColumnInfo(table: table)

        var orderClause = ""
        if let sort {
            let dir = sort.direction == .asc ? "ASC" : "DESC"
            orderClause = " ORDER BY \(quoteIdentifier(sort.column)) \(dir)"
        }

        let dataSql = "SELECT * FROM \(quotedTable)\(orderClause) LIMIT \(limit) OFFSET \(offset)"
        let dataResult = try runSQL(dataSql)

        let countSql = "SELECT COUNT(*) FROM \(quotedTable)"
        let countResult = try runSQL(countSql)
        let totalCount = countResult.rows.first?.first.flatMap { $0.flatMap { UInt64($0) } } ?? 0

        return QueryResult(
            columns: columns,
            rows: dataResult.rows,
            rowsAffected: nil,
            totalCount: totalCount
        )
    }

    func executeQuery(database: String, sql: String) async throws -> QueryResult {
        try runSQL(sql)
    }

    func updateCell(
        tablePath: [String],
        primaryKey: [(column: String, value: String)],
        column: String,
        newValue: String?
    ) async throws {
        guard tablePath.count == 3 else {
            throw DbError.invalidPath(expected: 3, got: tablePath.count)
        }

        let sql = generateUpdateSQL(tablePath: tablePath, primaryKey: primaryKey, column: column, newValue: newValue)
        try execSQL(sql)
    }

    func fetchCompletionSchema(database: String) async throws -> CompletionSchema {
        let tablesResult = try runSQL(
            "SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name NOT LIKE 'sqlite_%' ORDER BY name"
        )

        var tableMap: [String: [CompletionColumn]] = [:]
        for row in tablesResult.rows {
            guard let tableName = row.first ?? nil else { continue }
            let colResult = try runSQL("PRAGMA table_info(\(quoteIdentifier(tableName)))")
            var cols: [CompletionColumn] = []
            for colRow in colResult.rows {
                guard colRow.count >= 3,
                      let colName = colRow[1],
                      let colType = colRow[2] else { continue }
                cols.append(CompletionColumn(name: colName, typeName: colType))
            }
            tableMap[tableName] = cols
        }

        let tables: [String: [CompletionTable]] = [
            "main": tableMap.map { CompletionTable(name: $0.key, columns: $0.value) }
                .sorted { $0.name < $1.name }
        ]

        return CompletionSchema(schemas: ["main"], tables: tables, functions: [], types: [])
    }

    func fetchColumnInfo(table: String) throws -> [ColumnInfo] {
        let result = try runSQL("PRAGMA table_info(\(quoteIdentifier(table)))")
        // PRAGMA table_info columns: cid(0), name(1), type(2), notnull(3), dflt_value(4), pk(5)
        return result.rows.compactMap { row in
            guard row.count >= 6,
                  let name = row[1],
                  let typeName = row[2] else { return nil }
            let isPK = row[5] == "1"
            return ColumnInfo(name: name, typeName: typeName, isPrimaryKey: isPK)
        }
    }
}
