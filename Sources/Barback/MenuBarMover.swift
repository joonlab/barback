//
//  MenuBarMover.swift
//  Barback
//
//  노치 뒤/공간 밖에 가려진 메뉴바 아이템을 ⌘-드래그(CGEvent 합성)로
//  가시영역으로 끌어내거나(reveal), 다시 좌측으로 밀어 숨긴다(hide).
//
//  Ice 의 move() 원리: 시작점을 화면 밖(20000,20000)에 두고 windowID 로 아이템을 '집어',
//  목표 좌표에 windowID(드롭 기준)로 '놓는다'. ⌘ 플래그를 켠 채 드래그.
//  ⚠️ 비공개 동작 — 향후 macOS 에서 바뀔 수 있음.
//

import Cocoa

enum MenuBarMover {
    private static let offscreen = CGPoint(x: 20_000, y: 20_000)

    /// 가려진 아이템을 dropPoint(가시영역, anchor 왼쪽)로 끌어낸다. 끌어낸 뒤의 새 프레임을 반환.
    static func reveal(itemID: CGWindowID, itemPID: pid_t, dropPoint: CGPoint,
                       dropID: CGWindowID, dropPID: pid_t) -> CGRect? {
        dragMove(itemID: itemID, itemPID: itemPID, to: dropPoint, dropID: dropID, dropPID: dropPID)
        return Bridging.windowFrame(itemID)
    }

    /// 아이템을 메뉴바 좌측 끝(노치 뒤)으로 밀어 다시 숨긴다.
    static func hide(itemID: CGWindowID, pid: pid_t) {
        dragMove(itemID: itemID, itemPID: pid, to: CGPoint(x: 2, y: 12), dropID: itemID, dropPID: pid)
    }

    /// 아이템을 rightItem 의 '왼쪽'으로 이동 (순서 재배치용).
    static func move(itemID: CGWindowID, itemPID: pid_t, toLeftOf rightID: CGWindowID, rightPID: pid_t) {
        guard let rf = Bridging.windowFrame(rightID) else { return }
        dragMove(itemID: itemID, itemPID: itemPID,
                 to: CGPoint(x: rf.minX, y: rf.midY), dropID: rightID, dropPID: rightPID)
    }

    // MARK: - 저수준 ⌘-드래그

    private static func dragMove(itemID: CGWindowID, itemPID: pid_t, to endPoint: CGPoint,
                                 dropID: CGWindowID, dropPID: pid_t) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        ClickForwarder.permitAllEvents(source)

        // 집기: 화면 밖에서 itemID 로 mouseDown
        makeMove(.leftMouseDown, at: offscreen, windowID: itemID, pid: itemPID, source: source)?
            .post(tap: .cgSessionEventTap)
        usleep(130_000)
        // 놓기: endPoint 에서 dropID 기준으로 mouseUp
        makeMove(.leftMouseUp, at: endPoint, windowID: dropID, pid: dropPID, source: source)?
            .post(tap: .cgSessionEventTap)
        usleep(180_000)
    }

    private static func makeMove(_ type: CGEventType, at loc: CGPoint, windowID: CGWindowID,
                                 pid: pid_t, source: CGEventSource) -> CGEvent? {
        guard let e = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: loc, mouseButton: .left) else {
            return nil
        }
        e.flags = .maskCommand   // ⌘ 누른 채 드래그 = 메뉴바 아이템 이동
        let wid = Int64(windowID)
        e.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        e.setIntegerValueField(.eventSourceUserData, value: 0xBA2BAC)
        e.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: wid)
        e.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: wid)
        e.setIntegerValueField(ClickForwarder.windowIDField, value: wid)
        return e
    }
}
