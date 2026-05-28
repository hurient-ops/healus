# HealUS 인슐린 펌프 연동 앱 통합 개발 명세서 (PRD & TRD)

본 문서는 Antigravity IDE 환경에서 HealUS 인슐린 펌프 연동 모바일 애플리케이션을 개발하기 위한 통합 제품 요구사항 정의서(PRD) 및 기술 요구사항 정의서(TRD)이다. 본 명세서는 Antigravity 내장 AI 에이전트가 소스코드를 정밀하게 생성하고 구현할 수 있도록 구체적인 아키텍처와 프롬프트 가이드를 포함한다.

---

## 1. 프로젝트 개요 및 자원 환경

### 1.1 자원 경로 정의
* **UI/UX 디자인 및 코드 소스:** `.\ui_design`
    * 이미 완료된 UI 컴포넌트, 스타일시트, 화면 레이아웃 및 뷰 코드가 포함되어 있으며, 상태 관리자(State Manager)와의 바인딩만을 남겨둔 상태이다.
    * 버튼을 누르면 이동하는 화면과 멀티모달은 이미 완료된 상태이다.
    * 수신 데이터를 표현화는 것과 송신 데이터를 전송하는 기본 프레임은 갖추어진 상태이다.
* **통신 프로토콜 명세:** `In_pump_msg_set_260511.md` (v0.80 기반 사양 반영)
* **미디어 에셋 및 이미지 경로:** `.\media`
    * 펌프 오류 상태 알림, 주입 가이드 애니메이션 등에 사용되는 일러스트 및 아이콘 자원이 저장되어 있다.

### 1.2 개발 환경 특성 (Antigravity IDE)
* 본 프로젝트는 Antigravity IDE 내부의 AI 코딩 어시스턴트 기능을 적극 활용하여 개발한다.
* AI 에이전트의 컨텍스트 윈도우 한계를 고려하여, 복잡한 시스템 아키텍처를 원자적(Atomic) 단위의 프롬프트로 세분화하여 적용한다.

---

## 2. 제품 요구사항 정의서 (PRD)

### 2.1 핵심 기능 요구사항
1.  **안전한 디바이스 페어링 및 인증:** BLE 스캔을 통해 HealUS 펌프를 식별하고, 사용자 핀패드 UI를 통해 6자리 패스워드를 기기에 전달하여 인증 세션을 확립한다.
2.  **실시간 기기 상태 모니터링:** 펌프의 배터리 잔량, 인슐린 잔량, 현재 운용 상태(대기/주입중/오류)를 메인 대시보드 화면에 실시간으로 반영한다.
3.  **인슐린 주입 제어 시스템:** 식사 주입(아침, 점심, 저녁) 및 추가 주입(Bolus) 명령을 안전하게 전송하며, 주입 개시 전 사용자의 오조작을 방지하는 '더블 체크 모달'을 제공한다.
4.  **최우선 순위 긴급 정지 기능:** 주입 중 발생할 수 있는 비정상 상황에 대비하여, 앱 내 모든 화면에서 접근 가능한 최상위 '긴급 정지' 소프트웨어 버튼을 구현한다.
5.  **24시간 기초 주입(Basal) 설정:** 시간대별 기초 인슐린 주입량을 설정하고, 기기의 특성에 맞춰 분할 전송 및 동기화한다.
6.  **이력 데이터(Log) 시각화:** 펌프 내부 플래시 메모리에 저장된 최대 15일간의 주입 이력 데이터를 불러와 로컬 DB에 저장하고 차트로 렌더링한다.

### 2.2 사용자 시나리오 및 UI 흐름
* **인증 흐름:** 앱 실행 ➜ 펌프 자동 탐색 ➜ 6자리 PIN 입력 UI ➜ 패킷 송신 ➜ 인증 완료 후 홈 진입.
* **주입 락(UI Lock) 흐름:** 주입 명령 송신 ➜ 기기 상태 '주입 중(0x02)' 수신 ➜ 앱 내 긴급 정지 버튼을 제외한 모든 메뉴(설정, 히스토리 등) 및 입력 필드 터치 차단 오버레이 활성화 ➜ 주입 완료 패킷 수신 ➜ 오버레이 해제.

---

## 3. 기술 요구사항 정의서 (TRD)

### 3.1 논리 패킷 구조 (20Byte 고정)
모든 BLE 데이터 패킷은 다음과 같이 20Byte 고정 크기를 가지며, 일반적인 수치 데이터는 **Little-endian** 방식을 적용한다.

