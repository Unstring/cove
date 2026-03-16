import Foundation
import SQLite3
import Synchronization

final class SQLiteBackend: DatabaseBackend, @unchecked Sendable {
    let name = "SQLite"
    private let dbPath: String
    private let handle: Mutex<OpaquePointer?>

    let syntaxKeywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "INSERT", "INTO", "UPDATE", "DELETE", "SET",
        "CREATE", "DROP", "ALTER", "TABLE", "INDEX", "VIEW", "DATABASE",
        "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "CROSS", "ON", "AS",
        "AND", "OR", "NOT", "IN", "IS", "NULL", "LIKE", "BETWEEN", "EXISTS",
        "ORDER", "BY", "GROUP", "HAVING", "LIMIT", "OFFSET", "DISTINCT",
        "UNION", "ALL", "CASE", "WHEN", "THEN", "ELSE", "END", "BEGIN",
        "COMMIT", "ROLLBACK", "TRANSACTION", "VALUES", "DEFAULT", "PRIMARY",
        "KEY", "FOREIGN", "REFERENCES", "CASCADE", "CONSTRAINT", "CHECK",
        "UNIQUE", "ASC", "DESC", "WITH", "RECURSIVE", "RETURNING",
        "TRIGGER", "IF", "REPLACE", "ABORT", "FAIL", "IGNORE",
        "BOOLEAN", "INTEGER", "BIGINT", "SMALLINT", "TEXT", "VARCHAR",
        "CHAR", "NUMERIC", "DECIMAL", "REAL", "FLOAT", "DOUBLE", "DATE",
        "TIME", "TIMESTAMP", "BLOB", "JSON",
        "TRUE", "FALSE", "COUNT", "SUM", "AVG", "MIN", "MAX",
        "COALESCE", "CAST", "OVER", "PARTITION", "ROW_NUMBER", "RANK",
        "DENSE_RANK", "LAG", "LEAD", "FIRST_VALUE", "LAST_VALUE",
        "AUTOINCREMENT", "VACUUM", "REINDEX", "ATTACH", "DETACH",
        "PRAGMA", "EXPLAIN", "GLOB", "REGEXP", "COLLATE", "NOCASE",
        "ROWID", "WITHOUT",
    ]

    private init(dbPath: String, handle: consuming Mutex<OpaquePointer?>) {
        self.dbPath = dbPath
        self.handle = handle
    }

    deinit {
        handle.withLock { db in
            if let db {
                sqlite3_close_v2(db)
            }
        }
    }

    static func connect(config: ConnectionConfig) async throws -> SQLiteBackend {
        let path = config.database

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(path, &db, flags, nil)
        guard rc == SQLITE_OK, let db else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let db { sqlite3_close_v2(db) }
            throw DbError.connection("failed to open \(path): \(msg)")
        }

        let backend = SQLiteBackend(dbPath: path, handle: Mutex(db))

        // Enable WAL mode and foreign keys
        try backend.execSQL("PRAGMA journal_mode=WAL")
        try backend.execSQL("PRAGMA foreign_keys=ON")

        return backend
    }

    // MARK: - SQL execution

    func runSQL(_ sql: String) throws -> QueryResult {
        try handle.withLock { db in
            guard let db else { throw DbError.connection("database closed") }

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DbError.query(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            let colCount = sqlite3_column_count(stmt)

            guard colCount > 0 else {
                // Non-result statement (INSERT/UPDATE/DELETE)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw DbError.query(String(cString: sqlite3_errmsg(db)))
                }
                let affected = UInt64(sqlite3_changes(db))
                return QueryResult(columns: [], rows: [], rowsAffected: affected, totalCount: nil)
            }

            var columns: [ColumnInfo] = []
            for i in 0..<colCount {
                let name = sqlite3_column_name(stmt, i).map { String(cString: $0) } ?? "?"
                let typeName = sqlite3_column_decltype(stmt, i).map { String(cString: $0) } ?? ""
                columns.append(ColumnInfo(name: name, typeName: typeName, isPrimaryKey: false))
            }

            var rows: [[String?]] = []
            while true {
                let stepResult = sqlite3_step(stmt)
                if stepResult == SQLITE_DONE { break }
                guard stepResult == SQLITE_ROW else {
                    throw DbError.query(String(cString: sqlite3_errmsg(db)))
                }

                var row: [String?] = []
                for i in 0..<colCount {
                    row.append(columnValue(stmt: stmt!, index: i))
                }
                rows.append(row)
            }

            return QueryResult(columns: columns, rows: rows, rowsAffected: nil, totalCount: nil)
        }
    }

    func execSQL(_ sql: String) throws {
        try handle.withLock { db in
            guard let db else { throw DbError.connection("database closed") }

            var errMsg: UnsafeMutablePointer<CChar>?
            let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
            if rc != SQLITE_OK {
                let msg = errMsg.map { String(cString: $0) } ?? "unknown error"
                sqlite3_free(errMsg)
                throw DbError.query(msg)
            }
        }
    }

    func quoteIdentifier(_ name: String) -> String {
        let escaped = name.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    // MARK: - Private helpers

    private func columnValue(stmt: OpaquePointer, index: Int32) -> String? {
        switch sqlite3_column_type(stmt, index) {
        case SQLITE_NULL:
            return nil
        case SQLITE_BLOB:
            let bytes = sqlite3_column_bytes(stmt, index)
            return "<BLOB \(bytes) bytes>"
        default:
            guard let text = sqlite3_column_text(stmt, index) else { return nil }
            return String(cString: text)
        }
    }

    func escapeSQLString(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}
