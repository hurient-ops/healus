# 배터리 및 인슐린 잔량 동기화 파이프라인 구축 계획서

현재 Healus 앱(Flutter) 내부에서는 펌프와 블루투스로 통신하여 **'배터리 잔량'**과 **'인슐린 잔량'**을 실시간으로 수신받아 모바일 앱 화면에 잘 띄워주고 있습니다. 
하지만 **이 데이터를 클라우드 서버(백엔드)로 전송하는 로직이 빠져 있어** 웹 대시보드에서는 해당 정보를 볼 수가 없는 상태입니다.

이를 해결하기 위해 앱, 백엔드, 웹 프론트엔드 전체에 걸쳐 아래와 같이 데이터 파이프라인을 구축하려고 합니다.

## User Review Required
> [!IMPORTANT]
> - DB 스키마 업데이트: 사용자(User) 테이블에 `pump_battery` 및 `pump_insulin` 컬럼이 추가됩니다.
> - 웹 대시보드 UI 수정: 상단(예: 사용자 이름 옆 또는 KPI 카드 근처)에 '기기 상태(배터리, 인슐린 잔량)'를 표시하는 UI가 추가됩니다.

## Proposed Changes

---
### 1. 백엔드 (healus-backend)
- **DB 모델 확장 (`models.py`)**
  - `User` 모델에 `pump_battery_level` (Integer) 및 `pump_insulin_remaining` (Float) 컬럼 추가
- **API 엔드포인트 추가 (`api/web.py` 또는 `api/logs.py`)**
  - 모바일 앱이 실시간 잔량을 쏠 수 있도록 `POST /api/pump-status` 엔드포인트 신설
- **대시보드 응답 수정 (`api/web.py`)**
  - `GET /api/dashboard` 응답 데이터에 사용자의 최신 `battery_level`과 `insulin_remaining` 값을 포함하여 반환

---
### 2. 모바일 앱 (healus)
- **API 클라이언트 확장 (`api_client.dart`)**
  - 백엔드의 `/api/pump-status`를 호출하는 `postPumpStatus(int battery, double insulin)` 메서드 추가
- **상태 관리 연동 (`pump_state_provider.dart`)**
  - 펌프에서 `btPumpBatteryRes`(배터리 응답) 또는 `btPumpRemaInjQntRes`(인슐린 잔량 응답) 패킷이 올 때마다 `ApiClient`를 통해 클라우드 서버로 최신 값을 전송하여 실시간 동기화

---
### 3. 웹 대시보드 (healus-web)
- **타입 정의 업데이트 (`dashboard.ts` 등)**
  - 대시보드 응답 데이터(DashboardData) 인터페이스에 기기 상태 변수 추가
- **UI 표출 (`Dashboard.tsx`)**
  - 화면 상단(타이틀 부근)에 펌프 기기의 실시간 배터리 잔량 아이콘 및 인슐린 잔량(Unit)을 직관적으로 보여주는 UI 영역 추가
- **소수점 표기 정밀도 개선 (`Dashboard.tsx`)**
  - **[NEW]** 금일 기초 주입, 식사 주입, 추가 주입 수치를 `toFixed(2)`를 적용하여 소수점 이하 2자리까지 표시
  - **[NEW]** '인슐린 & 혈당 복합 트렌드' 그래프의 툴팁 및 Y축 등 인슐린 주입량 관련 지표들도 모두 소수점 이하 2자리까지 일관되게 표시

## Verification Plan
### Automated Tests
- 없음

### Manual Verification
1. 앱에서 모의(Mock) 펌프 또는 실제 펌프를 연결하여 배터리와 인슐린 잔량 데이터 발생 확인
2. 웹 대시보드를 새로고침하여 펌프 기기 상태(배터리, 인슐린)가 0이 아닌 실제 값으로 나타나는지 확인
3. 앱에서 잔량이 변동되었을 때, 웹 대시보드에서도 즉각(새로고침 시) 반영되는지 확인
