//
//  RevealPanel.swift
//  Barback
//
//  메뉴바 아래에 떠서 '안 보이는/모든' 메뉴바 아이콘들을 모아 보여주는 패널.
//  아이콘 클릭 → onPick(item) 으로 전달 → ClickForwarder 가 진짜 메뉴를 연다.
//

import Cocoa

@MainActor
final class RevealPanel: NSPanel {
    private var onPick: ((MenuBarItem) -> Void)?
    private var outsideClickMonitor: Any?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 44),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .mainMenu + 1
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    /// 패널을 채우고 메뉴바 아래에 띄운다.
    func present(items: [MenuBarItem], anchorButton: NSStatusBarButton?, onPick: @escaping (MenuBarItem) -> Void) {
        self.onPick = onPick
        let content = buildContent(items: items)
        let size = content.frame.size
        setContentSize(size)
        contentView = content
        setContentSize(size)   // contentView 할당 후 재확정
        positionBelowMenuBar(anchorButton: anchorButton)
        orderFrontRegardless()
        installOutsideClickMonitor()
    }

    func dismiss() {
        removeOutsideClickMonitor()
        orderOut(nil)
    }

    // MARK: - 콘텐츠 구성

    private func buildContent(items: [MenuBarItem]) -> NSView {
        let padding: CGFloat = 12
        let itemSize: CGFloat = 38      // 셀(버튼) 한 변
        let spacing: CGFloat = 6
        let maxColumns = 9              // 한 줄 최대 아이콘 수 → 넘으면 줄바꿈(격자)

        let columns = max(1, min(max(items.count, 1), maxColumns))
        let rowCount = items.isEmpty ? 1 : Int(ceil(Double(items.count) / Double(columns)))
        let width = padding * 2 + CGFloat(columns) * itemSize + CGFloat(columns - 1) * spacing
        let height = padding * 2 + CGFloat(rowCount) * itemSize + CGFloat(max(0, rowCount - 1)) * spacing

        // 불투명 어두운 배경 (반투명 비침/메뉴바 ghosting 방지).
        let background = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.98).cgColor
        background.layer?.cornerRadius = 14
        background.layer?.masksToBounds = true
        background.layer?.borderWidth = 0.5
        background.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.12).cgColor
        background.autoresizingMask = []

        if items.isEmpty {
            let label = NSTextField(labelWithString: "가려진 메뉴바 아이콘이 없습니다")
            label.textColor = .secondaryLabelColor
            label.sizeToFit()
            label.frame.origin = NSPoint(x: padding, y: (height - label.frame.height) / 2)
            background.addSubview(label)
        } else {
            // 명시적 프레임으로 격자 배치 (AutoLayout 이중 렌더링/멀티디스플레이 스케일 이슈 회피).
            for (i, item) in items.enumerated() {
                let col = i % columns
                let row = i / columns
                let x = padding + CGFloat(col) * (itemSize + spacing)
                let yTop = padding + CGFloat(row) * (itemSize + spacing)
                let y = height - yTop - itemSize    // NSView 는 bottom-left origin
                let btn = makeButton(for: item, size: itemSize)
                btn.frame = NSRect(x: x, y: y, width: itemSize, height: itemSize)
                background.addSubview(btn)
            }
        }

        return background
    }

    private func makeButton(for item: MenuBarItem, size: CGFloat) -> NSButton {
        let button = HoverButton()
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imageScaling = .scaleProportionallyDown
        if let image = item.image {
            button.image = image
        } else {
            // 캡처 실패 시 placeholder (어두운 배경에 밝게)
            let ph = NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil)
            ph?.isTemplate = true
            button.image = ph
            button.contentTintColor = .white
        }
        button.toolTip = item.displayName.isEmpty
            ? (item.isHidden ? "가려진 아이콘" : "메뉴바 아이콘")
            : item.displayName
        button.target = self
        button.action = #selector(pick(_:))
        button.itemRef = item
        return button
    }

    @objc private func pick(_ sender: HoverButton) {
        guard let item = sender.itemRef else { return }
        dismiss()
        onPick?(item)
    }

    // MARK: - 위치

    private func positionBelowMenuBar(anchorButton: NSStatusBarButton?) {
        let screen = anchorButton?.window?.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let menuBarHeight = screen.frame.height - (screen.visibleFrame.height + (screen.frame.height - screen.visibleFrame.maxY))
        let topInset = screen.frame.maxY - screen.visibleFrame.maxY // 메뉴바 두께 근사
        let gap: CGFloat = 4

        var originX: CGFloat
        if let aw = anchorButton?.window {
            // 앵커(Barback 아이콘) 오른쪽 끝에 패널 오른쪽을 정렬
            originX = aw.frame.maxX - frame.width
        } else {
            originX = screen.visibleFrame.maxX - frame.width - 8
        }
        originX = max(screen.visibleFrame.minX + 8, min(originX, screen.visibleFrame.maxX - frame.width - 8))

        let originY = screen.frame.maxY - topInset - gap - frame.height
        _ = menuBarHeight
        setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    // MARK: - 바깥 클릭으로 닫기

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
    }

    private func removeOutsideClickMonitor() {
        if let m = outsideClickMonitor {
            NSEvent.removeMonitor(m)
            outsideClickMonitor = nil
        }
    }

    override var canBecomeKey: Bool { true }
}

// MARK: - HoverButton (아이템 참조 + 호버 하이라이트)

@MainActor
private final class HoverButton: NSButton {
    var itemRef: MenuBarItem?
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
        layer?.cornerRadius = 8
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.clear.cgColor
    }
}
