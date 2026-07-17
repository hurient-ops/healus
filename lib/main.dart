import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'services/database/local_db.dart';
import 'services/sync/basal_sync_controller.dart';
import 'services/ble/opcodes.dart';
import 'services/ble/packet_parser.dart';
import 'services/ble/ble_service_provider.dart';
import 'services/ble/mock_ble_service.dart';
import 'services/ble/ble_handshake_controller.dart';
import 'services/ble/time_sync_controller.dart';
import 'state/pump_state_provider.dart';
import 'services/inject/inject_controller.dart';
import 'globals.dart';
import 'services/error/error_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
void main() async {
  // 1. Flutter 바인딩 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();

  // 2. SQLite 로컬 DB 인스턴스 싱글톤 생성 및 스키마 초기화
  final sqfliteDb = SqflitePumpDatabase();
  try {
    await sqfliteDb.init();
  } catch (e) {
    print("SQLite DB 초기화 중 치명적 에러 발생: $e");
  }

  runApp(
    ProviderScope(
      overrides: [
        pumpDatabaseProvider.overrideWithValue(sqfliteDb),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'HealUs Pump Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        useMaterial3: true,
      ),
      home: const WebViewHomeScreen(),
    );
  }
}

class WebViewHomeScreen extends ConsumerStatefulWidget {
  const WebViewHomeScreen({super.key});

  @override
  ConsumerState<WebViewHomeScreen> createState() => _WebViewHomeScreenState();
}

class _WebViewHomeScreenState extends ConsumerState<WebViewHomeScreen> {
  late final WebViewController _controller;
  StreamSubscription? _blePacketSub;
  StreamSubscription? _bleConnectionSub;
  bool _isRedirecting = false;
  String _currentUrl = "";

  bool _isConnectingDevice = false;
  String _connectingStatusMessage = "";
  Timer? _batteryTimer;
  final Duration _batteryInterval = const Duration(minutes: 30);
  Timer? _qntTimer;
  final Duration _qntInterval = const Duration(minutes: 30);
  bool _hasRequestedInitialData = false;

  // === [TEST MODE ONLY] ===
  Timer? _injectTimeoutTimer;
  Timer? _mockWaitTimer;
  final bool _enableAutoMacro = !kReleaseMode && false; // 테스트 편의를 위해 자동 매크로 비활성화 여부
  // ========================

  bool _isWebViewLoaded = false;

  @override
  void initState() {
    super.initState();
    _initWebViewController();
    _subscribeToBleService();
  }

