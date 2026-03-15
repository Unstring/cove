import Foundation
@preconcurrency import MongoKitten
import BSON

extension MongoDBBackend {

    func fetchTableData(
        path: [String],
        limit: UInt32,
        offset: UInt32,
        sort: (column: String, direction: SortDirection)?
    ) async throws -> QueryResult {
        guard path.count >= 3, path[1] == "Collections" || path[1] == "Views" else {
            throw DbError.invalidPath(expected: 3, got: path.count)
        }

        let dbName = path[0]
        let collName = path[2]
        let db = try await databaseFor(name: dbName)
        let collection = db[collName]

        var query = collection.find()

        if let sort {
            let direction: Sorting.Order = sort.direction == .asc ? .ascending : .descending
            query = query.sort([sort.column: direction])
        }

        let documents = try await query
            .skip(Int(offset))
            .limit(Int(limit))
            .drain()

        let totalCount = try await collection.count()

        guard !documents.isEmpty else {
            return QueryResult(
                columns: [ColumnInfo(name: "_id", typeName: "objectId", isPrimaryKey: true)],
                rows: [],
                rowsAffected: nil,
                totalCount: UInt64(totalCount)
            )
        }

        let keys = Self.extractKeys(from: documents)
        let columns = keys.map { key in
            ColumnInfo(
                name: key,
                typeName: key == "_id" ? "objectId" : "auto",
                isPrimaryKey: key == "_id"
            )
        }

        let rows: [[String?]] = documents.map { doc in
            keys.map { key in Self.primitiveToString(doc[key]) }
        }

        return QueryResult(
            columns: columns,
            rows: rows,
            rowsAffected: nil,
            totalCount: UInt64(totalCount)
        )
    }

    func executeQuery(database: String, sql: String) async throws -> QueryResult {
        let db = try await databaseFor(name: database)

        guard let cmd = Self.parseCommand(sql) else {
            throw DbError.query("expected format: db.collection.method({...})")
        }

        let collection = db[cmd.collection]
        let argDoc = cmd.argument.isEmpty ? Document() : Self.parseJSONToDocument(cmd.argument) ?? Document()

        switch cmd.method {
        case "find":
            let docs = try await collection.find(argDoc).drain()
            return formatDocumentResult(docs)

        case "findOne":
            if let doc = try await collection.findOne(argDoc) {
                return formatDocumentResult([doc])
            }
            return QueryResult(columns: [], rows: [], rowsAffected: 0, totalCount: nil)

        case "insertOne":
            let reply = try await collection.insert(argDoc)
            let cols = [ColumnInfo(name: "insertedCount", typeName: "integer", isPrimaryKey: false)]
            return QueryResult(columns: cols, rows: [[String(reply.insertCount)]], rowsAffected: UInt64(reply.insertCount), totalCount: nil)

        case "insertMany":
            let docs = argDoc.values.compactMap { $0 as? Document }
            guard !docs.isEmpty else {
                throw DbError.query("insertMany expects an array of documents")
            }
            let reply = try await collection.insertMany(docs)
            let cols = [ColumnInfo(name: "insertedCount", typeName: "integer", isPrimaryKey: false)]
            return QueryResult(columns: cols, rows: [[String(reply.insertCount)]], rowsAffected: UInt64(reply.insertCount), totalCount: nil)

        case "updateOne":
            let parts = Self.parseUpdateArgs(cmd.argument)
            let reply = try await collection.updateOne(where: parts.filter, to: parts.update)
            let affected = reply.updatedCount
            let cols = [ColumnInfo(name: "modifiedCount", typeName: "integer", isPrimaryKey: false)]
            return QueryResult(columns: cols, rows: [[String(affected)]], rowsAffected: UInt64(affected), totalCount: nil)

        case "updateMany":
            let parts = Self.parseUpdateArgs(cmd.argument)
            let reply = try await collection.updateMany(where: parts.filter, to: parts.update)
            let affected = reply.updatedCount
            let cols = [ColumnInfo(name: "modifiedCount", typeName: "integer", isPrimaryKey: false)]
            return QueryResult(columns: cols, rows: [[String(affected)]], rowsAffected: UInt64(affected), totalCount: nil)

        case "deleteOne":
            let reply = try await collection.deleteOne(where: argDoc)
            let cols = [ColumnInfo(name: "deletedCount", typeName: "integer", isPrimaryKey: false)]
            return QueryResult(columns: cols, rows: [[String(reply.deletes)]], rowsAffected: UInt64(reply.deletes), totalCount: nil)

        case "deleteMany":
            let reply = try await collection.deleteAll(where: argDoc)
            let cols = [ColumnInfo(name: "deletedCount", typeName: "integer", isPrimaryKey: false)]
            return QueryResult(columns: cols, rows: [[String(reply.deletes)]], rowsAffected: UInt64(reply.deletes), totalCount: nil)

        case "countDocuments", "count":
            let count = try await collection.count(argDoc)
            let cols = [ColumnInfo(name: "count", typeName: "integer", isPrimaryKey: false)]
            return QueryResult(columns: cols, rows: [[String(count)]], rowsAffected: nil, totalCount: nil)

        case "drop":
            try await collection.drop()
            let cols = [ColumnInfo(name: "Result", typeName: "text", isPrimaryKey: false)]
            return QueryResult(columns: cols, rows: [["ok"]], rowsAffected: nil, totalCount: nil)

        case "createIndex":
            let keys = argDoc.keys
            guard !keys.isEmpty else {
                throw DbError.query("createIndex expects index key specification")
            }
            try await collection.createIndex(named: keys.joined(separator: "_"), keys: argDoc)
            let cols = [ColumnInfo(name: "Result", typeName: "text", isPrimaryKey: false)]
            return QueryResult(columns: cols, rows: [["index created"]], rowsAffected: nil, totalCount: nil)

        case "dropIndex":
            let indexName = cmd.argument.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            struct DropIndexCommand: Encodable, Sendable {
                let dropIndexes: String
                let index: String
            }
            struct OK: Decodable, Sendable { let ok: Int }
            _ = try await executeRawCommand(
                DropIndexCommand(dropIndexes: cmd.collection, index: indexName),
                decodeAs: OK.self,
                on: db
            )
            let cols = [ColumnInfo(name: "Result", typeName: "text", isPrimaryKey: false)]
            return QueryResult(columns: cols, rows: [["index dropped"]], rowsAffected: nil, totalCount: nil)

        case "getIndexes", "listIndexes":
            let indexes = try await collection.listIndexes().drain()
            var rows: [[String?]] = []
            for index in indexes {
                rows.append([index.name, Self.documentToJSON(index.key)])
            }
            let cols = [
                ColumnInfo(name: "Name", typeName: "text", isPrimaryKey: false),
                ColumnInfo(name: "Keys", typeName: "text", isPrimaryKey: false),
            ]
            return QueryResult(columns: cols, rows: rows, rowsAffected: nil, totalCount: nil)

        default:
            throw DbError.query("unsupported method: \(cmd.method)")
        }
    }

