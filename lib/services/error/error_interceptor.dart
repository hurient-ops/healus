import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/opcodes.dart';
import '../ble/packet_parser.dart';

/// 전역 에러 인터셉터의 상태 모델
class PumpErrorState {
  /// 발생한 펌프 오류 유형 (Enum)
  final PumpErrorType errorType;

  /// 에러가 발생한 시각 (기기에서 6Byte DATE 데이터로 전달됨)
  final DateTime errorTime;

  /// 현재 에러가 발생한 경고 상태인지 여부 (UI 팝업 노출 트리거)
  final bool hasError;

  PumpErrorState({
    required this.errorType,
    required this.errorTime,
    this.hasError = false,
  });

  /// 에러가 없는 초기 대기 상태 팩토리
  factory PumpErrorState.none() {
    return PumpErrorState(
      errorType: PumpErrorType.none,
      errorTime: DateTime(2000, 1, 1),
      hasError: false,
    );
  }
}

/// 백그라운드 BLE 스트림 리스너에서 패킷을 인터셉트하여 에러 패킷(0x19) 발생 시 즉시 감지하는 인터셉터
class ErrorInterceptor extends StateNotifier<PumpErrorState> {
  ErrorInterceptor() : super(PumpErrorState.none());

  /// 들어오는 20Byte 패킷을 분석하여 BT_ERR_IND(0x19)인 경우 즉시 에러 상태로 전이합니다.
  void interceptPacket(List<int> packet) {
    if (packet.length != 20 || packet[0] != kStartCode) {
      return;
    }

    final int opCode = packet[1];
    final int dataLen = packet[2];

    if (opCode == Opcodes.btErrInd) {
      if (dataLen >= 1) {
        final int errVal = packet[3];
        // 16진수 0x0A(원인 불명 에러) 예외 파싱 바인딩 완료
        final errorType = PumpErrorType.fromValue(errVal);

        // 에러 발생 시간 6Byte DATE 디코딩
        DateTime errorTime;
        if (dataLen >= 7) {
          errorTime = PacketParser.parseDate(packet, offset: 4);
        } else {
          errorTime = DateTime.now();
        }

        // 전역 상태에 전파
        state = PumpErrorState(
          errorType: errorType,
          errorTime: errorTime,
          hasError: true,
        );
      }
    }
  }

  /// 사용자가 오류 확인 버튼을 터치하여 경고 오버레이를 해제합니다.
  void clearError() {
    state = PumpErrorState.none();
  }

  /// 임의의 테스트 에러를 유도하는 헬퍼 (UI 검증용)
  void setErrorForce(PumpErrorType type, DateTime time) {
    state = PumpErrorState(
      errorType: type,
      errorTime: time,
      hasError: true,
    );
  }
}

/// 전역 에러 인터셉터 프로바이더
final errorInterceptorProvider =
    StateNotifierProvider<ErrorInterceptor, PumpErrorState>((ref) {
  return ErrorInterceptor();
});
