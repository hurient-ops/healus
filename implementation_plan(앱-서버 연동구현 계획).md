# [Healus Cloud] 앱-서버 연동 구현 계획

현재 새롭게 분리된 `healus-cloud` 앱과 `healus-backend` 서버를 연결하기 위한 클라이언트 통신(API) 구현 계획입니다.

## User Review Required

> [!IMPORTANT]
> **원시 패킷(Raw Packet) 실시간 전송 관련 성능 검토**
> 블루투스로 통신하는 모든 패킷을 실시간으로 서버에 쏠 경우(예: 1초에도 여러 번 통신 시), 앱과 서버에 부하가 발생할 수 있습니다. 
> 즉시 실시간으로 쏘는 대신, 앱 내부 메모리에 쌓아두었다가 **10개씩 모아서 쏘거나(Batch)** 특정 이벤트 발생 시 한 번에 쏘는 방식이 안전합니다.
> 일단 본 계획에서는 가장 확실한 **"로그 동기화(`0x82`) 완료 시 대량 전송"** 기능부터 먼저 구축하는 것을 제안합니다. 동의하시나요?

## Open Questions

> [!WARNING]
> 1. 현재 로컬 환경에서 테스트 중이므로 백엔드 주소는 `http://10.0.2.2:8000` (에뮬레이터) 또는 내부망 IP(`http://192.168.x.x:8000`)를 사용해야 합니다. 실제 테스트 기기 환경을 알려주시면 맞춰서 적용하겠습니다.
> 2. **[매우 중요] 두 버전 간 코드 동기화 방식 결정**
> 사용자님께서 지적하신 대로, 폴더를 2개로 나누면 한쪽 코드를 수정할 때 다른 쪽도 똑같이 수정해 줘야 하는 치명적인 단점(유지보수 지옥)이 발생합니다. 이를 해결하기 위해 현업에서는 폴더를 2개로 나누지 않고 다음과 같은 방법을 씁니다.
>    * **추천안 (단일 코드베이스 + 스위치):** 폴더를 분리하지 않고 기존 `healus` 폴더 하나만 유지하되, 코드 내부에 `const bool enableCloudSync = true/false;` 라는 스위치를 만듭니다. 스위치가 꺼지면 기존과 똑같이 100% 오프라인으로 동작하고, 켜지면 서버와 통신합니다. (코드 1개로 두 버전 모두 완벽 관리 가능)
>    * **대안 (Git 브랜치):** `healus` 폴더 안에서 `main` 브랜치(오프라인)와 `cloud` 브랜치(온라인)를 나누어 관리하고, 공통 수정 사항은 `git merge`를 통해 병합합니다.
>    * 폴더 2개(`healus`, `healus-cloud`) 체제를 꼭 유지하셔야 한다면, 윈도우용 소스 비교 프로그램(Beyond Compare 등)을 쓰시거나 제가 변경된 파일만 복사해 드리는 수작업을 해야 합니다.
> 
> 가장 유지보수가 편하고 완벽한 **'추천안 (단일 코드베이스 + 클라우드 스위치 적용)'** 방식으로 방향을 틀어서 진행하는 것이 어떨까요?

## Proposed Changes

### 1. 100% 비결합형(Decoupled) 단일 코드베이스 (앱 원본 훼손 제로)
#### [NEW] lib/config/cloud_config.dart
- `const bool enableCloudSync = true;` (클라우드 연동 스위치)
- **핵심 보장 (사용자님 걱정 해결):** 앱의 기존 핵심 로직(BLE 통신, UI 등)에 서버로 데이터를 쏘는 코드를 덕지덕지 붙이지 않습니다! 대신 **'관찰자(Observer) 패턴'**을 사용하여, 기존 코드는 그저 "나 지금 패킷 보냈어~" 하고 방송(Stream)만 하게 둡니다.
- 뒤에서 조용히 숨어있던 `CloudSyncService`가 이 방송을 몰래 듣고 있다가 알아서 서버로 전송합니다. 따라서 나중에 앱 본연의 기능을 수정하실 때, **서버 연동 코드가 얽혀서 복잡해지는 일이 절대 발생하지 않습니다.** (스위치를 끄면 아예 방송을 듣지 않으므로 완벽히 이전 상태와 동일합니다.)

### 2. HTTP 통신 패키지 추가
#### [MODIFY] pubspec.yaml
- `http: ^1.2.0` 패키지를 추가하여 백엔드 서버(API)와의 REST 통신 기반을 마련합니다.

### 3. 서버 통신 전용 서비스(API Client) 구축
#### [NEW] lib/services/api/api_client.dart
- `postBulkLogs(List<PumpLogModel> logs)`: 이력 데이터 대량 전송
- `postRawPackets(List<RawPacket> packets)`: 모든 블루투스 원시 패킷(TX/RX) 일괄 전송

### 4. 모든 송수신 패킷(Raw Data) 서버 전송 (버퍼링 적용)
#### [MODIFY] lib/services/ble/ble_packet_transmitter.dart (송신)
- 앱에서 펌프로 패킷을 쏠 때(`TX`)마다 `api_client`의 버퍼에 패킷 데이터를 저장합니다.
#### [MODIFY] lib/services/ble/mock_ble_service.dart (또는 실 기기 수신부)
- 펌프에서 앱으로 패킷이 들어올 때(`RX`)마다 `api_client`의 버퍼에 저장합니다.
- **최적화:** 앱 버벅임 방지를 위해 즉시 전송하지 않고, 버퍼에 10개 이상 쌓이거나 3초가 지나면 백그라운드에서 한 번에 서버로 쏩니다.

### 5. 백엔드 스키마 및 API 확장 (`healus-backend`)
#### [MODIFY] `e:\projects\healus-backend\models\schemas.py` & `api\logs.py`
- 원시 패킷(`RawPacket`)을 받을 수 있는 엔드포인트 `/api/raw_logs`를 추가하여 수신된 바이트 데이터를 데이터베이스에 기록할 준비를 마칩니다.

## Verification Plan

### Automated Tests
- 없음

### Manual Verification
1. `healus-backend` 서버를 켜둡니다.
2. `healus-cloud` 앱을 실행하여 이력 데이터 동기화(`0x1D`)를 수행합니다.
3. 동기화가 완료되면, 백엔드 터미널 창에 `Received 14 logs from device...` 와 같은 성공 로그가 뜨는지 확인하여 앱-서버 연동을 검증합니다.
