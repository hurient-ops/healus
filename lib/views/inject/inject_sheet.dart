import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/inject/inject_controller.dart';

/// 사용자가 식사주입/추가주입 구분 및 인슐린 양을 설정하여 주입을 요청하는 바텀시트 위젯
class InjectSheet extends ConsumerStatefulWidget {
  const InjectSheet({super.key});

  @override
  ConsumerState<InjectSheet> createState() => _InjectSheetState();
}

class _InjectSheetState extends ConsumerState<InjectSheet> {
  int _selectedType = 0; // 0: 식사주입, 1: 추가주입
  final TextEditingController _amountController = TextEditingController(text: '1.0');
  double _insulinAmount = 1.0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _incrementAmount(double val) {
    setState(() {
      _insulinAmount = (_insulinAmount + val).clamp(0.05, 15.0);
      // 소수점 둘째 자리까지 반올림하여 텍스트 필드 업데이트
      _insulinAmount = double.parse(_insulinAmount.toStringAsFixed(2));
      _amountController.text = _insulinAmount.toString();
    });
  }

  void _onAmountChanged(String val) {
    final parsed = double.tryParse(val);
    if (parsed != null) {
      setState(() {
        _insulinAmount = parsed.clamp(0.0, 15.0);
      });
    }
  }

  /// 주입 시작 전 오조작 방지를 위한 더블 체크 모달 팝업
  void _showDoubleCheckModal() {
    if (_insulinAmount <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("주입량을 0 Unit보다 크게 설정해 주세요."),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final typeStr = _selectedType == 0 ? '식사 주입' : '추가 주입';
    const primaryColor = Color(0xFFFFD700); // 골드

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E24), // 프리미엄 딥다크 배경
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                '투약 정보 재확인',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '인슐린 주입을 개시하기 전에 아래 정보를 최종 검증하십시오.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('주입 유형', style: TextStyle(color: Colors.white60, fontSize: 14)),
                        Text(
                          typeStr,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('주입 용량', style: TextStyle(color: Colors.white60, fontSize: 14)),
                        Text(
                          '$_insulinAmount Unit',
                          style: const TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '확인 버튼을 누르면 기기로 즉시 주입 명령 패킷이 송출되며, 주입 중에는 긴급 정지를 제외한 화면 조작이 차단됩니다.',
                style: TextStyle(color: Colors.redAccent, fontSize: 12, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '취소',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // 1. 다이얼로그 닫기
                Navigator.of(context).pop();
                // 2. 바텀시트 닫기
                Navigator.of(context).pop();
                // 3. 주입 패킷 큐 삽입
                ref.read(injectControllerProvider.notifier).requestInjection(
                      _insulinAmount,
                      _selectedType,
                    );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004D40), // Deep Teal
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('확인 및 주입', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFFD700); // 골드
    const deepTealColor = Color(0xFF004D40); // 딥 틸

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24), // 프리미엄 딥다크 배경
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들바
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '인슐린 주입 제어',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // 주입 유형 선택 세그먼트
          Row(
            children: [
              Expanded(
                child: _buildTypeButton('식사 주입', 0, Icons.restaurant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeButton('추가 주입', 1, Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 주입 용량 타이틀
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '주입 용량 설정',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                '최대 15.0 Unit',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 입력 필드 및 퀵 증감 컨트롤러
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.bold),
                  onChanged: _onAmountChanged,
                  decoration: InputDecoration(
                    suffixText: 'Unit',
                    suffixStyle: const TextStyle(color: Colors.white60, fontSize: 16),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.03),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: primaryColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 퀵 조절 버튼 리스트
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickButton('-1.0', () => _incrementAmount(-1.0)),
              _buildQuickButton('-0.1', () => _incrementAmount(-0.1)),
              _buildQuickButton('+0.1', () => _incrementAmount(0.1)),
              _buildQuickButton('+1.0', () => _incrementAmount(1.0)),
            ],
          ),
          const SizedBox(height: 32),

          // 주입 개시 버튼
          ElevatedButton(
            onPressed: _showDoubleCheckModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: deepTealColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt, size: 20),
                SizedBox(width: 8),
                Text(
                  '주입 개시 요청',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, int typeIndex, IconData icon) {
    final isSelected = _selectedType == typeIndex;
    const primaryColor = Color(0xFFFFD700);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = typeIndex;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF004D40).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF004D40) : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : Colors.white60,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
