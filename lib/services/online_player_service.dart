import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/player_profile.dart';
import '../data/npcs.dart';

/// 온라인 플레이어 서비스 (Firebase 연동)
class OnlinePlayerService {
  final String myUserId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _publicUsersCollection = 'users_public';
  static const String _tossUsersCollection = 'users_appintos';
  static const String _tossNotificationsCollection =
      'battle_notifications_appintos';

  // 랭킹 캐시 (30초 TTL)
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

  int _parseInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  /// 내 프로필 업데이트
  Future<void> upsertMe(PlayerProfile me) async {
    if (myUserId.isEmpty) return;

    final key =
        '${me.nickname}|${me.swordId}|${me.swordLevel}|${me.swordBreakthroughLevel}|${me.titleId}|${me.totalBattle}|${me.totalBattleWin}|${me.codexCount}';
    if (!_shouldSyncProfile(key)) return;

    try {
      await _firestore.collection('users').doc(myUserId).set({
        'nickname': me.nickname,
        'equippedSwordId': me.swordId,
        'equippedSwordLevel': me.swordLevel,
        'equippedSwordBreakthroughLevel': me.swordBreakthroughLevel,
        'titleId': me.titleId,
        'totalBattle': me.totalBattle,
        'totalBattleWin': me.totalBattleWin,
        'codexCount': me.codexCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _firestore.collection(_publicUsersCollection).doc(myUserId).set({
        'nickname': me.nickname,
        'equippedSwordId': me.swordId,
        'equippedSwordLevel': me.swordLevel,
        'equippedSwordBreakthroughLevel': me.swordBreakthroughLevel,
        'titleId': me.titleId,
        'totalBattle': me.totalBattle,
        'totalBattleWin': me.totalBattleWin,
        'codexCount': me.codexCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _rankingsCache = null;
      _rankingsCacheTime = null;
      debugPrint('프로필 업데이트: ${me.nickname}');
    } catch (e) {
      debugPrint('프로필 업데이트 실패: $e');
    }
  }

  // ============================================================
  // 배틀 알림 시스템
  // ============================================================

  /// 배틀 알림 보내기 (공격받은 유저에게 공격자 정보 전송)
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
      debugPrint('배틀 알림 전송 실패: ID가 비어 있음');
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
        '배틀 알림 전송: $myNickname → $toUserId (상대 ${opponentWon ? "승리" : "패배"})',
      );
      debugPrint('   문서 ID: ${docRef.id}');
      return true;
    } catch (e) {
      debugPrint('배틀 알림 전송 실패: $e');
      return false;
    }
  }

  /// 내게 온 배틀 알림 가져오기
  Future<List<Map<String, dynamic>>> fetchBattleNotifications() async {
    if (myUserId.isEmpty) {
      debugPrint('배틀 알림 수신 실패: myUserId가 비어 있음');
      return [];
    }

    debugPrint('배틀 알림 조회: toUserId=$myUserId');

    try {
      final snapshot = await _firestore
          .collection('battle_notifications')
          .where('toUserId', isEqualTo: myUserId)
          .get();

      debugPrint('Firestore에서 ${snapshot.docs.length}개 문서 발견');

      final notifications = <Map<String, dynamic>>[];
      final unreadDocs = <DocumentSnapshot>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        if (data['read'] == true) {
          debugPrint('   - ${doc.id}: 이미 읽음, 스킵');
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
          'fromNickname': data['fromNickname'] ?? '알 수 없음',
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

      // 배치로 한 번에 읽음 처리 (Firebase 쓰기 비용 절감)
      if (unreadDocs.isNotEmpty) {
        try {
          final batch = _firestore.batch();
          for (final doc in unreadDocs) {
            batch.update(doc.reference, {'read': true});
          }
          await batch.commit();
          debugPrint('   ${unreadDocs.length}개 알림 배치 읽음 처리 완료');
        } catch (e) {
          debugPrint('   배치 읽음 처리 실패: $e');
        }
      }

      notifications.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      debugPrint('최종 ${notifications.length}개 알림 반환');
      return notifications;
    } catch (e) {
      debugPrint('배틀 알림 가져오기 실패: $e');
      return [];
    }
  }

  // ============================================================
  // 플레이어 조회
  // ============================================================

  /// ID로 플레이어 조회 (users_public → users_appintos → users 순서로 탐색)
  Future<PlayerProfile?> fetchById(
    String userId, {
    String platform = 'google',
  }) async {
    if (userId.trim().isEmpty) return null;

    try {
      // Toss 유저 힌트가 있으면 users_appintos 우선
      if (platform == 'toss') {
        final tossDoc = await _firestore
            .collection(_tossUsersCollection)
            .doc(userId)
            .get();
        if (tossDoc.exists) {
          return _profileFromToss(userId, tossDoc.data()!);
        }
      }

      // users_public 조회
      final doc = await _firestore
          .collection(_publicUsersCollection)
          .doc(userId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return PlayerProfile(
          userId: userId,
          nickname: data['nickname'] ?? '알 수 없음',
          swordId: data['equippedSwordId'] ?? 'sword_001',
          swordLevel: data['equippedSwordLevel'] ?? 1,
          swordBreakthroughLevel: data['equippedSwordBreakthroughLevel'] ?? 0,
          titleId: data['titleId'] ?? 't_01',
          updatedAt: _parseUpdatedAt(data['updatedAt']),
          totalBattle: data['totalBattle'] ?? 0,
          totalBattleWin: data['totalBattleWin'] ?? 0,
          codexCount: data['codexCount'] ?? 0,
        );
      }

      // users_appintos 폴백 (platform 힌트 없이도 Toss 유저 찾기)
      final tossDoc = await _firestore
          .collection(_tossUsersCollection)
          .doc(userId)
          .get();
      if (tossDoc.exists) {
        return _profileFromToss(userId, tossDoc.data()!);
      }

      // 레거시 users 폴백
      final legacyDoc = await _firestore.collection('users').doc(userId).get();
      if (!legacyDoc.exists) return null;
      final legacy = legacyDoc.data()!;
      return PlayerProfile(
        userId: userId,
        nickname: legacy['nickname'] ?? '알 수 없음',
        swordId: legacy['equippedSwordId'] ?? 'sword_001',
        swordLevel: legacy['equippedSwordLevel'] ?? 1,
        swordBreakthroughLevel: legacy['equippedSwordBreakthroughLevel'] ?? 0,
        titleId: legacy['titleId'] ?? 't_01',
        updatedAt: _parseUpdatedAt(legacy['updatedAt']),
      );
    } catch (e) {
      debugPrint('플레이어 조회 실패: $e');
      return null;
    }
  }

  PlayerProfile _profileFromToss(String userId, Map<String, dynamic> d) {
    return PlayerProfile(
      userId: userId,
      nickname: d['nickname'] ?? '알 수 없음',
      swordId: d['equippedSwordId'] ?? 'sword_001',
      swordLevel: d['equippedSwordLevel'] ?? 1,
      titleId: d['titleId'] ?? 't_01',
      updatedAt: _parseUpdatedAt(d['updatedAt']),
      totalBattle: d['totalBattle'] ?? 0,
      totalBattleWin: d['totalBattleWin'] ?? 0,
      codexCount: d['codexCount'] ?? 0,
      platform: 'toss',
    );
  }

  /// 닉네임으로 플레이어 조회
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
          nickname: legacy['nickname'] ?? '알 수 없음',
          swordId: legacy['equippedSwordId'] ?? 'sword_001',
          swordLevel: legacy['equippedSwordLevel'] ?? 1,
          swordBreakthroughLevel: legacy['equippedSwordBreakthroughLevel'] ?? 0,
          titleId: legacy['titleId'] ?? 't_01',
          updatedAt: _parseUpdatedAt(legacy['updatedAt']),
          totalBattle: legacy['totalBattle'] ?? 0,
          totalBattleWin: legacy['totalBattleWin'] ?? 0,
          codexCount: legacy['codexCount'] ?? 0,
        );
      }

