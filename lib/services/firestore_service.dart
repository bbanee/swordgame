// lib/services/firestore_service.dart
// Firebase Firestore를 사용하는 클라우드 저장소

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/owned_sword.dart';
import '../models/daily_quest.dart';
import 'auth_service.dart';

class FirestoreService {
  // Firestore 인스턴스
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // 싱글턴
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // ============================================================
  // 현재 사용자 문서 참조
  // ============================================================
  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _authService.uid;
    if (uid == null || uid.isEmpty) return null;
    return _firestore.collection('users').doc(uid);
  }

  // 로그인 상태 확인
  bool get isLoggedIn => _authService.isLoggedIn;
  String? get currentUid => _authService.uid;

  // ============================================================
  // 게임 데이터 로드 (한 번에 모든 데이터 가져오기)
  // ============================================================
  Future<Map<String, dynamic>?> loadGameData() async {
    try {
      final doc = _userDoc;
      if (doc == null) {
        debugPrint('로그인되지 않음');
        return null;
      }

      final snapshot = await doc.get();

      if (!snapshot.exists) {
        debugPrint('저장된 데이터 없음 (신규 유저)');
        return null;
      }

      debugPrint('게임 데이터 로드 성공');
      return snapshot.data();
    } catch (e) {
      debugPrint('게임 데이터 로드 실패: $e');
      return null;
    }
  }

  // ============================================================
  // 게임 데이터 저장 (한 번에 모든 데이터 저장하기)
  // ============================================================
  Future<bool> saveGameData({
    // 기본 정보
    required String visitorId,
    required String nickname,
    required int gold,
    required int diamond,
    required int enhanceStone,
    required int maxInventory,

    // 인벤토리
    required List<OwnedSword> inventory,
    required String? equippedSwordUid,

    // 배틀
    required int battleCount,
    required int battleRefillCount,
    required DateTime? lastBattleReset,
    required int battleWinStreak,
    required int maxWinStreak,

    // 보스
    required Map<String, DateTime> bossCooldowns,

    // 도감/칭호
    required Set<int> codex,
    required Set<String> unlockedTitles,
    required String? equippedTitle,

    // 업적
    required Set<String> unlockedAchievements,
    required Set<String> claimedAchievements,

    // 출석
    required int attendanceStreak,
    required DateTime? lastAttendance,

    // 일일 퀘스트
    required List<DailyQuest> dailyQuests,
    required DateTime? lastQuestReset,

    // 시즌패스
    required int seasonPassLevel,
    required int seasonPassExp,
    required Set<int> claimedSeasonRewards,
    required bool hasPremiumPass,
    required Set<int> claimedPremiumRewards,

    // 합성 천장
    required int normalToRarePity,
    required int rareToUniquePity,
    required int uniqueToLegendPity,

    // 통계
    required int totalEnhanceAttempts,
    required int totalEnhanceSuccess,
    required int totalEnhanceFail,
    required int totalDestroy,
    required int maxConsecutiveSuccess,
    required int totalGacha,
    required int totalSynthesis,
    required int totalSell,
    required int totalBattle,
    required int totalBattleWin,
    required int bossKills,
    required int totalGoldEarned,
    required int totalDiamondEarned,
    required int totalQuestsCompleted,
    required int totalRevengeWins,
    required int totalStoneUsed,
  }) async {
    try {
      final doc = _userDoc;
      if (doc == null) {
        debugPrint('로그인되지 않음 - 저장 불가');
        return false;
      }

      // 데이터를 Map으로 변환
      final data = {
        // 기본 정보
        'visitorId': visitorId,
        'nickname': nickname,
        'gold': gold,
        'diamond': diamond,
        'enhanceStone': enhanceStone,
        'maxInventory': maxInventory,

        // 인벤토리 (JSON 리스트로 변환)
        'inventory': inventory.map((s) => s.toJson()).toList(),
        'equippedSwordUid': equippedSwordUid,

        // 배틀
        'battleCount': battleCount,
        'battleRefillCount': battleRefillCount,
        'lastBattleReset': lastBattleReset?.toIso8601String(),
        'battleWinStreak': battleWinStreak,
        'maxWinStreak': maxWinStreak,

        // 보스 (DateTime을 String으로 변환)
        'bossCooldowns': bossCooldowns.map(
          (k, v) => MapEntry(k, v.toIso8601String()),
        ),

        // 도감/칭호 (Set을 List로 변환)
        'codex': codex.toList(),
        'unlockedTitles': unlockedTitles.toList(),
        'equippedTitle': equippedTitle,

        // 업적
        'unlockedAchievements': unlockedAchievements.toList(),
        'claimedAchievements': claimedAchievements.toList(),

        // 출석
        'attendanceStreak': attendanceStreak,
        'lastAttendance': lastAttendance?.toIso8601String(),

        // 일일 퀘스트
        'dailyQuests': dailyQuests.map((q) => q.toJson()).toList(),
        'lastQuestReset': lastQuestReset?.toIso8601String(),

        // 시즌패스
        'seasonPassLevel': seasonPassLevel,
        'seasonPassExp': seasonPassExp,
        'claimedSeasonRewards': claimedSeasonRewards.toList(),
        'hasPremiumPass': hasPremiumPass,
        'claimedPremiumRewards': claimedPremiumRewards.toList(),

        // 합성 천장
        'normalToRarePity': normalToRarePity,
        'rareToUniquePity': rareToUniquePity,
        'uniqueToLegendPity': uniqueToLegendPity,

        // 통계
        'totalEnhanceAttempts': totalEnhanceAttempts,
        'totalEnhanceSuccess': totalEnhanceSuccess,
        'totalEnhanceFail': totalEnhanceFail,
        'totalDestroy': totalDestroy,
        'maxConsecutiveSuccess': maxConsecutiveSuccess,
        'totalGacha': totalGacha,
        'totalSynthesis': totalSynthesis,
        'totalSell': totalSell,
        'totalBattle': totalBattle,
        'totalBattleWin': totalBattleWin,
        'bossKills': bossKills,
        'totalGoldEarned': totalGoldEarned,
        'totalDiamondEarned': totalDiamondEarned,
        'totalQuestsCompleted': totalQuestsCompleted,
        'totalRevengeWins': totalRevengeWins,
        'totalStoneUsed': totalStoneUsed,

        // 메타 정보
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Firestore에 저장 (merge: true = 기존 데이터와 병합)
      await doc.set(data, SetOptions(merge: true));

      await _firestore.collection('users_public').doc(doc.id).set({
        'nickname': nickname,
        'totalBattle': totalBattle,
        'totalBattleWin': totalBattleWin,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('게임 데이터 저장 성공');
      return true;
    } catch (e) {
      debugPrint('게임 데이터 저장 실패: $e');
      return false;
    }
  }

  // ============================================================
  // 전체 데이터 삭제 (계정 초기화)
  // ============================================================
  Future<bool> deleteGameData() async {
    try {
      final doc = _userDoc;
      if (doc == null) return false;

      await doc.delete();
      debugPrint('게임 데이터 삭제 완료');
      return true;
    } catch (e) {
      debugPrint('게임 데이터 삭제 실패: $e');
      return false;
    }
  }

  // ============================================================
  // 데이터 파싱 헬퍼 메서드
  // ============================================================

  // DateTime 파싱
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // List<int> 파싱
  static Set<int> parseIntSet(dynamic value) {
    if (value == null) return {};
    if (value is List) {
      return value.map((e) => e as int).toSet();
    }
    return {};
  }

  // List<String> 파싱
  static Set<String> parseStringSet(dynamic value) {
    if (value == null) return {};
    if (value is List) {
      return value.map((e) => e.toString()).toSet();
    }
    return {};
  }

  // Map<String, DateTime> 파싱
  static Map<String, DateTime> parseDateTimeMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      final result = <String, DateTime>{};
      value.forEach((k, v) {
        final dt = parseDateTime(v);
        if (dt != null) {
          result[k.toString()] = dt;
        }
      });
      return result;
    }
    return {};
  }

  // 인벤토리 파싱
  static List<OwnedSword> parseInventory(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((e) => OwnedSword.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  // 일일 퀘스트 파싱
  static List<DailyQuest> parseDailyQuests(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((e) => DailyQuest.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  // ============================================================
  // 디버그 출력
  // ============================================================
  void debugInfo() {
    debugPrint('=== FirestoreService Debug ===');
    debugPrint('UID: ${_authService.uid}');
    debugPrint('로그인: ${_authService.isLoggedIn}');
    debugPrint('문서 경로: users/${_authService.uid}');
    debugPrint('==============================');
  }
}
