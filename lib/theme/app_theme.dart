import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─────────────────────────────────────────────────────────────
///  디자인 시스템
///  컨셉: "Calm Transit" — 차분한 다크 인디고 베이스에
///  민트/라임 계열의 생생한 액센트. 교통(이동)의 신호등 메타포를
///  절제된 형태로 표현. 둥근 카드, 넉넉한 여백, 부드러운 그림자.
/// ─────────────────────────────────────────────────────────────
class AppColors {
  // 베이스 (다크)
  static const Color bg = Color(0xFF0E1116); // 거의 검정에 가까운 잉크
  static const Color surface = Color(0xFF171C24); // 카드 표면
  static const Color surfaceAlt = Color(0xFF1F2630); // 살짝 밝은 표면
  static const Color stroke = Color(0xFF2A323D); // 경계선

  // 텍스트
  static const Color textPrimary = Color(0xFFF2F5F8);
  static const Color textSecondary = Color(0xFF9AA6B2);
  static const Color textTertiary = Color(0xFF5E6B78);

  // 액센트 (신호 메타포)
  static const Color accent = Color(0xFF4ADE80); // 라임/민트 그린 — "출발/GO"
  static const Color accentDim = Color(0xFF22C55E);
  static const Color amber = Color(0xFFFBBF24); // 임박 경고
  static const Color danger = Color(0xFFF87171); // 막차/통과
  static const Color info = Color(0xFF60A5FA); // 정보

  // 그라데이션
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF4ADE80), Color(0xFF22D3EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF1B212B), Color(0xFF141921)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppRadius {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 26;
  static const double pill = 999;
}

class AppSpacing {
  static const double xs = 6;
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 26;
  static const double xl = 36;
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    // 본문: Pretendard 대체로 Noto Sans KR(한글 안정), 디스플레이: Space numeric용 숫자 강조
    final textTheme = GoogleFonts.notoSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accent,
        secondary: AppColors.info,
        error: AppColors.danger,
        onPrimary: Color(0xFF06210F),
        onSurface: AppColors.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.notoSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.4,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerColor: AppColors.stroke,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.stroke, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: const Color(0xFF06210F),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.notoSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }

  /// 숫자 강조용 (카운트다운, 도착시간 등) — 모노스페이스 톤
  static TextStyle mono({
    double size = 16,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) {
    return GoogleFonts.spaceMono(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.textPrimary,
      letterSpacing: -0.5,
    );
  }
}
