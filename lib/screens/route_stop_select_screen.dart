import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bus_route.dart';
import '../models/bus_stop.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'alarm_setting_screen.dart';

/// 노선번호 검색 결과에서 노선을 선택한 뒤,
/// 해당 노선의 경유 정류소 목록을 보여주는 화면.
/// 정류소를 탭하면 그 정류소 + 이 노선으로 알람 설정 화면으로 이동.
class RouteStopSelectScreen extends StatefulWidget {
  final BusRoute route;
  const RouteStopSelectScreen({super.key, required this.route});

  @override
  State<RouteStopSelectScreen> createState() => _RouteStopSelectScreenState();
}

class _RouteStopSelectScreenState extends State<RouteStopSelectScreen> {
  bool _loading = true;
  List<BusStop> _stops = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stops =
          await context.read<AppState>().loadRouteSections(widget.route.routeId);
      if (mounted) setState(() { _stops = stops; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final route = widget.route;
    final subtitle = (route.originStopName.isNotEmpty && route.destStopName.isNotEmpty)
        ? '${route.originStopName} → ${route.destStopName}'
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text('${route.routeNo}번 경유 정류장'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 노선 요약
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: SoftCard(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.accentGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        route.routeNo,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF06210F)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${route.routeNo}번',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          if (subtitle.isNotEmpty)
                            Text(subtitle,
                                style: AppTheme.mono(
                                    size: 11.5,
                                    color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SectionHeader(
                title: '정류장 선택',
                subtitle: '알람을 설정할 정류장을 탭하세요',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // 정류소 목록
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text('불러오기 실패: $_error',
                                style: const TextStyle(
                                    color: AppColors.danger, fontSize: 13)),
                          ),
                        )
                      : _stops.isEmpty
                          ? const Center(
                              child: Text('경유 정류장 정보가 없습니다',
                                  style: TextStyle(
                                      color: AppColors.textTertiary)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg),
                              itemCount: _stops.length,
                              itemBuilder: (context, i) {
                                final stop = _stops[i];
                                final isFav =
                                    state.favorites.contains(stop);
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm),
                                  child: SoftCard(
                                    onTap: () {
                                      // 이 노선만 선택 후 알람 설정으로
                                      state.clearRouteSelection();
                                      state.toggleRouteSelection(route);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              AlarmSettingScreen(stop: stop),
                                        ),
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        // 순번 뱃지
                                        SizedBox(
                                          width: 32,
                                          child: Text(
                                            '${i + 1}',
                                            style: AppTheme.mono(
                                                size: 12,
                                                color: AppColors.textTertiary),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // 정류소 구분선
                                        Column(
                                          children: [
                                            Container(
                                              width: 2,
                                              height: 10,
                                              color: i == 0
                                                  ? Colors.transparent
                                                  : AppColors.surfaceAlt,
                                            ),
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: i == 0 ||
                                                        i == _stops.length - 1
                                                    ? AppColors.accent
                                                    : AppColors.textTertiary
                                                        .withOpacity(0.4),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            Container(
                                              width: 2,
                                              height: 10,
                                              color: i == _stops.length - 1
                                                  ? Colors.transparent
                                                  : AppColors.surfaceAlt,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(stop.stopName,
                                                  style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: i == 0 ||
                                                              i == _stops.length - 1
                                                          ? FontWeight.w700
                                                          : FontWeight.w500)),
                                              if (stop.shortStopId.isNotEmpty)
                                                Text(
                                                  '단축번호 ${stop.shortStopId}',
                                                  style: AppTheme.mono(
                                                      size: 11,
                                                      color: AppColors.textTertiary),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // 즐겨찾기 버튼
                                        IconButton(
                                          icon: Icon(
                                            isFav
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
                                            size: 20,
                                            color: isFav
                                                ? AppColors.amber
                                                : AppColors.textTertiary,
                                          ),
                                          onPressed: () {
                                            if (isFav) {
                                              state.removeFavorite(stop);
                                            } else {
                                              state.addFavorite(stop);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: Text(
                                                    '${stop.stopName} 즐겨찾기 추가됨'),
                                                duration: const Duration(
                                                    seconds: 1),
                                              ));
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
