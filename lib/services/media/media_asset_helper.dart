import '../ble/opcodes.dart';

/// 각 에러 상태(PumpErrorType)에 부합하는 .\media 하위 폴더 내 일러스트 및 이미지 에셋 경로 매핑 헬퍼
class MediaAssetHelper {
  /// 지정된 에러 유형에 대응하는 일러스트 이미지 에셋 경로를 리턴합니다.
  static String getErrorIllustration(PumpErrorType errorType) {
    switch (errorType) {
      case PumpErrorType.needleClogged:
        return 'media/error_needle_clogged.png';
      case PumpErrorType.injFault:
        return 'media/error_inj_fault.png';
      case PumpErrorType.lowBatt:
        return 'media/error_low_batt.png';
      case PumpErrorType.pause:
        return 'media/error_pause.png';
      case PumpErrorType.insulShortage:
        return 'media/error_insul_shortage.png';
      case PumpErrorType.injTimeOver:
        return 'media/error_time_over.png';
      case PumpErrorType.insulDayTotalOver:
        return 'media/error_day_total_over.png';
      case PumpErrorType.insulUnitOver:
        return 'media/error_unit_over.png';
      case PumpErrorType.insulOnGoing:
        return 'media/error_on_going.png';
      case PumpErrorType.unknownErr:
        return 'media/error_unknown.png'; // 0x0A 원인 불명 에러
      case PumpErrorType.none:
      default:
        return 'media/error_normal.png';
    }
  }
}
