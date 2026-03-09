# Adding a Database Backend to Morfeo

Morfeo uses a protocol-based backend system. Each database (Postgres, MySQL, Redis, etc.) implements the `DatabaseBackend` protocol. The UI layer is fully agnostic — it never checks which backend is active, so adding a new database requires **zero changes to UI code**.

## Step-by-step

1. **Create `DB/YourDatabase/`** folder (e.g. `DB/MySQL/`)
2. **Add a case** to `BackendType` in `ConnectionConfig.swift`:
   - `displayName` — human-readable name shown in the UI
   - `iconAsset` — asset catalog image name for the logo
   - `defaultPort` — default port string (e.g. `"3306"`)
3. **Add the logo** to `Assets.xcassets/` (PDF or PNG, any size — it's displayed small)
4. **Implement `DatabaseBackend`** — see protocol reference below
5. **Add factory case** in `morfeoConnect()` in `ConnectionConfig.swift`
6. **Add the driver dependency** to the Xcode project (SPM)

## Protocol reference

```swift
protocol DatabaseBackend: Sendable {
    var name: String { get }
    var syntaxKeywords: Set<String> { get }

    // Tree hierarchy — path is [] for root, [db] for schemas, etc.
    func listChildren(path: [String]) async throws -> [HierarchyNode]

    // Capability queries — used by the UI to decide what actions are available
    func isDataBrowsable(path: [String]) -> Bool
    func isEditable(path: [String]) -> Bool
    func isStructureEditable(path: [String]) -> Bool

    // Data browsing with pagination
    func fetchTableData(path:limit:offset:sort:) async throws -> QueryResult

    // Detail view for tree groups (shows metadata tables)
    func fetchNodeDetails(path:) async throws -> QueryResult

    // Free-form query execution
    func executeQuery(database:sql:) async throws -> QueryResult

    // Data editing
    func updateCell(tablePath:primaryKey:column:newValue:) async throws

    // SQL generation for preview
    func generateUpdateSQL(...) -> String
    func generateInsertSQL(...) -> String
    func generateDeleteSQL(...) -> String
    func generateDropElementSQL(path:elementName:) -> String
}
```

### Key methods explained

- **`listChildren(path:)`** — Returns child nodes for a tree path. `[]` = databases/root, `[db]` = schemas or equivalent, deeper paths = tables, columns, etc. Each backend defines its own depth and grouping.
- **`isDataBrowsable(path:)`** — `true` if selecting this node should load a data grid (e.g. tables, views).
- **`isEditable(path:)`** — `true` if row editing (INSERT/UPDATE/DELETE) is supported for this node.
- **`isStructureEditable(path:)`** — `true` if structure elements (indexes, constraints, triggers) can be dropped.
- **`syntaxKeywords`** — Set of uppercase keywords for syntax highlighting. Can be empty for non-SQL backends.
- **`executeQuery(database:sql:)`** — Accepts any command string, not just SQL. For Redis this could be `GET key`, for MongoDB a JSON command.

## Hierarchy model

The tree is path-based. Each level is a string array:

```
[]           → root (databases or connections)
[db]         → second level (schemas, keyspaces, etc.)
[db, schema] → third level (groups like Tables, Views, etc.)
...          → deeper levels as needed
```

Each backend decides how deep the tree goes and what groups exist. Postgres uses 6 levels (database → schema → group → object → subgroup → element). A simpler backend might use 2-3 levels.

## Non-SQL backends

- `syntaxKeywords` can be an empty set
- `executeQuery` accepts any command string — return results as `QueryResult`
- SQL generation methods can return backend-native syntax
- The query editor is a plain text field, so any command format works

## File organization

Split implementations at ~300 lines per file. The Postgres backend uses:

```
Postgres/
  PostgresBackend.swift    — class definition, connection pool
  PostgresHierarchy.swift  — tree navigation, node details
  PostgresDataOps.swift    — data fetching, query execution
  PostgresSQLGen.swift     — SQL generation
  PostgresDecoders.swift   — binary wire format decoders
```

Each file is an `extension PostgresBackend`. Methods shared across files use `internal` access (drop `private`).

## Minimal skeleton

```swift
import Foundation

final class MyDBBackend: DatabaseBackend, @unchecked Sendable {
    let name = "MyDB"
    let syntaxKeywords: Set<String> = []

    static func connect(config: ConnectionConfig) async throws -> MyDBBackend {
        // Connect to the database, return initialized backend
        fatalError("TODO")
    }

    func isDataBrowsable(path: [String]) -> Bool { false }
    func isEditable(path: [String]) -> Bool { false }
    func isStructureEditable(path: [String]) -> Bool { false }

    func listChildren(path: [String]) async throws -> [HierarchyNode] { [] }
    func fetchTableData(path: [String], limit: UInt32, offset: UInt32,
                        sort: (column: String, direction: SortDirection)?) async throws -> QueryResult {
        QueryResult(columns: [], rows: [], rowsAffected: nil, totalCount: nil)
    }
    func fetchNodeDetails(path: [String]) async throws -> QueryResult {
        QueryResult(columns: [], rows: [], rowsAffected: nil, totalCount: nil)
    }
    func executeQuery(database: String, sql: String) async throws -> QueryResult {
        QueryResult(columns: [], rows: [], rowsAffected: nil, totalCount: nil)
    }
    func updateCell(tablePath: [String], primaryKey: [(column: String, value: String)],
                    column: String, newValue: String?) async throws {}
    func generateUpdateSQL(tablePath: [String], primaryKey: [(column: String, value: String)],
                           column: String, newValue: String?) -> String { "" }
    func generateInsertSQL(tablePath: [String], columns: [String], values: [String?]) -> String { "" }
    func generateDeleteSQL(tablePath: [String], primaryKey: [(column: String, value: String)]) -> String { "" }
    func generateDropElementSQL(path: [String], elementName: String) -> String { "" }
}
```
