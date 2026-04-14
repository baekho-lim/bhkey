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
