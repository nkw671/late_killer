import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 버스 도착 알림 수신 (UC-07) — 실시간 모니터링 화면.
/// 1초 간격 로컬 카운트다운(AppState._uiTick) + 8초 API 폴링.
class AlarmRunningScreen extends StatefulWidget {
  const AlarmRunningScreen({super.key});

  @override
  State<AlarmRunningScreen> createState() => _AlarmRunningScreenState();
}

class _AlarmRunningScreenState extends State<AlarmRunningScreen> {
  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _stopAndGoHome() async {
    _goHome(); // 네비게이션 먼저 (context 살아있을 때)
    await context.read<AppState>().stopAlarm();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // onAllPassed 등으로 알람이 자동 종료되면 홈으로 복귀
    if (!state.alarmRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goHome());
    }
    final target = state.departureAlarm.currentTargetBus;
    final walk = state.departureAlarm.walkTimeToStop;
    final secs = target?.busArriveTime ?? 0;
    final shouldDepart = secs > 0 && secs <= walk * 60;

    final Color statusColor = target == null
        ? AppColors.textTertiary
        : shouldDepart
            ? AppColors.danger
            : (secs <= walk * 60 + 60 ? AppColors.amber : AppColors.accent);

    return PopScope(
      // 뒤로가기 버튼으로도 알람 정지
      canPop: false,
      onPopInvokedWithResult: (_, __) => _stopAndGoHome(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('실시간 알람'),
          automaticallyImplyLeading: false, // 뒤로가기 숨김 (중지 버튼으로만 나감)
          actions: const [],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Text(state.activeStop?.stopName ?? '',
                    style: const TextStyle(
                        fontSize: 16, color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.lg),

                // 스케줄 창 밖이면 알림이 억제됨을 명시 (카운트다운만 표시)
                if (!state.departureAlarm.isScheduleActiveNow()) ...[
                  SoftCard(
                    border: AppColors.amber,
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            color: AppColors.amber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '지금은 알람 감시 시간이 아니에요. 도착 시간만 표시되며 출발 알림은 울리지 않습니다.',
                            style: TextStyle(
                                color: AppColors.amber,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 메인 카운트다운 카드
                Expanded(
                  child: SoftCard(
                    border: statusColor,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SignalDot(color: statusColor, size: 12),
                            const SizedBox(width: 8),
                            Text(
                              target == null
                                  ? '대기 중'
                                  : shouldDepart
                                      ? '지금 출발하세요!'
                                      : '도착 대기',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (target != null) ...[
                          Text('${target.routeNo}번',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: AppSpacing.md),
                          Text(formatMMSS(secs),
                              style: AppTheme.mono(
                                  size: 72,
                                  weight: FontWeight.w700,
                                  color: statusColor)),
                          const SizedBox(height: 8),
                          Text('도착까지 남은 시간',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ] else
                          Text('선택한 버스를 기다리는 중…',
                              style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 15)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 최근 이벤트
                if (state.lastEvent != null)
                  SoftCard(
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_rounded,
                            color: AppColors.info, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(state.lastEvent!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),

                // 선택 노선들의 도착 현황
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('선택 노선 현황',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 12),
                      ...state.selectedRoutes.map((r) {
                        final isTarget = r == target;
                        final passed = r.busArriveTime == 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              SignalDot(
                                  color: isTarget
                                      ? AppColors.accent
                                      : passed
                                          ? AppColors.danger
                                          : AppColors.textTertiary,
                                  size: 8,
                                  glow: isTarget),
                              const SizedBox(width: 10),
                              Text('${r.routeNo}번',
                                  style: TextStyle(
                                      fontWeight: isTarget
                                          ? FontWeight.w700
                                          : FontWeight.w500)),
                              const Spacer(),
                              // 통과 후 다음 버스 시간이 업데이트되면 자동으로 표시됨
                              Text(
                                r.busArriveTime > 0
                                    ? formatArrival(r.busArriveTime)
                                    : '통과 · 다음 대기 중',
                                style: AppTheme.mono(
                                    size: 13,
                                    color: r.busArriveTime > 0
                                        ? AppColors.textSecondary
                                        : AppColors.textTertiary),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: OutlinedButton.icon(
              onPressed: _stopAndGoHome,
              icon: const Icon(Icons.stop_rounded, color: AppColors.danger),
              label: const Text('알람 중지',
                  style: TextStyle(
                      color: AppColors.danger, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
