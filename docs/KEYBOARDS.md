# Keyboard Registry

bhkey를 적용한 키보드 목록과 각 설정 상태.

---

## 등록된 키보드

### Corsair K70 RGB (K70R)

- **등록일:** 2026-03-23
- **VendorID / ProductID:** (미기록 — Corsair 공통 VID 0x1b1c)
- **상태:** 비활성 (현재 미연결)
- **비고:** 한자 키(0x91)가 macOS에 HID 이벤트를 전달하지 않아 Right Win으로 대체

### Gaming Keyboard

- **등록일:** 2026-04-08
- **VendorID / ProductID:** 0x258a / 0x10c
- **상태:** 활성 (현재 연결 중)
- **비고:** 현재 사용 중인 메인 키보드

---

## 공통 매핑 정의

모든 키보드에 동일하게 적용되는 매핑 (`bhkey.sh` → `build_mapping_json()`):

| Src 키 | HID 코드 | Dst 키 | HID 코드 | 목적 |
|--------|----------|--------|----------|------|
| Left Alt | 0x7000000E2 | Left Win/Cmd | 0x7000000E3 | Windows 키보드 Alt/Win 스왑 |
| Left Win | 0x7000000E3 | Left Alt/Option | 0x7000000E2 | (위와 쌍) |
| Right Alt | 0x7000000E6 | Right Win/Cmd | 0x7000000E7 | Right Alt → Cmd |
| Right Win | 0x7000000E7 | F19 | 0x70000006E | macOS 받아쓰기(음성 입력) 트리거 |
| 한/영 (Lang1) | 0x700000090 | F18 | 0x70000006D | 입력 소스 전환 — macOS 커뮤니티 표준 |
| 한자 (Lang2) | 0x700000091 | F19 | 0x70000006E | 음성 입력 트리거 (한자 키 HID 미전달 대응) |

> macOS System Settings 연동:
> - F18 → **Keyboard Shortcuts > Input Sources > Select Next Input Source**
> - F19 → **Keyboard Shortcuts > ... > Dictation** 또는 받아쓰기 설정

---

## 현재 상태 확인

```bash
bash bhkey.sh status
```

출력 예시:
```
[External Keyboard]
  Gaming Keyboard (VendorID: 0x258a, ProductID: 0x10c)

[Current Mapping]
  Gaming Keyboard: 12 key mapping(s) active

[LaunchAgent]
  plist: ~/Library/LaunchAgents/com.bh.keymapping.plist (exists)
  status: registered (auto-applies on reboot)
```

---

## 새 키보드 연결 시 절차

1. System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys → 해당 기기 선택 후 **Restore Defaults**
2. `bash bhkey.sh apply`
3. `bash bhkey.sh status` 로 확인
4. 이 문서에 키보드 항목 추가

---

## 매핑 변경 방법

`bhkey.sh` 내 `build_mapping_json()` 함수 수정 후 재적용.  
키 코드 레퍼런스 → [`CUSTOMIZE.md`](CUSTOMIZE.md)
