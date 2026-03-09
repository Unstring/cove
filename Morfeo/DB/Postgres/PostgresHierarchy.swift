import PostgresNIO

extension PostgresBackend {
    private static let tintDatabase = NodeTint(r: 0.357, g: 0.608, b: 0.835)
    private static let tintSchema   = NodeTint(r: 0.773, g: 0.525, b: 0.753)
    private static let tintTable    = NodeTint(r: 0.420, g: 0.624, b: 0.800)
    private static let tintView     = NodeTint(r: 0.863, g: 0.863, b: 0.667)
    private static let tintGroup    = NodeTint(r: 0.60, g: 0.60, b: 0.60)
    private static let tintMatView  = NodeTint(r: 0.749, g: 0.824, b: 0.600)
    private static let tintIndex    = NodeTint(r: 0.400, g: 0.694, b: 0.659)
    private static let tintSequence = NodeTint(r: 0.529, g: 0.753, b: 0.518)
    private static let tintFunction = NodeTint(r: 0.694, g: 0.506, b: 0.804)
    private static let tintType     = NodeTint(r: 0.878, g: 0.647, b: 0.412)
    private static let tintColumn   = NodeTint(r: 0.545, g: 0.659, b: 0.780)
    private static let tintKey      = NodeTint(r: 0.835, g: 0.718, b: 0.392)
    private static let tintTrigger  = NodeTint(r: 0.835, g: 0.490, b: 0.392)

    // MARK: - Capability queries

    func isDataBrowsable(path: [String]) -> Bool {
        path.count == 4 && ["Tables", "Views", "Materialized Views"].contains(path[2])
    }

    func isEditable(path: [String]) -> Bool {
        path.count == 4 && path[2] == "Tables"
    }

    func isStructureEditable(path: [String]) -> Bool {
        path.count >= 5 && path[2] == "Tables"
            && ["Indexes", "Constraints", "Triggers"].contains(path[4])
    }

    // MARK: - Tree navigation

