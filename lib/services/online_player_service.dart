import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/player_profile.dart';
import '../data/npcs.dart';

/// ?라???레?어 ?비??(Firebase ?동)
class OnlinePlayerService {
  final String myUserId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _publicUsersCollection = 'users_public';

  // ? ?? 캐시 (30?TTL)
  List<PlayerProfile>? _rankingsCache;
  DateTime? _rankingsCacheTime;
  static const _rankingsCacheDuration = Duration(seconds: 30);
  String? _lastProfileSyncKey;
  DateTime? _lastProfileSyncTime;
  static const _profileSyncCooldown = Duration(seconds: 30);

  OnlinePlayerService({required this.myUserId});

  bool _shouldSyncProfile(String key) {
    final now = DateTime.now();
    final changed = _lastProfileSyncKey != key;
    if (!changed && _lastProfileSyncTime != null) {
      if (now.difference(_lastProfileSyncTime!) < _profileSyncCooldown) {
        return false;
      }
    }
    _lastProfileSyncKey = key;
    _lastProfileSyncTime = now;
    return true;
  }

  DateTime _parseUpdatedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// ???로??????데?트
  Future<void> upsertMe(PlayerProfile me) async {
    if (myUserId.isEmpty) return;

    final key =
        '${me.nickname}|${me.swordId}|${me.swordLevel}|${me.swordBreakthroughLevel}|${me.titleId}';
    if (!_shouldSyncProfile(key)) return;

    try {
      await _firestore.collection('users').doc(myUserId).set({
        'nickname': me.nickname,
        'equippedSwordId': me.swordId,
        'equippedSwordLevel': me.swordLevel,
        'equippedSwordBreakthroughLevel': me.swordBreakthroughLevel,
        'titleId': me.titleId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _firestore.collection(_publicUsersCollection).doc(myUserId).set({
        'nickname': me.nickname,
        'equippedSwordId': me.swordId,
        'equippedSwordLevel': me.swordLevel,
        'equippedSwordBreakthroughLevel': me.swordBreakthroughLevel,
        'titleId': me.titleId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _rankingsCache = null;
      _rankingsCacheTime = null;
      debugPrint('???로???데?트: ${me.nickname}');
    } catch (e) {
      debugPrint('???로???데?트 ?패: $e');
    }
  }

  // ============================================================
  // ?️ 배? ?림 ?스??
  // ============================================================

  /// 배? ?림 보내?(공격?????공격자)
  Future<bool> sendBattleNotification({
    required String toUserId,
    required String myNickname,
    required int myLevel,
    required String myGrade,
    required String myElement,
    required int opponentLevel,
    required String opponentGrade,
    required bool opponentWon,
  }) async {
    if (toUserId.isEmpty || myUserId.isEmpty) {
      debugPrint('??배? ?림 ?송 ?패: ID가 비어?음');
      return false;
    }

    try {
      final docRef = await _firestore.collection('battle_notifications').add({
        'toUserId': toUserId,
        'fromUserId': myUserId,
        'fromNickname': myNickname,
        'fromLevel': myLevel,
        'fromGrade': myGrade,
        'fromElement': myElement,
        'toLevel': opponentLevel,
        'toGrade': opponentGrade,
        'toWon': opponentWon,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
      debugPrint(
        '??배? ?림 ?송: $myNickname ??$toUserId (?? ${opponentWon ? "?리" : "?배"})',
      );
      debugPrint('   문서 ID: ${docRef.id}');
      return true;
    } catch (e) {
      debugPrint('??배? ?림 ?송 ?패: $e');
      return false;
    }
  }

  /// ?게 ??배? ?림 가?오?
  Future<List<Map<String, dynamic>>> fetchBattleNotifications() async {
    if (myUserId.isEmpty) {
      debugPrint('??배? ?림 ?신 ?패: myUserId가 비어?음');
      return [];
    }

    debugPrint('? 배? ?림 조회: toUserId=$myUserId');

    try {
      final snapshot = await _firestore
          .collection('battle_notifications')
          .where('toUserId', isEqualTo: myUserId)
          .get();

      debugPrint('? Firestore?서 ${snapshot.docs.length}?문서 발견');

      final notifications = <Map<String, dynamic>>[];
      final unreadDocs = <DocumentSnapshot>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        if (data['read'] == true) {
          debugPrint('   - ${doc.id}: ?? ?음, ?킵');
          continue;
        }

        debugPrint(
          '   - ' +
              doc.id +
              ': ' +
              (data['fromNickname'] ?? '') +
              ', result=' +
              (data['toWon'] == true ? 'win' : 'lose'),
        );

        notifications.add({
          'id': doc.id,
          'fromUserId': data['fromUserId'] ?? '',
          'fromNickname': data['fromNickname'] ?? '?????음',
          'fromLevel': data['fromLevel'] ?? 1,
          'fromGrade': data['fromGrade'] ?? 'normal',
          'fromElement': data['fromElement'] ?? 'fire',
          'toLevel': data['toLevel'] ?? 1,
          'toGrade': data['toGrade'] ?? 'normal',
          'toWon': data['toWon'] ?? false,
          'timestamp':
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        });

        unreadDocs.add(doc);
      }

      // ? 배치???번에 ?음 처리 (Firebase ?기 비용 ?감)
      if (unreadDocs.isNotEmpty) {
        try {
          final batch = _firestore.batch();
          for (final doc in unreadDocs) {
            batch.update(doc.reference, {'read': true});
          }
          await batch.commit();
          debugPrint('   ??${unreadDocs.length}??림 배치 ?음 처리 ?료');
        } catch (e) {
          debugPrint('   ??배치 ?음 처리 ?패: $e');
        }
      }

      notifications.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      debugPrint('? 최종 ${notifications.length}??림 반환');
      return notifications;
    } catch (e) {
      debugPrint('??배? ?림 가?오??패: $e');
      return [];
    }
  }

  // ============================================================
  // ? ?레?어 조회
  // ============================================================

  /// ID??레?어 조회
  Future<PlayerProfile?> fetchById(String userId) async {
    if (userId.trim().isEmpty) return null;

    try {
      final doc = await _firestore
          .collection(_publicUsersCollection)
          .doc(userId)
          .get();
      if (!doc.exists) {
        final legacyDoc = await _firestore
            .collection('users')
            .doc(userId)
            .get();
        if (!legacyDoc.exists) return null;
        final legacy = legacyDoc.data()!;
        return PlayerProfile(
          userId: userId,
          nickname: legacy['nickname'] ?? '  ',
          swordId: legacy['equippedSwordId'] ?? 'sword_001',
          swordLevel: legacy['equippedSwordLevel'] ?? 1,
          swordBreakthroughLevel: legacy['equippedSwordBreakthroughLevel'] ?? 0,
          titleId: legacy['titleId'] ?? 't_01',
          updatedAt: _parseUpdatedAt(legacy['updatedAt']),
        );
      }

      final data = doc.data()!;
      return PlayerProfile(
        userId: userId,
        nickname: data['nickname'] ?? '?????음',
        swordId: data['equippedSwordId'] ?? 'sword_001',
        swordLevel: data['equippedSwordLevel'] ?? 1,
        swordBreakthroughLevel: data['equippedSwordBreakthroughLevel'] ?? 0,
        titleId: data['titleId'] ?? 't_01',
        updatedAt: _parseUpdatedAt(data['updatedAt']),
      );
    } catch (e) {
      debugPrint('???레?어 조회 ?패: $e');
      return null;
    }
  }

  /// ?네?으??레?어 조회
  Future<PlayerProfile?> fetchByNickname(String nickname) async {
    if (nickname.trim().isEmpty) return null;

    try {
      final query = await _firestore
          .collection(_publicUsersCollection)
          .where('nickname', isEqualTo: nickname.trim())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        final legacyQuery = await _firestore
            .collection('users')
            .where('nickname', isEqualTo: nickname.trim())
            .limit(1)
            .get();
        if (legacyQuery.docs.isEmpty) return null;
        final legacyDoc = legacyQuery.docs.first;
        final legacy = legacyDoc.data();
        return PlayerProfile(
          userId: legacyDoc.id,
          nickname: legacy['nickname'] ?? '  ',
          swordId: legacy['equippedSwordId'] ?? 'sword_001',
          swordLevel: legacy['equippedSwordLevel'] ?? 1,
          swordBreakthroughLevel: legacy['equippedSwordBreakthroughLevel'] ?? 0,
          titleId: legacy['titleId'] ?? 't_01',
          updatedAt: _parseUpdatedAt(legacy['updatedAt']),
          totalBattle: legacy['totalBattle'] ?? 0,
          totalBattleWin: legacy['totalBattleWin'] ?? 0,
        );
      }

      final doc = query.docs.first;
      final data = doc.data();
      return PlayerProfile(
        userId: doc.id,
        nickname: data['nickname'] ?? '?????음',
        swordId: data['equippedSwordId'] ?? 'sword_001',
        swordLevel: data['equippedSwordLevel'] ?? 1,
        swordBreakthroughLevel: data['equippedSwordBreakthroughLevel'] ?? 0,
        titleId: data['titleId'] ?? 't_01',
        updatedAt: _parseUpdatedAt(data['updatedAt']),
        totalBattle: data['totalBattle'] ?? 0,
        totalBattleWin: data['totalBattleWin'] ?? 0,
      );
    } catch (e) {
      debugPrint('???네??조회 ?패: $e');
      return null;
    }
  }

  // ============================================================
  // ? ??
  // ============================================================

  /// ?위 ?? 조회 (100?까지, ?투??기? ?렬) - ? 30?캐시
  Future<List<PlayerProfile>> fetchTopRankings({
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    // ?? ?? ??
    if (!forceRefresh &&
        _rankingsCache != null &&
        _rankingsCacheTime != null &&
        DateTime.now().difference(_rankingsCacheTime!) <
            _rankingsCacheDuration) {
      debugPrint('?? ?? ?? ?? (${_rankingsCache!.length}?)');
      return _rankingsCache!;
    }

    final profiles = <PlayerProfile>[];
    final now = DateTime.now();

    try {
      final snapshot = await _firestore
          .collection(_publicUsersCollection)
          .orderBy('equippedSwordLevel', descending: true)
          .limit(limit)
          .get();

      if (kDebugMode) {
        debugPrint('? ?? 쿼리 문서 ?? ${snapshot.docs.length}');
        for (final doc in snapshot.docs.take(5)) {
          final data = doc.data();
          final level = data['equippedSwordLevel'];
          debugPrint('  - ${doc.id} level=$level (${level?.runtimeType})');
        }
      }

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final updatedRaw = data['updatedAt'];
        DateTime updatedAt;
        if (updatedRaw is Timestamp) {
          updatedAt = updatedRaw.toDate();
        } else if (updatedRaw is String) {
          updatedAt = DateTime.tryParse(updatedRaw) ?? now;
        } else {
          updatedAt = now;
        }
        profiles.add(
          PlayerProfile(
            userId: doc.id,
            nickname: data['nickname'] ?? '? ? ??',
            swordId: data['equippedSwordId'] ?? 'sword_001',
            swordLevel: data['equippedSwordLevel'] ?? 1,
            swordBreakthroughLevel: data['equippedSwordBreakthroughLevel'] ?? 0,
            titleId: data['titleId'] ?? 't_01',
            updatedAt: updatedAt,
            totalBattle: data['totalBattle'] ?? 0,
            totalBattleWin: data['totalBattleWin'] ?? 0,
          ),
        );
      }
      debugPrint('?? ?? ????: ${profiles.length}?');
    } catch (e) {
      debugPrint('?? ?? ?? ??: $e');
    }

    final result = profiles.take(100).toList();

    // ?? ?? ?? (?? ?????? ?? ???)
    if (result.length > 1) {
      _rankingsCache = result;
      _rankingsCacheTime = DateTime.now();
    }

    return result;
  }

  /// ?? ?? ?? ?덤 ?? 찾기
  Future<PlayerProfile?> findRandomOpponent({
    int myLevel = 1,
    int preferredRange = 5,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_publicUsersCollection)
          .limit(30)
          .get();

      final candidates = snapshot.docs
          .where((doc) => doc.id != myUserId)
          .map((doc) {
            final data = doc.data();
            return PlayerProfile(
              userId: doc.id,
              nickname: data['nickname'] ?? '?????음',
              swordId: data['equippedSwordId'] ?? 'sword_001',
              swordLevel: data['equippedSwordLevel'] ?? 1,
              swordBreakthroughLevel:
                  data['equippedSwordBreakthroughLevel'] ?? 0,
              titleId: data['titleId'] ?? 't_01',
              updatedAt: DateTime.now(),
              totalBattle: data['totalBattle'] ?? 0,
              totalBattleWin: data['totalBattleWin'] ?? 0,
            );
          })
          .where((p) => (p.swordLevel - myLevel).abs() <= preferredRange)
          .toList();

      if (candidates.isNotEmpty) {
        return candidates[math.Random().nextInt(candidates.length)];
      }

      // NPC ?택
      final npcCandidates = npcPlayers.where((npc) {
        return (npc.swordLevel - myLevel).abs() <= preferredRange;
      }).toList();

      if (npcCandidates.isNotEmpty) {
        final npc = npcCandidates[math.Random().nextInt(npcCandidates.length)];
        return PlayerProfile(
          userId: npc.id,
          nickname: npc.name,
          swordId: npc.sword.id,
          swordLevel: npc.swordLevel,
          swordBreakthroughLevel: 0,
          titleId: 't_01',
          updatedAt: DateTime.now(),
        );
      }

      return null;
    } catch (e) {
      debugPrint('?️ ?덤 ?? 찾기 ?패: $e');
      return null;
    }
  }
}
