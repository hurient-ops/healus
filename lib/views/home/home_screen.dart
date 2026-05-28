import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/pump_state_provider.dart';
import '../../services/sync/basal_sync_controller.dart';
import '../../services/inject/inject_controller.dart';
import '../../services/error/error_interceptor.dart';
import '../../services/ble/opcodes.dart';
import '../common/ui_lock_overlay.dart';
import '../common/error_overlay.dart';
import 'widgets/status_bar.dart';
import 'widgets/battery.dart';
import '../inject/inject_sheet.dart';

/// HealUS 모바일 앱 메인 대시보드 화면
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 로딩 시 로컬 DB의 주입 이력 정보 로드
    Future.microtask(() {
      ref.read(basalSyncControllerProvider.notifier).reloadLogsFromDb();
    });
  }

  /// 인슐린 주입 바텀시트 열기
  void _openInjectSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const InjectSheet(),
    );
  }

  /// 24시간 기초 설정값 강제 동기화 (테스트용)
  Future<void> _syncBasalSettings() async {
    // 24시간분량의 기초 주입 속도 (예시 데이터)
    final List<double> dummyBasalRates = List.generate(24, (index) {
      if (index >= 9 && index <= 17) return 1.5; // 일중 활동 시간대
      return 0.8; // 야간/수면 시간대
    });

    final success = await ref
        .read(basalSyncControllerProvider.notifier)
        .sync24hBasalSettings(dummyBasalRates);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "24시간 기초 설정 동기화가 성공적으로 완료되었습니다." : "동기화가 실패하였습니다."),
          backgroundColor: success ? const Color(0xFF004D40) : Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pumpState = ref.watch(pumpStateProvider);
    final syncState = ref.watch(basalSyncControllerProvider);

    const primaryColor = Color(0xFFFFD700); // 골드
    const deepTealColor = Color(0xFF004D40); // 딥 틸
    const scaffoldBg = Color(0xFF0D1117); // 딥다크 백그라운드

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: ErrorOverlay(
        child: UiLockOverlay(
          onEmergencyPressed: () {
            // 긴급 주입 정지 패킷 송출
            ref.read(injectControllerProvider.notifier).requestEmergencyStop();
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 상단 상태바 위젯
                  const StatusBar(),
                  const SizedBox(height: 20),

                  // 2. 오늘 요약 인슐린 대시보드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "인슐린 잔량",
                                  style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  "남은 용량",
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: deepTealColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: deepTealColor.withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.water_drop_rounded, color: primaryColor, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${pumpState.insulinRemaining.toStringAsFixed(1)} / 300 U",
                                    style: const TextStyle(
                                      color: primaryColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (pumpState.insulinRemaining / 300.0).clamp(0.0, 1.0),
                            backgroundColor: Colors.white.withOpacity(0.08),
                            valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. 배터리 정보 컴포넌트
                  const BatteryWidget(),

                  const SizedBox(height: 20),

                  // 24시간 기초 설정 동기화 진행 상태 바 (동기화 진행 중인 경우에만 표시)
                  if (syncState.isSyncingBasal) ...[
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      margin: const EdgeInsets.only(bottom: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "24시간 기초 설정 동기화 중...",
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "${(syncState.basalSyncProgress * 100).toInt()}%",
                                style: const TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: syncState.basalSyncProgress,
                            backgroundColor: Colors.white.withOpacity(0.08),
                            valueColor: const AlwaysStoppedAnimation<Color>(deepTealColor),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 4. 빠른 제어 & 기능 버튼들
                  const Text(
                    "동작 제어",
                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _buildControlCard(
                        title: "인슐린 주입",
                        subtitle: "식사/추가 선택 주입",
                        icon: Icons.play_circle_filled_rounded,
                        iconColor: primaryColor,
                        onTap: _openInjectSheet,
                      ),
                      _buildControlCard(
                        title: "24h 기초 동기화",
                        subtitle: "시간별 분할 전송",
                        icon: Icons.sync_rounded,
                        iconColor: Colors.blueAccent,
                        onTap: _syncBasalSettings,
                      ),
                      _buildControlCard(
                        title: "이력 로그 수집",
                        subtitle: "최대 15일 이력 요청",
                        icon: Icons.history_edu_rounded,
                        iconColor: Colors.orangeAccent,
                        onTap: () {
                          ref.read(basalSyncControllerProvider.notifier).requestHistoryLogs();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("이력 로그 동기화 패킷을 전송했습니다. 대량 모드로 전환합니다."),
                              backgroundColor: Colors.orangeAccent,
                            ),
                          );
                        },
                      ),
                      _buildControlCard(
                        title: "로그 클리어",
                        subtitle: "로컬 DB 비우기",
                        icon: Icons.delete_sweep_rounded,
                        iconColor: Colors.redAccent,
                        onTap: () async {
                          final db = ref.read(pumpDatabaseProvider);
                          await db.clearLogs();
                          ref.read(basalSyncControllerProvider.notifier).reloadLogsFromDb();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("로컬 DB의 이력 정보가 전부 비워졌습니다.")),
                            );
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 5. 로컬 DB에 누적된 주입 히스토리 차트/목록 리스트
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "주입 이력 로그 (최근)",
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "누적 ${syncState.logs.length}건",
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (syncState.logs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.01),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        "저장된 인슐린 주입 이력 데이터가 없습니다.",
                        style: TextStyle(color: Colors.white30, fontSize: 13),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: syncState.logs.length > 5 ? 5 : syncState.logs.length,
                      itemBuilder: (context, index) {
                        final log = syncState.logs[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${log.month}월 ${log.day}일 기록",
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "기초: ${log.baseTotal}U | 식사: ${log.eatTotal}U | 추가: ${log.appendTotal}U",
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                  ),
                                ],
                              ),
                              Text(
                                "+${(log.baseTotal + log.eatTotal + log.appendTotal).toStringAsFixed(2)} U",
                                style: const TextStyle(color: primaryColor, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 24),

                  // 6. 시뮬레이션용 보조 테스트 패널 (유저 테스트용 기기 연결 상태 Mock 조작)
                  _buildMockControlPanel(ref),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 수동 테스트 시 시나리오를 제어하기 위한 모의 조작 패널
  Widget _buildMockControlPanel(WidgetRef ref) {
    final stateNotifier = ref.read(pumpStateProvider.notifier);
    final errorNotifier = ref.read(errorInterceptorProvider.notifier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.build_circle_outlined, color: Colors.redAccent, size: 16),
              SizedBox(width: 6),
              Text(
                "테스트 시뮬레이션 제어 (기기 없을 때 대체)",
                style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => stateNotifier.setInjecting(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 11)),
                child: const Text("주입 시작 모의 (UI Lock)"),
              ),
              ElevatedButton(
                onPressed: () => stateNotifier.setInjecting(false),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 11)),
                child: const Text("주입 완료 모의 (Lock 해제)"),
              ),
              ElevatedButton(
                onPressed: () => errorNotifier.setErrorForce(PumpErrorType.needleClogged, DateTime.now()),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]?.withOpacity(0.4), foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 11)),
                child: const Text("바늘 막힘 에러 트리거"),
              ),
              ElevatedButton(
                onPressed: () => errorNotifier.setErrorForce(PumpErrorType.lowBatt, DateTime.now()),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]?.withOpacity(0.4), foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 11)),
                child: const Text("배터리 부족 에러 트리거"),
              ),
              ElevatedButton(
                onPressed: () {
                  // 임의의 응답(Ack)을 시뮬레이터에 전달하여 대기 중인 동기화 큐 승인
                  ref.read(basalSyncControllerProvider.notifier).handleSetResponse(ResCode.ok);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 11)),
                child: const Text("Basal Ack 모의전달"),
              ),
              ElevatedButton(
                onPressed: () async {
                  // 대량 이력 데이터 패킷 유입 모의 시나리오 시작
                  final syncNotifier = ref.read(basalSyncControllerProvider.notifier);
                  // 1. Start 알림
                  await syncNotifier.handleIncomingPacket([kStartCode, Opcodes.btDataStartInd, 0, ...List.filled(17, 0)]);
                  // 2. 14Byte 이력 3일치 주입
                  // packet layout: [0] Start, [1] Opcode (arbitrary as it matches syncing status and length == 14), [2] Length=14, [3] month, [4] day, [5-6] base, [7-8] eat, [9-10] morning, [11-12] afternoon, [13-14] evening, [15-16] append, [17-19] dummy
                  final l1 = [kStartCode, 0x99, 14, 5, 25, 0x64, 0x00, 0xC8, 0x00, 0x32, 0x00, 0x64, 0x00, 0x32, 0x00, 0x1E, 0x00, 0, 0, 0]; // base 1.0, eat 2.0, morning 0.5...
                  final l2 = [kStartCode, 0x99, 14, 5, 26, 0x96, 0x00, 0xFA, 0x00, 0x64, 0x00, 0x96, 0x00, 0x64, 0x00, 0x28, 0x00, 0, 0, 0]; // base 1.5, eat 2.5...
                  await syncNotifier.handleIncomingPacket(l1);
                  await syncNotifier.handleIncomingPacket(l2);
                  // 3. End 알림
                  await syncNotifier.handleIncomingPacket([kStartCode, Opcodes.btDataEndInd, 0, ...List.filled(17, 0)]);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 11)),
                child: const Text("이력 2건 벌크 유입 모의"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
