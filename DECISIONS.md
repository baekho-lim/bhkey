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

## D-007: LaunchAgent 자가파괴 방지 (`--agent` 플래그 분리)

**Date:** 2026-04-22
**Decision:** `apply --no-prompt` (CLI 비대화식) 와 `apply --agent` (launchd 자식 호출) 플래그를 분리. plist는 `--agent`를 호출하고, `--agent` 모드에서는 plist 재작성과 `launchctl bootout/bootstrap`을 건너뛴다.

**Trigger incident:** 2026-04-22 키보드 unplug/replug 시 매핑 복구 실패 버그. 증상: `bhkey status`가 "plist exists but not registered" 보고. LaunchEvent는 등록 안 된 서비스에서 발동하지 않으므로 replug 시 매핑 영구 상실.

**근본 원인 (자가파괴 체인):**
1. 사용자가 `bhkey apply` 실행 → plist 생성 → `launchctl bootstrap` → 서비스 등록 ✓
2. `RunAtLoad` 발동 → launchd가 `bhkey apply --no-prompt` 자식 프로세스 실행
3. 자식의 `apply()`도 plist 재작성 로직을 실행 → `launchctl bootout com.bh.keymapping` 호출 → **자기 서비스 제거**
4. 이어서 `launchctl bootstrap` 재등록 시도 — 하지만 bootout 이 in-flight인 상태라 race 발생 → 등록 실패 (에러는 `2>/dev/null`로 은폐)
5. **최종 상태: plist 파일 존재 + 서비스 미등록** → 이후 모든 IOKit LaunchEvent 무시됨

**왜 `--no-prompt` 단일 플래그로 구분 못 하는가:**
사용자가 CLI에서 `bhkey apply --no-prompt`를 쓸 때는 prompt만 건너뛰고 plist 관리는 정상 수행해야 함. launchd 자식일 때만 plist 관리를 건너뛰어야 함. 두 의도를 같은 플래그로 표현 불가 → `--agent` 신설.

**Reason — 왜 단순히 "재등록 skip"이 아니라 plist 재작성도 skip하는가:**
plist를 재작성할 유일한 이유는 bhkey.sh 경로 변경. 이는 L-1 orphan detection + 사용자 수동 `bhkey apply`로 충분히 커버됨. 에이전트 호출에서 plist를 만질 정당한 이유가 없으므로 "the simplest fix that works" 원칙으로 전체 블록 skip.

**커버되는 추가 시나리오 (집합론적 분석 결과):**
- E5. USB 키보드 unplug/replug (직접 원인)
- E8. 다중 키보드 중 1개 제거 후 복귀
- E9. USB 허브 power-cycle
- E10. 디스플레이 슬립 (모니터 내장 USB 허브 경유)
- E4. sleep/wake 일부 케이스 (USB re-enumeration 동반)

모두 동일한 자가파괴 체인에서 파생 → 한 수정으로 5개 시나리오 해결.

**Trade-off:**
- CLI 도움말 복잡도 증가 (`--no-prompt` vs `--agent` 구분)
- 기존 외부 자동화 스크립트가 `apply --no-prompt`를 사용했다면 그대로 동작 (CLI 의미 보존)

**Post-check 추가:** user-initiated apply 경로에 `launchctl print` 으로 등록 확인 + 1회 재시도. 실패 시 명시적 에러 로그. D-006 패턴을 launchctl 계층에도 적용.

## D-008: 구조화 로그 (`~/Library/Logs/bhkey.log`)

**Date:** 2026-04-22
**Decision:** 모든 `log_info`/`log_warn`/`log_error` 호출이 `~/Library/Logs/bhkey.log` 에도 기록. 포맷: `[YYYY-MM-DD HH:MM:SS][mode][pid=N] LEVEL message`. 100KB 초과 시 `.1` 로 1회 로테이트. plist의 `StandardErrorPath`는 별도 `bhkey-launchd.err` 로 분리.

**Reason:** D-007 디버깅 과정에서 "언제 왜 서비스가 등록 해제됐는가"를 추적할 방법이 없었음. 구조화된 로그 없이는 재발 시 동일한 blind debugging 반복 불가피.

**Observability value:**
- `mode=agent` vs `mode=cli` 구분으로 launchd 호출 vs 사용자 호출 구별
- `pid` 로 동시 실행 race condition 식별
- `status` 명령이 최근 5줄 표시 → 사용자 셀프 디버깅 가능

**Trade-off:** 디스크 쓰기 증가 (apply당 최대 ~1KB), 로테이트 로직 추가 복잡도. 모두 무시할 수 있는 수준.
