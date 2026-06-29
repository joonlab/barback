// Phase 0 스파이크 — CGEvent 클릭 전달 검증 (프로젝트 사활 핵심)
//
// 목표: 메뉴바 status item 에 CGEvent 합성 클릭을 보내 그 아이템의 메뉴가 열리는가?
//       Ice 의 click() + menuBarItemEvent() 를 충실히 복제. windowID(0x33) 필드 포함.
//
// 사용:
//   리스트:  /tmp/barback-clicktest
//   클릭:    /tmp/barback-clicktest <index>
//
// 빌드: swiftc -O spikes/clicktest.swift -o /tmp/barback-clicktest

import Cocoa

struct Item {
    let windowID: CGWindowID
    let pid: pid_t
    let frame: CGRect
    let name: String
}

func menuBarItems() -> [Item] {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return [] }
    var out: [Item] = []
    for i in list {
        guard (i[kCGWindowLayer as String] as? Int) == 25 else { continue }
        guard let num = i[kCGWindowNumber as String] as? Int,
              let pid = i[kCGWindowOwnerPID as String] as? Int,
              let b = i[kCGWindowBounds as String] as? [String: Any],
              let x = b["X"] as? Double, let y = b["Y"] as? Double,
              let w = b["Width"] as? Double, let h = b["Height"] as? Double else { continue }
        let name = (i[kCGWindowName as String] as? String) ?? ""
        out.append(Item(windowID: CGWindowID(num), pid: pid_t(pid),
                        frame: CGRect(x: x, y: y, width: w, height: h), name: name))
    }
    return out.sorted { $0.frame.minX < $1.frame.minX }
}

// Ice 의 CGEvent.menuBarItemEvent() 충실 복제
let kWindowID = CGEventField(rawValue: 0x33)!

func makeEvent(_ type: CGEventType, _ button: CGMouseButton, at loc: CGPoint,
               windowID: CGWindowID, pid: pid_t, source: CGEventSource, click: Bool) -> CGEvent? {
    guard let e = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: loc, mouseButton: button) else { return nil }
    let wid = Int64(windowID)
    e.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
    e.setIntegerValueField(.eventSourceUserData, value: 0x1CE)
    e.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: wid)
    e.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: wid)
    e.setIntegerValueField(kWindowID, value: wid)
    if click { e.setIntegerValueField(.mouseEventClickState, value: 1) }
    return e
}

func realPID(forBundleID bundleID: String, fallback: pid_t) -> pid_t {
    if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
        return app.processIdentifier
    }
    return fallback
}

func clickItem(_ item: Item) {
    guard let source = CGEventSource(stateID: .hidSystemState) else { print("source 실패"); return }
    let pt = CGPoint(x: item.frame.midX, y: item.frame.midY)
    // Tahoe: CGWindowList 가 보고하는 pid 는 Control Center. 실제 앱 pid 를 번들ID로 조회해 타깃팅.
    let targetPID = realPID(forBundleID: item.name, fallback: item.pid)
    print("클릭 시도 → '\(item.name)' windowID=\(item.windowID) CCpid=\(item.pid) 실제pid=\(targetPID) at (\(Int(pt.x)),\(Int(pt.y)))")

    // 이벤트 억제 방지 (모든 로컬 이벤트 허용)
    let permitAll: CGEventFilterMask = [.permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents]
    source.setLocalEventsFilterDuringSuppressionState(permitAll, state: .eventSuppressionStateSuppressionInterval)
    source.setLocalEventsFilterDuringSuppressionState(permitAll, state: .eventSuppressionStateRemoteMouseDrag)

    let savedCursor = CGEvent(source: nil)?.location ?? .zero

    // 탭 선택: 환경변수 TAP=hid|session (기본 hid)
    let useHid = (ProcessInfo.processInfo.environment["TAP"] ?? "hid") != "session"
    let tap: CGEventTapLocation = useHid ? .cghidEventTap : .cgSessionEventTap
    // 커서를 실제로 아이템 위로 이동 (WARP=0 이면 생략)
    let doWarp = (ProcessInfo.processInfo.environment["WARP"] ?? "1") == "1"
    if doWarp { CGWarpMouseCursorPosition(pt); usleep(60_000) }
    print("  tap=\(useHid ? "hid" : "session") warp=\(doWarp)")

    guard let down = makeEvent(.leftMouseDown, .left, at: pt, windowID: item.windowID, pid: targetPID, source: source, click: true),
          let up = makeEvent(.leftMouseUp, .left, at: pt, windowID: item.windowID, pid: targetPID, source: source, click: true) else {
        print("이벤트 생성 실패"); return
    }
    down.post(tap: tap)
    usleep(40_000)
    up.post(tap: tap)
    print("이벤트 post 완료. (대상 아이템의 메뉴가 열렸는지 확인)")
    _ = savedCursor   // 커서는 일단 그대로 둠(메뉴 유지 확인용)
}

let args = CommandLine.arguments
let items = menuBarItems()
if args.count < 2 {
    print("=== 메뉴바 아이템 목록 (index: name @x) ===")
    for (idx, it) in items.enumerated() {
        print(String(format: "%2d: %@  @x=%.0f y=%.0f  (pid %d, win %d)",
                     idx, it.name.isEmpty ? "(이름없음)" : it.name as String,
                     it.frame.minX, it.frame.minY, it.pid, it.windowID))
    }
    print("\n사용: /tmp/barback-clicktest <index>  → 해당 아이템에 클릭 전달")
} else if let idx = Int(args[1]), idx >= 0, idx < items.count {
    clickItem(items[idx])
} else {
    print("잘못된 index")
}
