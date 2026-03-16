import XCTest
@testable import Cove

final class CompletionEngineTests: XCTestCase {

    private let keywords: Set<String> = ["SELECT", "FROM", "WHERE", "INSERT", "INTO", "UPDATE", "DELETE", "SET"]

    private var schema: CompletionSchema {
        CompletionSchema(
            schemas: ["public"],
            tables: [
                "public": [
                    CompletionTable(name: "users", columns: [
                        CompletionColumn(name: "id", typeName: "integer"),
                        CompletionColumn(name: "name", typeName: "text"),
                        CompletionColumn(name: "email", typeName: "text"),
                    ]),
                    CompletionTable(name: "orders", columns: [
                        CompletionColumn(name: "id", typeName: "integer"),
                        CompletionColumn(name: "user_id", typeName: "integer"),
                        CompletionColumn(name: "total", typeName: "numeric"),
                    ]),
                ]
            ],
            functions: ["count", "sum", "avg"],
            types: ["integer", "text"]
        )
    }

    func testEmptyTextReturnsEmpty() {
        let items = CompletionEngine.complete(text: "", cursor: 0, schema: schema, keywords: keywords)
        XCTAssertTrue(items.isEmpty)
    }

    func testPartialKeywordCompletes() {
        let items = CompletionEngine.complete(text: "SEL", cursor: 3, schema: schema, keywords: keywords)
        XCTAssertTrue(items.contains { $0.label == "SELECT" })
    }

    func testTableNameAfterFROM() {
        let text = "SELECT * FROM us"
        let items = CompletionEngine.complete(text: text, cursor: text.count, schema: schema, keywords: keywords)
        XCTAssertTrue(items.contains { $0.label == "users" })
    }

    func testColumnAfterDot() {
        let text = "SELECT users."
        let items = CompletionEngine.complete(text: text, cursor: text.count, schema: schema, keywords: keywords)
        let labels = items.map(\.label)
        XCTAssertTrue(labels.contains("id"))
        XCTAssertTrue(labels.contains("name"))
        XCTAssertTrue(labels.contains("email"))
    }

    func testAliasResolution() {
        let text = "SELECT u. FROM users u"
        let cursor = 9 // right after "u."
        let items = CompletionEngine.complete(text: text, cursor: cursor, schema: schema, keywords: keywords)
        let labels = items.map(\.label)
        XCTAssertTrue(labels.contains("id"))
        XCTAssertTrue(labels.contains("name"))
    }

    func testMaxResults() {
        // Create schema with many tables to trigger the 50-item limit
        var largeTables: [CompletionTable] = []
        for i in 0..<60 {
            largeTables.append(CompletionTable(name: "table_\(i)", columns: []))
        }
        let largeSchema = CompletionSchema(
            schemas: ["public"],
            tables: ["public": largeTables],
            functions: [],
            types: []
        )
        let text = "SELECT * FROM t"
        let items = CompletionEngine.complete(text: text, cursor: text.count, schema: largeSchema, keywords: keywords)
        XCTAssertLessThanOrEqual(items.count, 50)
    }

    func testIsIdentBoundary() {
        XCTAssertTrue(CompletionEngine.isIdent(0x41))  // 'A'
        XCTAssertTrue(CompletionEngine.isIdent(0x5A))  // 'Z'
        XCTAssertTrue(CompletionEngine.isIdent(0x61))  // 'a'
        XCTAssertTrue(CompletionEngine.isIdent(0x7A))  // 'z'
        XCTAssertTrue(CompletionEngine.isIdent(0x30))  // '0'
        XCTAssertTrue(CompletionEngine.isIdent(0x39))  // '9'
        XCTAssertTrue(CompletionEngine.isIdent(0x5F))  // '_'
        XCTAssertFalse(CompletionEngine.isIdent(0x20)) // space
        XCTAssertFalse(CompletionEngine.isIdent(0x2E)) // '.'
    }

    func testNoCompletionsInsideString() {
        let text = "SELECT 'SEL"
        let items = CompletionEngine.complete(text: text, cursor: text.count, schema: schema, keywords: keywords)
        XCTAssertTrue(items.isEmpty)
    }

    func testNoCompletionsInsideComment() {
        let text = "-- SEL"
        let items = CompletionEngine.complete(text: text, cursor: text.count, schema: schema, keywords: keywords)
        XCTAssertTrue(items.isEmpty)
    }

    func testSchemaQualifiedTableCompletion() {
        let text = "SELECT * FROM public."
        let items = CompletionEngine.complete(text: text, cursor: text.count, schema: schema, keywords: keywords)
        let labels = items.map(\.label)
        XCTAssertTrue(labels.contains("users"))
        XCTAssertTrue(labels.contains("orders"))
    }
}
