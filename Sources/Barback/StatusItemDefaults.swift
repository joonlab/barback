//
//  StatusItemDefaults.swift
//  Barback
//
//  NSStatusItem 은 autosaveName 별로 위치(Preferred Position)와 표시 여부(Visible)를
//  표준 UserDefaults 에 "NSStatusItem <key> <autosaveName>" 형태의 키로 저장한다.
//  이 키를 직접 읽고 써서 우리 컨트롤 항목의 가로 위치를 제어한다.
//  (이 키 규약은 macOS 의 NSStatusItem 동작에서 비롯된 것으로, 향후 릴리스에서
//   바뀔 수 있는 비공식 영역이다. 바뀌면 위치 제어만 영향받고 숨김 자체는 동작한다.)
//

import Cocoa

enum StatusItemDefaults {
    /// "Preferred Position" — status item 의 가로 위치(낮을수록 우측, 시스템 아이콘에 가까움).
    static func preferredPosition(_ autosaveName: String) -> CGFloat? {
        UserDefaults.standard.object(forKey: "NSStatusItem Preferred Position \(autosaveName)") as? CGFloat
    }

    static func setPreferredPosition(_ value: CGFloat, _ autosaveName: String) {
        UserDefaults.standard.set(value, forKey: "NSStatusItem Preferred Position \(autosaveName)")
    }
}
