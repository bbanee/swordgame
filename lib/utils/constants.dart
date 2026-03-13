import 'package:flutter/material.dart';

// ===== 앱 상수 =====
class AppConstants {
  AppConstants._(); // ✅ 인스턴스화 방지

  // 앱 정보
  static const String appName = '최강 검 키우기';
  static const String appVersion = 'v9.1';

  // ===== 초기값 =====
  static const int startingGold = 5000;
  static const int startingDiamond = 100;
  static const int startingEnhanceStone = 10; // ✅ 추가
  static const int startingInventory = 10;

  // ===== 인벤토리 =====
  static const int minInventory = 10;
  static const int maxInventoryLimit = 20; // ✅ 확장 가능한 최대치
  static const int inventoryExpandAmount = 5;
  static const int inventoryExpandCostBase = 100; // ✅ 다이아 기본 비용
  static const double inventoryExpandCostMultiplier = 1.5; // ✅ 확장당 비용 증가율

  // ===== 강화 =====
  static const int maxEnhanceLevel = 30;
  static const int maxBreakthroughLevel = 3;
  static const int breakthroughLevelStep = 5;
  static const int enhanceStoneBonus = 10; // ✅ 강화석 성공률 보너스
  static const int enhanceStoneDestroyReduction = 5; // ✅ 파괴율 감소

  // ===== 배틀 =====
  static const int dailyBattleCount = 20;
  static const int maxBattleRefill = 5;
  static const int battleRefillCost = 50; // 다이아
  static const int battleRefillAmount = 5;
  static const int maxBattleRecords = 50;
  static const int revengeTimeLimit = 24; // ✅ 복수전 가능 시간 (시간)
  static const double revengeGoldBonus = 1.5; // ✅ 복수전 보상 보너스

  // ===== 보스 =====
  static const int bossCooldownHours = 4; // ✅ 보스 쿨다운
  static const int bossCount = 5; // ✅ 보스 종류 수
  static const double bossDropRateBonus = 2.0; // ✅ 보스 드랍률 보너스

  // ===== 뽑기 =====
  static const int singleGachaCostGold = 500;
  static const int singleGachaCostDiamond = 10; // ✅ 다이아 뽑기
  static const int multiGachaCount = 10; // ✅ 10연차로 변경
  static const double multiGachaDiscount = 0.9;
  static const int gachaPityRare = 10; // ✅ 레어 천장
  static const int gachaPityUnique = 50; // ✅ 유니크 천장
  static const int gachaPityLegend = 200; // ✅ 전설 천장

  // ===== 합성 =====
  static const int synthesisRequiredCount = 3;
  static const int synthesisCostGold = 1000; // ✅ 합성 비용

  // ===== 출석 =====
  static const int maxAttendanceStreak = 28; // ✅ 최대 연속 출석
  static const int weeklyAttendanceDiamond = 50;

  // ✅ 출석 골드 보상 계산 (일차별 선형 보간)
  static int getAttendanceGold(int day) {
    if (day <= 1) return 30000;
    if (day <= 5) {
      // 1일: 30,000 → 5일: 150,000
      return 30000 + ((day - 1) * (150000 - 30000) ~/ 4);
    }
    if (day <= 21) {
      // 5일: 150,000 → 21일: 500,000
      return 150000 + ((day - 5) * (500000 - 150000) ~/ 16);
    }
    if (day <= 28) {
      // 21일: 500,000 → 28일: 1,000,000
      return 500000 + ((day - 21) * (1000000 - 500000) ~/ 7);
    }
    return 1000000; // 28일 이상
  }

  // ===== 시즌패스 =====
  static const int maxSeasonPassLevel = 50;
  static const int expPerLevel = 100;
  static const int seasonDurationDays = 90; // ✅ 시즌 기간

  // ===== 일일 퀘스트 =====
  static const int dailyQuestCount = 6; // ✅ 일일 퀘스트 수
  static const int questResetHour = 0; // ✅ 리셋 시간 (자정)

  // ===== 시간 상수 =====
  static const Duration autoSaveInterval = Duration(minutes: 5); // ✅ 자동 저장
  static const Duration notificationDuration = Duration(seconds: 2);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration splashDuration = Duration(seconds: 2);

  // ===== 인벤토리 확장 비용 계산 =====
  static int getInventoryExpandCost(int currentMax) {
    final expansions = (currentMax - minInventory) ~/ inventoryExpandAmount;
    return (inventoryExpandCostBase *
            (expansions + 1) *
            inventoryExpandCostMultiplier)
        .round();
  }
}

// ===== 색상 =====
class AppColors {
  AppColors._();

