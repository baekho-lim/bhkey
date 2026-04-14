# bhkey

Zero-Latency Keyboard Remapper for macOS External Keyboards

## Description

bhkey remaps modifier keys on external keyboards using Apple's native `hidutil` kernel property API — no virtual driver, no background daemon eating CPU. Mapping is applied at the kernel level with zero input latency. Unlike Karabiner-Elements, bhkey installs nothing into the system; all files live inside your home directory.

It targets only your external keyboard (matched by VendorID+ProductID), so your built-in keyboard or Magic Keyboard is never touched.

## Requirements

- macOS 10.12 Sierra or later (`hidutil` was introduced in Sierra)
- `bash`

## Installation

```bash
git clone https://github.com/baekho-lim/bhkey.git
cd bhkey
chmod +x bhkey.sh
bash bhkey.sh apply
```

The `apply` command runs 5 pre-flight checks, applies the mapping via `hidutil`, and installs a LaunchAgent for persistence across reboots and USB hot-plug events.

## Default Mapping

| Physical Key | macOS Behavior | Note |
|---|---|---|
| Left Alt | Left Command (⌘) | Windows → Mac layout |
| Left Win | Left Option (⌥) | Windows → Mac layout |
| Right Alt | Right Command (⌘) | |
| Right Win | F19 | Voice input trigger |
| 한/영 key (0x90) | F18 | Input source switch |
| 한자 key (0x91) | F19 | Same as Right Win |

This default layout is designed for Windows-layout keyboards (e.g., Corsair, Leopold) used on macOS.

## Commands

```bash
bash bhkey.sh apply     # Run anti-thesis checks and apply mapping
bash bhkey.sh reset     # Remove all custom mappings
bash bhkey.sh status    # Show current hidutil state and LaunchAgent status
bash bhkey.sh version   # Print version
```

## How It Works

1. **hidutil**: bhkey calls `hidutil property --set` with a JSON mapping payload. This is a macOS-native API that sets kernel-level key translation — no driver, no process, no latency.
2. **Per-device targeting**: The `--matching` flag filters by `VendorID` and `ProductID`, so only the specified external keyboard is affected.
3. **LaunchAgent persistence**: bhkey installs a plist at `~/Library/LaunchAgents/com.bh.keymapping.plist` with `RunAtLoad: true` and `WatchPaths: /dev`. The mapping auto-applies on login and whenever a USB device is connected.

## Post-apply Setup (Korean Keyboard Users)

After running `bhkey apply`, assign the F18/F19 keys in System Settings:

1. **Input source switch (F18)**: System Settings > Keyboard > Keyboard Shortcuts > Input Sources > assign F18 to "Select the previous input source" or "Select next source in input menu"
2. **Voice input / dictation (F19)**: System Settings > Keyboard > Dictation > set the shortcut to F19 (press Right Win key in the shortcut field)

## Anti-Thesis Guards

bhkey runs 5 checks before applying any mapping:

1. Detects macOS System Settings modifier key overrides — warns if a key would be double-mapped
2. Checks for Karabiner-Elements or Corsair iCUE running — both can conflict with `hidutil`
3. Detects the target external keyboard — aborts if the device is not found
4. Handles `hidutil` permission errors and provides a `sudo` hint for macOS 14.2+
5. Validates the LaunchAgent plist syntax via `plutil -lint` before loading

## Customization

To change the key mappings, see [`docs/CUSTOMIZE.md`](docs/CUSTOMIZE.md) for the HID usage table, how to find your keyboard's VendorID/ProductID, and how to modify the mapping payload.

## License

MIT
