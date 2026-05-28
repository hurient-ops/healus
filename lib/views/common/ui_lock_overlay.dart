import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/pump_state_provider.dart';
import 'emergency_btn.dart';

/// 인슐린 주입 상태(isPumpInjecting)가 true일 때
/// 화면 전체의 터치를 완전 차단(AbsorbPointer)하는 동시에,
/// 최상위에 긴급 정지 버튼만 노출시켜 터치를 가능케 하는 전역 UI Lock 오버레이
class UiLockOverlay extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onEmergencyPressed;

  const UiLockOverlay({
    super.key,
    required this.child,
    this.onEmergencyPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pumpState = ref.watch(pumpStateProvider);
    final isInjecting = pumpState.isPumpInjecting;

    return Stack(
      children: [
        // 1. 하위 콘텐츠 (일반 대시보드 및 네비게이션 화면)
        child,

        // 2. 주입 중일 때 터치 차단 레이아웃 및 긴급 정지 오버레이 활성화
        if (isInjecting) ...[
          // BackdropFilter 및 Container로 터치 차단막 구성
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 깜빡이는 경고성 인디케이터
                            const _PulseIndicator(),
                            const SizedBox(height: 24),
                            const Text(
                              "인슐린 주입 진행 중",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "환자 안전을 위해 주입 완료 시까지 앱 내 조작 및 화면 제어가 차단됩니다.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 100), // 하단 긴급 정지 버튼 공간 확보
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. 락 오버레이 영역보다 상위(Z-index)에 긴급 정지 버튼을 위치시켜 터치 허용
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: EmergencyBtn(
                onPressed: onEmergencyPressed,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 부드러운 애니메이션 효과를 동반하는 로딩 원형 인디케이터
class _PulseIndicator extends StatefulWidget {
  const _PulseIndicator();

  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.redAccent.withOpacity(0.1 + (_controller.value * 0.2)),
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.5 + (_controller.value * 0.5)),
              width: 2 + (_controller.value * 2),
            ),
          ),
          child: const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                strokeWidth: 3.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
