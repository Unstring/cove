import XCTest
@testable import Cove

final class SQLHighlighterTests: XCTestCase {

    private let keywords: Set<String> = ["SELECT", "FROM", "WHERE", "INSERT", "INTO", "UPDATE", "DELETE", "SET"]

    func testKeywordsDetected() {
        let tokens = SQLHighlighter.tokenize("SELECT FROM WHERE", keywords: keywords)
        let keywordTokens = tokens.filter { $0.kind == .keyword }
        XCTAssertEqual(keywordTokens.count, 3)
    }

    func testStringLiteral() {
        let tokens = SQLHighlighter.tokenize("'hello'", keywords: keywords)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .string)
    }

    func testNumberLiteral() {
        let tokens = SQLHighlighter.tokenize("42", keywords: keywords)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .number)
    }

    func testDecimalNumber() {
        let tokens = SQLHighlighter.tokenize("3.14", keywords: keywords)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .number)
    }

    func testLineComment() {
        let tokens = SQLHighlighter.tokenize("-- this is a comment", keywords: keywords)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .comment)
    }

    func testBlockComment() {
        let tokens = SQLHighlighter.tokenize("/* block */", keywords: keywords)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .comment)
    }

    func testMixedStatement() {
        let sql = "SELECT name FROM users WHERE id = 42"
        let tokens = SQLHighlighter.tokenize(sql, keywords: keywords)

        let kinds = tokens.map { $0.kind }
        XCTAssertEqual(kinds, [.keyword, .normal, .keyword, .normal, .keyword, .normal, .number])
    }

    func testEmptyString() {
        let tokens = SQLHighlighter.tokenize("", keywords: keywords)
        XCTAssertTrue(tokens.isEmpty)
    }

    func testCaseInsensitiveKeywords() {
        let tokens = SQLHighlighter.tokenize("select from", keywords: keywords)
        let keywordTokens = tokens.filter { $0.kind == .keyword }
        XCTAssertEqual(keywordTokens.count, 2)
    }

    func testNormalIdentifier() {
        let tokens = SQLHighlighter.tokenize("mytable", keywords: keywords)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .normal)
    }

    func testCommentAfterKeyword() {
        let tokens = SQLHighlighter.tokenize("SELECT -- columns", keywords: keywords)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].kind, .keyword)
        XCTAssertEqual(tokens[1].kind, .comment)
    }

    func testStringWithSpaces() {
        let tokens = SQLHighlighter.tokenize("'hello world'", keywords: keywords)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .string)
    }
}
