import Foundation
@preconcurrency import MongoKitten

final class MongoDBBackend: DatabaseBackend, @unchecked Sendable {
    let name = "MongoDB"
    private let lock = NSLock()
    private let connectionString: String
    private var databases: [String: MongoDatabase] = [:]

    let syntaxKeywords: Set<String> = [
        "find", "findOne", "insertOne", "insertMany", "updateOne", "updateMany",
        "deleteOne", "deleteMany", "replaceOne", "aggregate", "countDocuments",
        "distinct", "createIndex", "dropIndex", "drop", "createCollection",
        "listCollections", "listDatabases", "getIndexes",
        "$match", "$group", "$sort", "$project", "$limit", "$skip", "$unwind",
        "$lookup", "$addFields", "$set", "$unset", "$replaceRoot", "$merge",
        "$out", "$count", "$facet", "$bucket", "$bucketAuto",
        "$eq", "$ne", "$gt", "$gte", "$lt", "$lte", "$in", "$nin",
        "$and", "$or", "$not", "$nor", "$exists", "$type", "$regex",
        "$all", "$elemMatch", "$size", "$push", "$pull", "$addToSet",
        "$pop", "$inc", "$mul", "$min", "$max", "$rename", "$currentDate",
        "ObjectId", "ISODate", "NumberLong", "NumberInt", "NumberDecimal",
        "true", "false", "null",
    ]

    private init(connectionString: String, initialDb: MongoDatabase) {
        self.connectionString = connectionString
        let dbName = initialDb.name
        self.databases[dbName] = initialDb
    }

    static func connect(config: ConnectionConfig) async throws -> MongoDBBackend {
        let connStr = buildConnectionString(config: config)

        do {
            let db = try await MongoDatabase.connect(to: connStr)
            let backend = MongoDBBackend(connectionString: connStr, initialDb: db)

            _ = try await db.listCollections()
            return backend
        } catch {
            throw DbError.connection(String(describing: error))
        }
    }

    func databaseFor(name: String) async throws -> MongoDatabase {
        if let existing = lock.withLock({ databases[name] }) {
            return existing
        }

        let adjusted = Self.replaceDatabase(in: connectionString, with: name)
        do {
            let db = try await MongoDatabase.connect(to: adjusted)
            lock.withLock { databases[name] = db }
            return db
        } catch {
            throw DbError.connection("failed to connect to database '\(name)': \(String(describing: error))")
        }
    }

    // MARK: - Connection string helpers

    private static func buildConnectionString(config: ConnectionConfig) -> String {
        let host = config.host.isEmpty ? "localhost" : config.host
        let port = config.port.isEmpty ? "27017" : config.port
        let db = config.database.isEmpty ? "admin" : config.database

        if config.user.isEmpty {
            return "mongodb://\(host):\(port)/\(db)"
        }

        let user = config.user.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? config.user
        let pass = config.password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? config.password
        return "mongodb://\(user):\(pass)@\(host):\(port)/\(db)"
    }

    private static func replaceDatabase(in connectionString: String, with dbName: String) -> String {
        guard var components = URLComponents(string: connectionString) else {
            return connectionString
        }
        components.path = "/\(dbName)"
        return components.string ?? connectionString
    }

    /// Execute a raw command on the given database and decode the result
    func executeRawCommand<E: Encodable & Sendable, D: Decodable & Sendable>(
        _ command: E,
        decodeAs: D.Type,
        on db: MongoDatabase
    ) async throws -> D {
        let connection = try await db.pool.next(for: .writable)
        return try await connection.executeCodable(
            command,
            decodeAs: D.self,
            namespace: db.commandNamespace,
            in: nil,
            sessionId: connection.implicitSessionId,
            traceLabel: "RawCommand"
        )
    }

    deinit {
        let pools = databases.values.map { $0.pool }
        Task { [pools] in
            for pool in pools {
                if let cluster = pool as? MongoCluster {
                    await cluster.disconnect()
                }
            }
        }
    }
}
