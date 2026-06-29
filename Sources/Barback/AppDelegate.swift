//
//  AppDelegate.swift
//  Barback
//

import Cocoa
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 합성 클릭 전달에는 '손쉬운 사용(Accessibility)' 권한이 필요.
        // 권한이 없으면 시스템 설정 안내 다이얼로그를 띄운다.
        // (kAXTrustedCheckOptionPrompt 의 실제 문자열 값 == "AXTrustedCheckOptionPrompt")
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)

        menuBarController = MenuBarController()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