| Byte Index | 필드명 | 데이터 타입 | 값 및 설명 |
| :--- | :--- | :--- | :--- |
| `0` | Start Code | `uint8` | `0xEF` (모든 메시지의 시작점) |
| `1` | Type Code | `uint8` | Message Type (명령어 Opcode) |
| `2` | Data Length | `uint8` | 페로드의 실제 길이 (0 ~ 17). 0일 경우 데이터 없음. |
| `3 ~ 19` | Data Payload | `uint8[17]` | 메시지 타입별 가변 데이터. 남는 공간은 반드시 `0x00`으로 패딩. |

### 3.2 하드웨어 제약 극복: 10Byte 물리 분할 송수신 아키텍처
HealUS 펌프 칩셋의 하드웨어 버퍼 한계로 인해, 물리 계층에서는 **10Byte씩 2회 분할**하여 송수신해야 한다. 통신 서비스 계층(BLE Service Layer)에서 이를 논리적 20Byte 패킷으로 투명하게 조립/분할하는 브릿지 로직을 구현한다.

#### 3.2.1 수신 데이터 조립 (Rx Packet Assembly)
하드웨어 Rx 인터럽트 스트림으로부터 들어오는 10Byte 청크 데이터를 전역 링 버퍼에 적재한 후, 20Byte 단위로 프레임을 정렬한다.
**상세 의사코드 (Pseudocode):**
```dart
class BlePacketAssembler {
  final List<int> _rxBuffer = [];
  final StreamController<List<int>> _packetStreamController = StreamController<List<int>>.broadcast();

  Stream<List<int>> get packetStream => _packetStreamController.stream;

  void onChunkReceived(List<int> chunk) {
    if (chunk.length != 10) {
      // 비정상 물리 청크 인입 시 로그 기록 후 가비지 처리 방지
      return;
    }
    _rxBuffer.addAll(chunk);

    while (_rxBuffer.length >= 20) {
      // 1. 패킷 헤더(Start Code) 검증
      if (_rxBuffer[0] == 0xEF) {
        List<int> completePacket = _rxBuffer.sublist(0, 20);
        _rxBuffer.removeRange(0, 20);
        _packetStreamController.add(completePacket);
      } else {
        // 2. 프레임 동기화 유실 시 0xEF를 찾을 때까지 1바이트씩 쉬프트하며 복구
        _rxBuffer.removeAt(0);
      }
    }
  }
}
#### 3.2.2 송신 데이터 분할 (Tx Packet Split)
비즈니스 레이어에서 완성된 20Byte 패킷을 하드웨어 특성에 맞춰 10Byte씩 쪼개어 순차 송신하되, 마이컴의 오버플로우를 막기 위해 Tx 지연 마진을 강제한다.
Future<void> send20BytePacket(BluetoothCharacteristic characteristic, List<int> logicalPacket) async {
  if (logicalPacket.length != 20 || logicalPacket[0] != 0xEF) {
    throw ArgumentError("무결성이 깨진 잘못된 논리 패킷 요청입니다.");
  }

  List<int> firstChunk = logicalPacket.sublist(0, 10);
  List<int> secondChunk = logicalPacket.sublist(10, 20);

  // 1. 첫 번째 10Byte 송신
  await characteristic.write(firstChunk, withoutResponse: true);
  
  // 2. 하드웨어 처리 마진 확보를 위한 물리적 딜레이 블로킹 (30ms)
  await Future.delayed(const Duration(milliseconds: 30));

  // 3. 두 번째 10Byte 송신
  await characteristic.write(secondChunk, withoutResponse: true);
}

### 3.3 프로토콜 정합성 보안 및 취약점 패치 사항
기존 문서 분석 결과 발견된 모호성과 사양 오류를 다음과 같이 보정하여 코딩 에이전트에 반영한다.
1.  **인슐린 단위 스케일링(Scaling Factor):** 펌프 하드웨어는 소수점을 처리하지 못하므로, 주입량(`inj_val`)은 100을 곱한 정수 형태로 송수신한다. (예: 앱 UI 상의 1.25 Unit ➜ 패킷에는 `125`로 Little-endian 인코딩).
2.  **원인 불명 에러 코드 정의:** `BT_ERR_IND (0x19)` 패킷 처리 시 문서상 문자 'A'로 표기된 원인 불명 에러(`err_unknown_err`)는 실제 16진수인 `0x0A`로 매핑하여 파싱 로직을 작성한다.
3.  **DATE 타입 오타 수정:** `BT_INJ_INFO_RES (0x16)` 메시지 명세서 중 `set_date` 필드의 길이가 1Byte로 표기된 오류가 있다. 이는 다른 메시지와 동일하게 연, 월, 일, 시, 분, 초를 포함하는 **6Byte DATE 구조체**로 강제 할당하여 버퍼 오버런을 방지한다.

---

## 4. 화면 - 데이터 프로토콜 정밀 매핑 테이블

`E:\projects\healus\ui_design` 폴더 내 위젯들과 패킷 바이트 간의 정밀 매핑 테이블이다.

| UI 화면 / 컴포넌트 경로 | 제어 방향 | 메시지 타입 (Opcode) | 데이터 바이트 구조 및 파싱/직렬화 로직 |
| :--- | :---: | :--- | :--- |
| **Password/PIN 패드 화면**<br>`/lib/views/auth/pin_view.dart` | 앱 ➜ 펌프 | `BT_PRS_APP_PASSWD_IND (0x3C)` | `[3~8]`: 입력된 6자리 PIN 번호를 각각 1바이트 정수로 변환하여 위치시킴. |
| **홈 대시보드 - 상태바**<br>`/lib/views/home/widgets/status_bar.dart` | 펌프 ➜ 앱 | `BT_STATE_IND (0x05)` | `[3]`: `0x02` 수신 시 주입 중 애니메이션 및 **전역 UI 조작 락(Lock) 트리거** |
| **홈 대시보드 - 배터리 아이콘**<br>`/lib/views/home/widgets/battery.dart` | 펌프 ➜ 앱 | `BT_BATT_DATA_IND (0x71)` | `[3]`: `batt_level` 1Byte 수신 (`0x00`~`0x04`). 미디어 폴더 내 에셋으로 실시간 스왑 렌더링. |
| **주입 제어 바텀시트**<br>`/lib/views/inject/inject_sheet.dart` | 앱 ➜ 펌프 | `BT_INJ_REQ (0x17)` | `[4~5]`: 주입량 `inj_val` (UI에서 입력받은 Double 값에 x100을 한 후 2Byte Little-endian 직렬화) |
| **긴급 정지 버튼**<br>`/lib/views/common/emergency_btn.dart` | 앱 ➜ 펌프 | `BT_INJ_STOP_REQ (0x37)` | `[3]`: `pause_state` 1Byte에 `0x01(TRUE)` 세팅. 송신 버퍼 큐 최우선 재정렬. |
| **전역 오류 알럿 모달**<br>`/lib/views/common/error_overlay.dart` | 펌프 ➜ 앱 | `BT_ERR_IND (0x19)` | `[3]`: 에러 코드 1Byte 파싱. `[4~9]`: 에러 발생 시간 6Byte (DATE 타입) 파싱. |

---

## 5. Antigravity AI 에이전트 맞춤형 단계별 프롬프트 가이드

개발 시 Antigravity의 중앙 'Ask anything'창에 단계별로 붙여넣어 완벽한 소스코드를 빌드하도록 구성된 프롬프트 셋트이다.

### [Phase 1] 10Byte 청크 분할 BLE 통신 코어 및 패킷 핸들러 구현
**프롬프트 명령어:**
"Flutter환경에서 20Byte 논리 패킷을 하드웨어 특성에 맞춰 10Byte씩 분할 송수신하는 고신뢰성 BLE 통신 코어 클래스를 작성해라.
1. 수신부: 기기에서 10Byte 단위로 무작위 수신되는 스트림을 `List<int> _rxBuffer`에 계속 누적해라. 버퍼 크기가 20바이트 이상이 되면 선두 바이트가 `0xEF`인지 검증해라. `0xEF`가 맞으면 20바이트를 떼어내어 패킷 스트림으로 브로드캐스트하고 버퍼에서 삭제해라. 만약 `0xEF`가 아니면 동기화 유실로 간주하고 `0xEF`를 찾을 때까지 버퍼의 0번 인덱스를 `removeAt(0)`하며 쉬프트 복구하는 알고리즘을 완벽히 작성해라.
2. 송신부: 외부 비즈니스 레이어로부터 20Byte 패킷을 받으면, 이를 0~9 인덱스(10바이트)와 10~19 인덱스(10바이트)로 슬라이싱해라. 첫 청크를 write한 후, 하드웨어 버퍼 오버플로우 방지를 위해 `Future.delayed(Duration(milliseconds: 30))`를 강제 차단식으로 실행한 뒤 두 번째 청크를 전송하는 `sendPacket` 메서드를 구현해라.
3. 유틸리티: 모든 2바이트 이상 수치는 Little-endian 인코딩/디코딩 방식을 따르도록 유틸리티화해라."

### [Phase 2] UI 비즈니스 계층 상태 관리(Riverpod) 및 락(Lock) 메커니즘 빌드
**프롬프트 명령어:**
"프로젝트 경로 `E:\projects\healus\ui_design`에 구현된 UI 컴포넌트들과 연동할 전역 상태 관리 엔진(Riverpod StateNotifier 기반)을 작성해라.
1. `BT_STATE_IND (0x05)` 패킷의 3번째 바이트인 `cur_state`를 실시간 모니터링하는 State를 구축해라. 해당 값이 `0x02 (state_inj)`로 변하면 앱의 전역 상태 변수 `isPumpInjecting`을 `true`로 셋업해라.
2. `isPumpInjecting`이 `true`일 때, 대시보드 화면 전체에 불투명 레이어 오버레이를 씌워 터치 이벤트를 완전히 차단(UI Lock)해라. 단, 이 상황에서도 메인 화면 하단의 '긴급 정지 버튼'은 터치 차단 대상에서 제외되어 언제든 즉시 호출 가능해야 한다."

### [Phase 3] 정밀 주입 제어 및 선점형(Preemption) 긴급 정지 트랜잭션 구현
**프롬프트 명령어:**
"인슐린 주입 요청과 소프트웨어 긴급 정지 비즈니스 로직을 구현해라.
1. 주입 컴포넌트에서 사용자가 주입량(예: 2.5 Unit)을 입력하면, 소수점 처리를 위해 소스코드 내부에서 100을 곱해 정수(`250`)로 변환해라. 이 정수값을 Little-endian 2바이트로 직렬화하여 `BT_INJ_REQ (0x17)` 패킷 레이아웃의 4~5번 바이트에 적재하고 전송 큐에 삽입하는 함수를 만들어라.
2. 사용자가 긴급 정지 버튼을 터치하면 `BT_INJ_STOP_REQ (0x37)` 패킷 데이터 필드에 `0x01`을 셋팅해라. 이 패킷은 대기 중인 다른 모든 제어/조회 패킷 순서를 무시하고, 송신 큐의 최선두로 배치(선점형 패킷 큐 관리)되어 지체 없이 10Byte 분할 송신 함수로 전달되도록 코딩해라."

### [Phase 4] 복합 대량 데이터 전송 처리 체인 및 히스토리 차트 파이프라인
**프롬프트 명령어:**
"기초 설정 대량 동기화 및 펌프 로그 수집 파이프라인을 구축해라.
1. 사용자가 24시간 치 기초 주입을 설정하고 저장하면, 앱은 `BT_TIME_BASE_SET_REQ (0x0F)` 명세서에 맞춰 데이터를 4시간 분량(8Byte)씩 6개의 독립 패킷으로 쪼개야 한다. 첫 패킷 송신 후 펌프로부터 정상 응답(RES_OK)을 확인하면 다음 순번 패킷을 체인 방식으로 연쇄 송신하는 비동기 시퀀스 루프를 안전하게 구현해라.
2. 이력 데이터 요청(`BT_LOG_REQ, 0x1D`) 후 대량 데이터 모드로 전환해라. 이후 들어오는 14Byte 이력 패킷 스트림을 수집하여 로컬 SQLite DB 테이블에 벌크 인서트하고, 홈 화면의 주입 히스토리 차트 위젯에 데이터를 갱신 매핑해라."

### [Phase 5] 전역 안전 에러 인터셉터 및 미디어 에셋 매핑 시스템 개발
**프롬프트 명령어:**
"의료 안정성 기준을 충족하기 위한 전역 에러 인터셉터와 미디어 에셋 바인딩 모듈을 구현해라.
1. 앱 내의 라우팅 네비게이션 위치와 무관하게 백그라운드 BLE 리스너에서 `BT_ERR_IND (0x19)` 패킷이 인터셉트되면 즉시 최상위 오버레이 팝업 위젯을 강제로 호출해라.
2. 패킷 3번 바이트의 에러 유형 값을 명확한 Enum 구조체로 매핑해라. 특히 문서상 오타나 표기 오류가 있는 원인 불명 에러는 `0x0A`로 완전하게 예외 파싱 처리해라.
3. 각 에러 Enum에 대응하여 `G:\2026년\05.개발\앱 신규개발\media` 폴더 내의 일러스트 에셋 경로를 리턴하는 매핑 헬퍼 클래스를 작성해라. 에러 시간(6Byte DATE) 값을 디코딩하여 에러 모달 창 하단에 포맷팅 출력해라."