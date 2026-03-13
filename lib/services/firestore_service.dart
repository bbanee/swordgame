// lib/services/firestore_service.dart
// Firebase Firestoreë¥??¬ìš©???´ë¼?°ë“œ ?€?¥ì†Œ

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/owned_sword.dart';
import '../models/daily_quest.dart';
import 'auth_service.dart';

class FirestoreService {
  // Firestore ?¸ìŠ¤?´ìŠ¤
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  
  // ?±ê????¨í„´
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();
  
  // ============================================================
  // ?„ì¬ ?¬ìš©??ë¬¸ì„œ ì°¸ì¡°
  // ============================================================
  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _authService.uid;
    if (uid == null || uid.isEmpty) return null;
    return _firestore.collection('users').doc(uid);
  }
  
  // ë¡œê·¸???íƒœ ?•ì¸
  bool get isLoggedIn => _authService.isLoggedIn;
  String? get currentUid => _authService.uid;
  
  // ============================================================
  // ?“¥ ?°ì´??ë¡œë“œ (??ë²ˆì— ëª¨ë“  ?°ì´??ê°€?¸ì˜¤ê¸?
  // ============================================================
  Future<Map<String, dynamic>?> loadGameData() async {
    try {
      final doc = _userDoc;
      if (doc == null) {
        debugPrint('??ë¡œê·¸?¸ë˜ì§€ ?ŠìŒ');
        return null;
      }
      
      final snapshot = await doc.get();
      
      if (!snapshot.exists) {
        debugPrint('?“­ ?€?¥ëœ ?°ì´???†ìŒ (? ê·œ ? ì?)');
        return null;
      }
      
      debugPrint('???°ì´??ë¡œë“œ ?±ê³µ!');
      return snapshot.data();
    } catch (e) {
      debugPrint('???°ì´??ë¡œë“œ ?¤íŒ¨: $e');
      return null;
    }
  }
  
  // ============================================================
  // ?“¤ ?°ì´???€??(??ë²ˆì— ëª¨ë“  ?°ì´???€?¥í•˜ê¸?
  // ============================================================
  Future<bool> saveGameData({
    // ê¸°ë³¸ ?•ë³´
    required String visitorId,
    required String nickname,
    required int gold,
    required int diamond,
    required int enhanceStone,
    required int maxInventory,
    
    // ?¸ë²¤? ë¦¬
    required List<OwnedSword> inventory,
    required String? equippedSwordUid,
    
    // ë°°í?
    required int battleCount,
    required int battleRefillCount,
    required DateTime? lastBattleReset,
    required int battleWinStreak,
    required int maxWinStreak,
    
    // ë³´ìŠ¤
    required Map<String, DateTime> bossCooldowns,
    
    // ?„ê°/ì¹?˜¸
    required Set<int> codex,
    required Set<String> unlockedTitles,
    required String? equippedTitle,
    
    // ?…ì 
    required Set<String> unlockedAchievements,
    required Set<String> claimedAchievements,
    
    // ì¶œì„
    required int attendanceStreak,
    required DateTime? lastAttendance,
    
    // ?¼ì¼ ?˜ìŠ¤??    required List<DailyQuest> dailyQuests,
    required DateTime? lastQuestReset,
    
    // ?œì¦Œ?¨ìŠ¤
    required int seasonPassLevel,
    required int seasonPassExp,
    required Set<int> claimedSeasonRewards,
    required bool hasPremiumPass,
    required Set<int> claimedPremiumRewards,
    
    // ?©ì„± ì²œì¥
    required int normalToRarePity,
    required int rareToUniquePity,
    required int uniqueToLegendPity,
    
    // ?µê³„
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
        debugPrint('??ë¡œê·¸?¸ë˜ì§€ ?ŠìŒ - ?€??ë¶ˆê?');
        return false;
      }
      
      // ?°ì´?°ë? Map?¼ë¡œ ë³€??      final data = {
        // ê¸°ë³¸ ?•ë³´
        'visitorId': visitorId,
        'nickname': nickname,
        'gold': gold,
        'diamond': diamond,
        'enhanceStone': enhanceStone,
        'maxInventory': maxInventory,
        
        // ?¸ë²¤? ë¦¬ (JSON ë¦¬ìŠ¤?¸ë¡œ ë³€??
        'inventory': inventory.map((s) => s.toJson()).toList(),
        'equippedSwordUid': equippedSwordUid,
        
        // ë°°í?
        'battleCount': battleCount,
        'battleRefillCount': battleRefillCount,
        'lastBattleReset': lastBattleReset?.toIso8601String(),
        'battleWinStreak': battleWinStreak,
        'maxWinStreak': maxWinStreak,
        
        // ë³´ìŠ¤ (DateTime??String?¼ë¡œ ë³€??
        'bossCooldowns': bossCooldowns.map((k, v) => MapEntry(k, v.toIso8601String())),
        
        // ?„ê°/ì¹?˜¸ (Set??Listë¡?ë³€??
        'codex': codex.toList(),
        'unlockedTitles': unlockedTitles.toList(),
        'equippedTitle': equippedTitle,
        
        // ?…ì 
        'unlockedAchievements': unlockedAchievements.toList(),
        'claimedAchievements': claimedAchievements.toList(),
        
        // ì¶œì„
        'attendanceStreak': attendanceStreak,
        'lastAttendance': lastAttendance?.toIso8601String(),
        
        // ?¼ì¼ ?˜ìŠ¤??        'dailyQuests': dailyQuests.map((q) => q.toJson()).toList(),
        'lastQuestReset': lastQuestReset?.toIso8601String(),
        
        // ?œì¦Œ?¨ìŠ¤
        'seasonPassLevel': seasonPassLevel,
        'seasonPassExp': seasonPassExp,
        'claimedSeasonRewards': claimedSeasonRewards.toList(),
        'hasPremiumPass': hasPremiumPass,
        'claimedPremiumRewards': claimedPremiumRewards.toList(),
        
        // ?©ì„± ì²œì¥
        'normalToRarePity': normalToRarePity,
        'rareToUniquePity': rareToUniquePity,
        'uniqueToLegendPity': uniqueToLegendPity,
        
        // ?µê³„
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
        
        // ë©”í? ?•ë³´
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      // Firestore???€??(merge: true = ê¸°ì¡´ ?°ì´?°ì? ë³‘í•©)
      await doc.set(data, SetOptions(merge: true));

      await _firestore.collection('users_public').doc(doc.id).set({
        'nickname': nickname,
        'totalBattle': totalBattle,
        'totalBattleWin': totalBattleWin,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('???°ì´???€???±ê³µ!');
      return true;
    } catch (e) {
      debugPrint('???°ì´???€???¤íŒ¨: $e');
      return false;
    }
  }
  
  // ============================================================
  // ?—‘ï¸??°ì´???? œ (ê³„ì • ì´ˆê¸°??
  // ============================================================
  Future<bool> deleteGameData() async {
    try {
      final doc = _userDoc;
      if (doc == null) return false;
      
      await doc.delete();
      debugPrint('???°ì´???? œ ?„ë£Œ');
      return true;
    } catch (e) {
      debugPrint('???°ì´???? œ ?¤íŒ¨: $e');
      return false;
    }
  }
  
  // ============================================================
  // ?”§ ?¬í¼ ë©”ì„œ?œë“¤
  // ============================================================
  
  // DateTime ?Œì‹±
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
  
  // List<int> ?Œì‹±
  static Set<int> parseIntSet(dynamic value) {
    if (value == null) return {};
    if (value is List) {
      return value.map((e) => e as int).toSet();
    }
    return {};
  }
  
  // List<String> ?Œì‹±
  static Set<String> parseStringSet(dynamic value) {
    if (value == null) return {};
    if (value is List) {
      return value.map((e) => e.toString()).toSet();
    }
    return {};
  }
  
  // Map<String, DateTime> ?Œì‹±
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
  
  // ?¸ë²¤? ë¦¬ ?Œì‹±
  static List<OwnedSword> parseInventory(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((e) => OwnedSword.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
  
  // ?¼ì¼ ?˜ìŠ¤???Œì‹±
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
  // ?“Š ?”ë²„ê·?ì¶œë ¥
  // ============================================================
  void debugInfo() {
    debugPrint('=== FirestoreService Debug ===');
    debugPrint('UID: ${_authService.uid}');
    debugPrint('ë¡œê·¸?? ${_authService.isLoggedIn}');
    debugPrint('ë¬¸ì„œ ê²½ë¡œ: users/${_authService.uid}');
    debugPrint('==============================');
  }
}