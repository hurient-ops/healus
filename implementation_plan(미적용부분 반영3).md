# 추가 요구사항 구현 계획서 (수정안 3)

사용자의 피드백을 반영하여 테스트 모드 인슐린 잔량의 초기값을 300U로 조정하고, 히스토리 화면 그래프의 Y축 눈금과 실제 막대 스케일 비율을 100U 기준으로 일치시키는 계획을 반영하였습니다.

## User Review Required

> [!IMPORTANT]
> 1. **테스트 모드 인슐린 잔량 초기값 변경:**
>    - 가상 BLE 기기 시뮬레이터([mock_ble_service.dart](file:///e:/projects/healus/lib/services/ble/mock_ble_service.dart)) 내의 `_insulinRemain` 변수 초기값을 기존 `7500` (75.0U)에서 `30000` (300.0U)으로 수정합니다. 이로써 대시보드의 초기 인슐린 잔량이 300.0U로 정상 연동됩니다.
> 2. **히스토리 Y축 및 막대 스케일 일치:**
>    - 히스토리 화면([code.html](file:///e:/projects/healus/ui_design/history/code.html)) 그래프의 Y축 눈금이 0 ~ 100U로 표현되어 있는 디자인 명세에 맞추어, 막대그래프의 스케일 계산 기준값(`MAX_STACK_VALUE`)을 기존 `15`에서 `100`으로 상향 변경합니다.
>    - 이를 통해 기초/식사/저녁 주입량 막대들이 Y축 눈금(0, 20, 40, 60, 80, 100) 좌표와 실제 스케일 비율이 정확히 1:1로 일치하여 렌더링되도록 보장합니다.

## Proposed Changes

### UI & Webview Layer

---

#### [MODIFY] [code.html (history)](file:///e:/projects/healus/ui_design/history/code.html)
- `const MAX_STACK_VALUE = 15;` 선언을 `const MAX_STACK_VALUE = 100;`으로 변경하여 그래프 스케일을 Y축 눈금(100)과 동기화합니다.

### Native Sync & Parser Layer

---

#### [MODIFY] [mock_ble_service.dart](file:///e:/projects/healus/lib/services/ble/mock_ble_service.dart)
- `int _insulinRemain = 7500;` 초기 선언부를 `int _insulinRemain = 30000;`으로 변경하여 가상 기기의 인슐린 잔량 상태 초기치를 300.0U로 설정합니다.

## Verification Plan

### Automated Tests
```powershell
flutter test test/pump_state_provider_test.dart
```

### Manual Verification
1. 에뮬레이터에서 **대시보드** 진입 -> 인슐린 잔량 초기값이 `300.0 / 300 U` (100% 게이지)로 깨끗하게 뜨는지 확인.
2. **히스토리** 화면으로 이동 -> 그래프 Y축 눈금(0 ~ 100)에 맞추어 이력 데이터 막대들의 높이가 정확한 주입량 스케일에 맞게 그려지는지 확인.
3. 이력 수집 후 맨 오른쪽 중심일과 이전 4일치 날짜 매칭 값이 Y축 기준선에 올바른 높이 비례로 노출되는지 최종 검토.
