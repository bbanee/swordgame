// lib/services/analytics_service.dart
// 📊 Firebase Analytics + Crashlytics 통합 서비스

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  // =====================================================
  // 초기화
  // =====================================================

  Future<void> initialize() async {
    // 📊 Analytics 활성화
    await _analytics.setAnalyticsCollectionEnabled(true);
    
    // 🔥 Crashlytics 활성화 (디버그 모드에서는 비활성화)
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    
    debugPrint('📊 AnalyticsService 초기화 완료 (Crashlytics: ${!kDebugMode})');
  }

  // =====================================================
  // 📊 유저 설정 (로그인 시 호출)
  // =====================================================

  /// 로그인 시 유저 식별 설정
  Future<void> setUser(String uid, {String? loginMethod}) async {
    await _analytics.setUserId(id: uid);
    await _crashlytics.setUserIdentifier(uid);
    
    if (loginMethod != null) {
      await _analytics.logLogin(loginMethod: loginMethod);
    }
    
    debugPrint('📊 유저 설정: $uid ($loginMethod)');
  }

  /// 유저 속성 설정 (레벨, 등급 등)
  Future<void> setUserProperty(String name, String value) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  // =====================================================
  // 📊 게임 이벤트
  // =====================================================

  /// 강화 시도
  Future<void> logEnhance({
    required String swordName,
    required String grade,
    required int level,
    required bool success,
    required bool destroyed,
  }) async {
    await _analytics.logEvent(
      name: 'enhance_attempt',
      parameters: {
        'sword_name': swordName,
        'grade': grade,
        'level': level,
        'success': success ? 1 : 0,
        'destroyed': destroyed ? 1 : 0,
      },
    );
  }

  /// 뽑기
  Future<void> logGacha({
    required String type,  // 'normal', 'advanced'
    required String resultGrade,
    required String resultName,
  }) async {
    await _analytics.logEvent(
      name: 'gacha_pull',
      parameters: {
        'gacha_type': type,
        'result_grade': resultGrade,
        'result_name': resultName,
      },
    );
  }

  /// 배틀
  Future<void> logBattle({
    required bool isWin,
    required String swordGrade,
    required int playerPower,
    required int enemyPower,
  }) async {
    await _analytics.logEvent(
      name: 'battle',
      parameters: {
        'is_win': isWin ? 1 : 0,
        'sword_grade': swordGrade,
        'player_power': playerPower,
        'enemy_power': enemyPower,
      },
    );
  }

  /// 보스 배틀
  Future<void> logBossBattle({
    required bool isWin,
    required int bossFloor,
  }) async {
    await _analytics.logEvent(
      name: 'boss_battle',
      parameters: {
        'is_win': isWin ? 1 : 0,
        'boss_floor': bossFloor,
      },
    );
  }

  /// 검 판매
  Future<void> logSellSword({
    required String grade,
    required int goldEarned,
  }) async {
    await _analytics.logEvent(
      name: 'sell_sword',
      parameters: {
        'grade': grade,
        'gold_earned': goldEarned,
      },
    );
  }

  /// 광고 시청
  Future<void> logAdWatch({
    required String adType,  // 'destroyRevive', 'bossSkip', 'sellBonus', etc.
  }) async {
    await _analytics.logEvent(
      name: 'ad_watch',
      parameters: {
        'ad_type': adType,
      },
    );
  }

  /// 출석 체크
  Future<void> logAttendance({
    required int streak,
    required int day,
  }) async {
    await _analytics.logEvent(
      name: 'attendance_check',
      parameters: {
        'streak': streak,
        'day': day,
      },
    );
  }

  // =====================================================
  // 📊 상점/결제 이벤트
  // =====================================================

  /// 인앱 구매
  Future<void> logPurchase({
    required String productId,
    required double price,
    required String currency,
  }) async {
    await _analytics.logPurchase(
      currency: currency,
      value: price,
      items: [AnalyticsEventItem(itemId: productId)],
    );
  }

  /// 골드/다이아 소비
  Future<void> logSpendCurrency({
    required String currency,  // 'gold', 'diamond'
    required int amount,
    required String itemName,  // 뭘 샀는지
  }) async {
    await _analytics.logSpendVirtualCurrency(
      itemName: itemName,
      virtualCurrencyName: currency,
      value: amount,
    );
  }

  /// 골드/다이아 획득
  Future<void> logEarnCurrency({
    required String currency,  // 'gold', 'diamond'
    required int amount,
    required String source,  // 'battle', 'sell', 'attendance', etc.
  }) async {
    await _analytics.logEarnVirtualCurrency(
      virtualCurrencyName: currency,
      value: amount,
    );
  }

  // =====================================================
  // 📊 진행 이벤트
  // =====================================================

  /// 시즌패스 레벨업
  Future<void> logSeasonLevelUp({required int newLevel}) async {
    await _analytics.logLevelUp(level: newLevel);
  }

  /// 화면 전환 (자동 추적 외 수동으로도 가능)
  Future<void> logScreen(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  // =====================================================
  // 🔥 Crashlytics: 에러 로깅
  // =====================================================

  /// 치명적이지 않은 에러 기록 (앱은 안 죽지만 기록해둘 것)
  Future<void> logError(dynamic error, StackTrace? stack, {String? reason}) async {
    await _crashlytics.recordError(error, stack, reason: reason ?? '');
    debugPrint('🔥 에러 기록: $reason - $error');
  }

  /// Crashlytics에 키-값 로그 남기기 (크래시 발생 시 맥락 파악용)
  Future<void> setContext(String key, dynamic value) async {
    if (value is int) {
      await _crashlytics.setCustomKey(key, value);
    } else if (value is double) {
      await _crashlytics.setCustomKey(key, value);
    } else if (value is bool) {
      await _crashlytics.setCustomKey(key, value);
    } else {
      await _crashlytics.setCustomKey(key, value.toString());
    }
  }

  /// Crashlytics 로그 메시지 (크래시 직전 행동 추적)
  void log(String message) {
    _crashlytics.log(message);
  }
}
