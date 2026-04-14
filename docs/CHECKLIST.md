# Pre-Flight Checklist

bhkey apply 실행 전 자동으로 체크하지만, 수동 확인이 필요한 경우:

## 1. macOS 보조 키 기본값 복원

시스템 설정 > 키보드 > 키보드 단축키 > 보조 키 > 대상 키보드 선택 > **기본값 복원**

bhkey가 자동 감지하지만, macOS가 "기본값 복원" 시 Src==Dst identity 매핑을 남기므로 키 자체는 삭제되지 않음. bhkey는 이를 구분하여 처리.

## 2. Karabiner / iCUE 비활성화

Karabiner-Elements, Corsair iCUE 등 키 리매핑 소프트웨어가 실행 중이면 충돌 가능.

```bash
pgrep karabiner   # 실행 중이면 PID 출력
pgrep -i icue     # 실행 중이면 PID 출력
```

## 3. 외장 키보드 연결 확인

```bash
hidutil list | grep -i keyboard
```

Built-In=0인 행이 외장 키보드. VendorID와 ProductID가 0x0이 아닌지 확인.

## 4. 한/영 전환 설정

bhkey가 한/영 키를 F18로 매핑한 후:

시스템 설정 > 키보드 > 키보드 단축키 > 입력 소스 > "다음 입력 소스 선택" → **F18** 할당
