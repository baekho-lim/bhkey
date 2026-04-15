# Architecture Decisions

## D-001: Use `hidutil --matching` for per-device mapping (not MatchingID)

**Date:** 2026-03-23
**Decision:** Use `hidutil --matching '{"VendorID":...,"ProductID":...}'` syntax
**Reason:** `MatchingID` does not exist in hidutil — `--matching` with a JSON dict is the official API.
**Impact:** Enables protecting the built-in keyboard by targeting only external devices

## D-002: LaunchAgent calls bhkey.sh itself (not hidutil directly)

**Date:** 2026-03-23
**Decision:** Use `bhkey.sh apply --no-prompt` in plist ProgramArguments instead of calling hidutil directly
**Reason:** (1) Automatic multi-keyboard support, (2) reuse device detection logic on boot, (3) enables WatchPaths + idempotency guard combination
**Trade-off:** If bhkey.sh is moved, the plist path must be updated (re-run `bhkey apply`)

## D-003: Han/Eng key → F18 (de facto macOS standard)

**Date:** 2026-03-23
**Decision:** `0x90 (Lang1) → F18 (0x6d)`, `0x91 (Lang2) → F19 (0x6e)`
**Reason:** F18 is the de facto standard in the macOS Korean community for input source switching. Assign F18 to "Select Next Input Source" in System Settings > Keyboard > Shortcuts > Input Sources.

## D-004: `set -eu` without `pipefail`

**Date:** 2026-03-23
**Decision:** Use `set -eu`, exclude `pipefail`
**Reason:** `awk exit` in `hidutil list | awk` triggers SIGPIPE, causing abnormal script termination when `pipefail` is enabled. Risky pipelines are individually guarded with `{ ...; } || true`.

## D-005: LaunchEvents IOKit Matching (WatchPaths/StartInterval 교체)

**Date:** 2026-04-14
**Decision:** `WatchPaths + StartInterval` → `LaunchEvents > com.apple.iokit.matching` 전환
**Reason:** (1) WatchPaths는 Apple man page에서 "highly discouraged, race-prone" 명시, (2) StartInterval < 10초는 launchd ThrottleInterval 위반으로 서비스 해제 위험, (3) IOKit matching은 커널 레벨 USB 이벤트 기반으로 정확하고 CPU/배터리 영향 제로
**Trade-off:** Bluetooth 키보드는 별도 IOProviderClass 매칭 필요 (Phase 1.2)
**Trigger:** 2026-04-14 잠 후 키 매핑 초기화 장애 → 근본 원인 분석

## D-006: 적용 후 검증 (Anti-Thesis #6)

**Date:** 2026-04-14
**Decision:** apply 완료 후 `hidutil property --get UserKeyMapping` 으로 실제 매핑 확인, 실패 시 sleep 1 후 1회 재시도
**Reason:** 기존 apply()는 hidutil exit code만 신뢰. macOS 14.2+ sudo 이슈 등에서 exit 0이지만 매핑 미적용(silent fail) 가능
**Trade-off:** 추가 hidutil 호출 1회 (무시할 수 있는 오버헤드)
