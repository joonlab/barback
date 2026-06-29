//
//  MenuBarItem.swift
//  Barback
//
//  메뉴바 status item 한 개. 단일 노치 디스플레이에서는 앱 식별 정보가 없으므로
//  '캡처된 아이콘 이미지' 와 windowID/위치/소유 pid 로만 다룬다.
//

import Cocoa

struct MenuBarItem: Identifiable, @unchecked Sendable {
    /// 윈도우 ID — 클릭/이동 라우팅의 핵심 식별자.
    let id: CGWindowID
    /// 화면상 위치 (CG 전역 좌표, top-left origin).
    let frame: CGRect
    /// 소유 프로세스 pid (Tahoe 단일 디스플레이에서는 Control Center).
    let ownerPID: pid_t
    /// 현재 노치 뒤/공간 밖으로 가려져 있는가.
    let isHidden: Bool
    /// 캡처된 메뉴바 아이콘 이미지 (ScreenCaptureKit).
    var image: NSImage?
    /// 식별 가능 시 앱 이름 (멀티 디스플레이일 때만 신뢰 가능, 아니면 빈 문자열).
    let displayName: String

    var windowID: CGWindowID { id }
}
