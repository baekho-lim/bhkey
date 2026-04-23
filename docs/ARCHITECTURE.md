# Architecture

## System Diagram

```
┌─────────────────────────────────────────────────┐
│                  bhkey.sh                        │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │
│  │ detect   │  │ anti-    │  │ build        │  │
│  │ _device()│  │ thesis   │  │ _mapping     │  │
│  │          │  │ guards   │  │ _json()      │  │
│  └────┬─────┘  └────┬─────┘  └──────┬───────┘  │
│       │              │               │          │
│       └──────┬───────┘               │          │
│              ▼                       │          │
│  ┌──────────────────┐               │          │
│  │    apply()        │◄──────────────┘          │
│  │  ├ pre-flight     │                          │
│  │  ├ hidutil --set  │                          │
│  │  └ plist create   │                          │
│  └──────────────────┘                           │
│              │                                   │
│  ┌───────────┴──────────┐                       │
│  │    reset()           │                       │
│  │  ├ per-device clear  │                       │
│  │  ├ global clear      │                       │
│  │  └ plist remove      │                       │
│  └──────────────────────┘                       │
└─────────────────────────────────────────────────┘
         │                          │
         ▼                          ▼
┌─────────────────┐    ┌──────────────────────────────┐
│ macOS hidutil    │    │ LaunchAgent plist             │
│ (kernel level)   │    │ ~/Library/LaunchAgents/       │
│                  │    │                               │
│ --matching:      │    │ RunAtLoad: boot/login 1회     │
│  per-device      │    │ LaunchEvents.com.apple.       │
│ --set:           │    │   iokit.matching:             │
│  global          │    │   IOHIDDevice UsagePage=1     │
│                  │    │   Usage=6 (keyboard attach)   │
│                  │    │ → bhkey.sh apply --agent      │
└─────────────────┘    └──────────────────────────────┘
```

## Data Flow

1. `detect_device()` → hidutil list 파싱 → `{VendorID, ProductID}` 쌍
2. `build_mapping_json()` → HID Usage Table 기반 매핑 JSON
3. `apply()` → pre-flight 체크 → `hidutil property --matching --set` → plist 생성 → launchctl bootstrap
4. `reset()` → per-device 초기화 → global 초기화 → plist 삭제

## Anti-Thesis Guard Architecture

```
apply() 진입
  │
  ├─ AT#1: defaults read → modifier key 충돌?
  │    └─ Src==Dst identity 매핑 구분
  │
  ├─ AT#2: pgrep → Karabiner/iCUE 실행 중?
  │
  ├─ AT#3: detect_device → Built-In=0 필터
  │    └─ 외장 없으면 글로벌 경고
  │
  ├─ AT#4: hidutil 실패 → EUID 체크 → sudo 안내
  │
  └─ AT#5: plutil -lint → plist 문법 검증
```

## Persistence Strategy

- **Runtime:** `hidutil property --matching --set` (세션 내 유효)
- **Boot:** LaunchAgent plist (`RunAtLoad`)
- **Hot-plug:** `LaunchEvents > com.apple.iokit.matching` (IOHIDDevice keyboard attach, 커널 이벤트)
- **Idempotency:** `--no-prompt`/`--agent` 모드에서 이미 매핑 적용 상태면 exit 0
- **Self-destruction guard (D-007):** `--agent` 모드(launchd 자식 호출)에서는 plist 재작성 및 `launchctl bootout/bootstrap` 건너뜀 → 서비스 등록 보존

## Invocation Modes

bhkey.sh는 세 가지 호출 모드를 구분:

| 모드 | 플래그 | Pre-flight | hidutil --set | plist 관리 | launchctl |
|------|--------|------------|---------------|-----------|-----------|
| 대화식 CLI | (없음) | prompts | ✓ | ✓ | ✓ |
| 비대화식 CLI | `--no-prompt` | auto-yes | ✓ (idempotent) | ✓ | ✓ |
| LaunchAgent 자식 | `--agent` | auto-yes | ✓ (idempotent) | ✗ skip | ✗ skip |

**왜 3-mode 분리인가:** plist는 `--agent`를 호출. `--agent`가 plist/launchctl을 건드리면 자기 서비스 제거 → 이후 IOKit event 미발동. D-007 참조.

## Observability

- 구조화 로그: `~/Library/Logs/bhkey.log` (`[timestamp][mode][pid] LEVEL msg`)
- launchd stderr: `~/Library/Logs/bhkey-launchd.err`
- `bhkey status`: 현재 매핑 + LaunchAgent 상태 + `runs`/`last exit code` + 최근 5줄 로그