    func listChildren(path: [String]) async throws -> [HierarchyNode] {
        switch path.count {
        case 0:
            let client = try getAnyClient()
            let rows = try await client.query("SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname")
            var nodes: [HierarchyNode] = []
            for try await row in rows {
                let name = try row.decode(String.self, context: .default)
                nodes.append(HierarchyNode(name: name, icon: "cylinder.split.1x2", tint: Self.tintDatabase, isExpandable: true))
            }
            return nodes

        case 1:
            let client = try await clientFor(database: path[0])
            let sql = "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('pg_toast', 'pg_catalog', 'information_schema') ORDER BY schema_name"
            let rows = try await client.query(PostgresQuery(stringLiteral: sql))
            var nodes: [HierarchyNode] = []
            for try await row in rows {
                let name = try row.decode(String.self, context: .default)
                nodes.append(HierarchyNode(name: name, icon: "square.grid.2x2", tint: Self.tintSchema, isExpandable: true))
            }
            return nodes

        case 2:
            return [
                HierarchyNode(name: "Tables", icon: "folder", tint: Self.tintGroup, isExpandable: true),
                HierarchyNode(name: "Views", icon: "folder", tint: Self.tintGroup, isExpandable: true),
                HierarchyNode(name: "Materialized Views", icon: "folder", tint: Self.tintGroup, isExpandable: true),
                HierarchyNode(name: "Sequences", icon: "folder", tint: Self.tintGroup, isExpandable: true),
                HierarchyNode(name: "Functions", icon: "folder", tint: Self.tintGroup, isExpandable: true),
                HierarchyNode(name: "Types", icon: "folder", tint: Self.tintGroup, isExpandable: true),
            ]

        case 3:
            let client = try await clientFor(database: path[0])
            let schema = path[1]
            switch path[2] {
            case "Tables":
                return try await queryNodeList(
                    client: client,
                    sql: "SELECT table_name FROM information_schema.tables WHERE table_schema = '\(schema)' AND table_type = 'BASE TABLE' ORDER BY table_name",
                    icon: "tablecells", tint: Self.tintTable, expandable: true
                )
            case "Views":
                return try await queryNodeList(
                    client: client,
                    sql: "SELECT table_name FROM information_schema.tables WHERE table_schema = '\(schema)' AND table_type = 'VIEW' ORDER BY table_name",
                    icon: "eye", tint: Self.tintView, expandable: true
                )
            case "Materialized Views":
                return try await queryNodeList(
                    client: client,
                    sql: "SELECT matviewname FROM pg_matviews WHERE schemaname = '\(schema)' ORDER BY matviewname",
                    icon: "eye.fill", tint: Self.tintMatView, expandable: true
                )
            case "Sequences":
                return try await queryNodeList(
                    client: client,
                    sql: "SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema = '\(schema)' ORDER BY sequence_name",
                    icon: "number", tint: Self.tintSequence, expandable: false
                )
            case "Functions":
                return try await queryNodeList(
                    client: client,
                    sql: "SELECT p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = '\(schema)' AND p.prokind IN ('f', 'p') ORDER BY 1",
                    icon: "function", tint: Self.tintFunction, expandable: false
                )
            case "Types":
                return try await queryNodeList(
                    client: client,
                    sql: """
                        SELECT t.typname FROM pg_type t \
                        JOIN pg_namespace n ON t.typnamespace = n.oid \
                        WHERE n.nspname = '\(schema)' \
                        AND t.typtype IN ('e', 'c', 'd') \
                        AND NOT EXISTS ( \
                            SELECT 1 FROM pg_class c \
                            WHERE c.reltype = t.oid AND c.relkind IN ('r', 'v', 'm') \
                        ) \
                        ORDER BY t.typname
                        """,
                    icon: "textformat", tint: Self.tintType, expandable: false
                )
            default:
                throw DbError.other("unknown group: \(path[2])")
            }

        case 4:
            switch path[2] {
            case "Tables":
                return [
                    HierarchyNode(name: "Columns", icon: "folder", tint: Self.tintGroup, isExpandable: true),
                    HierarchyNode(name: "Indexes", icon: "folder", tint: Self.tintGroup, isExpandable: true),
                    HierarchyNode(name: "Constraints", icon: "folder", tint: Self.tintGroup, isExpandable: true),
                    HierarchyNode(name: "Triggers", icon: "folder", tint: Self.tintGroup, isExpandable: true),
                ]
            case "Views":
                return [
                    HierarchyNode(name: "Columns", icon: "folder", tint: Self.tintGroup, isExpandable: true),
                    HierarchyNode(name: "Triggers", icon: "folder", tint: Self.tintGroup, isExpandable: true),
                ]
            case "Materialized Views":
                return [
                    HierarchyNode(name: "Columns", icon: "folder", tint: Self.tintGroup, isExpandable: true),
                    HierarchyNode(name: "Indexes", icon: "folder", tint: Self.tintGroup, isExpandable: true),
                ]
            default:
                return []
            }

        case 5:
            let client = try await clientFor(database: path[0])
            let schema = path[1]
            let relation = path[3]
            switch path[4] {
            case "Columns":
                return try await fetchTreeColumns(client: client, schema: schema, relation: relation)
            case "Indexes":
                return try await queryNodeList(
                    client: client,
                    sql: "SELECT indexname FROM pg_indexes WHERE schemaname = '\(schema)' AND tablename = '\(relation)' ORDER BY indexname",
                    icon: "arrow.up.arrow.down", tint: Self.tintIndex, expandable: false
                )
            case "Constraints":
                return try await fetchTreeConstraints(client: client, schema: schema, relation: relation)
            case "Triggers":
                return try await queryNodeList(
                    client: client,
                    sql: "SELECT DISTINCT trigger_name FROM information_schema.triggers WHERE event_object_schema = '\(schema)' AND event_object_table = '\(relation)' ORDER BY trigger_name",
                    icon: "bolt.fill", tint: Self.tintTrigger, expandable: false
                )
            default:
                return []
            }

        default:
            return []
        }
    }

    // MARK: - Node details

    func fetchNodeDetails(path: [String]) async throws -> QueryResult {
        guard path.count >= 3 else {
            return QueryResult(columns: [], rows: [], rowsAffected: nil, totalCount: nil)
        }

        let client = try await clientFor(database: path[0])
        let schema = path[1]

        let sql: String
        switch path.count {
        case 3, 4:
            sql = groupDetailSQL(schema: schema, group: path[2])
        case 5, 6:
            sql = subGroupDetailSQL(schema: schema, relation: path[3], subGroup: path[4])
        default:
            return QueryResult(columns: [], rows: [], rowsAffected: nil, totalCount: nil)
        }

        return try await runQuery(client: client, sql: sql)
    }

    // MARK: - Private helpers

    private func queryNodeList(
        client: PostgresClient,
        sql: String,
        icon: String,
        tint: NodeTint,
        expandable: Bool
    ) async throws -> [HierarchyNode] {
        let rows = try await client.query(PostgresQuery(stringLiteral: sql))
        var nodes: [HierarchyNode] = []
        for try await row in rows {
            let name = try row.decode(String.self, context: .default)
            nodes.append(HierarchyNode(name: name, icon: icon, tint: tint, isExpandable: expandable))
        }
        return nodes
    }

