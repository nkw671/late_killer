import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bus_stop.dart';
import '../models/bus_route.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'route_select_screen.dart';
import 'route_stop_select_screen.dart';

/// 정류장 검색 (REQ-01) + 노선번호 검색 (REQ-02) + 즐겨찾기 등록 (REQ-03)
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<BusStop> _stopResults = [];
  List<BusRoute> _routeResults = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // 탭 전환 시 검색어 유지하고 재검색
      if (!_tabController.indexIsChanging) _search();
    });
    _search();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (mounted) setState(() => _loading = true);
    final state = context.read<AppState>();

    try {
      if (_tabController.index == 0) {
        final res = await state.searchStops(q, byNumber: false);
        if (mounted) setState(() { _stopResults = res; _error = null; _loading = false; });
      } else {
        final res = await state.searchRoutes(q);
        if (mounted) setState(() { _routeResults = res; _error = null; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '서버 연결 실패: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('검색'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: _tabController.index == 0
                        ? '정류장 이름 입력 (예: 시청, 부평구청)'
                        : '노선번호 입력 (예: 564)',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textTertiary),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded,
                          color: AppColors.accent),
                      onPressed: _search,
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '정류장'),
                  Tab(text: '노선번호'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: 10),
                color: AppColors.danger.withOpacity(0.12),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _StopList(
                    loading: _loading,
                    results: _stopResults,
                    state: state,
                  ),
                  _RouteList(
                    loading: _loading,
                    results: _routeResults,
                    state: state,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 정류장 탭 ──────────────────────────────────────────
class _StopList extends StatelessWidget {
  final bool loading;
  final List<BusStop> results;
  final AppState state;
  const _StopList(
      {required this.loading, required this.results, required this.state});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            const Text('검색 결과가 없습니다',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              '정류장 이름으로 검색하세요\n예) 시청, 부평구청, 인천터미널',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final stop = results[i];
        final isFav = state.favorites.contains(stop);
        return SoftCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RouteSelectScreen(stop: stop)),
          ),
          child: Row(
            children: [
              const SignalDot(color: AppColors.textTertiary, size: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.stopName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('번호 ${stop.stopNumber}',
                        style: AppTheme.mono(
                            size: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFav ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFav ? AppColors.amber : AppColors.textTertiary,
                ),
                onPressed: () {
                  if (isFav) {
                    state.removeFavorite(stop);
                  } else {
                    state.addFavorite(stop);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${stop.stopName} 즐겨찾기 추가됨'),
                      duration: const Duration(seconds: 1),
                    ));
                  }
                },
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 18),
            ],
          ),
        );
      },
    );
  }
}

// ── 노선번호 탭 ─────────────────────────────────────────
class _RouteList extends StatelessWidget {
  final bool loading;
  final List<BusRoute> results;
  final AppState state;
  const _RouteList(
      {required this.loading, required this.results, required this.state});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (results.isEmpty) {
      return const Center(
          child: Text('검색 결과가 없습니다',
              style: TextStyle(color: AppColors.textTertiary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final route = results[i];
        final subtitle = (route.originStopName.isNotEmpty &&
                route.destStopName.isNotEmpty)
            ? '${route.originStopName} → ${route.destStopName}'
            : route.routeId;
        return SoftCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RouteStopSelectScreen(route: route)),
            );
          },
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  route.routeNo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.textPrimary),
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
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: AppTheme.mono(
                            size: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 18),
            ],
          ),
        );
      },
    );
  }

}
