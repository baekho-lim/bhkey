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
┌─────────────────┐    ┌────────────────────────┐
│ macOS hidutil    │    │ LaunchAgent plist       │
│ (kernel level)   │    │ ~/Library/LaunchAgents/ │
│                  │    │                         │
│ --matching:      │    │ RunAtLoad: boot 1회     │
│  per-device      │    │ WatchPaths: /dev 변경 시│
│ --set:           │    │ → bhkey.sh apply        │
│  global          │    │   --no-prompt           │
└─────────────────┘    └────────────────────────┘
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
- **Hot-plug:** WatchPaths `/dev` (USB 연결 시 재트리거)
- **Idempotency:** `--no-prompt` 모드에서 이미 매핑 적용 상태면 exit 0
