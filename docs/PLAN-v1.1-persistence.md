# bhkey v1.1 — Persistence Architecture Overhaul

## 관련 문서
[[ARCHITECTURE]] [[DECISIONS]] [[SESSION-LOG]] [[CHECKLIST]]

## 배경

2026-04-14 장애: 잠시 자고 일어났더니 키 매핑이 초기화됨.

**근본 원인**: LaunchAgent plist의 `StartInterval: 5`가 launchd 최소 스로틀(10초)에 걸려 서비스가 자동 해제됨. 이후 USB re-enumeration 발생 시 per-device 매핑 소실 → 복구 불가.

**Apple TN2450**: "Key remappings are lost when the keyboard service is removed (for example when the last keyboard is disconnected)."

## 장애 체인

```
StartInterval=5 (launchd 스로틀 위반)
  → idempotency guard exit 0 (즉시 종료 반복)
    → launchd 비활성 판단 → 서비스 제거
      → USB re-enumeration (디스플레이 슬립 등)
        → per-device 매핑 소실
          → LaunchAgent 없음 → 영구 상실
```

## 현재 plist 문제점 3건

| # | 문제 | 영향 | 근거 |
|---|------|------|------|
| 1 | `StartInterval: 5` | launchd 10초 미만 스로틀, 서비스 해제 위험 | `man launchd.plist` ThrottleInterval |
| 2 | `WatchPaths: /dev` | 모든 장치 변경에 트리거 (디스크, 네트워크 등), Apple "highly discouraged" | `man launchd.plist` WatchPaths 섹션 |
| 3 | StartInterval + WatchPaths 동시 | 독립 트리거로 중복 실행, 정의되지 않은 상호작용 | launchd.info |

## 해결 방안: LaunchEvents IOKit Matching

### Before (v1.0)
```xml
<key>RunAtLoad</key><true/>
<key>WatchPaths</key>
<array><string>/dev</string></array>
<key>StartInterval</key>
<integer>5</integer>
```

### After (v1.1)
```xml
<key>RunAtLoad</key>
<true/>
<key>LaunchEvents</key>
<dict>
    <key>com.apple.iokit.matching</key>
    <dict>
        <key>com.bh.keyboard.usb</key>
        <dict>
            <key>IOProviderClass</key>
            <string>IOUSBDevice</string>
            <key>IOMatchLaunchStream</key>
            <true/>
        </dict>
    </dict>
</dict>
<key>StandardOutPath</key>
<string>/tmp/bhkey.log</string>
<key>StandardErrorPath</key>
<string>/tmp/bhkey.err</string>
```

### 왜 이 방식인가

- `LaunchEvents > com.apple.iokit.matching`: Apple 공식 하드웨어 변경 감지 API
- 커널 레벨 이벤트 → race condition 없음
- CPU/배터리 영향 제로 (이벤트 없으면 idle)
- USB 장치 연결 시 자동 트리거 (슬립 복귀 후 재연결 포함)

### Anti-Thesis 분석

| 우려 | 평가 |
|------|------|
| IOKit이 bash에서 이벤트 소비 불가 | idempotency guard가 대체. 이미 매핑됨 → exit 0 |
| Bluetooth 키보드 미감지 | IOUSBDevice는 USB만. BT는 별도 매칭 추가 필요 (Phase 1.2) |
| DarkWake 중 미트리거 | 사용자 타이핑 = full wake 필요 → full wake 시 트리거됨 |
| macOS 버전별 IOKit 지원 | IOKit matching은 10.6+, LaunchEvents는 10.7+ 지원 |

## 구현 계획

### Phase 1.1: 즉시 안정화 (이번 세션)

1. **plist 구조 교정**
   - `StartInterval` 제거
   - `WatchPaths` → `LaunchEvents > com.apple.iokit.matching` 전환
   - `StandardOutPath`/`StandardErrorPath` 추가

2. **적용 후 검증 (AT#6)**
   - apply 완료 후 `hidutil --get UserKeyMapping` 으로 실제 확인
   - 실패 시 1회 재시도 (sleep 1 후)
   - 검증 실패 시 명확한 에러 + 로그

3. **macOS 버전 분기 (AT#7)**
   - `sw_vers -productVersion` 감지
   - 14.2+: sudo 필요 여부 사전 안내
   - 15+: Input Monitoring 권한 가이드

4. **로깅 인프라**
   - `~/Library/Logs/bhkey.log` 타임스탬프 로그
   - `bhkey status`에 최근 로그 표시
   - 100KB 초과 시 rotate

### Phase 1.2: OSS 품질 강화

5. **install.sh 개선** — 고정 위치 설치 + plist 안정성
6. **status 강화** — 경로 유효성 + 마지막 실행 시각 + 로그 요약
7. **Bluetooth 키보드** — IOKit BT 매칭 추가
8. **문서화** — macOS 버전별 차이, Fast User Switching 영향

### Phase 2.0: Swift 메뉴바 앱 (기존 로드맵)

9. IOKit power notification (슬립/웨이크 네이티브)
10. NSWorkspace 연동
11. 메뉴바 UI

## OSS 배포 레드플래그 체크리스트

- [ ] StartInterval 제거됨
- [ ] WatchPaths /dev 제거됨
- [ ] LaunchEvents IOKit 적용됨
- [ ] 로깅 추가됨
- [ ] macOS 14.2+ sudo 가드 추가됨
- [ ] macOS 15+ Input Monitoring 가이드 추가됨
- [ ] install.sh가 고정 위치에 복사함
- [ ] status에서 plist 경로 유효성 검증함
- [ ] Fast User Switching 영향 문서화됨
- [ ] README에 지원 macOS 버전 명시됨

## 새 DECISIONS 항목

### D-005: LaunchEvents IOKit Matching (WatchPaths/StartInterval 교체)
**Date:** 2026-04-14
**Decision:** `WatchPaths + StartInterval` → `LaunchEvents > com.apple.iokit.matching` 전환
**Reason:** (1) WatchPaths는 Apple "highly discouraged", (2) StartInterval < 10초는 launchd 스로틀 위반, (3) IOKit은 커널 레벨 USB 이벤트로 정확하고 효율적
**Trade-off:** Bluetooth 키보드는 별도 IOKit 매칭 필요 (Phase 1.2)

### D-006: 적용 후 검증 (Anti-Thesis #6)
**Date:** 2026-04-14
**Decision:** `hidutil --get UserKeyMapping` 으로 매핑 적용 확인, 실패 시 1회 재시도
**Reason:** 기존 apply는 hidutil exit code만 신뢰. macOS 14.2+ sudo 이슈 등에서 silent fail 가능
**Trade-off:** 추가 hidutil 호출 1회 (무시할 수 있는 오버헤드)
