//
//  ReorderApplier.swift
//  Barback
//
//  설정창의 목표 순서(좌→우)를 실제 메뉴바에 적용한다.
//
//  핵심: 라이브 좌표에 의존한 "전부 다시 정렬"은 이동마다 reflow 가 연쇄되어
//  거의 모든 아이템을 움직이고(느림) Barback/이웃까지 휩쓴다.
//  → 현재순서와 목표순서의 **LCS(공통 부분수열)** 를 구해, 그 안에 든 아이템은
//  '제자리'로 두고 **실제로 바뀐 아이템만 최소 이동**한다. (하나만 옮기면 이동 1번)
//

import CoreGraphics

enum ReorderApplier {
    /// desired: 원하는 좌→우 순서의 (windowID, pid).
    static func apply(_ desired: [(id: CGWindowID, pid: pid_t)]) {
        guard desired.count >= 2 else { return }

        // 현재 메뉴바 순서 = desired 아이템들을 라이브 x 로 정렬.
        let withX: [(item: (id: CGWindowID, pid: pid_t), x: CGFloat)] = desired.compactMap {
            guard let f = Bridging.windowFrame($0.id) else { return nil }
            return (item: $0, x: f.minX)
        }
        let current = withX.sorted { $0.x < $1.x }.map { $0.item.id }
        let desiredIDs = desired.map { $0.id }
        let stay = lcsSet(current, desiredIDs)   // 안 움직여도 되는 아이템

        // 바뀐 아이템만, 오른쪽→왼쪽으로 '목표상 오른쪽 이웃의 왼쪽'에 배치.
        // (오른쪽부터 처리하면 그 이웃은 이미 제자리)
        var i = desired.count - 2
        while i >= 0 {
            let item = desired[i]
            if !stay.contains(item.id) {
                let right = desired[i + 1]
                MenuBarMover.move(itemID: item.id, itemPID: item.pid, toLeftOf: right.id, rightPID: right.pid)
                usleep(140_000)
            }
            i -= 1
        }
    }

    /// 두 순열의 LCS 에 포함되는 windowID 집합 (= 이동 불필요한 아이템).
    private static func lcsSet(_ a: [CGWindowID], _ b: [CGWindowID]) -> Set<CGWindowID> {
        let n = a.count, m = b.count
        guard n > 0, m > 0 else { return [] }
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                dp[i][j] = a[i] == b[j] ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1])
            }
        }
        var i = 0, j = 0
        var stay = Set<CGWindowID>()
        while i < n, j < m {
            if a[i] == b[j] { stay.insert(a[i]); i += 1; j += 1 }
            else if dp[i + 1][j] >= dp[i][j + 1] { i += 1 } else { j += 1 }
        }
        return stay
    }
}
