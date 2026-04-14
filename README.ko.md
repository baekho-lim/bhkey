# bhkey

macOS 외장 키보드용 제로 레이턴시 키 리매퍼

**Language**: [English](README.md) | 한국어 | [中文](README.zh.md)

[![CI](https://github.com/baekho-lim/bhkey/actions/workflows/ci.yml/badge.svg)](https://github.com/baekho-lim/bhkey/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/baekho-lim/bhkey)](https://github.com/baekho-lim/bhkey/releases)
![macOS](https://img.shields.io/badge/macOS-10.12%2B-blue)

## 소개

bhkey는 Apple 네이티브 `hidutil` 커널 API를 사용해 외장 키보드의 수정자 키(modifier key)를 리매핑합니다. 가상 드라이버 없음, CPU를 잡아먹는 백그라운드 데몬 없음. 매핑은 커널 레벨에서 적용되어 입력 지연이 0ms입니다. Karabiner-Elements와 달리 시스템에 아무것도 설치하지 않으며, 모든 파일은 홈 디렉토리 안에 위치합니다.

VendorID+ProductID로 외장 키보드만 타겟팅하므로, 내장 키보드나 Magic Keyboard는 절대 건드리지 않습니다.

## 요구사항

- macOS 10.12 Sierra 이상 (`hidutil`은 Sierra에서 도입)
- `bash`

## 설치

### 방법 1: 한 줄 설치 (권장)

```bash
curl -fsSL https://raw.githubusercontent.com/baekho-lim/bhkey/main/install.sh | bash
```

### 방법 2: Homebrew

```bash
brew tap baekho-lim/bhkey
brew install bhkey
```

### 방법 3: 직접 다운로드

```bash
curl -L https://github.com/baekho-lim/bhkey/releases/latest/download/bhkey.sh -o bhkey.sh
chmod +x bhkey.sh
bash bhkey.sh apply
```

### 방법 4: git clone

```bash
git clone https://github.com/baekho-lim/bhkey.git
cd bhkey
chmod +x bhkey.sh
bash bhkey.sh apply
```

`apply` 명령은 5가지 사전 검사를 실행하고, `hidutil`을 통해 매핑을 적용하며, 재부팅 및 USB 핫플러그 시 자동 적용되는 LaunchAgent를 설치합니다.

## 기본 매핑

| 물리적 키 | macOS 동작 | 비고 |
|---|---|---|
| Left Alt | Left Command (⌘) | Windows → Mac 레이아웃 |
| Left Win | Left Option (⌥) | Windows → Mac 레이아웃 |
| Right Alt | Right Command (⌘) | |
| Right Win | F19 | 음성 입력 트리거 |
| 한/영 키 (0x90) | F18 | 입력 소스 전환 |
| 한자 키 (0x91) | F19 | Right Win과 동일 |

이 기본 레이아웃은 macOS에서 사용하는 Windows 배열 키보드(예: Corsair, Leopold)를 위해 설계되었습니다.

## 명령어

```bash
bash bhkey.sh apply     # 사전 검사 실행 후 매핑 적용
bash bhkey.sh reset     # 모든 커스텀 매핑 제거
bash bhkey.sh status    # 현재 hidutil 상태 및 LaunchAgent 상태 표시
bash bhkey.sh version   # 버전 출력
```

## 동작 원리

1. **hidutil**: bhkey는 JSON 매핑 페이로드를 포함한 `hidutil property --set`을 호출합니다. 이는 커널 레벨 키 변환을 설정하는 macOS 네이티브 API로, 드라이버·프로세스·지연이 없습니다.
2. **디바이스 타겟팅**: `--matching` 플래그가 VendorID와 ProductID로 필터링하여 지정한 외장 키보드에만 적용됩니다.
3. **LaunchAgent 영속성**: `RunAtLoad: true`와 `WatchPaths: /dev`가 설정된 plist를 `~/Library/LaunchAgents/com.bh.keymapping.plist`에 설치합니다. 로그인 시와 USB 디바이스 연결 시 자동으로 매핑을 재적용합니다.

## 적용 후 설정 (한국어 키보드 사용자)

`bhkey apply` 실행 후 F18/F19 키를 시스템 설정에서 할당합니다:

1. **입력 소스 전환 (F18)**: 시스템 설정 > 키보드 > 키보드 단축키 > 입력 소스 > F18을 "이전 입력 소스 선택" 또는 "입력 메뉴에서 다음 소스 선택"에 할당
2. **음성 입력 / 받아쓰기 (F19)**: 시스템 설정 > 키보드 > 받아쓰기 > 단축키를 F19로 설정 (Right Win 키를 단축키 입력란에서 누르면 됨)

## 안티테제 가드

bhkey는 매핑 적용 전 5가지 검사를 실행합니다:

1. macOS 시스템 설정의 수정자 키 변경 감지 — 이중 매핑 충돌 경고
2. Karabiner-Elements 또는 Corsair iCUE 실행 여부 확인 — 두 프로그램 모두 `hidutil`과 충돌 가능
3. 외장 키보드 감지 — 디바이스 미발견 시 중단
4. `hidutil` 권한 오류 처리 및 macOS 14.2+ 에서 `sudo` 힌트 제공
5. LaunchAgent plist 구문을 `plutil -lint`로 검증 후 로드

## 커스터마이징

키 매핑 변경은 [`docs/CUSTOMIZE.md`](docs/CUSTOMIZE.md)를 참고하세요. HID 사용 테이블, 키보드의 VendorID/ProductID 확인 방법, 매핑 페이로드 수정 방법이 안내되어 있습니다.

## 라이선스

MIT