  /// 사용자가 수동으로 패킷 바이트를 직접 타이핑하여 네이티브 스트림에 주입하는 다이얼로그
  void _showDebugPacketDialog() {
    final textController = TextEditingController(
      // 기본 예시로 주입 완료 (0x3B) 패킷 HEX 코드를 미리 적어줌
      text: "ef 3b 04 02 64 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
    );

    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final isHold = ref.watch(timeoutHoldProvider);
            final sentLogs = ref.watch(sentPacketsLogProvider);
            final receivedLogs = ref.watch(receivedPacketsLogProvider);

            return AlertDialog(
              backgroundColor: const Color(0xFF1B2330),
              title: const Text(
                "가상 BLE 패킷 수동 제어 패널",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 타임아웃 홀드 스위치
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "타임아웃 일시정지 (Hold)",
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        "수동 디버깅 시 자동 세션 해제를 방지합니다.",
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      value: isHold,
                      activeColor: Colors.tealAccent,
                      onChanged: (val) {
                        ref.read(timeoutHoldProvider.notifier).state = val;
                        final bleService = ref.read(bleServiceProvider);
                        bleService.setBypassTimeoutHold(val);
                      },
                    ),
                    const Divider(color: Colors.white24, height: 16),
                    const Text(
                      "가상 수신 패킷 수동 주입:",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: textController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "💡 자주 쓰이는 패킷 가이드:\n"
                      "• 0x3B (식사 완료): ef 3b 04 02 64 00 00 ...\n"
                      "• 0x3F (FW 응답): ef 3f 02 01 02 00 00 ... (v1.2)\n"
                      "• 0x7F (에러 01): ef 7f 01 01 00 00 ...\n"
                      "• 0x3A (주입 중): ef 3a 04 02 64 00 00 ...",
                      style: TextStyle(color: Colors.tealAccent, fontSize: 10, height: 1.4),
                    ),
                    const Divider(color: Colors.white24, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "📤 통신 패킷 로그 (앱 <-> 기기):",
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.copy, color: Colors.tealAccent, size: 20),
                          tooltip: "로그 복사",
                          onPressed: () async {
                            final allLogs = [...receivedLogs, ...sentLogs]..sort((a, b) => a.compareTo(b));
                            if (allLogs.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("복사할 통신 로그가 없습니다."),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }
                            final textToCopy = allLogs.join('\n');
                            await Clipboard.setData(ClipboardData(text: textToCopy));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("통신 로그가 클립보드에 복사되었습니다."),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: (sentLogs.isEmpty && receivedLogs.isEmpty)
                          ? const Center(
                              child: Text(
                                "통신 로그가 없습니다.",
                                style: TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(6),
                              itemCount: sentLogs.length + receivedLogs.length,
                              itemBuilder: (ctx, idx) {
                                // 임시로 두 로그를 시간순으로 병합 (실제로는 단순 교차 출력)
                                final allLogs = [...receivedLogs, ...sentLogs]..sort((a, b) => b.compareTo(a));
                                return SelectableText(
                                  allLogs[idx],
                                  style: TextStyle(
                                    color: allLogs[idx].contains('<-') ? Colors.cyanAccent : Colors.lightGreenAccent,
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("취소", style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final input = textController.text.trim();
                    try {
                      // 공백 제거 및 Hex 파싱
                      final hexStr = input.replaceAll(RegExp(r'\s+'), '').replaceAll('0x', '');
                      if (hexStr.length != 40) {
                        throw Exception("패킷 길이는 정확히 20Byte (40글자) 여야 합니다. (현재 ${hexStr.length / 2}Byte)");
                      }
                      
                      final bytes = <int>[];
                      for (int i = 0; i < hexStr.length; i += 2) {
                        final sub = hexStr.substring(i, i + 2);
                        final byte = int.parse(sub, radix: 16);
                        bytes.add(byte);
                      }

                      final bleService = ref.read(bleServiceProvider);
                      if (bleService is BleServiceManager) {
                        bleService.injectPacket(bytes);
                      }
                      
                      // 수동 주입된 디버그 패킷을 실측 데이터로 처리
                      ref.read(pumpStateProvider.notifier).handleIncomingPacket(bytes, isRealPacket: true);
                      ref.read(basalSyncControllerProvider.notifier).handleIncomingPacket(bytes, isRealPacket: true);
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("가상 패킷이 성공적으로 주입되었습니다."),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("파싱 에러"),
                          content: Text(e.toString()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("확인"),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F6568),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("패킷 주입"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _blePacketSub?.cancel();
    _bleConnectionSub?.cancel();
    _batteryTimer?.cancel();
    _qntTimer?.cancel();
    // === [TEST MODE ONLY] ===
    _injectTimeoutTimer?.cancel();
    _mockWaitTimer?.cancel();
    // ========================
    super.dispose();
  }

  /// 30분 주기적 배터리 요청 타이머 기동
  void _startBatteryPollTimer() {
    _batteryTimer?.cancel();
    _batteryTimer = Timer.periodic(_batteryInterval, (timer) {
      final bleService = ref.read(bleServiceProvider);
      if (bleService.isConnected && !bleService.isTestMode) {
        print("주기적 30분 배터리 데이터(0x70) 요청");
        final packet = List<int>.filled(20, 0);
        packet[0] = kStartCode;
        packet[1] = Opcodes.btBattDataReq;
        packet[2] = 0;
        ref.read(injectControllerProvider.notifier).queuePacket(packet);
      }
    });
  }

  /// 배터리 요청 타이머 정지
  void _stopBatteryPollTimer() {
    _batteryTimer?.cancel();
    _batteryTimer = null;
  }

  /// 30분 주기적 금일 주입량 요청 타이머 기동
  void _startQntPollTimer() {
    _qntTimer?.cancel();
    _qntTimer = Timer.periodic(_qntInterval, (timer) {
      final bleService = ref.read(bleServiceProvider);
      if (bleService.isConnected && !bleService.isTestMode) {
        print("주기적 30분 금일 주입량 데이터(0x1E) 요청");
        final qnt = List<int>.filled(20, 0);
        qnt[0] = kStartCode;
        qnt[1] = Opcodes.btLogInjQntReq;
        qnt[2] = 0;
        ref.read(injectControllerProvider.notifier).queuePacket(qnt);
      }
    });
  }

  /// 금일 주입량 요청 타이머 정지
  void _stopQntPollTimer() {
    _qntTimer?.cancel();
    _qntTimer = null;
  }

  /// 대시보드 화면 최초 진입 시 필요한 장치 정보 일괄 1회 요청 (배터리, PID, 금일 누적 주입, 식사 설정값, 기초 설정값, 인슐린 잔량)
  void _requestDashboardInitialData() {
    final bleService = ref.read(bleServiceProvider);
    if (!bleService.isConnected) return;

    // 폴링 타이머 자동 가동 확인 (대시보드 진입 시 타이머는 항상 보장)
    if (_batteryTimer == null) {
      _startBatteryPollTimer();
    }
    if (_qntTimer == null) {
      _startQntPollTimer();
    }

    // 이미 최초 1회 전체 동기화를 수행했는지 확인
    if (_hasRequestedInitialData) {
      return; 
    }

    print("최초 대시보드 진입 감지 -> 기기 초기 상태 정보 일체 동기화 개시 (1회성)");
    _hasRequestedInitialData = true;

    final injectNotifier = ref.read(injectControllerProvider.notifier);

    // 1. 배터리 잔량 요청
    final batt = List<int>.filled(20, 0);
    batt[0] = kStartCode;
    batt[1] = Opcodes.btBattDataReq;
    batt[2] = 0;
    injectNotifier.queuePacket(batt);

    // 2. 고유 PID 요청
    final pid = List<int>.filled(20, 0);
    pid[0] = kStartCode;
    pid[1] = Opcodes.btPumpPidReq;
    pid[2] = 0;
    injectNotifier.queuePacket(pid);

    // 3. 금일 주입량 정보 요청
    final qnt = List<int>.filled(20, 0);
    qnt[0] = kStartCode;
    qnt[1] = Opcodes.btLogInjQntReq;
    qnt[2] = 0;
    injectNotifier.queuePacket(qnt);

    // 4. 식사 설정값 요청 (0x2D)
    final eat = List<int>.filled(20, 0);
    eat[0] = kStartCode;
    eat[1] = Opcodes.btEatValueReq;
    eat[2] = 0;
    injectNotifier.queuePacket(eat);

    // 5. 24개 시간 구간 기초 설정값 요청 (0x2F)
    final base = List<int>.filled(20, 0);
    base[0] = kStartCode;
    base[1] = Opcodes.btBaseValueReq;
    base[2] = 0;
    injectNotifier.queuePacket(base);

    // 6. 인슐린 잔량 정보 요청 (0x15)
    final injInfo = List<int>.filled(20, 0);
    injInfo[0] = kStartCode;
    injInfo[1] = Opcodes.btInjInfoReq;
    injInfo[2] = 1;
    injInfo[3] = 0; // 식사 기준
    injectNotifier.queuePacket(injInfo);

    // 6.5 펌웨어 버전 요청 (0x3E)
    final fwReq = List<int>.filled(20, 0);
    fwReq[0] = kStartCode;
    fwReq[1] = Opcodes.btPumpFwReq;
    fwReq[2] = 0;
    injectNotifier.queuePacket(fwReq);

    // 7. 이력 데이터 최초 1회 요청 (0x1D)
    print("[DEBUG] main.dart: 이력 데이터 0x1D 전송 요청");
    final hist = List<int>.filled(20, 0);
    hist[0] = kStartCode;
    hist[1] = Opcodes.btLogReq;
    hist[2] = 0;
    injectNotifier.queuePacket(hist);

    // 폴링 타이머 자동 가동 확인
    if (_batteryTimer == null) {
      _startBatteryPollTimer();
    }
    if (_qntTimer == null) {
      _startQntPollTimer();
    }
  }

  /// 장비 연결 및 핸드셰이크 시퀀스를 수행하는 비동기 트리거
  Future<void> _startDeviceConnection(String targetMac) async {
    setState(() {
      _isConnectingDevice = true;
      _connectingStatusMessage = "장치와 보안 세션을 형성 중입니다...";
    });

    _hasRequestedInitialData = false;

    try {
      await ref.read(bleHandshakeControllerProvider.notifier).connectAndHandshake(targetMac);

      if (mounted) {
        setState(() {
          _isConnectingDevice = false;
        });
        // 연결 완료(실제 또는 테스트 모드) 후 비밀번호 입력 페이지 서빙
        // 테스트 모드 시 비밀번호는 "000000"으로 자동 설정됨
        _loadInterceptedPasswordPage();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnectingDevice = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// BLE 수신 서비스 및 패킷 핸들러 구독
  void _subscribeToBleService() {
    // 딜레이 기동을 보장하기 위해 마이크로태스크 사용
    Future.microtask(() {
      final bleService = ref.read(bleServiceProvider);

      // 1. 패킷 수신 대기
      _blePacketSub = bleService.receivedPacketsStream.listen((packet) {
        print("[DEBUG] main.dart _subscribeToBleService: received packet opcode=0x${packet[1].toRadixString(16)}");
        final isReal = !bleService.isTestMode;
        // 전역 상태 제공기 및 동기화 기기에 인계
        ref.read(pumpStateProvider.notifier).handleIncomingPacket(packet, isRealPacket: isReal);
        ref.read(basalSyncControllerProvider.notifier).handleIncomingPacket(packet, isRealPacket: isReal);
        ref.read(errorInterceptorProvider.notifier).interceptPacket(packet);

        // Ack 응답 처리
        if (packet[1] == Opcodes.btMsgRes) {
          final targetOp = packet[3];
          final resCode = ResCode.fromValue(packet[4]);
          if (targetOp == Opcodes.btTimeBaseSetReq || targetOp == Opcodes.btMealSetReq) {
            ref.read(basalSyncControllerProvider.notifier).handleSetResponse(resCode);
          }
        } else if (packet[1] == Opcodes.btSetRes) {
          // btSetRes 수신 시에도 Ack 대기 해제하여 기초설정 저장 락 방지
          ref.read(basalSyncControllerProvider.notifier).handleSetResponse(ResCode.ok);
        }
      });

      // 2. 연결 유실 감지 시 테스트 모드 전환 처리
      _bleConnectionSub = bleService.connectionStateStream.listen((newState) {
        if (!newState) {
          print("BLE 연결 끊김 발생 -> 테스트 모드로 자동 스위칭 시도");
          _hasRequestedInitialData = false; // 연결 끊김 시 1회성 플래그 초기화
          _stopBatteryPollTimer();
          _stopQntPollTimer();
          
          if (!kReleaseMode) {
            ref.read(testModeProvider.notifier).state = true;
          }
          
          // 웹뷰에 연결상태 통보 (필요시 새로고침)
          _syncStateToWebview();
        } else {
          // 기기 연결 수립 시 배터리 30분 폴링 기동
          _startBatteryPollTimer();
          _startQntPollTimer();
        }
      });
    });
  }

  /// 웹뷰 내의 console.log 스트림 분석 후 네이티브 BLE 바인딩 (JS -> Native 브릿지)
  void _sendHistoryLogsToWebview() {
    final logs = ref.read(basalSyncControllerProvider).logs;
    final jsonLogs = jsonEncode(logs.map((log) => {
      'month': log.month,
      'day': log.day,
      'base_total': log.baseTotal,
      'eat_total': log.eatTotal,
      'morning_total': log.morningTotal,
      'afternoon_total': log.afternoonTotal,
      'evening_total': log.eveningTotal,
      'append_total': log.appendTotal,
    }).toList());
    
    final js = '''
      (function() {
        try {
          localStorage.setItem('history_logs', '$jsonLogs');
          if (window.receiveBleHistoryLogs) {
            window.receiveBleHistoryLogs('$jsonLogs');
          }
        } catch(e) {
          console.error("Failed to inject history_logs into localStorage", e);
        }
      })();
    ''';
    _controller.runJavaScript(js);
  }

  void _handleConsoleMessage(String message) async {
    print("Webview Console: $message");

    if (message.contains("REQUEST_HISTORY_LOGS")) {
      print("[DEBUG] main.dart: Webview requested history logs");
      ref.read(basalSyncControllerProvider.notifier).requestHistoryLogs();
      _sendHistoryLogsToWebview();
      return;
    }

    if (message.contains("BLE Command Sent: [START_SCAN]")) {
      print("[DEBUG] main.dart: Webview requested START_SCAN");
      _startBleScan();
      return;
    }

    if (message.contains("BLE Command Sent: [PAUSE]")) {
      print("[DEBUG] main.dart: Webview requested PAUSE");
      ref.read(bleServiceProvider).setPauseState(true);
      return;
    }

    if (message.contains("BLE Command Sent: [RESUME]")) {
      print("[DEBUG] main.dart: Webview requested RESUME");
      ref.read(bleServiceProvider).setPauseState(false);
      return;
    }

    if (message.contains("BLE Command Sent: [DISCONNECT]")) {
      print("[DEBUG] main.dart: Webview requested DISCONNECT");
      ref.read(testModeProvider.notifier).state = false; // 테스트 모드 비활성화
      ref.read(bleServiceProvider).disconnect().then((_) {
        _controller.loadFlutterAsset('ui_design/ble_connect/code.html');
      });
      return;
    }

    if (message.contains("BLE Command Sent: [RESET]")) {
      print("[DEBUG] main.dart: Webview requested RESET");
      // 리셋 패킷만 전송하고 설정 화면을 그대로 유지
      ref.read(bleServiceProvider).resetDevice();
      return;
    }

    if (message.contains("REQUEST_BASAL_RATES")) {
      print("[DEBUG] main.dart: Webview requested basal rates, syncing current basalRates");
      final ratesJson = jsonEncode(ref.read(pumpStateProvider).basalRates.map((r) => r.toStringAsFixed(2)).toList());
      _controller.runJavaScript("if (window.receiveBleBasalData) { window.receiveBleBasalData($ratesJson); }");
      return;
    }

    if (message.contains("REQUEST_MEAL_RATES")) {
      print("[DEBUG] main.dart: Webview requested meal settings, syncing current mealSettings");
      final bf = ref.read(pumpStateProvider).mealSettings['breakfast'] ?? 1.00;
      final ln = ref.read(pumpStateProvider).mealSettings['lunch'] ?? 1.00;
      final dn = ref.read(pumpStateProvider).mealSettings['dinner'] ?? 1.00;
      final settingsJson = '{"breakfast":"$bf","lunch":"$ln","dinner":"$dn"}';
      _controller.runJavaScript('''
        try {
          localStorage.setItem('meal_settings', '$settingsJson');
        } catch(e) {}
        if (window.receiveBleMealData) {
          window.receiveBleMealData({ breakfast: '$bf', lunch: '$ln', dinner: '$dn' });
        }
      ''');
      return;
    }

    if (message.contains("UPDATE_BASAL_RATES:")) {
      print("[DEBUG] main.dart: Webview updated basal rates");
      final startIdx = message.indexOf("[");
      final endIdx = message.indexOf("]");
      if (startIdx != -1 && endIdx != -1) {
        final rawArr = message.substring(startIdx + 1, endIdx);
        final rates = rawArr.split(",").map((s) => double.tryParse(s.trim()) ?? 0.0).toList();
        if (rates.length == 24) {
          ref.read(pumpStateProvider.notifier).updateBasalRates(rates);
        }
      }
      return;
    }

    if (message.contains("BLE 명령 전송: 긴급 정지") || message.contains("BLE 명령 전송: 긴급정지")) {
      ref.read(injectControllerProvider.notifier).requestEmergencyStop();
      return;
    }

    if (message.contains("BLE 명령 전송: SEND_MEAL_INJECTION_COMMAND:")) {
      // 아침: 1.00 U, 점심: 1.00 U, 저녁: 1.00 U 형태로 파싱
      final RegExp reg = RegExp(r"(\d+\.\d+) U 아침, (\d+\.\d+) U 점심, (\d+\.\d+) U 저녁");
      final match = reg.firstMatch(message);
      if (match != null) {
        final double breakfastVal = double.tryParse(match.group(1) ?? "0.0") ?? 0.0;
        final double lunchVal = double.tryParse(match.group(2) ?? "0.0") ?? 0.0;
        final double dinnerVal = double.tryParse(match.group(3) ?? "0.0") ?? 0.0;
        
        // 현재 타임에 맞춰 식사 주입 요청 전송
        // (기획서에 따르면 식사 주입하기 버튼 누를 시 식사주입 코드 0x00와 인슐린 설정 값을 BT_INJ_REQ(0x17)에 넣어 전송)
        // 여기서는 점심 기준으로 주입 (식사 주입 종류는 웹뷰에선 일체로 넘기나, 기기 전송 시 0x00 식사주입 코드로 송출)
        // 주입할 최종 총량이나 선택적 단위를 산출
        double finalAmount = lunchVal;
        // 아침/점심/저녁 중 0이 아닌 단위를 주입량으로 산출
        if (breakfastVal > 0) finalAmount = breakfastVal;
        else if (dinnerVal > 0) finalAmount = dinnerVal;

        final success = await ref.read(injectControllerProvider.notifier).requestInjection(finalAmount, 0);
        if (success) {
          _controller.runJavaScript("if (window.onInjectionApproved) window.onInjectionApproved();");
        } else {
          _controller.runJavaScript("if (window.onInjectionRejected) window.onInjectionRejected();");
        }
      }
      return;
    }

    if (message.contains("BLE 명령 전송: SEND_ADD_INJECTION_COMMAND:")) {
      final RegExp reg = RegExp(r"SEND_ADD_INJECTION_COMMAND:\s*(\d+\.\d+)\s*U");
      final match = reg.firstMatch(message);
      if (match != null) {
        final double amount = double.tryParse(match.group(1) ?? "0.0") ?? 0.0;
        final success = await ref.read(injectControllerProvider.notifier).requestInjection(amount, 1); // 추가 주입 0x01
        if (success) {
          _controller.runJavaScript("if (window.onInjectionApproved) window.onInjectionApproved();");
        } else {
          _controller.runJavaScript("if (window.onInjectionRejected) window.onInjectionRejected();");
        }
      }
      return;
    }

    if (message.contains("BLE 명령 전송: SEND_DINING_COMMAND:")) {
      final RegExp reg = RegExp(r"SEND_DINING_COMMAND:\s*(\d+)\s*시간");
      final match = reg.firstMatch(message);
      if (match != null) {
        final int hours = int.tryParse(match.group(1) ?? "1") ?? 1;
        // 회식 모드 설정 코드(0x01: 온)와 시간 전송
        final packet = List<int>.filled(20, 0);
        packet[0] = kStartCode;
        packet[1] = Opcodes.btReceptionSetReq;
        packet[2] = 2;
        packet[3] = 0x01; // On
        packet[4] = hours;
        final success = await ref.read(injectControllerProvider.notifier).checkStateAndExecute(packet);
        if (success) {
          _controller.runJavaScript("if (window.onInjectionApproved) window.onInjectionApproved();");
        } else {
          _controller.runJavaScript("if (window.onInjectionRejected) window.onInjectionRejected();");
        }
      }
      return;
    }

    if (message.contains("BLE 명령 전송: SEND_EXERCISE_COMMAND:")) {
      final RegExp reg = RegExp(r"SEND_EXERCISE_COMMAND:\s*(\d+)\s*시간,\s*(\d+)\s*% 감소");
      final match = reg.firstMatch(message);
      if (match != null) {
        final int hours = int.tryParse(match.group(1) ?? "1") ?? 1;
        final int reduction = int.tryParse(match.group(2) ?? "20") ?? 20;
        // 운동 모드 설정 코드(0x01: 온)와 시간, 감량 전송
        final packet = List<int>.filled(20, 0);
        packet[0] = kStartCode;
        packet[1] = Opcodes.btExerciseSetReq;
        packet[2] = 3;
        packet[3] = 0x01; // On
        packet[4] = hours;
        packet[5] = reduction;
        final success = await ref.read(injectControllerProvider.notifier).checkStateAndExecute(packet);
        if (success) {
          _controller.runJavaScript("if (window.onInjectionApproved) window.onInjectionApproved();");
        } else {
          _controller.runJavaScript("if (window.onInjectionRejected) window.onInjectionRejected();");
        }
      }
      return;
    }

    if (message.contains("BLE 전송:")) {
      // 기초 설정 대량 동기화 유발 (basal_setting 저장 시)
      final startIdx = message.indexOf("[");
      final endIdx = message.indexOf("]");
      String rawArr = "";
      if (startIdx != -1 && endIdx != -1) {
        rawArr = message.substring(startIdx + 1, endIdx);
      } else {
        rawArr = message.substring(message.indexOf("BLE 전송:") + 7).trim();
      }
      if (rawArr.isNotEmpty) {
        final rates = rawArr.split(",").map((s) => double.tryParse(s.trim()) ?? 0.0).toList();
        if (rates.length == 24) {
          ref.read(basalSyncControllerProvider.notifier).sync24hBasalSettings(rates);
        }
      }
      return;
    }

    if (message.contains("BLE 명령 전송: BT_MEAL_SET_REQ (0x10)")) {
      // 식사 설정 변경 시 3회 분할 전송 실행
      final RegExp reg = RegExp(r"아침:\s*(\d+\.\d+)\s*U,\s*점심:\s*(\d+\.\d+)\s*U,\s*저녁:\s*(\d+\.\d+)\s*U");
      final match = reg.firstMatch(message);
      if (match != null) {
        final double bf = double.tryParse(match.group(1) ?? "1.0") ?? 1.0;
        final double ln = double.tryParse(match.group(2) ?? "1.0") ?? 1.0;
        final double dn = double.tryParse(match.group(3) ?? "1.0") ?? 1.0;

        // 공통 상태에 식사 설정값 업데이트
        ref.read(pumpStateProvider.notifier).updateMealSettings(bf, ln, dn);
        _sendMealSettingsToDevice(bf, ln, dn);
      }
      return;
    }
  }

  /// 기기 스캔 요청 처리 (kReleaseMode 기반으로 가상/실제 분기)
  void _startBleScan() async {
    if (!kReleaseMode) {
      // 에뮬레이터/디버그 모드: 실제 스캔 생략, 가짜 데이터 즉시 주입
      print("[DEBUG] _startBleScan: 디버그 모드 작동, Mock 기기 전송 (1.2초 대기)");
      Future.delayed(const Duration(milliseconds: 1200), () {
        const mockDeviceJson = '[{"name":"HealUS (Mock)","mac":"20:73:6A:19:3E:41","signal":"에뮬레이터 강제 신호"}]';
        _controller.runJavaScript("if(window.updateFoundDevices) window.updateFoundDevices($mockDeviceJson);");
      });
      return;
    }

    // 상용 릴리즈 모드: 실제 스캔
    try {
      // 1. 권한 확인 (블루투스 & 위치)
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      bool allGranted = statuses.values.every((status) => status.isGranted);
      
      // Android 11 이하에서는 bluetoothScan/Connect가 없으므로 location이나 그냥 bluetooth 권한으로 판별됨.
      // 엄밀하게는 추가 확인이 필요하지만, 대략적으로 허용되었다고 가정.
      if (!allGranted) {
        print("[WARN] _startBleScan: 권한이 완전히 부여되지 않았습니다. 일부 기기에서 검색이 실패할 수 있습니다.");
      }

      print("[DEBUG] _startBleScan: 실제 BLE 스캔 시작 (모든 기기 스캔 후 이름으로 필터링)...");
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );

      // 스캔 결과를 리스닝하여 웹뷰로 전달
      FlutterBluePlus.scanResults.listen((results) {
        final deviceList = [];
        for (var r in results) {
          // 이름 없는 장치나 불필요한 장치 필터링 가능
          if (r.device.platformName.isNotEmpty || r.advertisementData.advName.isNotEmpty) {
            final name = r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName;
            
            // "Heal" 이라는 단어가 포함된 기기만 필터링해서 리스트에 추가 (대소문자 무시)
            if (name.toLowerCase().contains("heal")) {
              final mac = r.device.remoteId.str; // Android: MAC, iOS: UUID
              final rssi = r.rssi;
              String signalLabel = '신호 약함';
              if (rssi > -60) signalLabel = '신호 매우 강함';
              else if (rssi > -80) signalLabel = '신호 강함';
              else if (rssi > -90) signalLabel = '신호 보통';
              
              deviceList.add({
                'name': name,
                'mac': mac,
                'signal': signalLabel,
              });
            }
          }
        }
        final jsonStr = jsonEncode(deviceList);
        _controller.runJavaScript("if(window.updateFoundDevices) window.updateFoundDevices($jsonStr);");
      });
    } catch (e) {
      print("[ERROR] _startBleScan 실패: $e");
    }
  }

  /// 아침, 점심, 저녁 설정을 기기에 3회에 걸쳐 송출
  void _sendMealSettingsToDevice(double bf, double ln, double dn) {
    final values = [bf, ln, dn];
    for (int i = 0; i < 3; i++) {
      final packet = List<int>.filled(20, 0);
      packet[0] = kStartCode;
      packet[1] = Opcodes.btMealSetReq;
      packet[2] = 3;
      packet[3] = i; // 0: 아침, 1: 점심, 2: 저녁
      PacketParser.writeUint16(packet, 4, (values[i] * 100).round());
      ref.read(injectControllerProvider.notifier).queuePacket(packet);
    }
  }

  /// 네이티브 상태 데이터를 웹뷰 내부 환경으로 밀어넣어 동기화 (Native -> JS 브릿지)
  void _syncStateToWebview() {
    final pumpState = ref.read(pumpStateProvider);

    // 0. 가로 기준 비례 및 세로 동적 가변 반응형 스케일링 강제 주입
    final scalingJs = '''
      (function() {
        // 1. 기존 메타 뷰포트를 반응형 지원하도록 강제 조정 또는 생성
        var viewport = document.querySelector('meta[name="viewport"]');
        if (!viewport) {
          viewport = document.createElement('meta');
          viewport.name = 'viewport';
          document.head.appendChild(viewport);
        }
        viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';

        // 2. 비례 스케일링을 위한 CSS 룰 정의 (body 직접 scale)
        var style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = `
          html {
            width: 100% !important;
            height: 100% !important;
            overflow: hidden !important;
            background-color: #f8fafa !important;
            margin: 0 !important;
            padding: 0 !important;
          }
          body {
            transform-origin: top left !important;
            position: absolute !important;
            top: 0 !important;
            left: 0 !important;
            margin: 0 !important;
            box-shadow: none !important;
            border: none !important;
            border-radius: 0 !important;
            overflow: hidden !important;
            display: flex !important;
            flex-direction: column !important;
          }
          /* 모바일 락 구조 초기화 */
          #root, .mobile-container {
            width: 100% !important;
            height: 100% !important;
            max-width: none !important;
            max-height: none !important;
            border-radius: 0 !important;
            box-shadow: none !important;
          }
          /* 메인 콘텐츠 스크롤 영역 고정 확보 */
          main {
            flex: 1 !important;
            overflow-y: auto !important;
            -webkit-overflow-scrolling: touch !important;
          }
          /* 하단 고정 요소들을 최하단에 절대 좌표로 붙여 짤림 현상 방지 */
          nav, footer, .fixed.bottom-0 {
            position: absolute !important;
            bottom: 0 !important;
            left: 0 !important;
            width: 100% !important;
            transform: none !important;
            z-index: 50 !important;
          }
          /* 특정 fixed 팝업들이 깨지지 않도록 scale 콘텍스트 안에 강제 */
          .modal-overlay {
            position: absolute !important;
            width: 100% !important;
            height: 100% !important;
            left: 0 !important;
            top: 0 !important;
          }
        `;
        document.head.appendChild(style);

        // 3. 동적 비례 계산 및 새로고침 바인딩
        function adjustScale() {
          var body = document.body;
          if (!body) return;

          // 기본 디자인 가로 기준 감지
          var baseW = 390;

          if (body.classList.contains('w-[393px]') || body.classList.contains('w-393')) {
            baseW = 393;
          } else if (body.classList.contains('w-[390px]') || body.classList.contains('w-390')) {
            baseW = 390;
          }

          var winW = window.innerWidth;
          var winH = window.innerHeight;

          // 가로폭 기준 비례 스케일 계산
          var scale = winW / baseW;
          // 세로 높이는 기기 가용 세로 높이에 스케일 역산 적용
          var targetH = winH / scale;

          // body에 스타일 주입 (!important로 기존 고정 높이 오버라이드)
          body.style.setProperty('width', baseW + 'px', 'important');
          body.style.setProperty('height', targetH + 'px', 'important');
          body.style.setProperty('max-height', 'none', 'important');
          body.style.setProperty('min-height', targetH + 'px', 'important');
          body.style.setProperty('transform', 'scale(' + scale + ')', 'important');
        }

        function bindRefreshButton() {
          var refreshBtn = document.getElementById('btn-refresh');
          if (refreshBtn) {
            // 중복 바인딩 방지
            if (!refreshBtn.dataset.boundRefresh) {
              refreshBtn.dataset.boundRefresh = 'true';
              refreshBtn.addEventListener('click', function() {
                setTimeout(function() {
                  window.location.reload();
                }, 400); // 회전 애니메이션 이후 새로고침 실행
              });
            }
          }
        }

        window.addEventListener('resize', adjustScale);
        adjustScale();
        bindRefreshButton();
        
        // 동적 로딩을 보정하기 위한 지연 처리
        setTimeout(function() {
          adjustScale();
          bindRefreshButton();
        }, 100);
        setTimeout(adjustScale, 300);
        setTimeout(adjustScale, 700);
      })();
    ''';
    _controller.runJavaScript(scalingJs);

    // 1. 공통 설정 주입 (시뮬레이터 타이머 끄기)
    // data: URL 스킴에서는 localStorage 접근이 차단되므로 try-catch로 안전하게 처리
    _controller.runJavaScript("try { localStorage.setItem('CONFIG_USE_TIMER', 'false'); } catch(e) {}");
    
    // 2. 주입 중 상태 동기화
    _controller.runJavaScript("try { localStorage.setItem('isInjecting', '${pumpState.isPumpInjecting}'); } catch(e) {}");

    final testMode = ref.read(testModeProvider);

    final basalText = (testMode || pumpState.hasReceivedSummary) ? pumpState.basalSum.toStringAsFixed(1) : '---';
    final mealText = (testMode || pumpState.hasReceivedSummary) ? pumpState.mealSum.toStringAsFixed(1) : '---';
    final appendText = (testMode || pumpState.hasReceivedSummary) ? pumpState.appendSum.toStringAsFixed(1) : '---';

    final batteryText = (testMode || pumpState.hasReceivedBattery) ? '${(pumpState.batteryLevel * 25)}%' : '---';
    final batteryStorage = (testMode || pumpState.hasReceivedBattery) ? '${pumpState.batteryLevel}' : '---';
    final batteryWidth = (testMode || pumpState.hasReceivedBattery) ? '${(pumpState.batteryLevel * 25)}%' : '0%';

    final insulinText = (testMode || pumpState.hasReceivedInsulin) ? '${pumpState.insulinRemaining.toStringAsFixed(1)} / 300 U' : '--- / 300 U';
    final insulinStorage = (testMode || pumpState.hasReceivedInsulin) ? '${pumpState.insulinRemaining.toStringAsFixed(1)}' : '---';
    final insulinWidth = (testMode || pumpState.hasReceivedInsulin) ? '${(pumpState.insulinRemaining / 300 * 100).clamp(0, 100)}%' : '0%';

    // 2.5 펌프 상태값 지속 업데이트를 위한 localStorage 주입
    _controller.runJavaScript('''
      try {
        localStorage.setItem('basalSum', '$basalText');
        localStorage.setItem('mealSum', '$mealText');
        localStorage.setItem('appendSum', '$appendText');
        localStorage.setItem('batteryLevel', '$batteryStorage');
        localStorage.setItem('insulinRemaining', '$insulinStorage');
      } catch(e) {}
    ''');

    // 3. 페이지별 커스텀 상태 동기화
    if (_currentUrl.contains("dashboard/code.html")) {
      final js = '''
        (function() {
          const valBasal = document.getElementById('val-basal');
          const valMeal = document.getElementById('val-meal');
          const valAdd = document.getElementById('val-add');
          const valBattery = document.getElementById('val-battery-pct');
          const barBattery = document.getElementById('bar-battery');
          const valInsulin = document.getElementById('val-insulin');
          const barInsulin = document.getElementById('bar-insulin');

          if (valBasal) {
            valBasal.textContent = '$basalText';
            try { localStorage.setItem('basalSum', '$basalText'); } catch(e) {}
          }
          if (valMeal) {
            valMeal.textContent = '$mealText';
            try { localStorage.setItem('mealSum', '$mealText'); } catch(e) {}
          }
          if (valAdd) {
            valAdd.textContent = '$appendText';
            try { localStorage.setItem('appendSum', '$appendText'); } catch(e) {}
          }
          if (valBattery) valBattery.textContent = '$batteryText';
          if (barBattery) barBattery.style.width = '$batteryWidth';
          if (valInsulin) valInsulin.textContent = '$insulinText';
          if (barInsulin) barInsulin.style.width = '$insulinWidth';
        })();
      ''';
      _controller.runJavaScript(js);
    } 
    else if (_currentUrl.contains("add_injection/code.html")) {
      _controller.runJavaScript('''
        (function() {
          try {
            localStorage.setItem('basalSum', '$basalText');
            localStorage.setItem('mealSum', '$mealText');
            localStorage.setItem('appendSum', '$appendText');
            
            const basalEl = document.getElementById('val-basal');
            const mealEl = document.getElementById('val-meal');
            const appendEl = document.getElementById('val-add');
            if (basalEl) basalEl.textContent = '$basalText' + ' U';
            if (mealEl) mealEl.textContent = '$mealText' + ' U';
            if (appendEl) appendEl.textContent = '$appendText' + ' U';
          } catch(e) {}
        })();
      ''');
    }
    else if (_currentUrl.contains("history/code.html")) {
      _sendHistoryLogsToWebview();
      
      _controller.runJavaScript('''
        (function() {
          try {
            localStorage.setItem('basalSum', '$basalText');
            localStorage.setItem('mealSum', '$mealText');
            localStorage.setItem('appendSum', '$appendText');
            
            const basalEl = document.getElementById('summary-basal');
            const mealEl = document.getElementById('summary-meal');
            const appendEl = document.getElementById('summary-append');
            if (basalEl) basalEl.textContent = '기초 ' + '$basalText';
            if (mealEl) mealEl.textContent = '식사 ' + '$mealText';
            if (appendEl) appendEl.textContent = '추가 ' + '$appendText';
          } catch(e) {}
        })();
      ''');
    } 
    else if (_currentUrl.contains("meal_setting/code.html") || 
             _currentUrl.contains("meal_injection/code.html") || 
             _currentUrl.contains("dining/code.html")) {
      final bf = pumpState.mealSettings['breakfast'] ?? 1.00;
      final ln = pumpState.mealSettings['lunch'] ?? 1.00;
      final dn = pumpState.mealSettings['dinner'] ?? 1.00;

      // localStorage에 식사 설정 저장 및 UI 바인딩 강제 갱신 스크립트 실행
      final settingsJson = '{"breakfast":"$bf","lunch":"$ln","dinner":"$dn"}';
      _controller.runJavaScript('''
        try {
          localStorage.setItem('meal_settings', '$settingsJson');
          
          // UI 요소도 강제 갱신 (식사 주입 및 회식 적용 화면 등에서 직접 연동되게 처리)
          const breakfastInput = document.getElementById('breakfast-val');
          const lunchInput = document.getElementById('lunch-val');
          const dinnerInput = document.getElementById('dinner-val');
          if (breakfastInput) breakfastInput.value = '$bf';
          if (lunchInput) lunchInput.value = '$ln';
          if (dinnerInput) dinnerInput.value = '$dn';
        } catch(e) {}
        if (window.receiveBleMealData) { 
          window.receiveBleMealData({ breakfast: '$bf', lunch: '$ln', dinner: '$dn' }); 
        }
      ''');
    }
    else if (_currentUrl.contains("basal_setting/code.html")) {
      final ratesJson = jsonEncode(pumpState.basalRates.map((r) => r.toStringAsFixed(2)).toList());
      _controller.runJavaScript("if (window.receiveBleBasalData) { window.receiveBleBasalData($ratesJson); }");
    }
    else if (_currentUrl.contains("app_info/code.html")) {
      final fwVer = pumpState.firmwareVersion.isNotEmpty ? pumpState.firmwareVersion : "v1.0";
      _controller.runJavaScript('''
        (function() {
          try {
            localStorage.setItem('firmwareVersion', '$fwVer');
          } catch(e) {}
          const el = document.getElementById('fw-version');
          if (el) el.textContent = '$fwVer';
        })();
      ''');
    }
    else if (_currentUrl.contains("main_setting/code.html")) {
      final isPaused = pumpState.connectionState == PumpState.normalStop;
      _controller.runJavaScript("try { localStorage.setItem('isPaused', '$isPaused'); } catch(e) {}");
    }
  }

  /// 대시보드 페이지 서빙 (쿼리 파라미터 보존용)
  Future<void> _loadDashboardPage({String? query, bool showComplete = false}) async {
    try {
      if (showComplete) {
        // 대시보드로 넘어가기 직전에 로컬스토리지 완료 모달 표시 플래그 세팅
        await _controller.runJavaScript("try { localStorage.setItem('showCompleteModal', 'true'); } catch(e) {}");
      }
      final querySuffix = (query != null && query.isNotEmpty ? '?$query' : '');
      final htmlContent = await rootBundle.loadString('ui_design/dashboard/code.html');
      await _controller.loadHtmlString(
        htmlContent,
        baseUrl: 'file:///android_asset/flutter_assets/ui_design/dashboard/code.html$querySuffix',
      );
      print("[DEBUG] 대시보드 진입 감지 -> 시간 동기화 트리거");
      ref.read(timeSyncControllerProvider.notifier).startTimeSync(_controller);
    } catch (e) {
      print("대시보드 템플릿 서빙 에러: $e");
      // 실패 시 fallback
      await _controller.loadFlutterAsset('ui_design/dashboard/code.html');
      print("[DEBUG] 대시보드 진입 감지(fallback) -> 시간 동기화 트리거");
      ref.read(timeSyncControllerProvider.notifier).startTimeSync(_controller);
    }
  }

  /// 비밀번호 입력 페이지 하이재킹 치환 서빙
  Future<void> _loadInterceptedPasswordPage() async {
    final pumpState = ref.read(pumpStateProvider);
    try {
      final htmlContent = await rootBundle.loadString('ui_design/password/code.html');
      // 암호 매치 변수를 기기 실암호(또는 수동 주입된 비밀번호)로 하이재킹 치환
      // isPasswordProvisioned가 true일 때만 기기 패킷에서 받은 비밀번호를 사용하고, 그렇지 않으면 디폴트 '000000'을 사용
      final targetPin = pumpState.isPasswordProvisioned ? pumpState.password : '000000';
      final updatedHtml = htmlContent.replaceAll("correctPin = '000000'", "correctPin = '$targetPin'");
      _controller.loadHtmlString(updatedHtml, baseUrl: 'file:///android_asset/flutter_assets/ui_design/password/code.html');
    } catch (e) {
      print("비밀번호 하이재킹 템플릿 서빙 에러: $e → 대시보드로 fallback 이동");
      _loadDashboardPage();
    }
  }

  /// 웹뷰 및 델리게이트 구성
  void _initWebViewController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF8FAFA))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView loading: $progress%');
          },
          onPageStarted: (String url) {
            _currentUrl = url;
            setState(() {
              _isWebViewLoaded = false;
            });
          },
          onPageFinished: (String url) async {
            // Tailwind CDN 비동기 다운로드 및 레이아웃(스케일링) 계산 대기를 위해 400ms 지연 후 페이드인
            Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted) {
                setState(() {
                  _isWebViewLoaded = true;
                });
              }
            });
            _currentUrl = url;
            if (url.contains("history/code.html")) {
              print("[DEBUG] 히스토리 진입 감지 -> DB 로드 시작");
              await ref.read(basalSyncControllerProvider.notifier).reloadLogsFromDb();
              print("[DEBUG] 히스토리 진입 감지 -> DB 로드 완료");
            }
            if (url.contains("dashboard/code.html")) {
              print("[DEBUG] 대시보드 진입 감지 -> 시간 동기화 트리거");
              ref.read(timeSyncControllerProvider.notifier).startTimeSync(_controller);
            }
            _syncStateToWebview();
            
            // === [TEST MODE ONLY] ===
            if (_enableAutoMacro) {
              if (url.contains("ble_connect/code.html")) {
                _controller.runJavaScript('''
                  (function() {
                    const intervalAllow = setInterval(() => {
                      try {
                        const btn = Array.from(document.querySelectorAll('button')).find(el => el.textContent.includes('허용'));
                        if (btn) {
                          clearInterval(intervalAllow);
                          btn.click();
                          
                          // 허용 클릭 후 HealUS 장치가 검색되어 나타날 때까지 추가 폴링
                          const intervalDev = setInterval(() => {
                            try {
                              const dev = Array.from(document.querySelectorAll('button')).find(el => el.textContent.includes('HealUS'));
                              if (dev) {
                                clearInterval(intervalDev);
                                dev.click();
                              }
                            } catch(e) {}
                          }, 200);
                          setTimeout(() => clearInterval(intervalDev), 10000);
                        }
                      } catch(e) {}
                    }, 200);
                    setTimeout(() => clearInterval(intervalAllow), 10000);
                  })();
                ''');
              }
              else if (url.contains("password/code.html") || url.startsWith("data:text/html")) {
                _controller.runJavaScript('''
                  (function() {
                    const intervalPin = setInterval(() => {
                      try {
                        const zeroBtn = Array.from(document.querySelectorAll('button')).find(el => el.textContent.trim() === '0');
                        if (zeroBtn) {
                          clearInterval(intervalPin);
                          for (let i = 0; i < 6; i++) {
                            zeroBtn.click();
                          }
                        }
                      } catch(e) {}
                    }, 200);
                    setTimeout(() => clearInterval(intervalPin), 10000);
                  })();
                ''');
              }
              else if (url.contains("dashboard/code.html")) {
                _requestDashboardInitialData();
                _controller.runJavaScript('''
                  (function() {
                    const intervalDashboard = setInterval(() => {
                      try {
                        // 1. 주입 요청 모달 OK 버튼 처리
                        const reqModal = document.getElementById('request-modal');
                        if (reqModal && reqModal.classList.contains('active')) {
                          const reqOkBtn = document.getElementById('btn-request-ok');
                          if (reqOkBtn) {
                            clearInterval(intervalDashboard);
                            reqOkBtn.click();
                            return;
                          }
                        }

                        // 2. 주입 완료 모달 OK 버튼 처리
                        const compModal = document.getElementById('complete-modal');
                        if (compModal && compModal.classList.contains('active')) {
                          const compOkBtn = document.getElementById('btn-complete-ok');
                          if (compOkBtn) {
                            clearInterval(intervalDashboard);
                            compOkBtn.click();
                            return;
                          }
                        }

                        // 3. 둘 다 아니면 식사 주입 버튼 클릭
                        const mealBtn = Array.from(document.querySelectorAll('button')).find(el => el.textContent.includes('식사 주입'));
                        if (mealBtn) {
                          clearInterval(intervalDashboard);
                          mealBtn.click();
                        }
                      } catch(e) {}
                    }, 200);
                    setTimeout(() => clearInterval(intervalDashboard), 10000);
                  })();
                ''');
              }
              else if (url.contains("meal_injection/code.html")) {
                _controller.runJavaScript('''
                  (function() {
                    const intervalInject = setInterval(() => {
                      try {
                        const injectBtn = Array.from(document.querySelectorAll('footer button')).find(el => el.textContent.includes('주입하기'));
                        if (injectBtn) {
                          clearInterval(intervalInject);
                          injectBtn.click();
                        }
                      } catch(e) {}
                    }, 200);
                    setTimeout(() => clearInterval(intervalInject), 10000);
                  })();
                ''');
              }
            } else {
              // 매크로가 꺼져 있어도 대시보드 진입 시 초기 데이터 동기화 기동은 필수
              if (url.contains("dashboard/code.html")) {
                _requestDashboardInitialData();
              }
            }
            // ========================
          },
          onNavigationRequest: (NavigationRequest request) {
            // 모든 .html 파일 페이지 탐색 가로채기 (CORS 우회 및 올바른 로컬 애셋 경로 매핑)
            if (request.url.contains(".html") && !request.url.startsWith("data:text/html")) {
              // dashboard와 password는 기존 커스텀 핸들러가 처리하도록 위임
              if (request.url.contains("dashboard/code.html")) {
                print("[DEBUG] Navigation request to dashboard detected.");
                final uri = Uri.parse(request.url);
                _loadDashboardPage(query: uri.hasQuery ? uri.query : null);
                return NavigationDecision.prevent;
              }
              if (request.url.contains("password/code.html")) {
                final isSuccess = ref.read(bleHandshakeControllerProvider).isSuccess;
                if (isSuccess || _isConnectingDevice) {
                  return NavigationDecision.prevent;
                }
                
                final uri = Uri.parse(request.url);
                final macAddress = uri.queryParameters['mac'] ?? "20:73:6A:19:3E:41";
                
                _startDeviceConnection(macAddress);
                return NavigationDecision.prevent;
              }
              
              // 나머지 모든 하위 화면에 대한 공통 Intercept & loadHtmlString 변환 처리
              // 예: file:///android_asset/flutter_assets/ui_design/meal_injection/code.html
              final uri = Uri.parse(request.url);
              final pathSegments = uri.pathSegments;
              if (pathSegments.length >= 2) {
                // 뒤에서 두 번째가 폴더 이름, 마지막이 파일 이름 (예: meal_injection, code.html)
                final folder = pathSegments[pathSegments.length - 2];
                final filename = pathSegments.last;
                final assetPath = 'ui_design/$folder/$filename';
                print("[DEBUG] Intercepted navigation to subpage: $assetPath");
                
                rootBundle.loadString(assetPath).then((htmlContent) {
                  final querySuffix = uri.hasQuery ? '?${uri.query}' : '';
                  _controller.loadHtmlString(
                    htmlContent,
                    baseUrl: 'file:///android_asset/flutter_assets/$assetPath$querySuffix',
                  ).then((_) {
                    // 페이지 로딩 지연 대응을 위해 50ms 후 상태 정보 재동기화 수행
                    Future.delayed(const Duration(milliseconds: 50), () {
                      _syncStateToWebview();
                    });
                  });
                }).catchError((err) {
                  print("[ERROR] Failed to load $assetPath via loadHtmlString: $err");
                  _controller.loadFlutterAsset(assetPath);
                });
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setOnConsoleMessage((consoleMessage) {
        _handleConsoleMessage(consoleMessage.message);
      });

    rootBundle.loadString('ui_design/ble_connect/code.html').then((htmlContent) {
      _controller.loadHtmlString(
        htmlContent,
        baseUrl: 'file:///android_asset/flutter_assets/ui_design/ble_connect/code.html',
      );
    }).catchError((e) {
      print("Error loading ble_connect via loadHtmlString: $e");
      _controller.loadFlutterAsset('ui_design/ble_connect/code.html');
    });

    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(basalSyncControllerProvider);

    ref.listen<BasalSyncState>(basalSyncControllerProvider, (previous, next) {
      print("[DEBUG] main.dart ref.listen(basalSyncControllerProvider): "
          "prevSync=${previous?.isSyncingLogs}, nextSync=${next.isSyncingLogs}, "
          "prevLogs=${previous?.logs.length}, nextLogs=${next.logs.length}");
      final wasSyncing = previous?.isSyncingLogs ?? false;
      final isSyncing = next.isSyncingLogs;
      final logsChanged = previous?.logs != next.logs;
      if ((wasSyncing && !isSyncing) || logsChanged) {
        print("[DEBUG] main.dart: History sync completed or logs changed, pushing data to Webview");
        _sendHistoryLogsToWebview();
      }
    });

    // 1. Riverpod 전역 에러 리스너 바인딩
    ref.listen(errorInterceptorProvider, (previous, next) {
      if (next.hasError) {
        // 어떠한 화면에 있더라도 즉시 대시보드로 이동시킴 (기획서 명세 100% 반영)
        if (!_currentUrl.contains("dashboard/code.html") && !_isRedirecting) {
          _isRedirecting = true;
          _loadDashboardPage().then((_) {
            _isRedirecting = false;
          });
        }
      }
    });

    // 2. 주입 종료 인디케이션 및 타임아웃 감시
    ref.listen(pumpStateProvider, (previous, next) {
      // 핵심 필드 변동 시 실시간으로 웹뷰 동기화 진행
      if (previous == null ||
          previous.insulinRemaining != next.insulinRemaining ||
          previous.batteryLevel != next.batteryLevel ||
          previous.basalSum != next.basalSum ||
          previous.mealSum != next.mealSum ||
          previous.appendSum != next.appendSum ||
          previous.isPumpInjecting != next.isPumpInjecting ||
          previous.basalRates != next.basalRates ||
          previous.mealSettings != next.mealSettings ||
          previous.hasReceivedBattery != next.hasReceivedBattery ||
          previous.hasReceivedInsulin != next.hasReceivedInsulin ||
          previous.hasReceivedSummary != next.hasReceivedSummary ||
          previous.firmwareVersion != next.firmwareVersion) {
        print("[DEBUG] main.dart: pump state changed, triggering _syncStateToWebview()");
        _syncStateToWebview();
      }

      // 비밀번호 갱신 시 화면 실시간 반영
      if (previous == null ||
          previous.password != next.password ||
          previous.isPasswordProvisioned != next.isPasswordProvisioned) {
        if (_currentUrl.contains("password/code.html") || _currentUrl.startsWith("data:text/html")) {
          print("[DEBUG] main.dart: password updated while on password page, reloading hijacked page");
          _loadInterceptedPasswordPage();
        }
      }

      final wasInjecting = previous?.isPumpInjecting ?? false;
      final isInjecting = next.isPumpInjecting;
      print("[DEBUG] main.dart pumpStateProvider listener: wasInjecting=$wasInjecting, isInjecting=$isInjecting");

      // 주입 개시 감지 (isPumpInjecting: false -> true)
      if (!wasInjecting && isInjecting) {
        _injectTimeoutTimer?.cancel();
        _injectTimeoutTimer = Timer(const Duration(seconds: 3), () {
          // === [TEST MODE ONLY] ===
          if (!kReleaseMode) {
            print("주입완료 메시지(0x3B)가 3초간 수신되지 않음 -> 테스트 모드 전환");
            ref.read(testModeProvider.notifier).state = true;
            _syncStateToWebview();
          }

          _mockWaitTimer?.cancel();
          _mockWaitTimer = Timer(const Duration(seconds: 5), () {
            print("테스트 모드 5초 대기 완료 -> 가상의 BLE 주입 완료 패킷(0x3B) 트리거");
            final bleService = ref.read(bleServiceProvider);
            if (bleService is MockBleService) {
              bleService.fireFakeStopPacket();
            } else if (bleService is BleServiceManager) {
              bleService.fireFakeStopPacket();
            }
          });
          // ========================
        });
      }

      // 주입 정상/비정상 종료 감지 (isPumpInjecting: true -> false)
      if (wasInjecting && !isInjecting) {
        _injectTimeoutTimer?.cancel();
        _mockWaitTimer?.cancel();

        if (_currentUrl.contains("dashboard/code.html")) {
          // 이미 대시보드 화면인 경우: 깜빡임 없이 즉시 완료 모달 팝업 가동
          _controller.runJavaScript("try { openModal('complete'); } catch(e) {}");
        } else {
          // 다른 화면에 있는 경우: 대시보드로 이동하고 로딩 완료 시점에 모달 자동 팝업
          if (!_isRedirecting) {
            _isRedirecting = true;
            _loadDashboardPage(showComplete: true).then((_) {
              _isRedirecting = false;
            });
          }
        }
      }
    });

    final errorState = ref.watch(errorInterceptorProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          if (context.mounted) {
            await SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 백그라운드 웹뷰
            Container(
              color: const Color(0xFFF8FAFA), // HTML 백그라운드 색상과 일치시켜 로딩 중 자연스럽게 보이도록 함
              child: SafeArea(
                child: AnimatedOpacity(
                  opacity: _isWebViewLoaded ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: WebViewWidget(controller: _controller),
                ),
              ),
            ),

            // 네이티브 연결 진행 로딩 팝업
            if (_isConnectingDevice)
              Container(
                color: Colors.black.withOpacity(0.65),
                child: Center(
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15.0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F6568)),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "인슐린 펌프 연결 중",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _connectingStatusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 네이티브 에러 경고 팝업 (기획서 사양 100% 만족)
            if (errorState.hasError)
              Container(
                color: Colors.black.withOpacity(0.55),
                child: Center(
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15.0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "장치 오류 발생",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          errorState.errorType.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              ref.read(errorInterceptorProvider.notifier).clearError();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F6568),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "확인",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 기초 설정 동기화 진행 로딩 팝업
            if (syncState.isSyncingBasal)
              Container(
                color: Colors.black.withOpacity(0.65),
                child: Center(
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15.0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          value: syncState.basalSyncProgress,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1F6568)),
                          backgroundColor: Colors.white10,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "기초 설정 저장 중",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "인슐린 펌프에 전송 중입니다... (${(syncState.basalSyncProgress * 6).round()}/6)",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 이력 데이터 동기화 진행 로딩 팝업
            if (syncState.isSyncingLogs)
              Container(
                color: Colors.black.withOpacity(0.65),
                child: Center(
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15.0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F6568)),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "이력 데이터 수집 중",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "인슐린 펌프로부터 이력 데이터를 가져오고 있습니다...",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // === 디버그 패킷 수동 주입 플로팅 버튼 (실제 앱 로깅용으로 임시 활성화) ===
            Positioned(
              right: 16,
                bottom: 90,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: const Color(0xFF1B2330),
                  foregroundColor: Colors.tealAccent,
                  onPressed: _showDebugPacketDialog,
                  tooltip: "가상 패킷 수동 주입",
                  child: const Icon(Icons.terminal),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
