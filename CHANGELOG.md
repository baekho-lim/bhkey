# Changelog

All notable changes to bhkey will be documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

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
