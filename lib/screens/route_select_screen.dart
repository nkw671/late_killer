import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bus_stop.dart';
import '../models/bus_route.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'alarm_setting_screen.dart';

/// 경유 노선 확인(UC-04, REQ-05) + 알람 노선 선택(UC-05, REQ-06)
///
/// 노선 카드를 탭하면 해당 노선 하나로 알람 설정 페이지로 바로 이동.
/// 여러 노선을 동시에 선택하려면 체크박스를 체크 후 하단 버튼 사용.
class RouteSelectScreen extends StatefulWidget {
  final BusStop stop;
  const RouteSelectScreen({super.key, required this.stop});

  @override
  State<RouteSelectScreen> createState() => _RouteSelectScreenState();
}

class _RouteSelectScreenState extends State<RouteSelectScreen> {
  bool _loading = true;
  List<BusRoute> _routes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    state.clearRouteSelection();
    final res = await state.loadArrivals(widget.stop);
    if (mounted) {
      setState(() {
        _routes = res;
        _loading = false;
      });
    }
  }

  void _goToAlarmSetting(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AlarmSettingScreen(stop: widget.stop)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selectedCount = state.selectedRoutes.length;
    final isFav = state.favorites.contains(widget.stop);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stop.stopName),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.star_rounded : Icons.star_border_rounded,
              color: isFav ? AppColors.amber : AppColors.textTertiary,
            ),
            onPressed: () {
              if (isFav) {
                state.removeFavorite(widget.stop);
              } else {
                state.addFavorite(widget.stop);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${widget.stop.stopName} 즐겨찾기 추가됨'),
                  duration: const Duration(seconds: 1),
                ));
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent))
            : Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    const SectionHeader(
                      title: '경유 노선',
                      subtitle: '탭하면 바로 알람 설정 · 체크 후 버튼으로 다중 선택',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (state.apiError != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: SoftCard(
                          border: AppColors.danger,
                          child: Row(
                            children: [
                              Icon(Icons.warning_rounded,
                                  color: AppColors.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(state.apiError!,
                                    style: TextStyle(
                                        color: AppColors.danger,
                                        fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_routes.isEmpty && state.apiError == null)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.directions_bus_rounded,
                                  size: 48, color: AppColors.textTertiary),
                              const SizedBox(height: 12),
                              const Text('도착 예정 버스가 없습니다',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(
                                '정류장 ID가 올바른지 확인하거나\n노선번호 탭에서 검색해보세요',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_routes.isNotEmpty)
                    Expanded(
                      child: ListView.separated(
                        itemCount: _routes.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          final r = _routes[i];
                          final selected =
                              state.selectedRoutes.contains(r);
                          return SoftCard(
                            border: selected ? AppColors.accent : null,
                            onTap: () {
                              // 단일 탭: 이 노선만 선택하고 바로 알람 설정으로
                              state.clearRouteSelection();
                              state.toggleRouteSelection(r);
                              _goToAlarmSetting(context);
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.accent
                                            .withOpacity(0.15)
                                        : AppColors.surfaceAlt,
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    r.routeNo,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: selected
                                            ? AppColors.accent
                                            : AppColors.textPrimary),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${r.routeNo}번',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight:
                                                  FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      Text(
                                          r.busArriveTime > 0
                                              ? '${formatArrival(r.busArriveTime)} 후 도착'
                                              : '도착 정보 없음',
                                          style: AppTheme.mono(
                                              size: 12.5,
                                              color: r.busArriveTime > 0
                                                  ? AppColors.accent
                                                  : AppColors
                                                      .textTertiary)),
                                    ],
                                  ),
                                ),
                                // 체크박스: 다중선택용 (탭 전파 차단)
                                GestureDetector(
                                  onTap: () =>
                                      state.toggleRouteSelection(r),
                                  behavior: HitTestBehavior.opaque,
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 160),
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppColors.accent
                                          : Colors.transparent,
                                      border: Border.all(
                                          color: selected
                                              ? AppColors.accent
                                              : AppColors.textTertiary,
                                          width: 2),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: selected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 18,
                                            color: Color(0xFF06210F))
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

      ),
      // 다중 선택 시 하단 버튼
      bottomNavigationBar: selectedCount < 2
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ElevatedButton(
                  onPressed: () => _goToAlarmSetting(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: Text('$selectedCount개 노선으로 알람 설정 →'),
                ),
              ),
            ),
    );
  }
}
