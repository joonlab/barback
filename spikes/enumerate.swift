// Phase 0 스파이크 #2 — 메뉴바 status item 열거 검증
//
// 목표:
//   1) CGWindowListCopyWindowInfo 로 메뉴바 우측 status item 들을
//      앱 이름 / PID / X좌표 와 함께 얻을 수 있는가?
//   2) status item 들이 위치한 window layer 매직넘버는 몇인가? (하드코딩 대신 실측)
//   3) 화면녹화 권한 없이 소유자명/bounds 를 얻을 수 있는가?
//
// 빌드:  swiftc -O spikes/enumerate.swift -o /tmp/barback-enumerate
// 실행:  /tmp/barback-enumerate

import Cocoa

// 메뉴바는 화면 최상단(y ≈ 0)에 위치. 메뉴바 높이는 Tahoe 기준 ~24~40pt.
// 우선 화면 상단 근처(y < 50)에 있는 모든 on-screen 윈도우를 레이어별로 덤프한다.

let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let infoList = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
    FileHandle.standardError.write("CGWindowListCopyWindowInfo 실패\n".data(using: .utf8)!)
    exit(1)
}

struct Row {
    let layer: Int
    let owner: String
    let pid: Int
    let x: Double
    let y: Double
    let w: Double
    let h: Double
    let name: String   // window title (보통 status item 은 빈 값) — 권한 없으면 어차피 비어있음
}

var rows: [Row] = []

for info in infoList {
    guard let layer = info[kCGWindowLayer as String] as? Int else { continue }
    guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
          let x = boundsDict["X"] as? Double,
          let y = boundsDict["Y"] as? Double,
          let w = boundsDict["Width"] as? Double,
          let h = boundsDict["Height"] as? Double else { continue }

    let owner = (info[kCGWindowOwnerName as String] as? String) ?? "?"
    let pid = (info[kCGWindowOwnerPID as String] as? Int) ?? -1
    let name = (info[kCGWindowName as String] as? String) ?? ""

    // 화면 상단 영역만 (메뉴바 후보)
    if y < 50 {
        rows.append(Row(layer: layer, owner: owner, pid: pid, x: x, y: y, w: w, h: h, name: name))
    }
}

// 레이어 → x좌표 순 정렬
rows.sort { $0.layer != $1.layer ? $0.layer < $1.layer : $0.x < $1.x }

print("=== 화면 상단(y<50) on-screen 윈도우 덤프 (메뉴바 후보) ===")
print(String(format: "%-7@ %-26@ %-7@ %8@ %6@ %7@ %6@  %@",
             "layer" as NSString, "owner" as NSString, "pid" as NSString,
             "x" as NSString, "y" as NSString, "w" as NSString, "h" as NSString, "title" as NSString))
for r in rows {
    print(String(format: "%-7d %-26@ %-7d %8.0f %6.0f %7.0f %6.0f  %@",
                 r.layer, r.owner as NSString, r.pid, r.x, r.y, r.w, r.h, r.name))
}

// 레이어별 카운트 요약 (status item 레이어 매직넘버 식별용)
print("\n=== 레이어별 항목 수 ===")
var byLayer: [Int: Int] = [:]
for r in rows { byLayer[r.layer, default: 0] += 1 }
for (layer, cnt) in byLayer.sorted(by: { $0.key < $1.key }) {
    print("layer \(layer): \(cnt)개")
}

// 메뉴바 우측 extras(=status items)는 보통 가장 흔한 단일 레이어에 다수 존재.
// 화면 너비 절반보다 오른쪽(x > screenWidth/2)에 있는 것들만 추려 "추정 status items" 출력.
let screenWidth = NSScreen.main?.frame.width ?? 1440
print("\n=== 추정 status items (x > \(Int(screenWidth/2)), layer 별) ===")
let candidates = rows.filter { $0.x > screenWidth / 2 }
for r in candidates.sorted(by: { $0.x < $1.x }) {
    print(String(format: "layer %-4d  x=%-6.0f  %@  (pid %d)", r.layer, r.x, r.owner as NSString, r.pid))
}

print("\n총 \(infoList.count)개 윈도우 중 상단 후보 \(rows.count)개, status item 추정 \(candidates.count)개")
