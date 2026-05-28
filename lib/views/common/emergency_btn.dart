import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 내 모든 화면에서 오버레이 위에 떠서 터치 가능한 최상위 소프트웨어 긴급 정지 버튼
class EmergencyBtn extends ConsumerWidget {
  final VoidCallback? onPressed;

  const EmergencyBtn({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed ?? () {
          // TODO: Phase 3에서 긴급 정지 트랜잭션 전송 기능 연결
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("긴급 정지 명령이 전송 큐 최선두로 배치되었습니다!"),
              backgroundColor: Colors.red,
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              "긴급 주입 정지",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