    func updateCell(
        tablePath: [String],
        primaryKey: [(column: String, value: String)],
        column: String,
        newValue: String?
    ) async throws {
        guard tablePath.count >= 3 else {
            throw DbError.invalidPath(expected: 3, got: tablePath.count)
        }

        let dbName = tablePath[0]
        let collName = tablePath[2]
        let db = try await databaseFor(name: dbName)
        let collection = db[collName]

        guard let idStr = primaryKey.first(where: { $0.column == "_id" })?.value else {
            throw DbError.other("missing _id in primary key")
        }

        let idValue = Self.parseObjectId(idStr)
        let newPrimitive = newValue.map { Self.parseValue($0) } ?? Null()

        let filter: Document = ["_id": idValue]
        let update: Document = ["$set": [column: newPrimitive] as Document]

        let result = try await collection.updateOne(where: filter, to: update)
        guard result.updatedCount > 0 else {
            throw DbError.other("no document matched _id: \(idStr)")
        }
    }

    func fetchCompletionSchema(database: String) async throws -> CompletionSchema {
        let db = try await databaseFor(name: database)
        let collections = try await db.listCollections()

        var tables: [CompletionTable] = []
        for mongoCollection in collections {
            let coll = db[mongoCollection.name]
            let sampleDocs = try await coll.find().limit(5).drain()
            let keys = Self.extractKeys(from: sampleDocs)
            let columns = keys.map { CompletionColumn(name: $0, typeName: "auto") }
            tables.append(CompletionTable(name: mongoCollection.name, columns: columns))
        }

        return CompletionSchema(
            schemas: [],
            tables: [database: tables],
            functions: [],
            types: []
        )
    }

    // MARK: - Helpers

    private func formatDocumentResult(_ documents: [Document]) -> QueryResult {
        guard !documents.isEmpty else {
            return QueryResult(columns: [], rows: [], rowsAffected: 0, totalCount: nil)
        }

        let keys = Self.extractKeys(from: documents)
        let columns = keys.map {
            ColumnInfo(name: $0, typeName: "auto", isPrimaryKey: $0 == "_id")
        }

        let rows: [[String?]] = documents.map { doc in
            keys.map { key in Self.primitiveToString(doc[key]) }
        }

        return QueryResult(columns: columns, rows: rows, rowsAffected: nil, totalCount: UInt64(documents.count))
    }

    static func parseUpdateArgs(_ input: String) -> (filter: Document, update: Document) {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        var depth = 0
        var splitIndex: String.Index?

        for (i, ch) in trimmed.enumerated() {
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 {
                    let nextIdx = trimmed.index(trimmed.startIndex, offsetBy: i + 1)
                    if nextIdx < trimmed.endIndex {
                        splitIndex = nextIdx
                    }
                    break
                }
            }
        }

        guard let split = splitIndex else {
            let doc = Self.parseJSONToDocument(trimmed) ?? Document()
            return (doc, Document())
        }

        let filterStr = String(trimmed[trimmed.startIndex...trimmed.index(before: split)])
            .trimmingCharacters(in: .whitespaces)
        var updateStr = String(trimmed[split...])
            .trimmingCharacters(in: .whitespaces)
        if updateStr.hasPrefix(",") {
            updateStr = String(updateStr.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        let filter = Self.parseJSONToDocument(filterStr) ?? Document()
        let update = Self.parseJSONToDocument(updateStr) ?? Document()
        return (filter, update)
    }
}
