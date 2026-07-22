/// HealUs 인슐린 펌프 통신 Opcode 및 상수 정의
library;

/// 패킷 시작 코드
const int kStartCode = 0xEF;

/// 통신 Opcode (Message Type) 정의
class Opcodes {
  static const int btMsgRes = 0x00; // 요청에 대한 응답
  static const int btStartReq = 0x01; // 상호 BLE통신 시작 요청 (마이컴 -> 앱)
  static const int btConnectableCtrlReq = 0x02; // 상호 BLE통신 시작 요청 (앱 -> 마이컴)
  static const int btStateReq = 0x04; // 장치 상태 요청
  static const int btStateInd = 0x05; // 장치 상태 알림
  static const int btCurTimeInd = 0x06; // 현재 시간 정보 알림
  static const int btBattDataReq = 0x70; // 배터리 잔량 요청
  static const int btBattDataInd = 0x71; // 배터리 잔량 응답
  static const int btBattDataRes = 0x72; // 배터리 잔량 응답 (0x72)
  static const int btPumpPidReq = 0x09; // 펌프 PID 요청
  static const int btPumpPidRes = 0x0A; // 펌프 PID 응답
  static const int btPumpFwReq = 0x3E; // 펌프 FW 버전 요청
  static const int btPumpFwRes = 0x3F; // 펌프 FW 버전 전송
  static const int btDataStartInd = 0x0B; // 대량 패킷(이력데이터) 시작 알림
  static const int btDataEndInd = 0x0C; // 대량 패킷(이력데이터) 종료 알림
  static const int btStopCtrlReq = 0x0D; // 기기 일시 정지 제어 요청
  static const int btTimeBaseSetReq = 0x0F; // 시간별 기초 설정
  static const int btMealSetReq = 0x10; // 식사 설정
  static const int btSetRes = 0x12; // 설정 요청에 대한 응답
  static const int btExerciseSetReq = 0x13; // 운동모드 설정 및 주입
  static const int btReceptionSetReq = 0x14; // 회식모드 설정 및 주입
  static const int btInjInfoReq = 0x15; // 주입 선택 요청
  static const int btInjInfoRes = 0x16; // 주입 선택 응답
  static const int btInjReq = 0x17; // 인슐린 주입 요청
  static const int btInjStopReq = 0x37; // 주입 중 강제정지
  static const int btInjStartInd = 0x3A; // 주입 시작 알림
  static const int btInjStopInd = 0x3B; // 주입 완료 알림
  static const int btErrInd = 0x19; // 장치 오류 상태 알림
  static const int btLogReq = 0x1D; // 이력 데이터 요청
  static const int btLogInjQntReq = 0x1E; // 금일 주입량 정보 요청
  static const int btLogInjQntInd = 0x1F; // 금일 주입량 정보 응답
  static const int btLogInjSet1Ind = 0x20; // 현 주입 설정이력 정보1
  static const int btLogDataInd = 0x82; // 이력 데이터 전송 본문
  static const int btExerciseInjStartInd = 0x29; // 운동모드 시작 알림
  static const int btExerciseInjStopInd = 0x2A; // 운동모드 종료 알림
  static const int btReceptionInjStartInd = 0x2B; // 회식모드 시작 알림
  static const int btReceptionInjStopInd = 0x2C; // 회식모드 종료 알림
  static const int btEatValueReq = 0x2D; // 펌프 식사 설정값 요청
  static const int btEatValueRes = 0x2E; // 펌프 식사 설정값 전달
  static const int btBaseValueReq = 0x2F; // 펌프 기초 설정값 요청
  static const int btBaseValueRes = 0x30; // 펌프 기초 설정값 전달
  static const int btBaseValueInd = 0x40; // 기초 설정값 변경 시 전달
  static const int btPrsAppPasswdInd = 0x3C; // 기존 Passwd 정보 전달 (앱 -> 펌프)
  static const int btNewAppPasswdInd = 0x42; // 신규 Passwd 정보 전달 (펌프 -> 앱) - 사용자 요청 0x42 매핑 반영
  static const int btPrsAppPasswdReq = 0x41; // 현재 앱 PassWord 조회 요청 (앱 -> 인슐린펌프)
  static const int btPrsAppPasswdRes = 0x3D; // 현재 PassWord 전달 (인슐린펌프 -> 앱)
  static const int btSystemReset = 0x43; // 시스템 Reset (앱 -> 인슐린펌프)
  static const int btCurTimeRes = 0x44; // 앱으로부터 받은 시간을 앱에게 확인 (인슐린펌프 -> 앱)
}

/// 요청에 대한 응답 코드 (RES_CODE) 정의
enum ResCode {
  ok(0x00, "요청 처리 가능"),
  invalidStatus(0x01, "현재 상태에서 요청 처리 불가"),
  invalidParam(0x02, "요청의 메시지 매개변수가 잘못됨"),
  unknownMsg(0x03, "정의되지 않은 Message type"),
  canNotHandleMsg(0x04, "기타 이유로 요청 처리 불가");

  final int value;
  final String description;
  const ResCode(this.value, this.description);

  static ResCode fromValue(int val) {
    return ResCode.values.firstWhere(
      (e) => e.value == val,
      orElse: () => ResCode.canNotHandleMsg,
    );
  }
}

/// 펌프의 현재 상태 (Current State) 정의
enum PumpState {
  unknown(0x00, "알 수 없는 상태"),
  idle(0x01, "동작 대기"),
  injecting(0x02, "주입 중"),
  normalStop(0x03, "일반 정지"),
  replace(0x04, "교체 중"),
  errorPause(0x05, "오류 정지");

  final int value;
  final String description;
  const PumpState(this.value, this.description);

  static PumpState fromValue(int val) {
    return PumpState.values.firstWhere(
      (e) => e.value == val,
      orElse: () => PumpState.unknown,
    );
  }
}

/// 장치 발생 오류 (Error Type) 정의
enum PumpErrorType {
  none(0, "특이 사항 없음"),
  needleClogged(1, "주사기 바늘 막힘 (주사기 막힘)"),
  injFault(2, "주입 불가, 모터 이상 동작"),
  lowBatt(3, "배터리 부족"),
  pause(4, "오류 정지 상태 (일시정지 설정/해제 모드)"),
  insulShortage(5, "인슐린 잔량 부족"),
  injTimeOver(6, "시간 제한 (추가된 명령, 2~3시간 식사 제한)"),
  insulDayTotalOver(7, "1일 초과 (식사주입, 추가주입)"),
  insulUnitOver(8, "단위 초과 (식사주입)"),
  insulOnGoing(9, "인슐린 현재 주입 중"),
  unknownErr(0x0A, "원인 불명 에러");

  final int value;
  final String description;
  const PumpErrorType(this.value, this.description);

  static PumpErrorType fromValue(int val) {
    return PumpErrorType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => PumpErrorType.unknownErr,
    );
  }
}