      final doc = query.docs.first;
      final data = doc.data();
      return PlayerProfile(
        userId: doc.id,
        nickname: data['nickname'] ?? '알 수 없음',
        swordId: data['equippedSwordId'] ?? 'sword_001',
        swordLevel: data['equippedSwordLevel'] ?? 1,
        swordBreakthroughLevel: data['equippedSwordBreakthroughLevel'] ?? 0,
        titleId: data['titleId'] ?? 't_01',
        updatedAt: _parseUpdatedAt(data['updatedAt']),
        totalBattle: data['totalBattle'] ?? 0,
        totalBattleWin: data['totalBattleWin'] ?? 0,
        codexCount: data['codexCount'] ?? 0,
      );
    } catch (e) {
      debugPrint('닉네임 조회 실패: $e');
      return null;
    }
  }

  // ============================================================
  // 랭킹
  // ============================================================

  /// 상위 랭킹 조회 — users_public(구글) + users_appintos(토스) 합산 후 정렬
  Future<List<PlayerProfile>> fetchTopRankings({
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _rankingsCache != null &&
        _rankingsCacheTime != null &&
        DateTime.now().difference(_rankingsCacheTime!) <
            _rankingsCacheDuration) {
      debugPrint('랭킹 캐시 사용 (${_rankingsCache!.length}명)');
      return _rankingsCache!;
    }

    final profiles = <PlayerProfile>[];

    // ── Google(Flutter) 유저
    try {
      final snap = await _firestore
          .collection(_publicUsersCollection)
          .orderBy('equippedSwordLevel', descending: true)
          .limit(limit)
          .get();

      for (final doc in snap.docs) {
        final d = doc.data();
        profiles.add(
          PlayerProfile(
            userId: doc.id,
            nickname: d['nickname'] ?? '알 수 없음',
            swordId: d['equippedSwordId'] ?? 'sword_001',
            swordLevel: d['equippedSwordLevel'] ?? 1,
            swordBreakthroughLevel: d['equippedSwordBreakthroughLevel'] ?? 0,
            titleId: d['titleId'] ?? 't_01',
            updatedAt: _parseUpdatedAt(d['updatedAt']),
            totalBattle: d['totalBattle'] ?? 0,
            totalBattleWin: d['totalBattleWin'] ?? 0,
            codexCount: d['codexCount'] ?? 0,
            platform: 'google',
          ),
        );
      }
      debugPrint('구글 랭킹: ${snap.docs.length}명');
    } catch (e) {
      debugPrint('구글 랭킹 로드 실패: $e');
    }

    // ── 토스(앱인토스) 유저
    try {
      final snap = await _firestore
          .collection(_tossUsersCollection)
          .orderBy('equippedSwordLevel', descending: true)
          .limit(limit)
          .get();

      for (final doc in snap.docs) {
        // 중복 userId 스킵
        if (profiles.any((p) => p.userId == doc.id)) continue;
        final d = doc.data();
        profiles.add(
          PlayerProfile(
            userId: doc.id,
            nickname: d['nickname'] ?? '알 수 없음',
            swordId: d['equippedSwordId'] ?? 'sword_001',
            swordLevel: d['equippedSwordLevel'] ?? 1,
            titleId: d['titleId'] ?? 't_01',
            updatedAt: _parseUpdatedAt(d['updatedAt']),
            totalBattle: d['totalBattle'] ?? 0,
            totalBattleWin: d['totalBattleWin'] ?? 0,
            codexCount: d['codexCount'] ?? 0,
            platform: 'toss',
          ),
        );
      }
      debugPrint('토스 랭킹: ${snap.docs.length}명');
    } catch (e) {
      // 권한 오류 등이어도 구글 랭킹은 유지
      debugPrint('토스 랭킹 로드 실패: $e');
    }

    // 검 레벨 내림차순 → 상위 limit명
    profiles.sort((a, b) => b.swordLevel.compareTo(a.swordLevel));
    final result = profiles.take(limit).toList();

    debugPrint('합산 랭킹: ${result.length}명 (구글+토스)');

    if (result.length > 1) {
      _rankingsCache = result;
      _rankingsCacheTime = DateTime.now();
    }

    return result;
  }

  Future<List<PlayerProfile>> fetchCodexRankings({int limit = 100}) async {
    final profiles = <PlayerProfile>[];

    try {
      final snap = await _firestore
          .collection(_publicUsersCollection)
          .orderBy('codexCount', descending: true)
          .limit(limit)
          .get();

      for (final doc in snap.docs) {
        final d = doc.data();
        profiles.add(
          PlayerProfile(
            userId: doc.id,
            nickname: d['nickname'] ?? '알 수 없음',
            swordId: d['equippedSwordId'] ?? 'sword_001',
            swordLevel: d['equippedSwordLevel'] ?? 1,
            swordBreakthroughLevel: d['equippedSwordBreakthroughLevel'] ?? 0,
            titleId: d['titleId'] ?? 't_01',
            updatedAt: _parseUpdatedAt(d['updatedAt']),
            totalBattle: d['totalBattle'] ?? 0,
            totalBattleWin: d['totalBattleWin'] ?? 0,
            codexCount: d['codexCount'] ?? 0,
            platform: 'google',
          ),
        );
      }
    } catch (e) {
      debugPrint('구글 도감 랭킹 로드 실패: $e');
    }

    try {
      final snap = await _firestore
          .collection(_tossUsersCollection)
          .orderBy('codexCount', descending: true)
          .limit(limit)
          .get();

      for (final doc in snap.docs) {
        if (profiles.any((p) => p.userId == doc.id)) continue;
        final d = doc.data();
        profiles.add(
          PlayerProfile(
            userId: doc.id,
            nickname: d['nickname'] ?? '알 수 없음',
            swordId: d['equippedSwordId'] ?? 'sword_001',
            swordLevel: d['equippedSwordLevel'] ?? 1,
            swordBreakthroughLevel: d['equippedSwordBreakthroughLevel'] ?? 0,
            titleId: d['titleId'] ?? 't_01',
            updatedAt: _parseUpdatedAt(d['updatedAt']),
            totalBattle: d['totalBattle'] ?? 0,
            totalBattleWin: d['totalBattleWin'] ?? 0,
            codexCount: d['codexCount'] ?? 0,
            platform: 'toss',
          ),
        );
      }
    } catch (e) {
      debugPrint('토스 도감 랭킹 로드 실패: $e');
    }

    profiles.sort((a, b) {
      final codexCmp = b.codexCount.compareTo(a.codexCount);
      if (codexCmp != 0) return codexCmp;
      return b.powerWithTitle.compareTo(a.powerWithTitle);
    });

    return profiles.take(limit).toList();
  }

  Future<void> updateInfiniteTowerRanking({
    required String nickname,
    required int floor,
    required String swordId,
    required String swordName,
    required int swordLevel,
    required int swordBreakthroughLevel,
    required int swordPower,
  }) async {
    if (myUserId.isEmpty || floor <= 0) return;

    final ref = _firestore.collection(_publicUsersCollection).doc(myUserId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? <String, dynamic>{};
        final currentFloor = _parseInt(data['infiniteTowerBestFloor']);
        final currentPower = _parseInt(data['infiniteTowerBestPower'], 1 << 30);
        final reachedAt = data['infiniteTowerBestFloorReachedAt'];

        final isHigherFloor = floor > currentFloor;
        final isSameFloorLowerPower =
            floor == currentFloor &&
            swordPower > 0 &&
            swordPower < currentPower;
        final needsReachedAt = reachedAt == null && floor >= currentFloor;

        if (!isHigherFloor && !isSameFloorLowerPower && !needsReachedAt) {
          return;
        }

        final update = <String, dynamic>{
          'nickname': nickname,
          'infiniteTowerBestFloor': isHigherFloor ? floor : currentFloor,
          'infiniteTowerBestPower': swordPower,
          'infiniteTowerBestSwordId': swordId,
          'infiniteTowerBestSwordName': swordName,
          'infiniteTowerBestSwordLevel': swordLevel,
          'infiniteTowerBestSwordBreakthroughLevel': swordBreakthroughLevel,
          'infiniteTowerBestRunUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (isHigherFloor || needsReachedAt) {
          update['infiniteTowerBestFloorReachedAt'] =
              FieldValue.serverTimestamp();
        }

        tx.set(ref, update, SetOptions(merge: true));
      });
      debugPrint('무한의 탑 랭킹 업데이트: $floor층');
    } catch (e) {
      debugPrint('무한의 탑 랭킹 업데이트 실패: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchInfiniteTowerRankings({
    int limit = 100,
  }) async {
    final rankings = <Map<String, dynamic>>[];

    try {
      final snap = await _firestore
          .collection(_publicUsersCollection)
          .orderBy('infiniteTowerBestFloor', descending: true)
          .limit(limit)
          .get();

      for (final doc in snap.docs) {
        final entry = _towerRankingFromData(doc.id, doc.data(), 'google');
        if (entry != null) rankings.add(entry);
      }
    } catch (e) {
      debugPrint('구글 무한의 탑 랭킹 로드 실패: $e');
    }

    try {
      final snap = await _firestore
          .collection(_tossUsersCollection)
          .orderBy('infiniteTowerBestFloor', descending: true)
          .limit(limit)
          .get();

      for (final doc in snap.docs) {
        if (rankings.any((r) => r['id'] == doc.id)) continue;
        final entry = _towerRankingFromData(doc.id, doc.data(), 'toss');
        if (entry != null) rankings.add(entry);
      }
    } catch (e) {
      debugPrint('토스 무한의 탑 랭킹 로드 실패: $e');
    }

    rankings.sort((a, b) {
      final floorCmp = (b['floor'] as int).compareTo(a['floor'] as int);
      if (floorCmp != 0) return floorCmp;
      final reachedCmp = (a['reachedAt'] as DateTime).compareTo(
        b['reachedAt'] as DateTime,
      );
      if (reachedCmp != 0) return reachedCmp;
      return (a['power'] as int).compareTo(b['power'] as int);
    });

    return rankings.take(limit).toList();
  }

  Map<String, dynamic>? _towerRankingFromData(
    String id,
    Map<String, dynamic> d,
    String platform,
  ) {
    final floor = _parseInt(d['infiniteTowerBestFloor']);
    if (floor <= 0) return null;

    return {
      'id': id,
      'name': d['nickname'] ?? '알 수 없음',
      'floor': floor,
      'reachedAt': _parseUpdatedAt(d['infiniteTowerBestFloorReachedAt']),
      'power': _parseInt(d['infiniteTowerBestPower']),
      'swordId':
          d['infiniteTowerBestSwordId'] ?? d['equippedSwordId'] ?? 'sword_001',
      'swordName': d['infiniteTowerBestSwordName'] ?? '검',
      'swordLevel': _parseInt(
        d['infiniteTowerBestSwordLevel'],
        _parseInt(d['equippedSwordLevel'], 1),
      ),
      'swordBreakthroughLevel': _parseInt(
        d['infiniteTowerBestSwordBreakthroughLevel'],
        _parseInt(d['equippedSwordBreakthroughLevel']),
      ),
      'platform': platform,
      'isOnline': true,
    };
  }

  /// 비슷한 레벨의 랜덤 상대 찾기
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
              nickname: data['nickname'] ?? '알 수 없음',
              swordId: data['equippedSwordId'] ?? 'sword_001',
              swordLevel: data['equippedSwordLevel'] ?? 1,
              swordBreakthroughLevel:
                  data['equippedSwordBreakthroughLevel'] ?? 0,
              titleId: data['titleId'] ?? 't_01',
              updatedAt: DateTime.now(),
              totalBattle: data['totalBattle'] ?? 0,
              totalBattleWin: data['totalBattleWin'] ?? 0,
              codexCount: data['codexCount'] ?? 0,
            );
          })
          .where((p) => (p.swordLevel - myLevel).abs() <= preferredRange)
          .toList();

      if (candidates.isNotEmpty) {
        return candidates[math.Random().nextInt(candidates.length)];
      }

      // NPC 선택
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
      debugPrint('랜덤 상대 찾기 실패: $e');
      return null;
    }
  }

  /// Toss 유저에게 배틀 알림 전송 (battle_notifications_appintos)
  Future<void> sendTossBattleNotification({
    required String toUserId,
    required String myNickname,
    required int myLevel,
    required String myGrade,
    required String myElement,
    required int opponentLevel,
    required String opponentGrade,
    required bool opponentWon,
  }) async {
    if (toUserId.isEmpty || myUserId.isEmpty) return;
    try {
      await _firestore.collection(_tossNotificationsCollection).add({
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
      debugPrint('토스 배틀 알림 전송: $myNickname → $toUserId');
    } catch (e) {
      debugPrint('토스 배틀 알림 전송 실패: $e');
    }
  }

  /// 상대방 totalBattle / totalBattleWin 업데이트
  Future<void> updateOpponentBattleStats({
    required String opponentUserId,
    required bool opponentWon,
    required String platform,
  }) async {
    if (opponentUserId.isEmpty) return;
    try {
      final collection = platform == 'toss'
          ? _tossUsersCollection
          : _publicUsersCollection;
      final data = <String, dynamic>{'totalBattle': FieldValue.increment(1)};
      if (opponentWon) data['totalBattleWin'] = FieldValue.increment(1);
      await _firestore
          .collection(collection)
          .doc(opponentUserId)
          .set(data, SetOptions(merge: true));
      _rankingsCache = null;
      _rankingsCacheTime = null;
      debugPrint(
        '상대방 승패 업데이트: $opponentUserId (${opponentWon ? "승" : "패"}, $platform)',
      );
    } catch (e) {
      debugPrint('상대방 승패 업데이트 실패: $e');
    }
  }
}
