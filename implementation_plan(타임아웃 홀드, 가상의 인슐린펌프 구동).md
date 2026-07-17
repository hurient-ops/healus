# 인슐린 펌프 가상 BLE 패킷 제어 고도화 및 연동 구현 계획서

이 계획서는 HealUs 모바일 앱과 인슐린 펌프 간의 가상/실제 BLE 패킷 파싱 로직을 정비하고, 비밀번호 및 기초 설정의 실시간 동기화 문제를 해결하며, 수동 디버깅의 편의성을 향상시키기 위한 구체적인 구현 방안을 다룹니다.

---

## 1. User Review Required (사용자 검토 필요 사항)

> [!IMPORTANT]
> **비밀번호 디코딩 방식의 근본적 개정**
> - 기존: 패킷 바이트 값을 아스키 문자로 변환하여 관리 (예: `0x31` -> `"1"`).
> - 변경: 기획서 ver 260608 예시(`EF 42 06 01 02 03 04 05 06 ...` -> `"123456"`)에 따라, 바이트 원시 값 자체를 10진수 문자열로 변환하여 결합합니다 (`0x01` -> `"1"`, `0x00` -> `"0"`).
> - 이에 따라 비밀번호 수동 주입 시 `ef 42 06 01 02 03 04 05 06 ...` 형식의 바이트 값을 사용해 비밀번호 `"123456"`을 테스트할 수 있게 됩니다.

> [!WARNING]
> **타임아웃 일시 정지(Hold) 활성화 시 동작 영향**
> - "타임아웃 홀드" 플래그가 켜지면 물리적인 연결 타임아웃(3초) 및 패킷 재조립 타임아웃(500ms)이 무제한(365일)으로 변경되어 에러 발생 및 자동 테스트 모드 전이가 억제됩니다.
> - 수동 디버깅 완료 후에는 반드시 토글을 비활성화하여 정상 자동 롤백 및 방어 흐름이 기동되도록 원복해주어야 합니다.

---

## 2. Proposed Changes (제안된 변경 사항)

