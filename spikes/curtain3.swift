// Phase 0 스파이크 #1-v3 — Ice식 충실 재현. 커튼이 '진짜 옆 아이콘'을 숨기는지 최종 검증.
//
// Ice 메커니즘 핵심:
//   - 구분자 status item 에 autosaveName + preferredPosition(비공개 키) 부여
//   - 숨길 때 length = 10000 (왼쪽으로 확장되어 왼쪽 아이콘을 화면 밖으로 밀어냄)
//   - 따라서 "숨길 아이콘"은 구분자의 '왼쪽'에 있어야 함
//
// 사용 절차(사용자 직접):
//   1) 실행하면 메뉴바에 "▦" 구분자가 뜬다 (length=8, 펼침 상태).
//   2) ⌘ 누른 채로 숨기고 싶은 실제 아이콘 1~3개를 "▦"의 '왼쪽'으로 드래그한다.
//   3) "▦" 를 클릭하면 length=10000 으로 접혀 왼쪽 아이콘들이 사라져야 한다(숨김).
//   4) 다시 클릭하면 length=8 로 펼쳐져 아이콘이 돌아와야 한다(표시).
//   매 토글마다 화면 밖으로 밀려난 실제 아이콘 수/이름을 출력한다.
//
// 빌드: swiftc -O spikes/curtain3.swift -o /tmp/barback-curtain3
// 실행: /tmp/barback-curtain3   (Ctrl-C 종료)

import Cocoa

setvbuf(stdout, nil, _IONBF, 0)

let AUTOSAVE = "BarbackCurtainTestV3"

func displayUnionCG() -> CGRect {
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &ids, &count)
    var u = CGRect.null
    for id in ids { u = u.union(CGDisplayBounds(id)) }
    return u
}

struct Icon { let name: String; let x: Double; let w: Double }
func realIcons() -> [Icon] {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return [] }
    var out: [Icon] = []
    for i in list {
        guard (i[kCGWindowLayer as String] as? Int) == 25 else { continue }
        let n = (i[kCGWindowName as String] as? String) ?? ""
        guard n.contains(".") else { continue }
        guard let b = i[kCGWindowBounds as String] as? [String: Any],
              let x = b["X"] as? Double, let w = b["Width"] as? Double else { continue }
        out.append(Icon(name: n, x: x, w: w))
    }
    return out.sorted { $0.x < $1.x }
}

final class Spike3: NSObject {
    var divider: NSStatusItem!
    var collapsed = false   // false = length 8(펼침), true = length 10000(숨김)
    let thin: CGFloat = 8
    let expanded: CGFloat = 10000

    func setup() {
        // preferredPosition 을 미리 심어 구분자를 우측(0)에 배치 시도
        let key = "NSStatusItem Preferred Position \(AUTOSAVE)"
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(CGFloat(0), forKey: key)
        }
        divider = NSStatusBar.system.statusItem(withLength: thin)
        divider.autosaveName = AUTOSAVE
        divider.button?.title = "▦"
        divider.button?.target = self
        divider.button?.action = #selector(toggle)

        let u = displayUnionCG()
        print("== 커튼 v3 (Ice식) == 디스플레이 union x=\(Int(u.minX))..\(Int(u.maxX))")
        print("👉 1) ⌘-드래그로 숨길 실제 아이콘 1~3개를 '▦' 왼쪽으로 옮기세요.")
        print("👉 2) '▦' 를 클릭해 접으면(length=10000) 왼쪽 아이콘이 사라지는지 보세요.")
        print("    (3초마다 자동으로도 측정값을 찍습니다)")
        report(tag: "초기(펼침)")
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in self?.report(tag: "주기측정") }
    }

    @objc func toggle() {
        collapsed.toggle()
        divider.length = collapsed ? expanded : thin
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.report(tag: self!.collapsed ? "클릭→숨김(10000)" : "클릭→표시(8)")
        }
    }

    func report(tag: String) {
        let u = displayUnionCG()
        let icons = realIcons()
        let off = icons.filter { $0.x + $0.w <= u.minX + 1 || $0.x >= u.maxX - 1 }
        let dx = divider.button?.window?.frame.origin.x ?? .nan
        print("[\(tag)] ▦x=\(Int(dx)) len=\(Int(divider.length)) | 실제아이콘 \(icons.count) 중 화면밖 \(off.count)")
        if !off.isEmpty { print("    숨겨짐: " + off.map { $0.name }.joined(separator: ", ")) }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let s = Spike3()
s.setup()
app.run()
