# [Healus Backend] 데이터베이스 저장 로직 구현 계획

앱이 전송하는 데이터를 단순히 수신만 하던 백엔드에, 실제 데이터베이스(SQLite/PostgreSQL)에 영구 기록하는 '저장소(DB) 로직'을 구축합니다.

## User Review Required

> [!IMPORTANT]
> **데이터베이스 설계안 승인 요청**
> 수신된 데이터를 저장하기 위해 다음과 같이 2개의 핵심 테이블을 구성하려고 합니다.
> 1. **`pump_logs` 테이블**: 이력 데이터 (일별 기초/식사 주입량 통계)
> 2. **`raw_packet_logs` 테이블**: 펌프와 앱 간의 모든 통신 원시 패킷 (TX/RX 패킷 헥사코드 및 타임스탬프)
> 
> **🏆 데이터베이스 선정: PostgreSQL**
> 사용자님의 요청에 따라 전 세계 엔터프라이즈(대기업)에서 가장 많이 사용하며, **100% 무료(오픈소스)이고 성능 및 안정성이 압도적인 `PostgreSQL`**을 최종 목표 DB로 선정했습니다. 특히 수많은 원시 패킷(로그)이 쌓이는 환경에 가장 최적화되어 있습니다.
> 
> *(참고: 현재 로컬 PC에서 즉시 테스트할 수 있도록 파이썬 내장형인 `SQLite`로 코드를 작성하지만, `SQLAlchemy`라는 기술을 쓰기 때문에 나중에 진짜 `PostgreSQL` 서버를 띄우면 코드 수정 없이 주소 한 줄만 바꾸면 1초 만에 완벽하게 호환 연동됩니다.)* 설계 방향에 동의하시나요?

## Proposed Changes

### 1. 데이터베이스 모델(테이블) 정의
#### [NEW] e:\projects\healus-backend\models\models.py
- SQLAlchemy ORM을 사용하여 파이썬 코드로 테이블 구조를 정의합니다.
- `PumpLog` 클래스 정의 (컬럼: id, mac, 날짜, 주입량 등)
- `RawPacketLog` 클래스 정의 (컬럼: id, mac, 방향, 패킷 헥사코드, 수신시간)

### 2. API 수신 창구에 DB Insert 로직 적용
#### [MODIFY] e:\projects\healus-backend\api\logs.py
- 현재 `print()`만 하고 끝나는 가짜 로직을 제거합니다.
- FastAPI의 의존성 주입(`Depends(get_db)`)을 사용해 데이터베이스 세션을 열고, 수신된 JSON 데이터를 DB 모델로 변환하여 `session.commit()`을 통해 영구 저장합니다.

### 3. 서버 구동 시 자동 테이블 생성 연동
#### [MODIFY] e:\projects\healus-backend\main.py
- 서버가 켜질 때 DB 파일(`healus.db`)을 확인하고, 테이블이 없다면 자동으로 `pump_logs`와 `raw_packet_logs` 테이블을 생성하도록 초기화 스크립트를 삽입합니다.

## Verification Plan

### Manual Verification
1. 코딩 완료 후 `uvicorn main:app --reload` 명령으로 서버를 재가동합니다.
2. 루트 폴더에 `healus.db`라는 물리적 데이터베이스 파일이 자동으로 생성되었는지 확인합니다.
3. 앱에서 동기화를 수행하거나 서버를 켜두고, DB 뷰어 프로그램(DBeaver 등)이나 스크립트로 실제 데이터가 표(Table) 형태로 예쁘게 쌓이는지 검증합니다.
