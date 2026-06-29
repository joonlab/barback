# Barback

macOS 메뉴바 관리 앱 (Bartender 류). **노치/공간 부족으로 가려진 메뉴바 아이콘을 꺼내 쓰는** 게 핵심 목적.

- 메뉴바의 `▦` 아이콘 클릭 → **가려진 것 포함 모든 status item**을 캡처해 **팝업 패널(격자)** 로 표시
- 패널의 아이콘 클릭 → 그 아이템의 **진짜 메뉴/팝오버가 열림**
  - 보이는 아이템: 그 자리에서 클릭
  - 가려진(노치 뒤) 아이템: **메뉴바 가시영역으로 잠깐 끌어낸 뒤 클릭**, 다음 패널 열 때 원위치
- 우클릭 → **"아이콘 순서 설정…"**: 드래그로 메뉴바 아이콘 좌→우 순서 재배치 후 적용

## 환경 / 빌드

- Swift 6, macOS 14+ (개발·검증은 macOS 26.4 / Apple Silicon)
- 빌드 & .app 번들:
  ```bash
  bash scripts/bundle.sh release      # → Barback.app (ad-hoc 서명)
  ./Barback.app/Contents/MacOS/Barback
  ```
- **권한 필요**: 손쉬운 사용(Accessibility) — 합성 클릭/드래그 주입용. 첫 실행 시 요청 다이얼로그.
  (메뉴바 아이콘 캡처에는 화면 녹화 권한도 사용)

## 아키텍처 (Sources/Barback)

| 파일 | 역할 |
|------|------|
| `main.swift` / `AppDelegate.swift` | accessory 앱 부트스트랩, AX 권한 요청 |
| `MenuBarController.swift` | `▦` status item, 패널 토글, 클릭 라우팅(보임=직접/숨김=끌어내기) |
| `Bridging.swift` | 비공개 CGS API (`CGSGetProcessMenuBarWindowList` 등) — 숨김 포함 열거 |
| `MenuBarScanner.swift` | 열거 + 메인 디스플레이 필터(멀티모니터 중복 제거) + ScreenCaptureKit 아이콘 캡처 |
| `ClickForwarder.swift` | 검증된 클릭 전달 (windowID 0x33 + 커서 워프 + hid tap) |
| `MenuBarMover.swift` | ⌘-드래그 합성으로 아이템 이동(끌어내기/숨기기/순서) |
| `RevealPanel.swift` | 캡처 아이콘 격자 팝업(NSPanel) |
| `SettingsWindowController.swift` | 순서 재배치 설정창(드래그 리스트) |
| `ReorderApplier.swift` | 목표 순서를 ⌘-드래그 이동으로 적용 |

## macOS 26(Tahoe) 검증 메모 — 핵심 기법

> 과거(Hidden Bar/Dozer 시절) 기법이 Tahoe에서 다수 변경됨. 아래는 **이 머신에서 실측 검증**한 것.

1. **메뉴바 아이템은 Control Center가 호스팅** (모든 item의 ownerPID = Control Center). 식별 정보는
   단일 디스플레이에선 익명(`Item-0`)이라 **아이콘은 ScreenCaptureKit 캡처로** 보여줌(숨김 윈도우도 캡처됨).
2. **숨김 포함 전체 열거**: 공개 `CGWindowList(.optionOnScreenOnly)`는 노치 뒤 아이템을 놓침
   → 비공개 `CGSGetProcessMenuBarWindowList` 사용.
3. **클릭 전달**: `CGEvent` mouseDown/Up에 **비공개 field `windowID`(0x33)** + 타깃 pid + clickState,
   **커서를 아이템 위로 워프**, **`.cghidEventTap`** post. (커서 워프가 핵심)
4. **숨김 아이템 끌어내기**: ⌘ 플래그 + windowID로 "집어서"(시작점 화면 밖 20000,20000) 목표 위치에 "놓기".
5. **권한**: 합성 이벤트가 먹히려면 **서명된 .app + Accessibility 권한** 필요(터미널 자식으로 실행 시 상속).
6. **멀티 디스플레이**: 디스플레이마다 메뉴바가 떠 같은 아이템이 중복 열거됨 → **메인 디스플레이 범위로 필터**.

## 알려진 한계 / 다음 단계

- 비공개 API 의존(Tahoe 동작 기준) — macOS 업데이트 시 깨질 수 있음
- 순서 재배치: 시스템 아이콘(시계/와이파이)은 macOS가 고정 → 이동 제한
- 끌어내기 후 자동 복원은 "다음 패널 열 때" 처리(즉시 복원 아님)
- 향후: 표시/숨김 지정(섹션), 단축키, 로그인 시 실행, 디버그 로그 제거

## 라이선스 (License)

[MIT License](LICENSE) — © 2026 **JoonLab (준랩) · PARK JOON**.

자유롭게 사용·복제·수정·배포할 수 있습니다. MIT 라이선스 조건에 따라 **복제·포크·재배포 시 위 저작권 표시와 라이선스 전문을 반드시 포함**해야 합니다(= 원작자 표기 유지).

## 크레딧 / 출처 표기 (Attribution)

이 프로젝트를 **포크하거나 일부 코드를 가져다 쓰실 때는, 원작자 “JoonLab (준랩)”을 밝혀 주세요.** (MIT가 요구하는 저작권 표시 유지로 충족됩니다.) 예:

> Based on **Barback** by JoonLab (준랩) — https://github.com/joonlab/barback

### 참고 프로젝트
- macOS 26(Tahoe)의 메뉴바 조작 기법은 오픈소스 [**Ice**](https://github.com/jordanbaird/Ice)(GPLv3)를 **연구해 독립적으로 재구현**했습니다. Ice의 소스 코드를 복사하지 않았으며, 비공개 시스템 API 선언(CGS 함수 시그니처, `windowID 0x33` 등)은 OS가 정한 인터페이스(사실)입니다. 알고리즘과 구현은 본 프로젝트의 자체 코드입니다.

## 기여 (Contributing)

이슈/PR 환영합니다. 비공개 API 의존 특성상 macOS 버전 업데이트 시 동작이 바뀔 수 있으니, 버그 리포트 시 **macOS 버전 / 디스플레이 구성**을 함께 적어 주세요.
