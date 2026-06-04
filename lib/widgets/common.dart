import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 부드러운 그림자와 미세한 그라데이션이 들어간 카드
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? border;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            gradient: AppColors.surfaceGradient,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border ?? AppColors.stroke),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 신호등 메타포의 작은 상태 점
class SignalDot extends StatelessWidget {
  final Color color;
  final double size;
  final bool glow;
  const SignalDot(
      {super.key, required this.color, this.size = 10, this.glow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow
            ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 10)]
            : null,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppColors.textPrimary)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: const TextStyle(
                  fontSize: 13.5, color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

/// 도착 시간(초) → 사람이 읽는 라벨
String formatArrival(int seconds) {
  if (seconds <= 0) return '도착/통과';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m == 0) return '$s초';
  return '$m분 $s초';
}

String formatMMSS(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
