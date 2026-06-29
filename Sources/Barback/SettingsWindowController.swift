//
//  SettingsWindowController.swift
//  Barback
//
//  메뉴바 아이콘 순서 재배치 설정창.
//  세로 리스트(위=왼쪽, 아래=오른쪽)를 드래그로 재정렬한 뒤 '적용'하면
//  실제 메뉴바 아이콘 순서가 ⌘-드래그 이동으로 바뀐다.
//

import Cocoa

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private var window: NSWindow?
    private var tableView: NSTableView!
    private var statusLabel: NSTextField!
    private var items: [MenuBarItem] = []
    private var busy = false

    /// Barback 자기 아이콘 화면 x좌표 (목록/재배치에서 위치로 제외).
    var excludeNearX: CGFloat?

    private static let dragType = NSPasteboard.PasteboardType("com.joonlab.barback.row")

    func show() {
        if window == nil { buildWindow() }
        reload()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - 윈도우 구성

    private func buildWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
                         styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        w.title = "Barback — 메뉴바 아이콘 순서"
        w.delegate = self
        w.isReleasedWhenClosed = false
        w.center()

        let hint = NSTextField(labelWithString: "위 = 왼쪽 · 아래 = 오른쪽\n드래그로 순서를 바꾼 뒤 '적용'을 누르세요.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.maximumNumberOfLines = 2

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let tv = NSTableView()
        tv.headerView = nil
        tv.rowHeight = 42
        tv.style = .inset
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        col.width = 360
        tv.addTableColumn(col)
        tv.dataSource = self
        tv.delegate = self
        tv.registerForDraggedTypes([Self.dragType])
        tv.draggingDestinationFeedbackStyle = .gap
        scroll.documentView = tv
        self.tableView = tv

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor

        let refreshBtn = NSButton(title: "새로고침", target: self, action: #selector(refreshTapped))
        let applyBtn = NSButton(title: "적용", target: self, action: #selector(applyTapped))
        applyBtn.keyEquivalent = "\r"
        let buttonRow = NSStackView(views: [statusLabel, NSView(), refreshBtn, applyBtn])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let stack = NSStackView(views: [hint, scroll, buttonRow])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setHuggingPriority(.defaultLow, for: .vertical)
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)

        let content = w.contentView!
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        self.window = w
    }

    // MARK: - 데이터 로드

    private func reload() {
        statusLabel.stringValue = "불러오는 중…"
        let exclude = excludeNearX
        Task { @MainActor in
            self.items = await MenuBarScanner.scan(excludingNearX: exclude)
            self.tableView.reloadData()
            self.statusLabel.stringValue = "\(self.items.count)개 아이콘"
        }
    }

    // MARK: - 버튼

    @objc private func refreshTapped() { reload() }

    @objc private func applyTapped() {
        guard !busy, items.count >= 2 else { return }
        busy = true
        statusLabel.stringValue = "적용 중…"
        let ordered = items.map { (id: $0.windowID, pid: $0.ownerPID) }
        DispatchQueue.global(qos: .userInitiated).async {
            ReorderApplier.apply(ordered)
            DispatchQueue.main.async { [weak self] in
                self?.busy = false
                self?.statusLabel.stringValue = "적용 완료"
                self?.reload()
            }
        }
    }

    // MARK: - NSTableView 데이터/뷰

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell = (tableView.makeView(withIdentifier: id, owner: self) as? RowView) ?? RowView(reuseID: id)
        cell.configure(with: items[row], index: row)
        return cell
    }

    func tableView(_ tableView: NSTableView, rowHeight row: Int) -> CGFloat { 42 }

    // MARK: - 드래그 재정렬

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: Self.dragType)
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo,
                   proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        return dropOperation == .above ? .move : []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo,
                   row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let s = info.draggingPasteboard.string(forType: Self.dragType), let from = Int(s) else { return false }
        var to = row
        let moved = items.remove(at: from)
        if from < to { to -= 1 }
        items.insert(moved, at: min(to, items.count))
        tableView.reloadData()
        statusLabel.stringValue = "순서 변경됨 — '적용'을 누르세요"
        return true
    }

    func windowWillClose(_ notification: Notification) {}
}

// MARK: - 행 뷰 (어두운 칩 + 아이콘 + 라벨)

@MainActor
private final class RowView: NSTableCellView {
    private let chip = NSView()
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let badge = NSTextField(labelWithString: "")

    init(reuseID: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        identifier = reuseID

        chip.wantsLayer = true
        chip.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        chip.layer?.cornerRadius = 6
        icon.imageScaling = .scaleProportionallyDown
        label.font = .systemFont(ofSize: 13)
        badge.font = .systemFont(ofSize: 10)
        badge.textColor = .secondaryLabelColor

        for v in [chip, icon, label, badge] { v.translatesAutoresizingMaskIntoConstraints = false; addSubview(v) }
        addSubview(icon) // icon above chip
        NSLayoutConstraint.activate([
            chip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            chip.centerYAnchor.constraint(equalTo: centerYAnchor),
            chip.widthAnchor.constraint(equalToConstant: 40),
            chip.heightAnchor.constraint(equalToConstant: 26),
            icon.centerXAnchor.constraint(equalTo: chip.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),
            label.leadingAnchor.constraint(equalTo: chip.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: MenuBarItem, index: Int) {
        icon.image = item.image
        let name = item.displayName.isEmpty ? "아이콘 #\(index + 1)" : item.displayName
        label.stringValue = name
        badge.stringValue = item.isHidden ? "가려짐" : ""
    }
}
