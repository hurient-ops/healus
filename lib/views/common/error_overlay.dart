import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/error/error_interceptor.dart';
import '../../services/media/media_asset_helper.dart';

/// 앱 내 현재 라우팅 경로와 상관없이 백그라운드에서 에러 패킷 수신 시
/// 최상위에 강제 경고 팝업을 노출시키는 전역 안전 에러 오버레이 위젯
class ErrorOverlay extends ConsumerWidget {
  final Widget child;

  const ErrorOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errorState = ref.watch(errorInterceptorProvider);

    return Stack(
      children: [
        // 1. 일반 메인 콘텐츠 화면
        child,

        // 2. 의료 장치 에러 경고 모달 강제 팝업
        if (errorState.hasError)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.85), // 화면 어둡게 차단
              child: Center(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 28.0),
                  color: const Color(0xFF1E1E24), // 프리미엄 딥다크 백그라운드
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(color: Colors.redAccent, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 오류 상황을 묘사하는 에셋 이미지 렌더링
                        // 실제 빌드 환경에서 파일이 존재하지 않는 경우를 대비한 안전 예외 처리(errorBuilder) 반영
                        Image.asset(
                          MediaAssetHelper.getErrorIllustration(errorState.errorType),
                          height: 120,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 80,
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "인슐린 펌프 경고",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          errorState.errorType.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "기기 및 주입부의 상태를 즉시 확인하십시오.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
                        // 디코딩된 기기 에러 시각 표시
                        Text(
                          "발생 시각: ${_formatTime(errorState.errorTime)}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            ref.read(errorInterceptorProvider.notifier).clearError();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "확인",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// DateTime 포맷팅 헬퍼 메서드
  String _formatTime(DateTime dt) {
    return "${dt.year}년 ${dt.month.toString().padLeft(2, '0')}월 ${dt.day.toString().padLeft(2, '0')}일 "
        "${dt.hour.toString().padLeft(2, '0')}시 ${dt.minute.toString().padLeft(2, '0')}분 ${dt.second.toString().padLeft(2, '0')}초";
  }
}
