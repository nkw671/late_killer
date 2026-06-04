import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../models/bus_alarm.dart';
import 'search_screen.dart';
import 'route_select_screen.dart';
import 'alarm_running_screen.dart';

/// 홈 — 검색창 + 즐겨찾기 정류장 + 설정된 알람 목록
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── 헤더 + 검색창 ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: AppColors.accentGradient,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(Icons.directions_bus_rounded,
                              color: Color(0xFF06210F)),
                        ),
                        const SizedBox(width: 12),
                        const Text('버스 알람',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8)),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // 검색창 (탭하면 SearchScreen으로 이동)
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SearchScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded,
                                color: AppColors.textTertiary, size: 20),
                            const SizedBox(width: 10),
                            Text('정류장 이름 또는 번호로 검색',
                                style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── 저장된 알람 목록 ───
            _buildBusAlarmSection(context, state),

            // ─── 즐겨찾는 정류장 ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: const SectionHeader(
                  title: '즐겨찾는 정류장',
                  subtitle: '정류장을 탭하여 노선을 선택하고 알람을 설정하세요',
                ),
              ),
            ),
            if (state.favorites.isEmpty)
              SliverToBoxAdapter(child: _EmptyFavorites())
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                sliver: SliverList.separated(
                  itemCount: state.favorites.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final stop = state.favorites[i];
                    return SoftCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => RouteSelectScreen(stop: stop)),
                      ),
                      child: Row(
                        children: [
                          const SignalDot(color: AppColors.accent),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stop.stopName,
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text('정류장 번호 ${stop.stopNumber}',
                                    style: AppTheme.mono(
                                        size: 12.5,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.star_rounded,
                                color: AppColors.amber),
                            onPressed: () => state.removeFavorite(stop),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textTertiary),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildBusAlarmSection(BuildContext context, AppState state) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: SectionHeader(
                    title: '내 알람',
                    subtitle: '정류장과 노선을 검색해 알람을 추가하세요',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (state.busAlarms.isEmpty)
              SoftCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '저장된 알람이 없어요\n정류장을 검색해 알람을 만들어보세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 14),
                    ),
                  ),
                ),
              )
            else
              ...state.busAlarms.map((alarm) =>
                  _BusAlarmCard(alarm: alarm)),
          ],
        ),
      ),
    );
  }
}

/// 저장된 알람 카드 — 정류장/노선/스케줄 표시 + 실행/삭제
class _BusAlarmCard extends StatelessWidget {
  final BusAlarm alarm;
  const _BusAlarmCard({required this.alarm});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final routeLabel = alarm.routes.map((r) => '${r.routeNo}번').join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SoftCard(
        child: Row(
          children: [
            // 아이콘
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.alarm_rounded,
                  color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 14),
            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alarm.stopName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(routeLabel,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(alarm.scheduleLabel,
                          style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Text(alarm.timeLabel,
                          style: AppTheme.mono(
                              size: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 6),
                      Text('도보 ${alarm.walkTimeToStop}분',
                          style: TextStyle(
                              color: AppColors.textTertiary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            // 삭제
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.textTertiary, size: 20),
              onPressed: () => state.deleteBusAlarm(alarm.id),
            ),
            // 실행
            IconButton(
              icon: const Icon(Icons.play_circle_filled_rounded,
                  color: AppColors.accent, size: 28),
              onPressed: () async {
                await state.runBusAlarm(alarm);
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AlarmRunningScreen()),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.bookmark_border_rounded,
                  size: 34, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 14),
            const Text('즐겨찾는 정류장이 없어요',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 5),
            const Text('위 검색창으로 정류장을 찾아 추가하세요',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }
}
