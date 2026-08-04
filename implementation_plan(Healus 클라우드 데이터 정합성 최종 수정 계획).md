# Healus 클라우드 데이터 정합성 최종 수정 계획

앞선 분석 내용에 따라, **앱(Flutter)**이 데이터를 보낼 때 값은 제대로 `PID`를 쓰고 있으나, 통신용 JSON 키 이름이 구버전인 `device_mac`으로 남아 백엔드에서 에러(422)가 발생하는 문제를 수정합니다. 또한 **백엔드(Python)**가 로컬 DB(SQLite)를 사용하여 **웹(Supabase)**과 데이터가 단절된 핵심적인 아키텍처 결함을 수정하여 세 가지 프로젝트를 하나로 묶습니다.

---

## 🛠️ 수정 단계 (Proposed Changes)

### 1. 앱(Flutter) 페이로드 통신 규격 일치화
앱 내부에서 사용하는 모든 `device_mac` 변수 및 키 이름을 백엔드가 요구하는 `pump_id`로 변경합니다.

#### [MODIFY] `lib/services/api/api_client.dart`
- JSON Payload 조립 시 `"device_mac"` 키를 `"pump_id"`로 변경합니다.
- 함수의 파라미터명도 혼동을 막기 위해 `deviceMac`에서 `pumpId`로 수정합니다.

#### [MODIFY] `lib/services/database/sync_queue_db.dart`
- 로컬 오프라인 큐용 SQLite 테이블(`unsynced_packets`)의 컬럼명을 `device_mac`에서 `pump_id`로 변경합니다.
- `insertPacket` 메서드의 파라미터 역시 `pumpId`로 수정합니다.

#### [MODIFY] `lib/services/api/cloud_sync_service.dart`
- `RawPacketEvent` 객체 생성 시 전달하는 파라미터명을 `pumpId`로 변경하여 일관성을 맞춥니다.

---

### 2. 백엔드(Python) DB 클라우드 마이그레이션
현재 `healus.db`(로컬 SQLite)로 저장되는 구조를 파기하고, `healus-web`과 동일한 클라우드(Supabase) PostgreSQL DB로 데이터를 직접 밀어넣도록 수정합니다.

#### [MODIFY] `healus-backend/core/database.py`
- 기존 SQLite 연결 코드를 주석 처리(혹은 삭제)하고, 환경 변수(`.env`)에서 클라우드 데이터베이스 URL을 가져와 `SQLAlchemy`에 주입하도록 변경합니다.

---

### 3. 클라우드 서버 주소 설정 반영
앱이 테스트용 로컬 IP(`10.0.2.2`)가 아닌, 실제 배포된 서버를 바라보도록 설정합니다.

#### [MODIFY] `lib/config/cloud_config.dart`
- `serverBaseUrl` 값을 실제 운영 중인 Python 백엔드 클라우드 URL로 변경합니다.

---

## User Review Required (사용자님께서 알려주셔야 할 필수 정보)

> [!CAUTION]
> 위 2번과 3번 작업을 성공적으로 수행하기 위해, 작업을 시작하기 전 사용자님께서 **다음 두 가지 필수 정보**를 저에게 꼭! 알려주셔야 합니다.

**1. Supabase PostgreSQL 연결 문자열 (DB 주소)**
- 백엔드(`healus-backend`)가 클라우드 DB에 직접 접속하기 위해 필요합니다.
- Supabase 대시보드 [Project Settings -> Database -> Connection string (URI)] 에서 확인할 수 있는 아래와 같은 형태의 문자열이 필요합니다. (비밀번호 포함)
  - `postgresql://postgres.[프로젝트아이디]:[비밀번호]@aws-0-[리전].pooler.supabase.com:6543/postgres`

**2. 배포된 Python 백엔드 서버 URL (API 주소)**
- 앱(`healus`)이 데이터를 보낼 실제 도착지 주소입니다.
- 예: `https://api.healus.io` 또는 `https://healus-backend-xxx.herokuapp.com` 등 실제 백엔드가 배포된 주소가 필요합니다. (만약 아직 백엔드를 배포하지 않으셨다면, 로컬 환경에서 테스트할지 먼저 결정해 주세요.)

위 두 가지 정보를 채팅창에 입력해 주시면, 확인 후 1~3단계 코딩 작업을 즉시 시작하겠습니다!
