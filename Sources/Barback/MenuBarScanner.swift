//
//  MenuBarScanner.swift
//  Barback
//
//  메뉴바 status item 들을 열거(가려진 것 포함)하고 각 아이콘을 캡처한다.
//  - 열거: Bridging.menuBarWindowIDs (CGS, 숨김 포함)
//  - 가시여부: CGWindowList(.optionOnScreenOnly) 와 대조
//  - 아이콘: ScreenCaptureKit (가려진 윈도우도 캡처 가능)
//

import Cocoa
import ScreenCaptureKit

enum MenuBarScanner {
    private static let statusItemLayer = 25
    private static let controlCenterFallbackPID: pid_t = 0

    /// 이전에 끌어낸 아이템들을 먼저 원위치(숨김)한 뒤 스캔. (패널 열 때 호출)
    static func revertAndScan(_ toHide: [(CGWindowID, pid_t)], excludingNearX: CGFloat? = nil) async -> [MenuBarItem] {
        for (id, pid) in toHide {
            MenuBarMover.hide(itemID: id, pid: pid)
        }
        return await scan(excludingNearX: excludingNearX)
    }

    /// 현재 메뉴바 아이템들을 좌→우 순서로 반환 (가려진 것 포함, 아이콘 캡처 포함).
    /// - Parameter excludingNearX: 이 x좌표 부근(±8pt)의 아이템 제외 (Barback 자기 아이콘).
    ///   windowNumber 는 64비트 내부값이라 CGWindowID 와 안 맞으므로 위치로 식별한다.
    static func scan(excludingNearX: CGFloat? = nil) async -> [MenuBarItem] {
        let ids = Bridging.menuBarWindowIDs()
        guard !ids.isEmpty else { return [] }

        // 메타데이터 (소유 pid / 이름 / 레이어) — 필터 없는 전체 윈도우 목록.
        let all = (CGWindowListCopyWindowInfo([], kCGNullWindowID) as? [[String: Any]]) ?? []
        var meta: [CGWindowID: (pid: pid_t, name: String, owner: String)] = [:]
        for info in all {
            guard let n = info[kCGWindowNumber as String] as? Int else { continue }
            let pid = pid_t(info[kCGWindowOwnerPID as String] as? Int ?? 0)
            let name = info[kCGWindowName as String] as? String ?? ""
            let owner = info[kCGWindowOwnerName as String] as? String ?? ""
            meta[CGWindowID(n)] = (pid, name, owner)
        }

        // 현재 화면에 보이는 status item 집합.
        let onScreen = Set(((CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? [])
            .filter { ($0[kCGWindowLayer as String] as? Int) == statusItemLayer }
            .compactMap { $0[kCGWindowNumber as String] as? Int }
            .map { CGWindowID($0) })

        // 후보 추리기: 실제 status item 만 (전폭 Menubar 윈도우/Window Server 제외).
        struct Candidate { let id: CGWindowID; let frame: CGRect; let pid: pid_t; let name: String; let hidden: Bool }
        var candidates: [Candidate] = []
        for id in ids {
            guard let f = Bridging.windowFrame(id), f.width > 5, f.width < 300, f.height < 60 else { continue }
            if let ex = excludingNearX, abs(f.minX - ex) < 8 { continue }   // Barback 자기 아이콘 제외(위치)
            let m = meta[id]
            if m?.owner == "Window Server" || m?.name == "Menubar" { continue }
            if m?.owner == "Barback" { continue }   // 이름으로도 한 번 더 방어
            let pid = m?.pid ?? controlCenterFallbackPID
            candidates.append(Candidate(id: id, frame: f, pid: pid, name: m?.name ?? "", hidden: !onScreen.contains(id)))
        }
        candidates.sort { $0.frame.minX < $1.frame.minX }

        // 멀티 디스플레이 중복 제거: macOS 는 디스플레이마다 메뉴바를 띄워 같은 아이템이
        // 디스플레이 수만큼(각각 다른 x좌표로) 잡힌다. 메뉴바가 있는 메인 디스플레이의
        // 아이템만 남겨 한 세트로 만든다. (패널도 메인 디스플레이에 뜬다)
        let mainBounds = CGDisplayBounds(CGMainDisplayID())
        candidates = candidates.filter {
            $0.frame.midX >= mainBounds.minX - 2 && $0.frame.midX <= mainBounds.maxX + 2
        }
        // 안전망: 동일 번들ID 중복도 제거
        var seenBundleID = Set<String>()
        candidates = candidates.filter { c in
            guard c.name.contains(".") else { return true }
            return seenBundleID.insert(c.name).inserted
        }

        // 아이콘 캡처 (ScreenCaptureKit, 동시).
        let images = await captureIcons(for: candidates.map { ($0.id, $0.frame) })

        let runningApps = NSWorkspace.shared.runningApplications
        return candidates.map { c in
            // 이름이 번들ID 형태면(멀티 디스플레이) 앱 이름 보강.
            let appName: String
            if c.name.contains(".") {
                appName = runningApps.first { $0.bundleIdentifier == c.name }?.localizedName ?? c.name
            } else {
                appName = ""
            }
            return MenuBarItem(
                id: c.id, frame: c.frame, ownerPID: c.pid, isHidden: c.hidden,
                image: images[c.id], displayName: appName
            )
        }
    }

    // MARK: - ScreenCaptureKit 캡처

    private static func captureIcons(for items: [(CGWindowID, CGRect)]) async -> [CGWindowID: NSImage] {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false) else {
            return [:]
        }
        let scByID = Dictionary(content.windows.map { (CGWindowID($0.windowID), $0) }, uniquingKeysWith: { a, _ in a })

        var result: [CGWindowID: NSImage] = [:]
        for (id, frame) in items {
            guard let scWin = scByID[id] else { continue }
            let cfg = SCStreamConfiguration()
            cfg.width = max(2, Int(frame.width * 2))
            cfg.height = max(2, Int(frame.height * 2))
            cfg.showsCursor = false
            let filter = SCContentFilter(desktopIndependentWindow: scWin)
            if let cg = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg) {
                result[id] = NSImage(cgImage: cg, size: NSSize(width: frame.width, height: frame.height))
            }
        }
        return result
    }
}
