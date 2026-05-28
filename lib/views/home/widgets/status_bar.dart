import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/pump_state_provider.dart';
import '../../../services/ble/opcodes.dart';

/// 펌프의 동작 및 연결 상태를 상단에 실시간으로 표시하는 상태바 위젯
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pumpState = ref.watch(pumpStateProvider);
    final connectionState = pumpState.connectionState;

    Color statusColor;
    String statusText;
    IconData statusIcon;
    bool isPulse = false;

    switch (connectionState) {
      case PumpState.idle:
        statusColor = const Color(0xFF004D40); // Deep Teal (정상 대기)
        statusText = '펌프 대기 중';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case PumpState.injecting:
        statusColor = const Color(0xFFFFD700); // 골드 (주입 진행)
        statusText = '인슐린 주입 중';
        statusIcon = Icons.play_arrow_rounded;
        isPulse = true;
        break;
      case PumpState.normalStop:
        statusColor = Colors.orangeAccent;
        statusText = '주입 일시정지';
        statusIcon = Icons.pause_circle_outline_rounded;
        break;
      case PumpState.replace:
        statusColor = Colors.blueAccent;
        statusText = '카트리지 교체 중';
        statusIcon = Icons.loop_rounded;
        break;
      case PumpState.errorPause:
        statusColor = Colors.redAccent;
        statusText = '펌프 오류 정지';
        statusIcon = Icons.error_outline_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusText = '장치 연결 없음';
        statusIcon = Icons.bluetooth_disabled_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.bluetooth, color: Colors.blueAccent[100], size: 20),
              const SizedBox(width: 8),
              Text(
                'HealUS 펌프 v0.80',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          _PulseStatusChip(
            color: statusColor,
            text: statusText,
            icon: statusIcon,
            pulse: isPulse,
          ),
        ],
      ),
    );
  }
}

class _PulseStatusChip extends StatefulWidget {
  final Color color;
  final String text;
  final IconData icon;
  final bool pulse;

  const _PulseStatusChip({
    required this.color,
    required this.text,
    required this.icon,
    required this.pulse,
  });

  @override
  State<_PulseStatusChip> createState() => _PulseStatusChipState();
}

class _PulseStatusChipState extends State<_PulseStatusChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.pulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PulseStatusChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulse && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chipContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.color.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, color: widget.color, size: 16),
          const SizedBox(width: 6),
          Text(
            widget.text,
            style: TextStyle(
              color: widget.color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    if (!widget.pulse) return chipContent;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_controller.value * 0.25),
                blurRadius: 8,
                spreadRadius: 2 * _controller.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: chipContent,
    );
  }
}
