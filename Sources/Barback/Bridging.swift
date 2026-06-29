//
//  Bridging.swift
//  Barback
//
//  비공개 CoreGraphics(WindowServer, CGS) API 브리지.
//  공개 CGWindowList API 는 '.optionOnScreenOnly' 로 보이는 윈도우만 주므로,
//  노치 뒤/공간 밖으로 가려진 메뉴바 아이콘을 놓친다.
//  CGSGetProcessMenuBarWindowList 는 '숨겨진 것 포함 전체' 메뉴바 윈도우를 준다.
//
//  ⚠️ 비공식 API — 향후 macOS 릴리스에서 바뀔 수 있다. (Ice 도 동일 방식 사용)
//

import CoreGraphics

private typealias CGSConnectionID = Int32

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSGetWindowCount")
private func CGSGetWindowCount(
    _ cid: CGSConnectionID, _ targetCID: CGSConnectionID, _ outCount: inout Int32
) -> CGError

@_silgen_name("CGSGetProcessMenuBarWindowList")
private func CGSGetProcessMenuBarWindowList(
    _ cid: CGSConnectionID, _ targetCID: CGSConnectionID, _ count: Int32,
    _ list: UnsafeMutablePointer<CGWindowID>, _ outCount: inout Int32
) -> CGError

@_silgen_name("CGSGetScreenRectForWindow")
private func CGSGetScreenRectForWindow(
    _ cid: CGSConnectionID, _ wid: CGWindowID, _ outRect: inout CGRect
) -> CGError

enum Bridging {
    /// 숨겨진 것 포함, 모든 메뉴바 status item 윈도우 ID.
    static func menuBarWindowIDs() -> [CGWindowID] {
        let cid = CGSMainConnectionID()
        var total: Int32 = 0
        guard CGSGetWindowCount(cid, 0, &total) == .success, total > 0 else { return [] }
        var list = [CGWindowID](repeating: 0, count: Int(total))
        var realCount: Int32 = 0
        let result = list.withUnsafeMutableBufferPointer { buf -> CGError in
            CGSGetProcessMenuBarWindowList(cid, 0, total, buf.baseAddress!, &realCount)
        }
        guard result == .success else { return [] }
        return Array(list[..<Int(realCount)])
    }

    /// 윈도우의 화면 좌표 프레임 (가려진 윈도우도 가능).
    static func windowFrame(_ windowID: CGWindowID) -> CGRect? {
        var rect = CGRect.zero
        guard CGSGetScreenRectForWindow(CGSMainConnectionID(), windowID, &rect) == .success else {
            return nil
        }
        return rect
    }
}
