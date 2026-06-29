//
//  ClickForwarder.swift
//  Barback
//
//  메뉴바 아이템 위치로 CGEvent 클릭을 합성해 진짜 메뉴를 연다.
//  검증된 레시피: windowID(0x33) + 타깃 pid + 커서 워프 + .cghidEventTap
//

import Cocoa

enum ClickForwarder {
    static let windowIDField = CGEventField(rawValue: 0x33)!

    /// 보이는 아이템 직접 클릭.
    static func click(_ item: MenuBarItem) {
        clickAt(point: CGPoint(x: item.frame.midX, y: item.frame.midY),
                windowID: item.windowID, pid: item.ownerPID)
    }

    /// 좌표/윈도우/pid 를 명시해 클릭 (끌어낸 직후 새 위치 클릭에 사용).
    static func clickAt(point: CGPoint, windowID: CGWindowID, pid: pid_t) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        permitAllEvents(source)

        CGWarpMouseCursorPosition(point)
        usleep(80_000)

        makeClick(.leftMouseDown, at: point, windowID: windowID, pid: pid, source: source)?.post(tap: .cghidEventTap)
        usleep(50_000)
        makeClick(.leftMouseUp, at: point, windowID: windowID, pid: pid, source: source)?.post(tap: .cghidEventTap)
    }

    private static func makeClick(_ type: CGEventType, at loc: CGPoint, windowID: CGWindowID,
                                  pid: pid_t, source: CGEventSource) -> CGEvent? {
        guard let e = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: loc, mouseButton: .left) else {
            return nil
        }
        let wid = Int64(windowID)
        e.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        e.setIntegerValueField(.eventSourceUserData, value: 0xBA2BAC)
        e.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: wid)
        e.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: wid)
        e.setIntegerValueField(windowIDField, value: wid)
        e.setIntegerValueField(.mouseEventClickState, value: 1)
        return e
    }

    static func permitAllEvents(_ source: CGEventSource) {
        let permit: CGEventFilterMask = [.permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents]
        source.setLocalEventsFilterDuringSuppressionState(permit, state: .eventSuppressionStateSuppressionInterval)
        source.setLocalEventsFilterDuringSuppressionState(permit, state: .eventSuppressionStateRemoteMouseDrag)
    }
}
