// Phase 0 스파이크 #1 — 커튼(curtain) 숨김 기법 검증
//
// 목표: macOS 26.4(Tahoe)에서 "폭이 매우 넓은 NSStatusItem"이
//       자기 왼쪽에 있는 status item 을 실제로 화면 밖으로 밀어/가려서 숨기는가?
//
// 구성(생성 순서상 새 항목이 더 왼쪽에 배치됨 → 왼쪽부터: marker | separator | toggle):
//   - toggleItem   : 우측, 항상 보임. "B" 라벨. 클릭하면 즉시 토글.
//   - separatorItem: 가운데. 평소 thin(8pt), 숨김모드 huge(10000pt).
//   - markerItem   : 좌측. 🔴 라벨. separator 왼쪽에 있으므로 커튼에 가려져야 할 대상.
//
// 3초마다 자동 토글하며 각 항목 버튼의 화면상 frame 을 출력한다.
// 사용자는 메뉴바에서 🔴 마커가 사라졌다(huge)/다시 나타났다(thin) 를 육안 확인.
//
// 빌드:  swiftc -O spikes/curtain.swift -o /tmp/barback-curtain
// 실행:  /tmp/barback-curtain   (Ctrl-C 로 종료)

import Cocoa

setvbuf(stdout, nil, _IONBF, 0)   // 런루프 중 print 즉시 flush (파일 리다이렉트 시 버퍼링 방지)

final class Spike: NSObject {
    let toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let separatorItem = NSStatusBar.system.statusItem(withLength: 8)
    let markerItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    var collapsed = false
    let hugeLength: CGFloat = 10000
    let thinLength: CGFloat = 8

    func setup() {
        toggleItem.button?.title = "B"
        toggleItem.button?.target = self
        toggleItem.button?.action = #selector(manualToggle)

        separatorItem.button?.title = "|"

        markerItem.button?.title = "🔴"

        print("== 셋업 완료. 4초마다 자동 토글. (Ctrl-C 종료) ==")
        printFrames(tag: "초기")

        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.autoToggle()
        }
    }

    @objc func manualToggle() { autoToggle() }

    func autoToggle() {
        collapsed.toggle()
        separatorItem.length = collapsed ? hugeLength : thinLength
        printFrames(tag: collapsed ? "숨김(huge=\(Int(hugeLength)))" : "표시(thin=\(Int(thinLength)))")
    }

    func frameStr(_ item: NSStatusItem, _ name: String) -> String {
        guard let w = item.button?.window else { return "\(name): window=nil" }
        let f = w.frame
        let visible = w.isVisible
        let onScreen = NSScreen.screens.contains { $0.frame.intersects(f) }
        return String(format: "%@ x=%.0f y=%.0f w=%.0f visible=%@ onScreen=%@",
                      name, f.origin.x, f.origin.y, f.width,
                      visible ? "Y" : "N", onScreen ? "Y" : "N")
    }

    func printFrames(tag: String) {
        print("[\(tag)]")
        print("   " + frameStr(markerItem, "🔴marker(좌)"))
        print("   " + frameStr(separatorItem, "|sep(중)"))
        print("   " + frameStr(toggleItem, "B toggle(우)"))
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let spike = Spike()
spike.setup()
app.run()
