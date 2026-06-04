import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/bus_stop.dart';
import '../models/day_of_week.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 알람 설정 (UC-06): 도보시간(REQ-07), 요일별 활성/시각(REQ-08/09), 볼륨(REQ-17)
class AlarmSettingScreen extends StatefulWidget {
  final BusStop stop;
  const AlarmSettingScreen({super.key, required this.stop});

  @override
  State<AlarmSettingScreen> createState() => _AlarmSettingScreenState();
}

class _AlarmSettingScreenState extends State<AlarmSettingScreen> {
  /// 드럼롤 시간 선택 바텀시트
  void _showTimePicker(
    BuildContext context,
    AppState state,
    DayOfWeek day,
    int initHour,
    int initMinute,
  ) {
    int selectedHour = initHour;
    int selectedMinute = initMinute;

    final hourController =
        FixedExtentScrollController(initialItem: initHour);
    final minuteController =
        FixedExtentScrollController(initialItem: initMinute);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Text('${day.labelKo}요일 알람 시간',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        state.setSchedule(
                            day, true, selectedHour, selectedMinute);
                        Navigator.pop(ctx);
                      },
                      child: Text('확인',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    // 시간 휠
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: hourController,
                        itemExtent: 52,
                        backgroundColor: Colors.transparent,
                        onSelectedItemChanged: (i) => selectedHour = i,
                        selectionOverlay: _WheelOverlay(),
                        children: List.generate(
                          24,
                          (i) => Center(
                            child: Text(
                              i.toString().padLeft(2, '0'),
                              style: AppTheme.mono(
                                  size: 32,
                                  weight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(':',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary)),
                    // 분 휠
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: minuteController,
                        itemExtent: 52,
                        backgroundColor: Colors.transparent,
                        onSelectedItemChanged: (i) => selectedMinute = i,
                        selectionOverlay: _WheelOverlay(),
                        children: List.generate(
                          60,
                          (i) => Center(
                            child: Text(
                              i.toString().padLeft(2, '0'),
                              style: AppTheme.mono(
                                  size: 32,
                                  weight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final alarm = state.departureAlarm;

    return Scaffold(
      appBar: AppBar(title: const Text('알람 설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // 선택된 노선 요약
            SoftCard(
              child: Row(
                children: [
                  const Icon(Icons.directions_bus_rounded,
                      color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${widget.stop.stopName} · '
                      '${state.selectedRoutes.map((e) => e.routeNo).join(", ")}번',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // REQ-07: 도보 소요 시간
            const SectionHeader(
                title: '도보 소요 시간', subtitle: '정류장까지 걸리는 시간 (1~60분)'),
            const SizedBox(height: AppSpacing.sm),
            SoftCard(
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.remove_rounded,
                    onTap: () => state.setWalkTime(alarm.walkTimeToStop - 1),
                  ),
                  Expanded(
                    child: Center(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                                text: '${alarm.walkTimeToStop}',
                                style: AppTheme.mono(
                                    size: 34,
                                    weight: FontWeight.w700,
                                    color: AppColors.accent)),
                            const TextSpan(
                                text: '  분',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _RoundIconButton(
                    icon: Icons.add_rounded,
                    onTap: () => state.setWalkTime(alarm.walkTimeToStop + 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // REQ-08/09: 요일별 활성/시각 (드럼롤 시간 선택)
            const SectionHeader(
                title: '요일별 알람',
                subtitle: '시간을 탭하면 드럼롤로 설정할 수 있어요'),
            const SizedBox(height: AppSpacing.sm),
            ...DayOfWeek.values.map((day) {
              final s = alarm.schedules[day]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: SoftCard(
                  border: s.isEnabled ? AppColors.accent : null,
                  child: Row(
                    children: [
                      // 요일 레이블
                      SizedBox(
                        width: 34,
                        child: Text(day.labelKo,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: s.isEnabled
                                    ? AppColors.accent
                                    : AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      // 시간 표시 (탭으로 드럼롤 열기)
                      GestureDetector(
                        onTap: () => _showTimePicker(
                          context,
                          state,
                          day,
                          s.hour,
                          s.minute,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: s.isEnabled
                                ? AppColors.accent.withOpacity(0.12)
                                : AppColors.surfaceAlt,
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                            border: s.isEnabled
                                ? Border.all(
                                    color:
                                        AppColors.accent.withOpacity(0.4),
                                    width: 1)
                                : null,
                          ),
                          child: Text(s.timeLabel,
                              style: AppTheme.mono(
                                  size: 20,
                                  weight: FontWeight.w700,
                                  color: s.isEnabled
                                      ? AppColors.accent
                                      : AppColors.textTertiary)),
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: s.isEnabled,
                        activeColor: AppColors.accent,
                        onChanged: (v) =>
                            state.setSchedule(day, v, s.hour, s.minute),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.md),

            // REQ-17: TTS 볼륨
            const SectionHeader(
                title: '음성 안내 볼륨', subtitle: '시스템 볼륨과 독립적으로 조절'),
            const SizedBox(height: AppSpacing.sm),
            SoftCard(
              child: Row(
                children: [
                  const Icon(Icons.volume_up_rounded,
                      color: AppColors.textSecondary),
                  Expanded(
                    child: Slider(
                      value: state.playTTS.volume.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      activeColor: AppColors.accent,
                      label: '${state.playTTS.volume}%',
                      onChanged: (v) => state.setTtsVolume(v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text('${state.playTTS.volume}%',
                        textAlign: TextAlign.right,
                        style: AppTheme.mono(size: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ElevatedButton.icon(
            onPressed: () async {
              if (state.selectedRoutes.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('노선을 하나 이상 선택해주세요')),
                );
                return;
              }
              await state.saveCurrentAlarm(widget.stop);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('알람이 저장되었습니다')),
                );
                // 홈으로 복귀
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('알람 저장'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56)),
          ),
        ),
      ),
    );
  }
}

/// 드럼롤 휠의 선택 영역 오버레이 (위아래 반투명 라인)
class _WheelOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surface,
                  AppColors.surface.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(
                  color: AppColors.accent.withOpacity(0.4), width: 1.5),
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.surface,
                  AppColors.surface.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
