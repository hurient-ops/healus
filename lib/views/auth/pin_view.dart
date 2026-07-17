import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ble/opcodes.dart';
import '../../services/inject/inject_controller.dart';
import '../home/home_screen.dart';

/// HealUS 인슐린 펌프 비밀번호(PIN) 인증 입력 화면
class PinView extends ConsumerStatefulWidget {
  const PinView({super.key});

  @override
  ConsumerState<PinView> createState() => _PinViewState();
}

class _PinViewState extends ConsumerState<PinView> with SingleTickerProviderStateMixin {
  String _pin = '';
  final int _pinLength = 6;
  String _message = '보안을 위해 비밀번호 6자리를 입력해 주세요';
  bool _isError = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleNumberClick(String number) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += number;
        if (_isError) {
          _isError = false;
          _message = '보안을 위해 비밀번호 6자리를 입력해 주세요';
        }
      });

      if (_pin.length == _pinLength) {
        _verifyAndSendPin();
      }
    }
  }

  void _handleBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _handleClear() {
    setState(() {
      _pin = '';
      _isError = false;
      _message = '보안을 위해 비밀번호 6자리를 입력해 주세요';
    });
  }

  /// PIN 번호 유효성 검증 및 패킷 전송
  Future<void> _verifyAndSendPin() async {
    // 1. BLE 패킷 구성 (BT_PRS_APP_PASSWD_IND - 0x3C)
    final packet = List<int>.filled(20, 0);
    packet[0] = kStartCode;
    packet[1] = Opcodes.btPrsAppPasswdInd;
    packet[2] = 6; // Data length
    try {
      for (int i = 0; i < 6; i++) {
        packet[3 + i] = int.parse(_pin[i]);
      }
    } catch (_) {
      _showPinError('잘못된 입력 양식입니다.');
      return;
    }

    // 2. InjectController를 통해 송신 큐에 패킷 전달
    ref.read(injectControllerProvider.notifier).queuePacket(packet);

    // 3. 수신된 기기 비밀번호 검증
    final pumpState = ref.read(pumpStateProvider);
    final correctPassword = (pumpState.password.isNotEmpty) ? pumpState.password : '000000';
    if (_pin == correctPassword) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      // 비밀번호 불일치 시 에러 효과 적용
      _shakeController.forward(from: 0.0);
      _showPinError('암호가 일치하지 않습니다.');
    }
  }

  void _showPinError(String errStr) {
    setState(() {
      _pin = '';
      _isError = true;
      _message = errStr;
    });
  }

  /// 데모 모드로 바로 진입할 수 있는 강제 진입 헬퍼
  void _bypassForDemo() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 디자인 컬러 가이드라인 반영 (골드 #FFD700, 딥틸 #004D40)
    const primaryColor = Color(0xFFFFD700); // 골드
    const deepTealColor = Color(0xFF004D40); // 딥 틸 (주요 컴포넌트 포인트)
    const scaffoldBg = Color(0xFF0D1117); // 딥다크 백그라운드

    // 쉐이크 애니메이션 오프셋 계산
    final Animation<double> offsetAnimation = Tween<double>(begin: 0.0, end: 24.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.medical_services_outlined, color: primaryColor, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'HealUs',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _bypassForDemo,
                    icon: const Icon(Icons.arrow_forward, color: primaryColor, size: 16),
                    label: const Text(
                      '데모 모드 진입',
                      style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // PIN 입력 메시지
            AnimatedBuilder(
              animation: offsetAnimation,
              builder: (context, child) {
                return Padding(
                  padding: EdgeInsets.only(left: offsetAnimation.value, right: -offsetAnimation.value),
                  child: Column(
                    children: [
                      const Text(
                        '암호 입력',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _message,
                        style: TextStyle(
                          color: _isError ? Colors.redAccent : Colors.white60,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 48),

            // PIN 도트 인디케이터
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (index) {
                final isFilled = index < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10.0),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? primaryColor : Colors.white24,
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : [],
                  ),
                );
              }),
            ),

            const Spacer(flex: 3),

            // 키패드 그리드
            Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  for (var r = 0; r < 3; r++) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var c = 1; c <= 3; c++) ...[
                          _buildKey((r * 3 + c).toString()),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildIconButton(Icons.close, _handleClear),
                      _buildKey('0'),
                      _buildIconButton(Icons.backspace_outlined, _handleBackspace),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String number) {
    return InkWell(
      onTap: () => _handleNumberClick(number),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
        ),
        child: Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.03),
        ),
        child: Icon(
          icon,
          color: Colors.white70,
          size: 28,
        ),
      ),
    );
  }
}
