# Backend UUID 리팩토링 계획

현재 Integer(Auto-increment)로 설정된 `healus-backend`의 데이터베이스 Primary Key(PK)와 Foreign Key(FK)를 모두 UUID로 교체하는 아키텍처 리팩토링을 진행합니다.

## User Review Required
> [!IMPORTANT]
> - 기존의 `healus.db` SQLite 파일은 구조가 변경되므로 **삭제 후 새로 생성(초기화)** 됩니다.
> - 이전에 임시로 쌓아둔 더미 데이터가 있다면 모두 초기화되며, `seed_data.py`를 다시 실행해 깨끗한 UUID 기반의 더미 데이터 100일치를 다시 넣게 됩니다.
> - 진행해도 괜찮으신지 확인 부탁드립니다.

## Proposed Changes

### 1. `models/models.py`
PK를 String(36) 타입의 UUID로 변경합니다.
#### [MODIFY] models.py
- 모든 테이블(`User`, `PumpLog`, `RawPacketLog`, `BloodGlucoseLog`)의 `id` 컬럼 변경:
  `id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))`
- 관련된 모든 Foreign Key (`user_id`) 타입을 `String(36)`으로 변경.

### 2. `models/schemas.py`
클라이언트(앱)에서 선택적으로 UUID를 넘길 수 있도록 스키마를 유연하게 엽니다.
#### [MODIFY] schemas.py
- `PumpLogPayload` 및 `RawPacketPayload` 등 데이터 수신 스키마에 `id: Optional[str] = None` 필드를 추가합니다.

### 3. `api/logs.py`
앱에서 UUID를 주면 쓰고, 안 주면 자동 생성된 UUID를 쓰도록 라우터를 수정합니다.
#### [MODIFY] logs.py
- `PumpLog(id=log.id or str(uuid.uuid4()), ...)` 형태로 데이터를 넣을 때 안전하게 UUID를 처리합니다.

### 4. `healus.db` 삭제 및 초기화
구조적 변경이므로 마이그레이션 대신 기존 로컬 DB를 삭제합니다.
#### [DELETE] healus.db
- 파일 삭제 후 `seed_data.py`를 실행하면 UUID가 반영된 테이블이 새로 자동 생성되고 시드 데이터가 채워집니다.

## Verification Plan
### Automated Tests
- DB 초기화 후 `python seed_data.py` 명령어 실행 시 오류 없이 성공적으로 더미 데이터가 적재되는지 확인합니다.
- `seed_data.py` 결과 로그를 통해 UUID 형식의 유저가 정상 생성되었는지 터미널에서 검증합니다.