  // 배경
  static const Color background = Color(0xFF1a1a2e);
  static const Color backgroundDark = Color(0xFF0f0f1a);
  static const Color backgroundLight = Color(0xFF252542); // ✅ 추가
  static const Color cardBackground = Color(0xFF252540);
  static const Color dialogBackground = Color(0xFF2a2a4a); // ✅ 추가

  // 강조
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF5046E5); // ✅ 추가
  static const Color accent = Color(0xFFFFD700);
  static const Color accentDark = Color(0xFFE5C100); // ✅ 추가

  // 재화
  static const Color gold = Color(0xFFFFD700);
  static const Color diamond = Color(0xFF4FC3F7);
  static const Color enhanceStone = Color(0xFF9C27B0); // ✅ 추가

  // 상태
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3); // ✅ 추가

  // 등급 색상 (SwordGrade와 동일하게 유지)
  static const Color gradeNormal = Colors.grey;
  static const Color gradeRare = Colors.blue;
  static const Color gradeUnique = Colors.purple;
  static const Color gradeLegend = Colors.orange;
  static const Color gradeHidden = Colors.pink;
  static const Color gradeImmortal = Colors.red;

  // ✅ 글로우 효과
  static Color getGradeGlow(Color baseColor, {double opacity = 0.5}) {
    return baseColor.withOpacity(opacity);
  }

  // ✅ 투명도 조절
  static Color withAlpha(Color color, double opacity) {
    return color.withOpacity(opacity.clamp(0.0, 1.0));
  }
}

// ===== 텍스트 스타일 =====
class AppTextStyles {
  AppTextStyles._();

  // ✅ 기본 폰트 패밀리 (나중에 커스텀 폰트 적용 용이)
  static const String? _fontFamily = null;

  static const TextStyle title = TextStyle(
    fontFamily: _fontFamily,
    color: Colors.white,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: _fontFamily,
    color: Colors.white,
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: _fontFamily,
    color: Colors.white70,
    fontSize: 16,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    color: Colors.white,
    fontSize: 14,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    color: Colors.white,
    fontSize: 12,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    color: Colors.white54,
    fontSize: 12,
  );

  static const TextStyle gold = TextStyle(
    fontFamily: _fontFamily,
    color: AppColors.gold,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle goldLarge = TextStyle(
    fontFamily: _fontFamily,
    color: AppColors.gold,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle diamond = TextStyle(
    fontFamily: _fontFamily,
    color: AppColors.diamond,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle enhanceStone = TextStyle(
    fontFamily: _fontFamily,
    color: AppColors.enhanceStone,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  // ✅ 동적 스타일 생성
  static TextStyle withColor(TextStyle base, Color color) {
    return base.copyWith(color: color);
  }

  static TextStyle withSize(TextStyle base, double size) {
    return base.copyWith(fontSize: size);
  }
}

// ===== 박스 데코레이션 =====
class AppDecorations {
  AppDecorations._();

  static const double defaultRadius = 12.0;
  static const double smallRadius = 8.0;
  static const double largeRadius = 16.0;

  static BoxDecoration card({
    Color? color,
    Color? borderColor,
    double? radius,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.withAlpha(Colors.white, 0.05),
      borderRadius: BorderRadius.circular(radius ?? defaultRadius),
      border: borderColor != null ? Border.all(color: borderColor) : null,
    );
  }

  static BoxDecoration gradientCard(List<Color> colors, {double? radius}) {
    return BoxDecoration(
      gradient: LinearGradient(colors: colors),
      borderRadius: BorderRadius.circular(radius ?? defaultRadius),
    );
  }

  static BoxDecoration glowCard(
    Color color, {
    double blurRadius = 20,
    double? radius,
  }) {
    return BoxDecoration(
      color: AppColors.withAlpha(color, 0.2),
      borderRadius: BorderRadius.circular(radius ?? defaultRadius),
      border: Border.all(color: color),
      boxShadow: [
        BoxShadow(
          color: AppColors.withAlpha(color, 0.3),
          blurRadius: blurRadius,
          spreadRadius: 2,
        ),
      ],
    );
  }

  // ✅ 버튼 데코레이션
  static BoxDecoration button(Color color, {double? radius}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [color, AppColors.withAlpha(color, 0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius ?? smallRadius),
      boxShadow: [
        BoxShadow(
          color: AppColors.withAlpha(color, 0.4),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // ✅ 비활성화 버튼
  static BoxDecoration buttonDisabled({double? radius}) {
    return BoxDecoration(
      color: Colors.grey.shade700,
      borderRadius: BorderRadius.circular(radius ?? smallRadius),
    );
  }
}

// ===== 애니메이션 커브 =====
class AppCurves {
  AppCurves._();

  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve sharpCurve = Curves.easeOutCubic;
}
