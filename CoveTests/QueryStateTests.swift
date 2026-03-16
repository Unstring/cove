import XCTest
@testable import Cove

final class QueryStateTests: XCTestCase {

    func testSingleBlockReturnsFullText() {
        let state = QueryState()
        state.text = "SELECT * FROM users"
        state.selectedRange = NSRange(location: 5, length: 0)

        let range = state.runnableRange
        XCTAssertEqual(range.location, 0)
        XCTAssertEqual(range.length, state.text.count)
    }

    func testTwoBlocksCursorInFirst() {
        let state = QueryState()
        state.text = "SELECT 1\n\nSELECT 2"
        state.selectedRange = NSRange(location: 3, length: 0) // cursor in "SELECT 1"

        let sql = state.runnableSQL
        XCTAssertEqual(sql, "SELECT 1")
    }

    func testTwoBlocksCursorInSecond() {
        let state = QueryState()
        state.text = "SELECT 1\n\nSELECT 2"
        state.selectedRange = NSRange(location: 14, length: 0) // cursor in "SELECT 2"

        let sql = state.runnableSQL
        XCTAssertEqual(sql, "SELECT 2")
    }

    func testSelectionOverridesBlockDetection() {
        let state = QueryState()
        state.text = "SELECT 1\n\nSELECT 2"
        state.selectedRange = NSRange(location: 0, length: 8) // "SELECT 1" selected

        let range = state.runnableRange
        XCTAssertEqual(range, NSRange(location: 0, length: 8))
    }

    func testEmptyTextReturnsEmptyRange() {
        let state = QueryState()
        state.text = ""
        state.selectedRange = NSRange(location: 0, length: 0)

        let range = state.runnableRange
        XCTAssertEqual(range.length, 0)
    }

    func testWhitespaceTrimming() {
        let state = QueryState()
        state.text = "  SELECT 1  "
        state.selectedRange = NSRange(location: 5, length: 0)

        let sql = state.runnableSQL
        XCTAssertEqual(sql, "SELECT 1")
    }

    func testThreeBlocks() {
        let state = QueryState()
        state.text = "SELECT 1\n\nSELECT 2\n\nSELECT 3"
        state.selectedRange = NSRange(location: 14, length: 0) // cursor in "SELECT 2"

        let sql = state.runnableSQL
        XCTAssertEqual(sql, "SELECT 2")
    }

    func testCursorAtEnd() {
        let state = QueryState()
        state.text = "SELECT 1"
        state.selectedRange = NSRange(location: 8, length: 0)

        let sql = state.runnableSQL
        XCTAssertEqual(sql, "SELECT 1")
    }
}
