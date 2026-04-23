---
date: 2026-04-22
version: 1.0.2 → 1.0.3
type: bug-retrospective
---

# 회고: 키보드 unplug/replug 시 매핑 복구 실패 (v1.0.2)

## 관련 문서
[[DECISIONS]] [[CHANGELOG]] [[ARCHITECTURE]] [[SESSION-LOG]]

## 한 줄 요약

`apply --no-prompt`(plist가 호출)가 `launchctl bootout`으로 자기 서비스를 제거해, 이후 IOKit LaunchEvent가 영원히 발동하지 않는 자가파괴 루프.

## 근본 원인

`apply()` 후반부의 plist 재작성 + `bootout → bootstrap` 블록이 **호출 맥락을 구분하지 않고** 항상 실행됐다.

- 사용자 CLI 호출 → 정상 (서비스 없음 → 생성)
- launchd 자식 호출 → 자가파괴 (서비스 있음 → 제거 후 race로 재등록 실패)

`2>/dev/null`로 에러가 은폐되어 조용히 실패, 증상만 보고 원인을 역추적하기 어려웠음.

## 수정 (D-007)

`--agent` 플래그 신설. 쓰임새:

```
사용자 → bhkey apply           : prompts + plist + launchctl ✓
사용자 → bhkey apply --no-prompt: no-prompts + plist + launchctl ✓
launchd → bhkey apply --agent   : no-prompts, plist/launchctl skip ✓
```

## 재발 방지 (로컬)

| 구현 | 위치 |
|------|------|
| `--agent` 플래그 분기 | [bhkey.sh:358](../bhkey.sh) |
| plist는 `--agent` 호출 | [bhkey.sh:435](../bhkey.sh) |
| 등록 post-check | [bhkey.sh:455](../bhkey.sh) |
| `~/Library/Logs/bhkey.log` 구조화 로그 | D-008 |

## 부산물 (집합론 분석)

D-007 한 수정으로 E5(replug) + E8(다중 키보드 복귀) + E9(USB 허브 power-cycle) + E10(모니터 허브 슬립) 4개 시나리오 동시 해결. 근본 원인이 같으면 수정도 하나로 충분.

## 전역 교훈 포인터

→ `[[bhOS/09-knowledge/incidents/2026-04-22-bhkey-launchagent-self-destruction]]`  
→ `[[bhOS/09-knowledge/anti-patterns/launchagent-child-self-destruction]]`
