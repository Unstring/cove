import XCTest
@testable import Cove

final class TableStateTests: XCTestCase {

    private func makeState(rows: Int = 5, cols: Int = 3) -> TableState {
        let columns = (0..<cols).map { ColumnInfo(name: "col\($0)", typeName: "text", isPrimaryKey: $0 == 0) }
        let rowData = (0..<rows).map { row in
            (0..<cols).map { col -> String? in "r\(row)c\(col)" }
        }
        let result = QueryResult(columns: columns, rows: rowData, rowsAffected: nil, totalCount: UInt64(rows))
        return TableState(tablePath: ["db", "public", "Tables", "test"], result: result)
    }

    // MARK: - addNewRow

    func testAddNewRow() {
        let state = makeState()
        let initialCount = state.rows.count
        let idx = state.addNewRow()

        XCTAssertEqual(idx, initialCount)
        XCTAssertEqual(state.rows.count, initialCount + 1)
        XCTAssertTrue(state.isNewRow(idx))
        // New row should have nil values
        XCTAssertTrue(state.rows[idx].allSatisfy { $0 == nil })
    }

    // MARK: - toggleDelete

    func testToggleDelete() {
        let state = makeState()
        XCTAssertFalse(state.isDeletedRow(2))

        state.toggleDelete(2)
        XCTAssertTrue(state.isDeletedRow(2))

        state.toggleDelete(2)
        XCTAssertFalse(state.isDeletedRow(2))
    }

    // MARK: - effectiveValue

    func testEffectiveValueReturnsOriginal() {
        let state = makeState()
        XCTAssertEqual(state.effectiveValue(row: 0, col: 0), "r0c0")
    }

    func testEffectiveValueReturnsEditedValue() {
        let state = makeState()
        state.pendingEdits.append(PendingEdit(row: 0, col: 0, newValue: "edited"))
        XCTAssertEqual(state.effectiveValue(row: 0, col: 0), "edited")
    }

    func testEffectiveValueReturnsLatestEdit() {
        let state = makeState()
        state.pendingEdits.append(PendingEdit(row: 0, col: 0, newValue: "first"))
        state.pendingEdits.append(PendingEdit(row: 0, col: 0, newValue: "second"))
        XCTAssertEqual(state.effectiveValue(row: 0, col: 0), "second")
    }

    func testEffectiveValueNilEdit() {
        let state = makeState()
        state.pendingEdits.append(PendingEdit(row: 0, col: 0, newValue: nil))
        XCTAssertNil(state.effectiveValue(row: 0, col: 0))
    }

    // MARK: - discardEdits

    func testDiscardEdits() {
        let state = makeState()
        let idx = state.addNewRow()
        state.pendingEdits.append(PendingEdit(row: 0, col: 0, newValue: "edited"))
        state.toggleDelete(1)

        state.discardEdits()

        XCTAssertTrue(state.pendingEdits.isEmpty)
        XCTAssertTrue(state.pendingNewRows.isEmpty)
        XCTAssertTrue(state.pendingDeletes.isEmpty)
        XCTAssertNil(state.selectedRow)
        XCTAssertNil(state.selectedColumn)
        // New row should have been removed
        XCTAssertEqual(state.rows.count, 5)
    }

    // MARK: - hasEdit

    func testHasEdit() {
        let state = makeState()
        XCTAssertFalse(state.hasEdit(row: 0, col: 0))
        state.pendingEdits.append(PendingEdit(row: 0, col: 0, newValue: "x"))
        XCTAssertTrue(state.hasEdit(row: 0, col: 0))
        XCTAssertFalse(state.hasEdit(row: 0, col: 1))
    }

    // MARK: - Pagination

    func testPageInfo() {
        let state = makeState()
        state.pageSize = 50
        state.offset = 0
        let info = state.pageInfo
        XCTAssertTrue(info.contains("Rows 1-"))
        XCTAssertTrue(info.contains("Page 1/"))
    }

    func testHasPrev() {
        let state = makeState()
        state.offset = 0
        XCTAssertFalse(state.hasPrev)
        state.offset = 50
        XCTAssertTrue(state.hasPrev)
    }


    func testSortIndicator() {
        let state = makeState()
        XCTAssertEqual(state.sortIndicator(for: "col0"), "")

        state.sortColumn = "col0"
        state.sortDirection = .asc
        XCTAssertEqual(state.sortIndicator(for: "col0"), "\u{2191}")

        state.sortDirection = .desc
        XCTAssertEqual(state.sortIndicator(for: "col0"), "\u{2193}")

        XCTAssertEqual(state.sortIndicator(for: "col1"), "")
    }
}
