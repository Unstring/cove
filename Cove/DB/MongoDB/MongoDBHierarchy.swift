import Foundation
@preconcurrency import MongoKitten
import BSON

// Path structure:
// []                                     -> databases
// ["mydb"]                               -> groups: Collections, Views
// ["mydb", "Collections"]                -> collection names
// ["mydb", "Collections", "users"]       -> sub-groups: Indexes
// ["mydb", "Collections", "users", "Indexes"] -> index names

extension MongoDBBackend {
    private static let systemDatabases: Set<String> = ["admin", "local", "config"]

    private static let tintDatabase   = NodeTint(r: 0.298, g: 0.686, b: 0.314)
    private static let tintGroup      = NodeTint(r: 0.60, g: 0.60, b: 0.60)
    private static let tintCollection = NodeTint(r: 0.400, g: 0.600, b: 0.800)
    private static let tintIndex      = NodeTint(r: 0.700, g: 0.550, b: 0.350)

    // MARK: - Capability queries

    func isDataBrowsable(path: [String]) -> Bool {
        path.count == 3 && (path[1] == "Collections" || path[1] == "Views")
    }

    func isEditable(path: [String]) -> Bool {
        path.count == 3 && path[1] == "Collections"
    }

    func isStructureEditable(path: [String]) -> Bool {
        path.count >= 4 && path[3] == "Indexes"
    }

    func structurePath(for tablePath: [String]) -> [String]? {
        guard tablePath.count == 3 else { return nil }
        return tablePath + ["Indexes"]
    }

    // MARK: - Creation

    func creatableChildLabel(path: [String]) -> String? {
        switch path.count {
        case 2 where path[1] == "Collections": "Collection"
        default: nil
        }
    }

    func createFormFields(path: [String]) -> [CreateField] {
        guard path.count == 2, path[1] == "Collections" else { return [] }
        return [
            CreateField(id: "name", label: "Collection Name", defaultValue: "", placeholder: "my_collection"),
            CreateField(id: "capped", label: "Capped", defaultValue: "No", placeholder: "No", options: ["No", "Yes"]),
            CreateField(id: "size", label: "Max Size (bytes)", defaultValue: "", placeholder: "optional"),
        ]
    }

    func generateCreateChildSQL(path: [String], values: [String: String]) -> String? {
        guard path.count == 2, path[1] == "Collections" else { return nil }
        let name = values["name", default: ""].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        if values["capped"] == "Yes", let size = Int(values["size", default: ""]) {
            return "db.createCollection(\"\(name)\", {capped: true, size: \(size)})"
        }
        return "db.createCollection(\"\(name)\")"
    }

    // MARK: - Deletion

    func isDeletable(path: [String]) -> Bool {
        switch path.count {
        case 1: true
        case 3 where path[1] == "Collections": true
        default: false
        }
    }

    func generateDropSQL(path: [String]) -> String? {
        switch path.count {
        case 1:
            return "db.dropDatabase()"
        case 3 where path[1] == "Collections":
            return "db.\(path[2]).drop()"
        default:
            return nil
        }
    }

    // MARK: - Tree navigation

    func listChildren(path: [String]) async throws -> [HierarchyNode] {
        switch path.count {
        case 0:
            return try await listDatabases()
        case 1:
            return listGroups()
        case 2:
            return try await listCollectionsForGroup(path: path)
        case 3:
            return listSubGroups(path: path)
        case 4:
            return try await listIndexes(path: path)
        default:
            return []
        }
    }

    // MARK: - Node details

