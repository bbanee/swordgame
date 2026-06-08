// lib/services/ad_service.dart
// 🎬 AdMob 광고 서비스

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'storage_service.dart';

/// 광고 유형
enum AdRewardType {
  destroyRevive, // 파괴 복구
  bossSkip, // 보스 쿨다운 스킵
  sellBonus, // 판매 2배
  stoneReward, // 강화석 획득
  attendanceBonus, // 출석 보상 2배
  freeGacha, // 일일 무료 고급 뽑기
  minigamePlay, // 미니게임 추가 플레이 (무제한)
  infiniteTowerPlay, // 무한의 탑 추가 도전
}

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  bool _isInitialized = false;

  // 일일 광고 시청 횟수
  Map<AdRewardType, int> _dailyAdCounts = {};
  DateTime? _lastResetDate;

  // =====================================================
  // 광고 단위 ID
  // =====================================================

  /// 🧪 테스트 광고 ID (개발 중에는 이것 사용!)
  static String get _testRewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// 🚀 실제 광고 ID (출시 시 여기에 실제 ID 입력!)
  static const String _realAndroidAdUnitId =
      'ca-app-pub-4392701551381492/1283432434';
  static const String _realIosAdUnitId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  /// 현재 사용할 광고 ID
  static String get rewardedAdUnitId {
    // 🔥 출시 시 kReleaseMode를 확인하여 실제 ID 사용

    if (kReleaseMode) {
      // 출시 모드
      if (Platform.isAndroid) {
        return _realAndroidAdUnitId;
      } else if (Platform.isIOS) {
        return _realIosAdUnitId;
      }
    }

    // 개발 모드 - 테스트 ID 사용
    return _testRewardedAdUnitId;
  }

  // =====================================================
  // 일일 광고 제한
  // =====================================================

  static const Map<AdRewardType, int> _dailyLimits = {
    AdRewardType.destroyRevive: 3, // 파괴 복구: 3회
    AdRewardType.bossSkip: 3, // 보스 쿨다운: 3회
    AdRewardType.sellBonus: 5, // 판매 2배: 5회
    AdRewardType.stoneReward: 3, // 강화석: 3회
    AdRewardType.attendanceBonus: 1, // 출석 2배: 1회
    AdRewardType.freeGacha: 1, // 무료 고급 뽑기: 1회
    AdRewardType.minigamePlay: 999, // 미니게임 추가 플레이: 사실상 무제한
    AdRewardType.infiniteTowerPlay: 3, // 무한의 탑 추가 도전: 3회
  };

  // =====================================================
  // 초기화
  // =====================================================

  /// AdMob 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;

      // 광고 미리 로드
      loadRewardedAd();

      debugPrint('✅ AdMob 초기화 완료');
    } catch (e) {
      debugPrint('❌ AdMob 초기화 실패: $e');
    }
  }

  // =====================================================
  // 보상형 광고
  // =====================================================

  /// 보상형 광고 로드
  void loadRewardedAd() {
    if (_isLoading || _rewardedAd != null) return;

    _isLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
          debugPrint('✅ 보상형 광고 로드 완료');
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          debugPrint('❌ 보상형 광고 로드 실패: ${error.message}');
          // 5초 후 재시도
          Future.delayed(const Duration(seconds: 5), loadRewardedAd);
        },
      ),
    );
  }

  /// 광고 준비 여부
  bool get isRewardedAdReady => _rewardedAd != null;

  /// 특정 보상 타입의 남은 광고 횟수
  int getRemainingAdCount(AdRewardType type) {
    _checkDailyReset();
    final used = _dailyAdCounts[type] ?? 0;
    final limit = _dailyLimits[type] ?? 0;
    return (limit - used).clamp(0, limit);
  }

  /// 광고 시청 가능 여부
  bool canWatchAd(AdRewardType type) {
    return getRemainingAdCount(type) > 0;
  }

  /// 보상형 광고 표시
  Future<bool> showRewardedAd({
    required AdRewardType type,
    required Function() onRewarded,
    Function()? onAdClosed,
    Function(String)? onError,
  }) async {
    // 일일 제한 체크
    if (!canWatchAd(type)) {
      onError?.call('오늘 광고 시청 횟수를 모두 사용했습니다');
      return false;
    }

    // 광고 준비 체크
    if (_rewardedAd == null) {
      debugPrint('⚠️ 광고가 준비되지 않았습니다');
      loadRewardedAd();
      onError?.call('광고를 불러오는 중입니다. 잠시 후 다시 시도해주세요.');
      return false;
    }

    bool rewarded = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // 다음 광고 미리 로드
        onAdClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        debugPrint('❌ 광고 표시 실패: ${error.message}');
        onError?.call('광고를 표시할 수 없습니다');
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;

        // 일일 광고 횟수 증가
        _incrementAdCount(type);

        // 보상 지급
        onRewarded();

        debugPrint('🎁 보상 획득: ${type.name}');
      },
    );

    return rewarded;
  }

  // =====================================================
  // 일일 광고 횟수 관리
  // =====================================================

  /// 일일 리셋 체크
  void _checkDailyReset() {
    final storage = StorageService();
    final now = storage.serverNow;
    final today = DateTime(now.year, now.month, now.day);

    if (_lastResetDate == null || _lastResetDate!.isBefore(today)) {
      // 날짜가 바뀌면 리셋
      _dailyAdCounts = {};
      _lastResetDate = today;
      _saveDailyAdCounts();
      debugPrint('🔄 일일 광고 횟수 리셋');
    }
  }

  /// 광고 횟수 증가
  void _incrementAdCount(AdRewardType type) {
    _checkDailyReset();
    _dailyAdCounts[type] = (_dailyAdCounts[type] ?? 0) + 1;
    _saveDailyAdCounts();
  }

  /// 일일 광고 횟수 저장 (Firestore 동기화 대상 캐시)
  void _saveDailyAdCounts() {
    final storage = StorageService();

    final countMap = <String, int>{};
    for (final type in AdRewardType.values) {
      countMap[type.name] = _dailyAdCounts[type] ?? 0;
    }

    storage.adDailyCounts = countMap;
    if (_lastResetDate != null) {
      storage.adResetDate = _lastResetDate!.toIso8601String();
    }

    storage.saveToCloud();
  }

  /// 일일 광고 횟수 로드
  Future<void> _loadDailyAdCounts() async {
    final storage = StorageService();

    final resetDateStr = storage.adResetDate;
    if (resetDateStr != null) {
      _lastResetDate = DateTime.tryParse(resetDateStr);
    }

    // 리셋 체크
    _checkDailyReset();

    // 횟수 로드
    final countMap = storage.adDailyCounts;
    for (final type in AdRewardType.values) {
      _dailyAdCounts[type] = countMap[type.name] ?? 0;
    }
  }

  // =====================================================
  // 유틸리티
  // =====================================================

  /// 광고 타입별 한글 이름
  static String getAdTypeName(AdRewardType type) {
    switch (type) {
      case AdRewardType.destroyRevive:
        return '파괴 복구';
      case AdRewardType.bossSkip:
        return '보스 쿨다운 스킵';
      case AdRewardType.sellBonus:
        return '판매 2배';
      case AdRewardType.stoneReward:
        return '강화석 획득';
      case AdRewardType.attendanceBonus:
        return '출석 보상 2배';
      case AdRewardType.freeGacha:
        return '무료 고급 뽑기';
      case AdRewardType.minigamePlay:
        return '미니게임 추가 플레이';
      case AdRewardType.infiniteTowerPlay:
        return '무한의 탑 추가 도전';
    }
  }

  /// 리소스 정리
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }

  /// 로그아웃 시 광고 횟수 초기화
  Future<void> resetForLogout() async {
    _dailyAdCounts = {};
    _lastResetDate = null;
    debugPrint('🔄 로그아웃: 메모리 광고 횟수 초기화 완료');
  }

  /// ✅ 로그인 후 해당 유저의 광고 횟수 로드
  Future<void> loadForCurrentUser() async {
    _dailyAdCounts = {};
    _lastResetDate = null;
    await _loadDailyAdCounts();
    debugPrint('✅ 유저별 광고 횟수 로드 완료 (Firestore)');
  }
}