    private func fetchTreeColumns(
        client: PostgresClient,
        schema: String,
        relation: String
    ) async throws -> [HierarchyNode] {
        let columns = try await fetchColumnInfo(client: client, schema: schema, table: relation)
        return columns.map { col in
            HierarchyNode(
                name: "\(col.name) : \(col.typeName)",
                icon: col.isPrimaryKey ? "key.fill" : "circle.fill",
                tint: col.isPrimaryKey ? Self.tintKey : Self.tintColumn,
                isExpandable: false
            )
        }
    }

    private func fetchTreeConstraints(
        client: PostgresClient,
        schema: String,
        relation: String
    ) async throws -> [HierarchyNode] {
        let sql = """
            SELECT conname, contype::text \
            FROM pg_constraint c \
            JOIN pg_class t ON c.conrelid = t.oid \
            JOIN pg_namespace n ON t.relnamespace = n.oid \
            WHERE n.nspname = '\(schema)' AND t.relname = '\(relation)' \
            ORDER BY conname
            """
        let rows = try await client.query(PostgresQuery(stringLiteral: sql))
        var nodes: [HierarchyNode] = []
        for try await row in rows {
            let (name, contype) = try row.decode((String, String).self, context: .default)
            let typeLabel = switch contype {
            case "p": "primary key"
            case "f": "foreign key"
            case "u": "unique"
            case "c": "check"
            case "x": "exclusion"
            default: contype
            }
            let icon = switch contype {
            case "p": "key.fill"
            case "f": "link"
            default: "checkmark.circle"
            }
            nodes.append(HierarchyNode(
                name: "\(name) (\(typeLabel))",
                icon: icon,
                tint: Self.tintKey,
                isExpandable: false
            ))
        }
        return nodes
    }

    private func groupDetailSQL(schema: String, group: String) -> String {
        switch group {
        case "Tables":
            return """
                SELECT t.tablename AS "Table", \
                pg_size_pretty(pg_total_relation_size(quote_ident(t.schemaname) || '.' || quote_ident(t.tablename))) AS "Size", \
                s.n_live_tup AS "Rows (est.)", \
                obj_description((quote_ident(t.schemaname) || '.' || quote_ident(t.tablename))::regclass) AS "Comment" \
                FROM pg_tables t \
                LEFT JOIN pg_stat_user_tables s ON t.schemaname = s.schemaname AND t.tablename = s.relname \
                WHERE t.schemaname = '\(schema)' \
                ORDER BY t.tablename
                """
        case "Views":
            return """
                SELECT v.viewname AS "View", \
                obj_description((quote_ident(v.schemaname) || '.' || quote_ident(v.viewname))::regclass) AS "Comment" \
                FROM pg_views v \
                WHERE v.schemaname = '\(schema)' \
                ORDER BY v.viewname
                """
        case "Materialized Views":
            return """
                SELECT m.matviewname AS "Materialized View", \
                pg_size_pretty(pg_total_relation_size(quote_ident(m.schemaname) || '.' || quote_ident(m.matviewname))) AS "Size", \
                obj_description((quote_ident(m.schemaname) || '.' || quote_ident(m.matviewname))::regclass) AS "Comment" \
                FROM pg_matviews m \
                WHERE m.schemaname = '\(schema)' \
                ORDER BY m.matviewname
                """
        case "Sequences":
            return """
                SELECT s.sequencename AS "Sequence", \
                s.data_type AS "Type", \
                s.start_value AS "Start", \
                s.min_value AS "Min", \
                s.max_value AS "Max", \
                s.increment_by AS "Increment" \
                FROM pg_sequences s \
                WHERE s.schemaname = '\(schema)' \
                ORDER BY s.sequencename
                """
        case "Functions":
            return """
                SELECT p.proname AS "Name", \
                pg_get_function_identity_arguments(p.oid) AS "Arguments", \
                pg_get_function_result(p.oid) AS "Returns", \
                l.lanname AS "Language", \
                CASE p.prokind WHEN 'f' THEN 'function' WHEN 'p' THEN 'procedure' END AS "Kind" \
                FROM pg_proc p \
                JOIN pg_namespace n ON p.pronamespace = n.oid \
                JOIN pg_language l ON p.prolang = l.oid \
                WHERE n.nspname = '\(schema)' AND p.prokind IN ('f', 'p') \
                ORDER BY p.proname
                """
        case "Types":
            return """
                SELECT t.typname AS "Name", \
                CASE t.typtype WHEN 'e' THEN 'enum' WHEN 'c' THEN 'composite' WHEN 'd' THEN 'domain' END AS "Kind", \
                CASE \
                    WHEN t.typtype = 'e' THEN ( \
                        SELECT string_agg(e.enumlabel, ', ' ORDER BY e.enumsortorder) \
                        FROM pg_enum e WHERE e.enumtypid = t.oid \
                    ) \
                    WHEN t.typtype = 'd' THEN pg_catalog.format_type(t.typbasetype, t.typtypmod) \
                    ELSE NULL \
                END AS "Details" \
                FROM pg_type t \
                JOIN pg_namespace n ON t.typnamespace = n.oid \
                WHERE n.nspname = '\(schema)' \
                AND t.typtype IN ('e', 'c', 'd') \
                AND NOT EXISTS ( \
                    SELECT 1 FROM pg_class c \
                    WHERE c.reltype = t.oid AND c.relkind IN ('r', 'v', 'm') \
                ) \
                ORDER BY t.typname
                """
        default:
            return "SELECT 1 AS \"Info\" WHERE false"
        }
    }

