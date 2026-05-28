import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/pump_state_provider.dart';

/// 펌프의 배터리 레벨 (0~4) 상태를 실시간 스왑 렌더링하는 위젯
class BatteryWidget extends ConsumerWidget {
  const BatteryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pumpState = ref.watch(pumpStateProvider);
    final batteryLevel = pumpState.batteryLevel;

    // 배터리 상태 묘사 텍스트 및 퍼센트 추정
    String levelText;
    double percent;
    IconData fallbackIcon;
    Color levelColor;

    switch (batteryLevel) {
      case 0:
        levelText = '교체 필요 (0%)';
        percent = 0.0;
        fallbackIcon = Icons.battery_alert_rounded;
        levelColor = Colors.redAccent;
        break;
      case 1:
        levelText = '매우 낮음 (25%)';
        percent = 0.25;
        fallbackIcon = Icons.battery_2_bar_rounded;
        levelColor = Colors.orangeAccent;
        break;
      case 2:
        levelText = '보통 (50%)';
        percent = 0.50;
        fallbackIcon = Icons.battery_4_bar_rounded;
        levelColor = Colors.amberAccent;
        break;
      case 3:
        levelText = '충분 (75%)';
        percent = 0.75;
        fallbackIcon = Icons.battery_6_bar_rounded;
        levelColor = const Color(0xFF004D40); // Deep Teal 포인트 매칭
        break;
      case 4:
      default:
        levelText = '가득 참 (100%)';
        percent = 1.0;
        fallbackIcon = Icons.battery_full_rounded;
        levelColor = const Color(0xFF004D40);
        break;
    }

    final String assetPath = 'media/batt_level_$batteryLevel.png';

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.battery_charging_full_rounded, color: Colors.white60, size: 16),
                  SizedBox(width: 6),
                  Text(
                    '펌프 배터리',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '${(percent * 100).toInt()}%',
                style: TextStyle(
                  color: levelColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // 배터리 이미지 에셋 렌더링 (없을 시 fallbackIcon 노출)
              SizedBox(
                width: 48,
                height: 48,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      fallbackIcon,
                      color: levelColor,
                      size: 40,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      levelText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 선형 퍼센트 게이지바
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
