//
//  MenuBarController.swift
//  Barback
//
//  Barback 메인 컨트롤러.
//  메뉴바에 항상 보이는 Barback 아이콘을 두고, 클릭하면 '가려진 것 포함 모든 메뉴바 아이콘'을
//  캡처해 패널로 보여준다. 패널에서 아이콘을 클릭하면:
//    - 보이는 아이템: 그 자리에서 바로 클릭 → 메뉴 열림
//    - 가려진 아이템: 가시영역으로 끌어낸 뒤 클릭 → 메뉴 열림 (다음 패널 열 때 원위치)
//

import Cocoa

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let panel = RevealPanel()
    private let settings = SettingsWindowController()
    private var panelVisible = false

    /// 끌어내서 임시로 보이게 한 아이템들 (다음 패널 열 때 다시 숨김).
    private var revealedItems: [(CGWindowID, pid_t)] = []

    private static let iconAutosave = "BarbackIcon"

    /// Barback 자기 아이콘의 화면 x좌표 (스캔/재배치에서 위치로 제외하기 위함).
    /// (windowNumber 는 CGWindowID 와 안 맞아 위치 매칭이 신뢰성 높음)
    private var ownMinX: CGFloat? {
        statusItem.button?.window?.frame.minX
    }

    init() {
        if StatusItemDefaults.preferredPosition(Self.iconAutosave) == nil {
            StatusItemDefaults.setPreferredPosition(0, Self.iconAutosave)
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = Self.iconAutosave
        configure()
    }

    private func configure() {
        guard let button = statusItem.button else { return }
        let img = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Barback")
        img?.isTemplate = true
        button.image = img
        button.target = self
        button.action = #selector(iconClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Barback — 클릭: 가려진 메뉴바 아이콘 펼치기"
    }

    @objc private func iconClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false) {
            showMenu()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        if panelVisible {
            panel.dismiss()
            panelVisible = false
            return
        }
        panelVisible = true
        let toHide = revealedItems
        revealedItems.removeAll()

        let exclude = ownMinX
        Task { @MainActor in
            let items = await MenuBarScanner.revertAndScan(toHide, excludingNearX: exclude)
            guard self.panelVisible else { return }   // 그새 닫혔으면 무시
            self.panel.present(items: items, anchorButton: self.statusItem.button) { [weak self] picked in
                self?.handlePick(picked, allItems: items)
            }
        }
    }

    private func handlePick(_ item: MenuBarItem, allItems: [MenuBarItem]) {
        panelVisible = false

        let itemID = item.windowID
        let itemPID = item.ownerPID
        let itemFrame = item.frame

        if !item.isHidden {
            // 보이는 아이템: 직접 클릭
            DispatchQueue.global(qos: .userInitiated).async {
                ClickForwarder.clickAt(point: CGPoint(x: itemFrame.midX, y: itemFrame.midY),
                                       windowID: itemID, pid: itemPID)
            }
            return
        }

        // 가려진 아이템: 명확히 보이는 오른쪽 영역(rightmost 보이는 아이템 왼쪽)으로 끌어낸 뒤 클릭.
        // (leftmost 는 노치/카메라 근처라 거기로 숨는 것처럼 보임)
        guard let anchor = allItems.last(where: { !$0.isHidden }) else {
            DispatchQueue.global(qos: .userInitiated).async {
                ClickForwarder.clickAt(point: CGPoint(x: itemFrame.midX, y: itemFrame.midY),
                                       windowID: itemID, pid: itemPID)
            }
            return
        }
        let dropPoint = CGPoint(x: anchor.frame.minX, y: anchor.frame.midY)
        let anchorID = anchor.windowID
        let anchorPID = anchor.ownerPID

        DispatchQueue.global(qos: .userInitiated).async {
            let newFrame = MenuBarMover.reveal(itemID: itemID, itemPID: itemPID, dropPoint: dropPoint,
                                               dropID: anchorID, dropPID: anchorPID)
            let pt = newFrame.map { CGPoint(x: $0.midX, y: $0.midY) }
                ?? CGPoint(x: itemFrame.midX, y: itemFrame.midY)
            ClickForwarder.clickAt(point: pt, windowID: itemID, pid: itemPID)
            DispatchQueue.main.async { [weak self] in
                self?.revealedItems.append((itemID, itemPID))
            }
        }
    }

    // MARK: - 우클릭 메뉴

    private func showMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: "Barback", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
        menu.addItem(withTitle: "패널 열기", action: #selector(openPanel), keyEquivalent: "").target = self
        menu.addItem(withTitle: "아이콘 순서 설정…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "가려진 아이콘 원위치", action: #selector(revertAll), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Barback 종료", action: #selector(quit), keyEquivalent: "q").target = self

        let origin = NSPoint(x: 0, y: button.bounds.height + 4)
        menu.popUp(positioning: nil, at: origin, in: button)
    }

    @objc private func openPanel() { if !panelVisible { togglePanel() } }

    @objc private func openSettings() {
        settings.excludeNearX = ownMinX
        settings.show()
    }

    @objc private func revertAll() {
        let toHide = revealedItems
        revealedItems.removeAll()
        guard !toHide.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            for (id, pid) in toHide { MenuBarMover.hide(itemID: id, pid: pid) }
        }
    }

    @objc private func quit() {
        revertAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
    }
}
