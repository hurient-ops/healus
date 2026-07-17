# HealUs 가상 BLE 완료 패킷 트리거링 및 프록시 스트림 연동 구현 완료 보고서

주입 중 상태에서 3초 동안 정상 완료 패킷이 수신되지 않을 때, 테스트 모드로 전이 후 5초 뒤에 가상의 `BT_INJ_STOP_IND(0x3B)` 패킷을 네이티브 상에서 직접 방출(트리거)하여 정상 주입 완료 및 리다이렉트 흐름이 유기적으로 가동되도록 시뮬레이션을 구현하고 최종 검증을 완료하였습니다.

특히, 하드웨어 BLE 서비스에서 가상 Mock BLE 서비스로 전환될 때 수신 패킷/연결 스트림의 구독이 중단되는 문제를 **BleServiceManager** 프록시 도입을 통해 원천 해결하였습니다.

---

## 1. 주요 구현 내용

### 1) BleServiceManager 프록시 패턴 도입
- **[ble_service_provider.dart](file:///e:/projects/healus/lib/services/ble/ble_service_provider.dart)**:
  - `BleService` 인터페이스를 직접 위임(Proxying) 구현하는 `BleServiceManager` 클래스를 작성하였습니다.
  - 외부 컴포넌트(`main.dart`)는 `BleServiceManager`가 공급하는 단 하나의 브로드캐스트 스트림을 한 번만 구독하게 하여, 내부적으로 `testModeProvider`의 상태가 변경되어 `HardwareBleService`에서 `MockBleService`로 인스턴스가 전환되더라도 스트림 재구독 없이 자연스럽게 이벤트를 전달(forwarding)받도록 구조적인 안정성을 확보하였습니다.
  - 핸드셰이크 실패 시에 호출되는 `.disconnect()` 작업에 의해 `MockBleService` 가상 연결 상태가 꺼지는 것을 방지하도록, 테스트 모드일 때에는 `.disconnect()` 요청을 무시하는 예외 방어 처리를 추가했습니다.

### 2) MockBleService 가상 패킷 방출 퍼블릭 API 구현
- **[mock_ble_service.dart](file:///e:/projects/healus/lib/services/ble/mock_ble_service.dart)**:
  - `MockBleService` 내부에 `void fireFakeStopPacket()` 퍼블릭 메서드를 추가하였습니다.
  - 이 메서드는 주입 종류(`0x02` 식사), 현재 동기화 일자 DATE 패킷화, 모의 인슐린 설정값(`100` = 1.00U), 펌프 내부 가상 인슐린 잔량을 페이로드로 하는 20Byte 크기의 가상 `BT_INJ_STOP_IND(0x3B)` 패킷을 생성해 `_fireFakeIncomingPacket`을 거쳐 수신 패킷 스트림(`receivedPacketsStream`)으로 직접 방출합니다.
  - `// === [TEST MODE ONLY] ===` 주석 구역으로 코드를 완전하게 격리하여 추후 제거가 극히 용이합니다.

### 3) 주입 타임아웃 감시 및 가상 이벤트 트리거 연동
- **[main.dart](file:///e:/projects/healus/lib/main.dart)**:
  - `ref.listen(pumpStateProvider, ...)` 내의 주입 시작/종료 감지 흐름을 고도화했습니다:
    - **3초 타임아웃 감지**: 주입이 시작되었으나 3초 동안 완료 패킷이 오지 않으면, 자동으로 테스트 모드(`testModeProvider = true`)로 스위칭하고 웹뷰에 테스트 모드를 동기화합니다.
    - **5초 가상 완료 시뮬레이터**: 테스트 모드 진입 직후 5초 대기 타이머가 동작하며, 5초 만료 시점에 `MockBleService` 또는 `BleServiceManager`의 `fireFakeStopPacket()`을 직접 호출합니다.
  - **기대 효과**: 네이티브의 수신 패킷 스트림에 가상의 `0x3B`가 주입되면, 기존에 구축된 안전한 패킷 파이프라인과 `pumpStateProvider`의 정상 패킷 핸들러가 가동되어 주입 락 해제, 대시보드로의 정상 페이지 이동, 로컬스토리지 정리 및 대시보드 내 완료 멀티모달 팝업이 완벽하고 자연스럽게 작동합니다.

### 4) 자동 테스트 매크로 제어 플래그 추가
- **[main.dart](file:///e:/projects/healus/lib/main.dart)**:
  - 에뮬레이터 상에서 자동 매크로 동작이 끝없이 무한 루프를 도는 것을 방어하기 위해 `final bool _enableAutoMacro = false;` 제어 플래그를 추가하고 웹뷰 JS 자동화 코드를 해당 조건 하에 래핑하였습니다. 
  - 이를 통해 평상 시의 수동 조작 및 실제 릴리즈 사양의 연결 흐름을 완벽하게 지원하며, 자동 매크로 실행을 원할 때만 `true`로 켜서 테스트할 수 있도록 격리도를 향상시켰습니다.

---

## 2. 검증 및 테스트 결과 요약

### 1) 단위 테스트 검증
- 개선된 프록시 구조가 기존 유닛 테스트들에 영향을 끼치지 않는지 확인하기 위해 전체 테스트 세트를 실행하였고, 24개 테스트 전체가 성공적으로 패스됨을 검증했습니다.
```bash
$ flutter test
...
00:01 +24: All tests passed!
```

### 2) 에뮬레이터 흐름 검증 수행
- 앱 핫 리스타트 이후 최초 BLE 연결 실패 감지에 따른 테스트 모드 자동 스위칭(진입)을 검증했습니다.
- 비밀번호 입력창에 `000000` 입력 시 정상적으로 대시보드로 진입하도록 매칭 처리가 올바르게 수행되는 것을 확인했습니다.
- 식사 주입 실행 후 3초 동안 완료 패킷이 들어오지 않을 때 3초 타임아웃이 돌며, 5초 뒤 `BleServiceManager`와 `MockBleService`에 의해 가상의 주입 완료 패킷 `0x3B`가 정확한 스케일의 페이로드로 방출되어 대시보드 화면 위에 완료 팝업(OK 버튼) 모달이 정상 렌더링되고 흐름이 완료되는 전과정을 추적 로그를 통해 완벽히 입증하였습니다.

#### 검증 화면 증적 (에뮬레이터 스크린샷)
- 에뮬레이터 검증 결과 캡처 이미지(`screen.png`)는 같은 아티팩트 디렉토리에 저장되어 있으므로 파일 뷰어 등으로 확인 가능합니다. ([screen.png](file:///C:/Users/COMPANY/.gemini/antigravity-ide/brain/21c92c85-4f16-4a11-bc01-0e35252deed5/screen.png))

#### 에뮬레이터 실행 실제 로그
```text
I/flutter (22357): [DEBUG] BleServiceManager.forwardPacket: opcode=0x3a (mock)
I/flutter (22357): [DEBUG] main.dart _subscribeToBleService: received packet opcode=0x3a
I/flutter (22357): [DEBUG] main.dart pumpStateProvider listener: wasInjecting=false, isInjecting=true
I/flutter (22357): WebView loading: 10%
I/flutter (22357): WebView loading: 100%
I/flutter (22357): WebView loading: 100%
I/flutter (22357): 주입완료 메시지(0x3B)가 3초간 수신되지 않음 -> 테스트 모드 전환
I/flutter (22357): 테스트 모드 5초 대기 완료 -> 가상의 BLE 주입 완료 패킷(0x3B) 트리거
I/flutter (22357): Mock BLE 서비스: 가상의 주입 완료 패킷(0x3B)을 강제 트리거합니다.
I/flutter (22357): [DEBUG] BleServiceManager.forwardPacket: opcode=0x3b (mock)
I/flutter (22357): [DEBUG] main.dart _subscribeToBleService: received packet opcode=0x3b
I/flutter (22357): [DEBUG] main.dart pumpStateProvider listener: wasInjecting=true, isInjecting=false
```

---

## 3. 변경 이력 요약

| 파일명 | 변경 구분 | 상세 변경 내용 |
| :--- | :---: | :--- |
| [ble_service_provider.dart](file:///e:/projects/healus/lib/services/ble/ble_service_provider.dart) | **MODIFY** | 프록시 래핑 클래스 `BleServiceManager` 구현 도입 및 disconnect 차단 방어 로직 추가 |
| [mock_ble_service.dart](file:///e:/projects/healus/lib/services/ble/mock_ble_service.dart) | **MODIFY** | 가상 완료 패킷 `0x3B`를 스트림으로 방출하는 `fireFakeStopPacket()` 메서드 구현 추가 |
| [main.dart](file:///e:/projects/healus/lib/main.dart) | **MODIFY** | 5초 만료 시점에 `BleServiceManager`를 캐스팅하여 `fireFakeStopPacket()`을 호출하는 시뮬레이터 트리거 구현 및 `_enableAutoMacro` 플래그 추가 |
| [task.md](file:///C:/Users/COMPANY/.gemini/antigravity-ide/brain/21c92c85-4f16-4a11-bc01-0e35252deed5/task.md) | **MODIFY** | 가상 패킷 방출 연동 및 검증 태스크 최종 완료 마킹 |
| [walkthrough.md](file:///C:/Users/COMPANY/.gemini/antigravity-ide/brain/21c92c85-4f16-4a11-bc01-0e35252deed5/walkthrough.md) | **MODIFY** | 가상 BLE 패킷 방출 시뮬레이션 설계 및 프록시 스트림 도입 조치 결과 최종 업데이트 |
