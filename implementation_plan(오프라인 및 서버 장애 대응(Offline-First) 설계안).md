# [Healus App] 오프라인 및 서버 장애 대응(Offline-First) 설계안

스마트폰의 통신 불가(WiFi/LTE 단절) 및 백엔드 서버 장애(서버 다운, 응답 없음) 상황에서도 의료 데이터(인슐린 펌프 패킷)가 절대 유실되지 않도록 **앱 내부에 완벽한 오프라인 큐(Offline Queue) 시스템**을 구축합니다.

## User Review Required

> [!IMPORTANT]
> **오프라인 우선(Offline-First) 설계 승인**
> 이 설계가 적용되면 앱은 더 이상 서버로 '직접' 전송하지 않습니다. 무조건 '내 폰(로컬 DB)'에 먼저 저장한 뒤, 폰이 알아서 백그라운드에서 서버와 통신하며 동기화를 시도합니다.
> 이 방식은 생명과 직결된 헬스케어 앱의 글로벌 표준입니다. 이 아키텍처 도입에 동의하신다면 하단의 **'Proceed(승인)'**를 눌러주세요.

## Proposed Changes

### 1. 로컬 큐 데이터베이스(SQLite) 구축
현재 앱에 이미 설치된 `sqflite` 패키지를 활용하여 '미전송 데이터 보관소'를 만듭니다.

#### [NEW] e:\projects\healus\lib\services\database\sync_queue_db.dart
- `unsynced_packets` 테이블 생성
- 컬럼: `id`, `device_mac`, `direction`, `payload_hex`, `timestamp`
- 역할: 블루투스 패킷이 들어올 때마다 무조건 이 로컬 테이블에 먼저 Insert(저장)합니다.

### 2. ApiClient 전송 로직 및 장애 처리(Retry) 전면 개편
네트워크 단절 및 서버 응답 없음(Timeout, 500 Error 등)을 완벽하게 방어하도록 전송기를 뜯어고칩니다.

#### [MODIFY] e:\projects\healus\lib\services\api\api_client.dart
- **기존 방식:** 데이터를 메모리(변수)에 담아뒀다가 바로 서버로 전송 시도 ➔ 실패 시 허공에 증발.
- **변경 방식:** 
  1. 데이터를 메모리가 아닌 `SyncQueueDB`에 물리적으로 저장.
  2. 서버로 전송(`http.post`) 시도.
  3. **장애 발생 (서버 다운, 와이파이 끊김 등):** 전송 시도를 멈추고 `SyncQueueDB`에 데이터는 그대로 안전하게 둡니다. (사용자에게는 "오프라인 상태로 저장됨" 내부 처리)
  4. **재시도(Retry) 메커니즘:** 앱 구동 중 주기적(예: 1분마다)으로 또는 다음 데이터가 들어올 때 `SyncQueueDB`에 쌓인 미전송 데이터를 다시 꺼내어 벌크(Bulk) 전송 시도.
  5. **전송 성공 (HTTP 200):** 성공한 데이터만 `SyncQueueDB`에서 삭제(Delete).

### 3. 필수 패키지 추가 (네트워크 상태 감지)
#### [MODIFY] e:\projects\healus\pubspec.yaml
- `connectivity_plus`: 스마트폰이 오프라인 상태인지 서버 장애인지 구분하고, 인터넷이 복구되는 순간 즉시 재전송(Sync)을 트리거하기 위해 패키지를 추가합니다.

## Verification Plan
1. `connectivity_plus` 패키지 설치 및 로컬 DB 테이블 생성을 확인합니다.
2. 백엔드 서버를 강제로 끈 상태(장애 상황 시뮬레이션)에서 앱을 구동하여 펌프 패킷을 수신합니다.
3. 데이터가 날아가지 않고 스마트폰 내부 DB에 안전하게 보관되는지 로그로 확인합니다.
4. 백엔드 서버를 다시 켜고(복구 시뮬레이션) 인터넷을 연결했을 때, 폰에 고여있던 패킷들이 서버로 일제히(Bulk) 성공적으로 날아가는지 검증합니다.