    func fetchNodeDetails(path: [String]) async throws -> QueryResult {
        guard path.count == 3, path[1] == "Collections" else {
            return QueryResult(columns: [], rows: [], rowsAffected: nil, totalCount: nil)
        }

        let dbName = path[0]
        let collName = path[2]
        let db = try await databaseFor(name: dbName)

        var rows: [[String?]] = [["Collection", collName]]

        struct CollStatsCommand: Encodable, Sendable {
            let collStats: String
        }

        if let stats = try? await executeRawCommand(
            CollStatsCommand(collStats: collName),
            decodeAs: Document.self,
            on: db
        ) {
            if let count = stats["count"] {
                rows.append(["Document Count", Self.primitiveToString(count)])
            }
            if let size = stats["size"] {
                rows.append(["Size", Self.primitiveToString(size)])
            }
            if let avgObjSize = stats["avgObjSize"] {
                rows.append(["Avg Object Size", Self.primitiveToString(avgObjSize)])
            }
            if let storageSize = stats["storageSize"] {
                rows.append(["Storage Size", Self.primitiveToString(storageSize)])
            }
            if let nindexes = stats["nindexes"] {
                rows.append(["Index Count", Self.primitiveToString(nindexes)])
            }
            if let totalIndexSize = stats["totalIndexSize"] {
                rows.append(["Total Index Size", Self.primitiveToString(totalIndexSize)])
            }
            if let capped = stats["capped"] {
                rows.append(["Capped", Self.primitiveToString(capped)])
            }
        }

        let cols = [
            ColumnInfo(name: "Property", typeName: "text", isPrimaryKey: false),
            ColumnInfo(name: "Value", typeName: "text", isPrimaryKey: false),
        ]
        return QueryResult(columns: cols, rows: rows, rowsAffected: nil, totalCount: nil)
    }

    // MARK: - Private helpers

    private func listDatabases() async throws -> [HierarchyNode] {
        let db = try await databaseFor(name: "admin")
        let allDbs = try await db.pool.listDatabases()

        return allDbs
            .filter { !Self.systemDatabases.contains($0.name) }
            .sorted { $0.name < $1.name }
            .map { mongoDb in
                HierarchyNode(
                    name: mongoDb.name,
                    icon: "cylinder.split.1x2",
                    tint: Self.tintDatabase,
                    isExpandable: true
                )
            }
    }

    private func listGroups() -> [HierarchyNode] {
        [
            HierarchyNode(name: "Collections", icon: "folder", tint: Self.tintGroup, isExpandable: true),
            HierarchyNode(name: "Views", icon: "folder", tint: Self.tintGroup, isExpandable: true),
        ]
    }

    private func listCollectionsForGroup(path: [String]) async throws -> [HierarchyNode] {
        let dbName = path[0]
        let group = path[1]
        let db = try await databaseFor(name: dbName)

        // Use raw listCollections command to get type info
        struct ListCollectionsWithType: Encodable, Sendable {
            let listCollections: Int32 = 1
            let filter: Document?
        }

        let filter: Document = group == "Views"
            ? ["type": "view"]
            : ["type": "collection"]

        struct CursorResponse: Decodable, Sendable {
            struct Batch: Decodable, Sendable {
                let firstBatch: [CollEntry]
            }
            let cursor: Batch
        }
        struct CollEntry: Decodable, Sendable {
            let name: String
            let type: String
        }

        let isView = group == "Views"

        do {
            let response = try await executeRawCommand(
                ListCollectionsWithType(filter: filter),
                decodeAs: CursorResponse.self,
                on: db
            )

            return response.cursor.firstBatch
                .sorted { $0.name < $1.name }
                .map { entry in
                    HierarchyNode(
                        name: entry.name,
                        icon: isView ? "eye" : "doc.text",
                        tint: Self.tintCollection,
                        isExpandable: !isView
                    )
                }
        } catch {
            // Fallback: list all collections without type filtering
            let collections = try await db.listCollections()
            return collections
                .sorted { $0.name < $1.name }
                .map { coll in
                    HierarchyNode(
                        name: coll.name,
                        icon: "doc.text",
                        tint: Self.tintCollection,
                        isExpandable: true
                    )
                }
        }
    }

    private func listSubGroups(path: [String]) -> [HierarchyNode] {
        guard path[1] == "Collections" else { return [] }
        return [
            HierarchyNode(name: "Indexes", icon: "folder", tint: Self.tintGroup, isExpandable: true),
        ]
    }

    private func listIndexes(path: [String]) async throws -> [HierarchyNode] {
        guard path.count == 4, path[3] == "Indexes" else { return [] }

        let dbName = path[0]
        let collName = path[2]
        let db = try await databaseFor(name: dbName)
        let collection = db[collName]

        let indexes = try await collection.listIndexes().drain()
        return indexes.map { index in
            HierarchyNode(
                name: index.name,
                icon: "bolt",
                tint: Self.tintIndex,
                isExpandable: false
            )
        }
    }
}
