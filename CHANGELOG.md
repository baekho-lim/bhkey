# Changelog

All notable changes to bhkey will be documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

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
