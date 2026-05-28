import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healus/services/ble/opcodes.dart';
import 'package:healus/services/error/error_interceptor.dart';
import 'package:healus/services/media/media_asset_helper.dart';

void main() {
  group('ErrorInterceptor & MediaAssetHelper Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('초기에는 에러가 없는 상태를 유지한다', () {
      final state = container.read(errorInterceptorProvider);
      expect(state.hasError, false);
      expect(state.errorType, PumpErrorType.none);
    });

    test('BT_ERR_IND 패킷 수신 시 오류 타입 및 기기 오류 날짜를 디코딩하여 전역 경고 상태를 설정한다', () {
      final interceptor = container.read(errorInterceptorProvider.notifier);

      // 주사기 바늘 막힘 (err_type = 1) 패킷 세팅
      // DATE: 17년 9월 8일 7시 5분 35초 -> [17, 9, 8, 7, 5, 35]
      final errPacket = List<int>.filled(20, 0);
      errPacket[0] = kStartCode;
      errPacket[1] = Opcodes.btErrInd;
      errPacket[2] = 7; // dataLen
      errPacket[3] = 1; // err_type = 1 (needleClogged)
      errPacket[4] = 17; // Year
      errPacket[5] = 9;  // Month
      errPacket[6] = 8;  // Day
      errPacket[7] = 7;  // Hour
      errPacket[8] = 5;  // Min
      errPacket[9] = 35; // Sec

      interceptor.interceptPacket(errPacket);

      final state = container.read(errorInterceptorProvider);
      expect(state.hasError, true);
      expect(state.errorType, PumpErrorType.needleClogged);
      expect(state.errorTime.year, 2017);
      expect(state.errorTime.month, 9);
      expect(state.errorTime.day, 8);
      expect(state.errorTime.hour, 7);
      expect(state.errorTime.minute, 5);
      expect(state.errorTime.second, 35);
    });

    test('0x0A 원인 불명 에러 유입 시 예외 없이 unknownErr로 파싱 바인딩된다', () {
      final interceptor = container.read(errorInterceptorProvider.notifier);

      final errUnknownPacket = List<int>.filled(20, 0);
      errUnknownPacket[0] = kStartCode;
      errUnknownPacket[1] = Opcodes.btErrInd;
      errUnknownPacket[2] = 1; // dataLen (날짜 누락 케이스 방어)
      errUnknownPacket[3] = 0x0A; // err_unknown_err

      interceptor.interceptPacket(errUnknownPacket);

      final state = container.read(errorInterceptorProvider);
      expect(state.hasError, true);
      expect(state.errorType, PumpErrorType.unknownErr);
    });

    test('MediaAssetHelper가 에러 유형에 따라 타당한 에셋 상대 경로를 반환한다', () {
      // 1. 바늘 막힘 이미지 경로 검증
      final needlePath = MediaAssetHelper.getErrorIllustration(PumpErrorType.needleClogged);
      expect(needlePath, 'media/error_needle_clogged.png');

      // 2. 원인 불명 에러 이미지 경로 검증 (0x0A)
      final unknownPath = MediaAssetHelper.getErrorIllustration(PumpErrorType.unknownErr);
      expect(unknownPath, 'media/error_unknown.png');

      // 3. 배터리 부족 이미지 경로 검증
      final battPath = MediaAssetHelper.getErrorIllustration(PumpErrorType.lowBatt);
      expect(battPath, 'media/error_low_batt.png');
    });

    test('clearError 호출 시 에러 경고 상태가 정상적으로 소멸한다', () {
      final interceptor = container.read(errorInterceptorProvider.notifier);

      // 강제 에러 설정
      interceptor.setErrorForce(PumpErrorType.lowBatt, DateTime.now());
      expect(container.read(errorInterceptorProvider).hasError, true);

      // 에러 클리어
      interceptor.clearError();
      expect(container.read(errorInterceptorProvider).hasError, false);
      expect(container.read(errorInterceptorProvider).errorType, PumpErrorType.none);
    });
  });
}
