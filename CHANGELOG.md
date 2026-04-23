# Changelog

All notable changes to bhkey will be documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [1.0.3] — 2026-04-22

### Fixed
- **D-007**: Prevent LaunchAgent self-destruction on keyboard unplug/replug.

  **Symptom:** After running `bhkey apply`, the key mapping reverts when the external keyboard is unplugged and plugged back in. `bhkey status` reports *"plist exists but not registered"*.

  **Root cause:** `apply --no-prompt` (invoked by the LaunchAgent itself) was re-running the plist-write + `launchctl bootout/bootstrap` path, which terminated the service that had just spawned it. The subsequent `bootstrap` raced with the in-flight teardown and silently failed (errors suppressed via `2>/dev/null`), leaving the plist on disk but the service unregistered. No registered service → the IOKit `hid-keyboard-attach` LaunchEvent never fires → subsequent replug never re-applies the mapping.

  **Fix:** Introduce a dedicated `--agent` flag used exclusively by the plist's `ProgramArguments`. In `--agent` mode, `apply()` re-applies hidutil mappings but skips plist rewrite and `launchctl` management entirely. `--no-prompt` retains its original CLI meaning (skip confirmations, still manage plist).

  **Additional scenarios resolved (same root cause):** (a) USB hub power-cycle, (b) monitor-integrated USB hub sleep, (c) one of multiple external keyboards detached and re-attached, (d) some sleep/wake cases that trigger USB re-enumeration.

### Added
- **D-008**: Structured logging at `~/Library/Logs/bhkey.log`.
  Every `log_info`/`log_warn`/`log_error` is mirrored to the log file with `[timestamp][mode=cli|agent][pid=N]` prefix. Rotates at 100KB (keeps one `.1` backup). plist captures stderr to a separate `bhkey-launchd.err`.
- Post-apply `launchctl print` verification with one retry — surfaces launchd registration failures that were previously silent.
- `bhkey status` now shows `runs`/`last exit code` from `launchctl print`, last 5 log lines, and a red warning when the plist is unregistered.

### Changed
- The plist's `ProgramArguments` now calls `apply --agent` instead of `apply --no-prompt`. Upgrade path: run `bhkey apply` once after install to refresh the plist.

---

## [1.0.2] — 2026-04-15

### Fixed
- **L-1**: Detect orphaned plist in `bhkey status`.
  When bhkey.sh is moved or deleted after `apply`, the LaunchAgent holds a stale path and fails silently on keyboard attach.
  Now extracts `ProgramArguments[1]` from the plist and warns if the path no longer exists, with a `bhkey apply` fix instruction.

---

## [1.0.1] — 2026-04-14

### Fixed
- **D-005**: Replace deprecated `WatchPaths: /dev` + `StartInterval: 5` with `LaunchEvents IOKit` matching.
  `WatchPaths` is race-prone on sleep/wake; `StartInterval < 10s` violates launchd ThrottleInterval and risks service suspension.
  Now uses kernel-level `IOHIDDevice` (PrimaryUsagePage=1, PrimaryUsage=6) USB attach event — triggers only on actual keyboard plug-in.
- **D-006**: Add post-apply mapping verification (`hidutil --get UserKeyMapping`) with one automatic retry.
  `hidutil` exits 0 but silently skips mapping without sufficient privileges on macOS 14.2+.
  If mapping not confirmed after retry, prints explicit `sudo bhkey apply` hint.

---

## [1.0.0] — 2026-04-14

### Added
- `apply` command: apply modifier key mapping via `hidutil` with 5 anti-thesis pre-flight checks
- `reset` command: remove all custom mappings and unload LaunchAgent
- `status` command: display current mapping, LaunchAgent state, and conflicting processes
- `version` command: print version string
- Anti-thesis #1: detect macOS System Settings modifier key conflicts
- Anti-thesis #2: detect conflicting processes (Karabiner-Elements, Corsair iCUE)
- Anti-thesis #3: per-device targeting via `--matching VendorID+ProductID` (protects built-in keyboard)
- Anti-thesis #4: handle `hidutil` permission errors with `sudo` hint for macOS 14.2+
- Anti-thesis #5: validate LaunchAgent plist via `plutil -lint` before loading
- LaunchAgent persistence: auto-applies on login and USB hot-plug via `WatchPaths: /dev`
- `--no-prompt` flag for non-interactive / LaunchAgent re-apply mode
- Default mapping for Windows-layout keyboards (Alt↔Cmd swap, Right Win→F19, 한/영→F18)
