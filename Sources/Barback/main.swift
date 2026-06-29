//
//  main.swift
//  Barback — macOS 메뉴바 관리 앱
//

import Cocoa

setvbuf(stdout, nil, _IONBF, 0)   // 디버그 로그 즉시 flush

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // Dock 아이콘 없음, 메뉴바 전용 (LSUIElement 상당)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
