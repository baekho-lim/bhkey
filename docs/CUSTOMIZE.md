# Customizing Key Mappings

## Overview

All key mappings are defined in the `build_mapping_json()` function inside `bhkey.sh`. Edit that function to add, remove, or change any mapping, then re-apply.

---

## Mapping Format

```json
{"UserKeyMapping":[
    {"HIDKeyboardModifierMappingSrc": 0x7000000E0, "HIDKeyboardModifierMappingDst": 0x7000000E4}
]}
```

- `Src` — the physical key being pressed
- `Dst` — the key it should behave as

**HID code formula:**

```
0x700000000 + usage_code
```

Usage page `0x07` (Keyboard/Keypad) → prefix `0x700` + 6 hex digits.

Example: Caps Lock has usage code `0x39` → full HID code `0x700000039`.

---

## Key Code Quick Reference

### Modifier Keys

| Key | Usage Code | Full HID Code |
|-----|-----------|---------------|
| Left Ctrl | 0xE0 | 0x7000000E0 |
| Left Shift | 0xE1 | 0x7000000E1 |
| Left Alt/Option | 0xE2 | 0x7000000E2 |
| Left Win/Cmd | 0xE3 | 0x7000000E3 |
| Right Ctrl | 0xE4 | 0x7000000E4 |
| Right Shift | 0xE5 | 0x7000000E5 |
| Right Alt/Option | 0xE6 | 0x7000000E6 |
| Right Win/Cmd | 0xE7 | 0x7000000E7 |
| Caps Lock | 0x39 | 0x700000039 |

### Function Keys

| Key | Usage Code | Full HID Code |
|-----|-----------|---------------|
| F1–F12 | 0x3A–0x45 | 0x70000003A–0x700000045 |
| F13 | 0x68 | 0x700000068 |
| F14 | 0x69 | 0x700000069 |
| F15 | 0x6A | 0x70000006A |
| F16 | 0x6B | 0x70000006B |
| F17 | 0x6C | 0x70000006C |
| F18 | 0x6D | 0x70000006D |
| F19 | 0x6E | 0x70000006E |

### Special Keys

| Key | Usage Code | Full HID Code |
|-----|-----------|---------------|
| Escape | 0x29 | 0x700000029 |
| Caps Lock | 0x39 | 0x700000039 |
| Print Screen | 0x46 | 0x700000046 |
| Scroll Lock | 0x47 | 0x700000047 |
| Pause | 0x48 | 0x700000048 |
| Delete/Backspace | 0x2A | 0x70000002A |
| Han/Eng (Korean) | 0x90 | 0x700000090 |
| Hanja (Korean) | 0x91 | 0x700000091 |

---

## Common Customization Examples

### Swap Caps Lock and Escape (Vim users)

```bash
build_mapping_json() {
    cat <<'MAPPING'
{"UserKeyMapping":[
    {"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029},
    {"HIDKeyboardModifierMappingSrc":0x700000029,"HIDKeyboardModifierMappingDst":0x700000039}
]}
MAPPING
}
```

### Map Right Ctrl to F18 (alternative input source key)

```bash
build_mapping_json() {
    cat <<'MAPPING'
{"UserKeyMapping":[
    {"HIDKeyboardModifierMappingSrc":0x7000000e4,"HIDKeyboardModifierMappingDst":0x70000006d}
]}
MAPPING
}
```

### Remove a specific mapping

Delete the corresponding line from the JSON array. Ensure the last entry has no trailing comma.

```bash
# Before (Right Win -> F19 included):
{"UserKeyMapping":[
    {"HIDKeyboardModifierMappingSrc":0x7000000e2,"HIDKeyboardModifierMappingDst":0x7000000e3},
    {"HIDKeyboardModifierMappingSrc":0x7000000e7,"HIDKeyboardModifierMappingDst":0x70000006e}
]}

# After (Right Win mapping removed):
{"UserKeyMapping":[
    {"HIDKeyboardModifierMappingSrc":0x7000000e2,"HIDKeyboardModifierMappingDst":0x7000000e3}
]}
```

---

## After Editing

1. Save `bhkey.sh`
2. Run:

```bash
bash bhkey.sh apply
```

---

## Finding Key Codes

List all connected HID devices and their current mappings:

```bash
hidutil list
```

For the full HID Usage Tables spec (all usage codes for every key):
https://usb.org/sites/default/files/hut1_5.pdf

> Keyboard/Keypad usage codes are in **Section 10, Table 12** (page 88+).
