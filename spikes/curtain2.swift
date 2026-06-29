// Phase 0 스파이크 #1-v2 — 커튼 기법: "진짜 옆 아이콘"을 밀어내는가 (객관 측정)
//
// 구성(Hidden Bar 방식 충실 재현):
//   - curtainItem : 확장 항목. 평소 thin(8), 숨김모드 huge. 라벨 "🟦".
//   - toggleItem  : 우측 항상보임. 라벨 "▶︎". 클릭 시 토글.
//
// 매 토글마다 CGWindowList 로 layer25 '진짜 status item'(이름=번들ID 있는 것)을 열거해
//   - 전 디스플레이 union 밖(=화면에서 사라짐)으로 밀려난 개수와 이름을 출력.
//   - curtain 자신의 x/width 도 출력.
//
// 사용자 행동: 🟦 커튼의 '왼쪽'으로 ⌘-드래그해 실제 아이콘 1~2개를 옮긴 뒤 토글을 지켜보세요.
//
// 빌드: swiftc -O spikes/curtain2.swift -o /tmp/barback-curtain2
// 실행: /tmp/barback-curtain2   (Ctrl-C 종료)

import Cocoa

setvbuf(stdout, nil, _IONBF, 0)

func displayUnionBoundsCG() -> CGRect {
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &ids, &count)
    var union = CGRect.null
    for id in ids { union = union.union(CGDisplayBounds(id)) }
    return union
}

struct RealIcon { let name: String; let x: Double; let w: Double }

func realStatusIcons() -> [RealIcon] {
    let opts: CGWindowListOption = [.optionOnScreenOnly]
    guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return [] }
    var out: [RealIcon] = []
    for info in list {
        guard (info[kCGWindowLayer as String] as? Int) == 25 else { continue }
        let name = (info[kCGWindowName as String] as? String) ?? ""
        guard name.contains(".") else { continue }   // 번들ID 형태만 (우리 항목/시스템 항목 제외)
        guard let b = info[kCGWindowBounds as String] as? [String: Any],
              let x = b["X"] as? Double, let w = b["Width"] as? Double else { continue }
        out.append(RealIcon(name: name, x: x, w: w))
    }
    return out.sorted { $0.x < $1.x }
}

final class Spike2: NSObject {
    let curtainItem = NSStatusBar.system.statusItem(withLength: 8)
    let toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var collapsed = false
    let huge: CGFloat = 10000
    let thin: CGFloat = 8

    func setup() {
        curtainItem.button?.title = "🟦"
        toggleItem.button?.title = "▶︎"
        toggleItem.button?.target = self
        toggleItem.button?.action = #selector(t)

        let u = displayUnionBoundsCG()
        print("== 커튼 v2 == 디스플레이 union(CG): x=\(Int(u.minX))..\(Int(u.maxX)) w=\(Int(u.width))")
        print("👉 메뉴바에서 🟦 의 '왼쪽'으로 실제 아이콘 1~2개를 ⌘-드래그하세요. 4초마다 자동 토글.")
        report(tag: "초기")
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in self?.t() }
    }

    @objc func t() {
        collapsed.toggle()
        curtainItem.length = collapsed ? huge : thin
        // 레이아웃 반영을 약간 기다린 뒤 측정
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.report(tag: self!.collapsed ? "숨김(huge)" : "표시(thin)")
        }
    }

    func report(tag: String) {
        let u = displayUnionBoundsCG()
        let icons = realStatusIcons()
        // union 밖으로 밀려난(=실제로 화면에서 사라진) 아이콘
        let off = icons.filter { $0.x + $0.w <= u.minX + 1 || $0.x >= u.maxX - 1 }
        let curX = curtainItem.button?.window?.frame.origin.x ?? .nan
        let curW = curtainItem.length
        print("[\(tag)] curtain x=\(Int(curX)) w=\(Int(curW)) | 실제아이콘 \(icons.count)개 중 화면밖 \(off.count)개")
        if !off.isEmpty {
            print("    화면밖: " + off.map { "\($0.name)@\(Int($0.x))" }.joined(separator: ", "))
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let s = Spike2()
s.setup()
app.run()
