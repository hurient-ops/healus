# 데이터 동기화 무결성 및 대시보드 정렬 수정 계획서

## 문제 요약 및 무결성 강화 목표
앱(App) -> 백엔드(DB) -> 웹 대시보드(Vercel)로 이어지는 데이터 파이프라인에서 "고아 데이터"나 "중복 데이터"가 발생하지 않도록 3단계(프론트-백-앱)에 걸쳐 **데이터 무결성과 정합성을 강제하는 엄격한 규칙**을 도입합니다.

## 제안하는 변경 사항

### 1. 모바일 앱(healus) - 데이터 송출 원천 통제 및 PID 강제화
앱에서 백엔드로 데이터를 보낼 때 **반드시 유효한 펌프 ID(PID)가 있어야만 전송되도록 원천 차단**합니다.

#### [MODIFY] [api_client.dart](file:///e:/projects/healus/lib/services/api/api_client.dart)
- `postBulkLogs` 및 `bufferRawPacket` 전송 직전에 `pumpId` 값을 엄격히 검사합니다.
- `pumpId`가 비어있거나(`""`), `"EMPTY"`, `"UNKNOWN_PID"`인 경우 **네트워크 요청(HTTP POST) 자체를 아예 실행하지 않고 차단(Drop 또는 Hold)** 합니다.

#### [MODIFY] [sync_queue_db.dart](file:///e:/projects/healus/lib/services/database/sync_queue_db.dart)
- PID 없이 앱에 임시 저장된 데이터들은 오프라인 큐에 대기합니다.
- 실제 펌프와 연결되어 진짜 PID를 획득하는 순간, 오프라인 큐에 쌓인 모든 미식별 패킷의 PID를 진짜 PID로 일괄 업데이트한 뒤에만 큐를 비워 서버로 전송합니다.

### 2. 백엔드(healus-backend) - DB 2차 방어 및 완벽한 Upsert 로직

#### [MODIFY] [logs.py](file:///e:/projects/healus-backend/api/logs.py)
- **API 게이트웨이 방어**: 앱에서 날아온 데이터의 `pump_id`가 유효하지 않은 경우 DB 접근을 불허하고 즉시 **400 Bad Request** 에러를 반환하여 쓰레기 데이터 유입을 2차로 차단합니다.
- **정합성(Upsert) 보장**: 유효한 펌프 ID가 들어오면 `users` 테이블을 조회해 정확한 `user_id`를 가져옵니다. 같은 `user_id`와 같은 `month`, `day`를 가진 데이터가 이미 존재한다면 **절대 새로 생성하지 않고 오직 기존 데이터를 업데이트(Update)** 하도록 철저하게 분기 처리합니다.

### 3. 프론트엔드 대시보드(healus-web) - 데이터 렌더링 무결성 및 정렬

#### [MODIFY] [dashboard.ts](file:///e:/projects/healus-web/api/dashboard.ts)
- 백엔드에서 데이터를 가져온 직후, `Dashboard.tsx` 차트로 넘겨주기 전에 데이터를 반드시 측정 날짜(`Date` 기준) 오름차순으로 정렬(Sort)합니다.
- 만약 DB에 예기치 못한 중복 날짜(동일한 7월 5일 데이터가 2개 등)가 존재하더라도, 프론트엔드 단에서 최신 데이터 하나만 남기고 중복을 자체 필터링하는 안전장치(Fallback)를 추가하여 UI 상에 차트가 겹치거나 뒤섞이는 일을 완벽히 방지합니다.

## 확인(Verification) 계획
- 모바일 앱의 펌프 ID를 고의로 제거한 뒤 전송 테스트를 진행하여, 앱 내부에서 전송이 차단되는지 확인합니다.
- 포스트맨(Postman) 등으로 백엔드에 빈 `pump_id` 데이터를 쏘아 정상적으로 차단(에러 반환)되는지 확인합니다.
- 프론트엔드 대시보드 차트가 날짜순으로 한 치의 오차 없이 정렬되어 예쁘게 렌더링되는지 확인합니다.
