import SwiftUI
import AppKit

// MARK: - DataTableView (SwiftUI wrapper)
// Thin SwiftUI shell. All keyboard handling lives in CoveTableView (NSTableView subclass).

struct DataTableView: View {
    @Environment(AppState.self) private var state
    let table: TableState
    let isQueryResult: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                NativeDataTable(
                    table: table,
                    isQueryResult: isQueryResult,
                    onCellSelected: { row, col in
                        guard !isQueryResult else { return }
                        state.tableRowClicked(row: row)
                        table.selectedColumn = col
                    },
                    onCellDoubleClicked: { row, col in
                        guard !isQueryResult else { return }
                        state.tableCellDoubleClicked(row: row, col: col)
                    },
                    onInlineEdit: { row, col, value in
                        guard !isQueryResult else { return }
                        state.tableInlineEdit(row: row, col: col, value: value)
                    },
                    onSortClicked: { col in
                        guard !isQueryResult else { return }
                        state.tableSortClicked(col)
                    },
                    onDelete: {
                        guard !isQueryResult else { return }
                        state.deleteSelectedRow()
                    },
                    onCopy: { state.tableCopyCell() },
                    onRefresh: { state.refresh() },
                    onPreviewChanges: {
                        guard table.hasPendingEdits else { return }
                        CoveDialogHost.present(key: "sql-preview", title: "Review Changes", onDismiss: { @Sendable in
                            Task { @MainActor in state.showSQLPreview = false }
                        }) { SQLPreviewSheet().environment(state) }
                    },
                    onExecuteChanges: {
                        guard table.hasPendingEdits else { return }
                        CoveDialogHost.dismiss(key: "sql-preview")
                        state.commitEdits()
                    }
                )
                reviewChangesButton
            }

            if !isQueryResult {
                paginationFooter
            }
        }
        .onChange(of: state.showSQLPreview) { _, show in
            if show {
                CoveDialogHost.present(key: "sql-preview", title: "Review Changes", onDismiss: { @Sendable in
                    Task { @MainActor in state.showSQLPreview = false }
                }) {
                    SQLPreviewSheet().environment(state)
                }
            }
        }
    }

    @ViewBuilder
    private var reviewChangesButton: some View {
        if !isQueryResult && table.hasPendingEdits {
            HStack(spacing: 8) {
                Button { state.table?.discardEdits() } label: {
                    Label("Discard", systemImage: "xmark")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button { state.commitEdits() } label: {
                    Label("Execute", systemImage: "bolt.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(AppShortcuts.executeChanges)

                Button {
                    CoveDialogHost.present(key: "sql-preview", title: "Review Changes", onDismiss: { @Sendable in
                        Task { @MainActor in state.showSQLPreview = false }
                    }) {
                        SQLPreviewSheet().environment(state)
                    }
                } label: {
                    Label("Review Changes", systemImage: "eye")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(AppShortcuts.previewChanges)
            }
            .padding(16)
        }
    }

    private var paginationFooter: some View {
        HStack {
            if state.hasStructureTab {
                Picker("", selection: Binding(
                    get: { state.tableTab },
                    set: { state.tableTabChanged($0) }
                )) {
                    Text("Data").tag(TableTab.data)
                    Text("Structure").tag(TableTab.structure)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
            }

            if state.isEditableTable {
                Button { state.addRow() } label: {
                    Label("New Row", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()

            HStack(spacing: 6) {
                Button { state.tablePrevPage() } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!table.hasPrev)

                Text(table.pageInfo)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Button { state.tableNextPage() } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!table.hasNext)
            }

            Spacer()

            Picker("", selection: Binding(
                get: { table.pageSize },
                set: { state.tablePageSize($0) }
            )) {
                Text("50").tag(UInt32(50))
                Text("100").tag(UInt32(100))
                Text("500").tag(UInt32(500))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(height: 34)
        .background(CoveTheme.bgAlt)
        .overlay(alignment: .top) {
            CoveTheme.border.frame(height: 1)
        }
    }
}

// MARK: - NativeDataTable (NSViewRepresentable)

private struct NativeDataTable: NSViewRepresentable {
    let table: TableState
    let isQueryResult: Bool
    let onCellSelected: (Int, Int) -> Void
    let onCellDoubleClicked: (Int, Int) -> Void
    let onInlineEdit: (Int, Int, String) -> Void
    let onSortClicked: (Int) -> Void
    let onDelete: () -> Void
    let onCopy: () -> Void
    let onRefresh: () -> Void
    let onPreviewChanges: () -> Void
    let onExecuteChanges: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller   = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers    = true
        scrollView.borderType            = .noBorder
        scrollView.drawsBackground       = false

        let tv = CoveTableView()
        let coord = context.coordinator

        // Wire up callbacks — use weak coord to avoid retain cycles
        tv.onDelete         = { [weak coord] in coord?.parent.onDelete() }
        tv.onCellSelected   = { [weak coord] row, col in coord?.parent.onCellSelected(row, col) }
        tv.onCellDoubleClicked = { [weak coord] row, col in coord?.parent.onCellDoubleClicked(row, col) }
        tv.onCommitEdit     = { [weak coord] row, col, val in coord?.parent.onInlineEdit(row, col, val) }
        tv.canEdit          = { [weak coord] row, col in coord?.canEditCell(row: row, col: col) ?? false }
        tv.onCopy           = { [weak coord] in coord?.parent.onCopy() }
        tv.onRefresh        = { [weak coord] in coord?.parent.onRefresh() }
        tv.onPreviewChanges = { [weak coord] in coord?.parent.onPreviewChanges() }
        tv.onExecuteChanges = { [weak coord] in coord?.parent.onExecuteChanges() }

        tv.style                              = .plain
        tv.usesAlternatingRowBackgroundColors = false
        tv.backgroundColor                   = .clear
        tv.columnAutoresizingStyle            = .noColumnAutoresizing
        tv.allowsColumnResizing               = true
        tv.allowsColumnReordering             = false
        tv.rowHeight                          = 22
        tv.intercellSpacing                   = NSSize(width: 8, height: 0)
        tv.gridStyleMask                      = [.solidVerticalGridLineMask]
        tv.allowsMultipleSelection            = false
        tv.headerView                         = NSTableHeaderView()
        tv.dataSource                         = coord
        tv.delegate                           = coord

        setupColumns(tv)
        scrollView.documentView = tv
        coord.tableView = tv
        coord.lastDataGeneration = table.dataGeneration
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? CoveTableView else { return }
        let coord = context.coordinator
        coord.parent = self

        // Rebuild columns only if schema changed
        let curIds = tv.tableColumns.map { $0.identifier.rawValue }
        let newIds = table.columns.enumerated().map { "col_\($0)_\($1.name)" }
        if curIds != newIds {
            tv.tableColumns.reversed().forEach { tv.removeTableColumn($0) }
            setupColumns(tv)
            coord.lastDataGeneration = 0
        }

        guard !tv.isEditingCell else { return }

        // Only reload data when data actually changed
        let gen = table.dataGeneration
        if gen != coord.lastDataGeneration {
            tv.reloadData()
            coord.lastDataGeneration = gen
        }

        syncSortIndicator(tv)

        // Sync row selection
        if let row = table.selectedRow, row < table.rows.count {
            if tv.selectedRow != row {
                coord.suppressCallback = true
                tv.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                tv.scrollRowToVisible(row)
                coord.suppressCallback = false
            }
        } else if tv.selectedRow >= 0 {
            coord.suppressCallback = true
            tv.deselectAll(nil)
            coord.suppressCallback = false
        }

        // Move focus ring
        tv.moveFocusRing(row: table.selectedRow, col: table.selectedColumn)
    }

    private func setupColumns(_ tv: NSTableView) {
        for (i, col) in table.columns.enumerated() {
            let tc = NSTableColumn(identifier: .init("col_\(i)_\(col.name)"))
            tc.headerCell.attributedStringValue = Self.headerAttr(col.name, col.typeName)
            tc.minWidth = 60; tc.maxWidth = 600
            tc.width = table.cachedColWidths.indices.contains(i) ? table.cachedColWidths[i] : 120
            if !isQueryResult { tc.sortDescriptorPrototype = NSSortDescriptor(key: col.name, ascending: true) }
            tv.addTableColumn(tc)
        }
    }

    private func syncSortIndicator(_ tv: NSTableView) {
        tv.tableColumns.forEach { tv.setIndicatorImage(nil, in: $0) }
        guard let name = table.sortColumn,
              let col  = tv.tableColumns.first(where: { $0.sortDescriptorPrototype?.key == name })
        else { return }
        let img = table.sortDirection == .asc ? "NSAscendingSortIndicator" : "NSDescendingSortIndicator"
        tv.setIndicatorImage(NSImage(named: .init(img)), in: col)
        tv.highlightedTableColumn = col
    }

    private static func headerAttr(_ name: String, _ type: String) -> NSAttributedString {
        let s = NSMutableAttributedString(string: name,
            attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium)])
        s.append(NSAttributedString(string: " \(type)",
            attributes: [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.secondaryLabelColor]))
        return s
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: NativeDataTable
        weak var tableView: CoveTableView?
        var suppressCallback = false
        var lastDataGeneration: UInt = 0

        init(parent: NativeDataTable) { self.parent = parent }

        func canEditCell(row: Int, col: Int) -> Bool {
            !parent.isQueryResult
            && row < parent.table.rows.count
            && col < parent.table.columns.count
            && !parent.table.isDeletedRow(row)
            && parent.table.columns.contains(where: { $0.isPrimaryKey })
        }

        func numberOfRows(in tableView: NSTableView) -> Int { parent.table.rows.count }

        // Prevent NSTableView from starting its own editing (we use overlay editing)
        func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
            return false
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let tc = tableColumn,
                  let colIdx = tableView.tableColumns.firstIndex(of: tc),
                  row < parent.table.rows.count,
                  colIdx < parent.table.columns.count else { return nil }

            let id = NSUserInterfaceItemIdentifier("DataCell")
            let cell: NSTableCellView
            if let existing = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView {
                cell = existing
            } else {
                let tf = NSTextField()
                tf.isBordered = false; tf.drawsBackground = false
                tf.isEditable = false   // non-editable by default — saves memory
                tf.isSelectable = false
                tf.lineBreakMode = .byTruncatingTail
                tf.font = .systemFont(ofSize: 12)
                tf.focusRingType = .none
                tf.translatesAutoresizingMaskIntoConstraints = false
                let cv = NSTableCellView()
                cv.identifier = id; cv.textField = tf; cv.addSubview(tf)
                NSLayoutConstraint.activate([
                    tf.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 2),
                    tf.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -2),
                    tf.topAnchor.constraint(equalTo: cv.topAnchor),
                    tf.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
                ])
                cell = cv
            }

            let value = parent.table.effectiveValue(row: row, col: colIdx)
            cell.textField?.stringValue = value ?? "NULL"
            cell.textField?.textColor = parent.table.isDeletedRow(row) ? .secondaryLabelColor
                : parent.table.hasEdit(row: row, col: colIdx) ? .systemOrange
                : value == nil ? .tertiaryLabelColor : .labelColor
            return cell
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            let t = parent.table
            if t.isDeletedRow(row) {
                let rv = TintedRowView(); rv.tintColor = NSColor.systemRed.withAlphaComponent(0.08); return rv
            } else if t.hasEditInRow(row) || t.isNewRow(row) {
                let rv = TintedRowView(); rv.tintColor = NSColor.systemGreen.withAlphaComponent(0.08); return rv
            }
            return nil
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !suppressCallback,
                  let tv = notification.object as? NSTableView else { return }
            let row = tv.selectedRow
            guard row >= 0 else { return }
            let col = tv.clickedColumn >= 0 ? tv.clickedColumn : (parent.table.selectedColumn ?? 0)
            parent.onCellSelected(row, col)
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange old: [NSSortDescriptor]) {
            guard let sort = tableView.sortDescriptors.first,
                  let key = sort.key,
                  let idx = parent.table.columns.firstIndex(where: { $0.name == key }) else { return }
            parent.onSortClicked(idx)
        }
    }
}

// MARK: - CoveTableView
// NSTableView subclass that owns ALL keyboard and mouse handling.
// This is the single source of truth for navigation and editing.

private final class CoveTableView: NSTableView {
    var onDelete: (() -> Void)?
    var onCellSelected: ((Int, Int) -> Void)?
    var onCellDoubleClicked: ((Int, Int) -> Void)?
    var onCommitEdit: ((Int, Int, String) -> Void)?
    var canEdit: ((Int, Int) -> Bool)?
    var isEditingCell = false
    // Cmd shortcut callbacks
    var onCopy: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onPreviewChanges: (() -> Void)?
    var onExecuteChanges: (() -> Void)?

    // Focus ring overlay — uses layer.zPosition to stay on top (no sortSubviews needed)
    private let focusRing = FocusRingView()
    // Overlay editor — lives in the clip view, NOT inside any table cell
    private var cellEditor: CellEditorOverlay?

    override init(frame: NSRect) {
        super.init(frame: frame)
        focusRing.isHidden = true
        addSubview(focusRing)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Focus ring

    func moveFocusRing(row: Int?, col: Int?) {
        guard let row, let col,
              row >= 0, row < numberOfRows,
              col >= 0, col < tableColumns.count else {
            focusRing.isHidden = true
            return
        }
        let rowRect = rect(ofRow: row)
        let colRect = rect(ofColumn: col)
        focusRing.frame = NSRect(x: colRect.minX + 1, y: rowRect.minY + 1,
                                  width: colRect.width - 2, height: rowRect.height - 2)
        focusRing.isHidden = false
    }

    // MARK: Mouse

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let pt  = convert(event.locationInWindow, from: nil)
        let row = self.row(at: pt)
        let col = self.column(at: pt)

        if isEditingCell { commitOverlayEdit() }

        super.mouseDown(with: event)

        if event.clickCount == 2 {
            if row >= 0, col >= 0 { onCellDoubleClicked?(row, col) }
        } else {
            if row >= 0, col >= 0 {
                onCellSelected?(row, col)
                moveFocusRing(row: row, col: col)
            }
            window?.makeFirstResponder(self)
        }
    }

    // MARK: Keyboard — this is the heart of the Excel-like behavior

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let code  = event.keyCode

        switch code {
        case 126: moveSelection(dRow: -1, dCol: 0)
        case 125: moveSelection(dRow: +1, dCol: 0)
        case 123: moveSelection(dRow: 0, dCol: -1)
        case 124: moveSelection(dRow: 0, dCol: +1)
        case 36, 76: startEditingSelected()
        case 48:
            if flags == .shift { moveSelection(dRow: 0, dCol: -1) }
            else               { moveSelection(dRow: 0, dCol: +1) }
        case 53: deselectAll(nil)
        case 51 where flags == .command, 117 where flags.isEmpty: onDelete?()
        // Cmd shortcuts
        case 8  where flags == .command: onCopy?()            // Cmd+C
        case 15 where flags == .command: onRefresh?()         // Cmd+R
        case 1  where flags == .command: onPreviewChanges?()  // Cmd+S
        case 14 where flags == [.command, .shift]: onExecuteChanges?() // Cmd+Shift+E
        default: super.keyDown(with: event)
        }
    }

    private func moveSelection(dRow: Int, dCol: Int) {
        let curRow = selectedRow < 0 ? 0 : selectedRow
        let curCol = (delegate as? NativeDataTable.Coordinator)?.parent.table.selectedColumn ?? 0

        let newRow = max(0, min(numberOfRows - 1, curRow + dRow))
        let newCol = max(0, min(tableColumns.count - 1, curCol + dCol))

        selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        scrollRowToVisible(newRow)
        onCellSelected?(newRow, newCol)
        moveFocusRing(row: newRow, col: newCol)
    }

    // MARK: Overlay Editing

    private func startEditingSelected() {
        let row = selectedRow
        guard row >= 0 else { return }
        let col = (delegate as? NativeDataTable.Coordinator)?.parent.table.selectedColumn ?? 0
        guard canEdit?(row, col) == true else { return }
        guard let sv = enclosingScrollView else { return }

        let table = (delegate as? NativeDataTable.Coordinator)?.parent.table
        let currentValue = table?.effectiveValue(row: row, col: col) ?? ""

        let rowRect = rect(ofRow: row)
        let colRect = rect(ofColumn: col)
        let cellFrame = NSRect(x: colRect.minX, y: rowRect.minY,
                               width: colRect.width, height: rowRect.height)
        let editFrame = convert(cellFrame, to: sv)

        cellEditor?.removeFromSuperview()

        let editor = CellEditorOverlay(frame: editFrame)
        editor.stringValue = currentValue
        editor.font = .systemFont(ofSize: 12)
        editor.editingRow = row
        editor.editingCol = col

        editor.onCommit = { [weak self] value in
            self?.finishOverlayEdit(value: value, row: row, col: col)
        }
        editor.onCancel = { [weak self] in
            self?.cancelOverlayEdit()
        }

        sv.addSubview(editor)
        cellEditor = editor
        isEditingCell = true
        focusRing.isHidden = true

        window?.makeFirstResponder(editor)
        editor.currentEditor()?.selectAll(nil)
    }

    private func commitOverlayEdit() {
        guard let editor = cellEditor else { return }
        finishOverlayEdit(value: editor.stringValue, row: editor.editingRow, col: editor.editingCol)
    }

    private func finishOverlayEdit(value: String, row: Int, col: Int) {
        cellEditor?.removeFromSuperview()
        cellEditor = nil
        isEditingCell = false

        let coord = delegate as? NativeDataTable.Coordinator
        coord?.parent.onInlineEdit(row, col, value)

        selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)

        DispatchQueue.main.async { [weak self, weak coord] in
            guard let self else { return }
            self.reloadData(forRowIndexes: IndexSet(integer: row),
                            columnIndexes: IndexSet(integersIn: 0..<self.tableColumns.count))
            coord?.lastDataGeneration = coord?.parent.table.dataGeneration ?? 0
            self.moveFocusRing(row: row, col: col)
        }

        window?.makeFirstResponder(self)
    }

    private func cancelOverlayEdit() {
        cellEditor?.removeFromSuperview()
        cellEditor = nil
        isEditingCell = false

        let table = (delegate as? NativeDataTable.Coordinator)?.parent.table
        moveFocusRing(row: table?.selectedRow, col: table?.selectedColumn)
        window?.makeFirstResponder(self)
    }
}
// MARK: - CellEditorOverlay
// A standalone NSTextField that floats over the table cell being edited.
// It is NOT a child of any NSTableCellView, so NSTableView cannot interfere
// with its first-responder status.

private final class CellEditorOverlay: NSTextField, NSTextFieldDelegate {
    var editingRow = -1
    var editingCol = -1
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    private var committed = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        isBordered = true
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        isEditable = true
        isSelectable = true
        focusRingType = .none
        lineBreakMode = .byTruncatingTail
        wantsLayer = true
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.borderWidth = 2
        layer?.cornerRadius = 2
        delegate = self
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            guard !committed else { return true }
            committed = true
            onCommit?(stringValue)
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            guard !committed else { return true }
            committed = true
            onCancel?()
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard !committed else { return }
        committed = true
        onCommit?(stringValue)
    }
}

// MARK: - FocusRingView

private final class FocusRingView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.borderColor  = NSColor.controlAccentColor.cgColor
        layer?.borderWidth  = 1.5
        layer?.cornerRadius = 2
        layer?.zPosition    = 100
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil } // clicks pass through
}

// MARK: - TintedRowView

private final class TintedRowView: NSTableRowView {
    var tintColor: NSColor?
    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        if let tint = tintColor { tint.setFill(); dirtyRect.fill() }
    }
}