### A. 비밀번호 및 인슐린 잔량 파싱 로직 수정
- **파일**: [pump_state_provider.dart](file:///e:/projects/healus/lib/state/pump_state_provider.dart)
  - `case Opcodes.btPrsAppPasswdRes:` / `case Opcodes.btNewAppPasswdInd:` 의 문자 변환 코드를 `passwordBytes.map((b) => b.toString()).join('')`으로 개정하여 원시 숫자로 동기화합니다.
  - `insul_remain` 파싱 바이트 인덱스를 기획서(ver 260608) 기준으로 정확하게 고정합니다.
    - `BT_SET_RES` (0x12): 마지막 2byte (9번째, 10번째 -> 0-based index `9, 10` 번 바이트). 기존 `PacketParser.readUint16(packet, 9)` 유지.
    - `BT_INJ_INFO_RES` (0x16): 마지막 2byte (12번째, 13번째 -> 0-based index `12, 13` 번 바이트). 기존 `PacketParser.readUint16(packet, 12)` 유지.
    - `BT_INJ_STOP_IND` (0x3B): 마지막 2byte (12번째, 13번째 -> 0-based index `12, 13` 번 바이트). 기존 `PacketParser.readUint16(packet, 12)` 유지.

### B. 실시간 웹뷰 데이터 피드백 동기화 및 기초 설정 화면 연동
- **파일**: [main.dart](file:///e:/projects/healus/lib/main.dart)
  - `ref.listen(pumpStateProvider, ...)` 내에서 인슐린 잔량, 배터리, 기초 설정값, 주입 중 상태 등 핵심 필드의 값 변동을 감지할 때마다 `_syncStateToWebview()`를 강제 기동하여 대시보드 웹뷰(`val-insulin` 및 `bar-insulin` 프로그레시브 바)를 실시간 갱신합니다.
  - 웹뷰와의 브릿지 인터페이스(`_handleConsoleMessage`)를 보강합니다:
    - `"REQUEST_BASAL_RATES"` 수신 시: 네이티브 상태의 `basalRates` 배열을 웹뷰로 전달하는 `window.receiveBleBasalData` JS 함수 실행.
    - `"UPDATE_BASAL_RATES: [...]"` 수신 시: 웹뷰에서 수정된 시간대별 값을 실시간 파싱하여 네이티브 공통 상태(`pumpStateProvider`)에 강제 업데이트.
- **파일**: [basal_setting/code.html](file:///e:/projects/healus/ui_design/basal_setting/code.html)
  - 웹뷰 로딩 완료 시 콘솔로 `"REQUEST_BASAL_RATES"` 메시지를 출력하여 네이티브에서 최신 기초 설정값을 밀어주도록 역요청하는 핸드셰이크를 구현합니다.
  - 설정 버튼 터치(`setValues`) 및 저장 버튼 터치(`save`) 시마다 콘솔로 `"UPDATE_BASAL_RATES: [...]"` 메시지를 발송하여 수정한 즉시 네이티브 상태와 공유되도록 연동합니다.

### C. BLE 송신 패킷 기록 및 수동 디버그 컨트롤 (Hold) UI 추가
- **파일**: [ble_service_provider.dart](file:///e:/projects/healus/lib/services/ble/ble_service_provider.dart)
  - `final timeoutHoldProvider = StateProvider<bool>((ref) => false);` 전역 타임아웃 홀드 플래그 추가.
  - `final sentPacketsLogProvider = StateProvider<List<String>>((ref) => []);` 전역 BLE 송신 패킷 이력 로그 프로바이더 추가.
  - `BleServiceManager.sendPacket`이 호출될 때마다 송신한 패킷 바이트를 포맷팅하여 타임스탬프와 함께 최근 20개 내역을 로그 프로바이더에 적재합니다.
  - `BleService` 인터페이스에 `void setBypassTimeoutHold(bool hold);` 메서드를 선언하고, `HardwareBleService`/`MockBleService`/`BleServiceManager`에 맞춤형 바인딩을 추가합니다.
- **파일**: [ble_packet_assembler.dart](file:///e:/projects/healus/lib/services/ble/ble_packet_assembler.dart)
  - `bool bypassTimeoutHold = false;` 변수를 추가하여, 활성화 시 500ms 재조립 만료 타이머 기동을 전면 억제합니다.
- **파일**: [ble_handshake_controller.dart](file:///e:/projects/healus/lib/services/ble/ble_handshake_controller.dart)
  - `timeoutHoldProvider`가 활성화되어 있는 동안에는 핸드셰이크 내의 모든 `connect` 및 `_waitForPacket` 대기 타임아웃을 `const Duration(days: 365)`으로 우회 적용하여 수동 데이터 조작 중의 세션 해제를 방지합니다.
- **파일**: [main.dart](file:///e:/projects/healus/lib/main.dart)
  - `_showDebugPacketDialog()` 다이얼로그 UI를 리팩토링합니다:
    - **타임아웃 홀드 토글**: 스위치를 추가해 `timeoutHoldProvider`와 연동하고, 변경 시 `bleServiceProvider.setBypassTimeoutHold`를 동기 호출합니다.
    - **송신 패킷 기록 패널**: 다이얼로그 하단에 스크롤 가능한 최근 20개 송신 패킷 텍스트 리스트를 출력하여 앱이 가상/실제 펌프로 송신한 패킷 내역을 즉각 모니터링할 수 있도록 제공합니다.

---

## 3. Verification Plan (검증 계획)

### Automated Tests
- `test/pump_state_provider_test.dart`의 비밀번호 검증 케이스를 원시 숫자 기반 패킷 예시(`0x01, 0x02...` -> `"123456"`)로 수정하여 단위 테스트를 통과시킵니다.
  - 명령어: `flutter test test/pump_state_provider_test.dart`

### Manual Verification
1. **비밀번호 수동 주입**:
   - `ef 42 06 01 02 03 04 05 06 00 00 00 00 00 00 00 00 00 00 00` 패킷 주입 시 비밀번호가 `"123456"`으로 올바르게 반영되고 대시보드로 리다이렉트되는지 확인합니다.
2. **인슐린 잔량 연동**:
   - `0x12`, `0x16`, `0x3B` 수신 시 마지막 2바이트 값이 대시보드의 잔량 및 프로그레시브 바에 동적으로 갱신되는지 수동 주입 테스트를 통해 검증합니다.
3. **기초 설정 전역 보존**:
   - 기초 설정 페이지에서 값을 수정하고 뒤로 갔다가 다시 진입했을 때, 혹은 앱의 다른 화면으로 이동했다가 복귀해도 최종 수정된 기초 설정값이 유지 및 표시되는지 확인합니다.
4. **수동 디버깅 및 타임아웃 홀드**:
   - 디버그 다이얼로그에서 "타임아웃 홀드"를 활성화한 상태에서 장치 연결 지연이나 분할 패킷 누락 시 세션 단절이나 오류 페이지 이동이 홀딩되는지 확인합니다.
   - 하단의 송신 로그 패널에 실제 발송된 패킷들이 타임스탬프와 함께 안정적으로 기록 및 출력되는지 검증합니다.