    private func subGroupDetailSQL(schema: String, relation: String, subGroup: String) -> String {
        switch subGroup {
        case "Columns":
            return """
                SELECT a.attname AS "Column", \
                pg_catalog.format_type(a.atttypid, a.atttypmod) AS "Type", \
                CASE WHEN a.attnotnull THEN 'NO' ELSE 'YES' END AS "Nullable", \
                pg_get_expr(d.adbin, d.adrelid) AS "Default", \
                COALESCE((SELECT 'YES' FROM pg_constraint pc \
                    WHERE pc.conrelid = c.oid AND pc.contype = 'p' \
                    AND a.attnum = ANY(pc.conkey)), 'NO') AS "PK" \
                FROM pg_attribute a \
                JOIN pg_class c ON a.attrelid = c.oid \
                JOIN pg_namespace n ON c.relnamespace = n.oid \
                LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum \
                WHERE n.nspname = '\(schema)' AND c.relname = '\(relation)' \
                AND a.attnum > 0 AND NOT a.attisdropped \
                ORDER BY a.attnum
                """
        case "Indexes":
            return """
                SELECT i.indexname AS "Index", \
                CASE WHEN ix.indisunique THEN 'YES' ELSE 'NO' END AS "Unique", \
                CASE WHEN ix.indisprimary THEN 'YES' ELSE 'NO' END AS "Primary", \
                am.amname AS "Method", \
                pg_get_indexdef(ix.indexrelid) AS "Definition" \
                FROM pg_indexes i \
                JOIN pg_class ci ON ci.relname = i.indexname \
                JOIN pg_namespace ni ON ci.relnamespace = ni.oid AND ni.nspname = i.schemaname \
                JOIN pg_index ix ON ix.indexrelid = ci.oid \
                JOIN pg_am am ON ci.relam = am.oid \
                WHERE i.schemaname = '\(schema)' AND i.tablename = '\(relation)' \
                ORDER BY i.indexname
                """
        case "Constraints":
            return """
                SELECT con.conname AS "Constraint", \
                CASE con.contype \
                    WHEN 'p' THEN 'PRIMARY KEY' \
                    WHEN 'f' THEN 'FOREIGN KEY' \
                    WHEN 'u' THEN 'UNIQUE' \
                    WHEN 'c' THEN 'CHECK' \
                    WHEN 'x' THEN 'EXCLUSION' \
                END AS "Type", \
                pg_get_constraintdef(con.oid) AS "Definition" \
                FROM pg_constraint con \
                JOIN pg_class t ON con.conrelid = t.oid \
                JOIN pg_namespace n ON t.relnamespace = n.oid \
                WHERE n.nspname = '\(schema)' AND t.relname = '\(relation)' \
                ORDER BY con.conname
                """
        case "Triggers":
            return """
                SELECT trigger_name AS "Trigger", \
                action_timing AS "Timing", \
                event_manipulation AS "Event", \
                action_statement AS "Action" \
                FROM information_schema.triggers \
                WHERE event_object_schema = '\(schema)' \
                AND event_object_table = '\(relation)' \
                ORDER BY trigger_name, event_manipulation
                """
        default:
            return "SELECT 1 AS \"Info\" WHERE false"
        }
    }
}
