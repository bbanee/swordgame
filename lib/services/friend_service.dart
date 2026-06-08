// lib/services/friend_service.dart
// 친구 시스템 서비스

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/player_profile.dart';
import 'auth_service.dart';

class FriendService {
  static final FriendService _instance = FriendService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _publicUsersCollection = 'users_public';
  final AuthService _auth = AuthService();

  factory FriendService() => _instance;
  FriendService._internal();

  DateTime _parseUpdatedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  List<List<String>> _chunkIds(List<String> ids, int size) {
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += size) {
      chunks.add(ids.sublist(i, i + size > ids.length ? ids.length : i + size));
    }
    return chunks;
  }

  // 현재 사용자 UID
  String? get _uid => _auth.uid;

  // 친구 프로필 캐시 (5분 TTL)
  List<PlayerProfile>? _friendProfilesCache;
  DateTime? _friendProfilesCacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// 닉네임 중복 확인
  Future<bool> isNicknameAvailable(String nickname) async {
    if (nickname.trim().isEmpty) return false;

    try {
      final query = await _firestore
          .collection('users')
          .where('nickname', isEqualTo: nickname.trim())
          .limit(1)
          .get();

      if (query.docs.isEmpty) return true;
      if (query.docs.first.id == _uid) return true;
      return false;
    } catch (e) {
      debugPrint('닉네임 중복 체크 실패: $e');
      return true;
    }
  }

  /// 닉네임으로 사용자 UID 조회
  Future<String?> getUidByNickname(String nickname) async {
    if (nickname.trim().isEmpty) return null;

    try {
      final query = await _firestore
          .collection('users')
          .where('nickname', isEqualTo: nickname.trim())
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return query.docs.first.id;
    } catch (e) {
      debugPrint('닉네임 조회 실패: $e');
      return null;
    }
  }

  /// 친구 ID 목록 조회
  Future<List<String>> getFriendIds() async {
    if (_uid == null) return [];

    try {
      final doc = await _firestore.collection('users').doc(_uid).get();
      if (!doc.exists) return [];

      final data = doc.data();
      final friendIds = data?['friendIds'] as List<dynamic>?;
      return friendIds?.cast<String>() ?? [];
    } catch (e) {
      debugPrint('친구 목록 로드 실패: $e');
      return [];
    }
  }

  /// 친구 추가
  Future<FriendResult> addFriendByNickname(String nickname) async {
    if (_uid == null) return FriendResult.failure('Failed to add friend.');

    final trimmed = nickname.trim();
    if (trimmed.isEmpty) return FriendResult.failure('Failed to add friend.');
    if (trimmed.length < 2)
      return FriendResult.failure('Failed to add friend.');

    try {
      var query = await _firestore
          .collection(_publicUsersCollection)
          .where('nickname', isEqualTo: trimmed)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        query = await _firestore
            .collection('users')
            .where('nickname', isEqualTo: trimmed)
            .limit(1)
            .get();
      }

      if (query.docs.isEmpty)
        return FriendResult.failure('Failed to add friend.');

      final friendDoc = query.docs.first;
      final friendUid = friendDoc.id;

      if (friendUid == _uid)
        return FriendResult.failure('Failed to add friend.');

      final myDoc = await _firestore.collection('users').doc(_uid).get();
      final currentFriends =
          (myDoc.data()?['friendIds'] as List<dynamic>?)?.cast<String>() ?? [];

      if (currentFriends.contains(friendUid)) {
        return FriendResult.failure('Failed to add friend.');
      }

      await _firestore.collection('users').doc(_uid).update({
        'friendIds': FieldValue.arrayUnion([friendUid]),
      });

      clearFriendCache();

      final friendData = friendDoc.data();
      return FriendResult.success(
        PlayerProfile(
          userId: friendUid,
          nickname: friendData['nickname'] ?? '알 수 없음',
          swordId: friendData['equippedSwordId'] ?? 'sword_001',
          swordLevel: friendData['equippedSwordLevel'] ?? 1,
          swordBreakthroughLevel:
              friendData['equippedSwordBreakthroughLevel'] ?? 0,
          titleId: friendData['titleId'] ?? 't_01',
          updatedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('친구 추가 실패: $e');
      return FriendResult.failure('Failed to add friend.');
    }
  }

  /// 친구 삭제
  Future<bool> removeFriend(String friendUid) async {
    if (_uid == null) return false;

    try {
      debugPrint('친구 삭제 시작: $friendUid');

      await _firestore.collection('users').doc(_uid).update({
        'friendIds': FieldValue.arrayRemove([friendUid]),
      });

      clearFriendCache();

      debugPrint('친구 삭제 완료: $friendUid');
      return true;
    } catch (e) {
      debugPrint('친구 삭제 실패: $e');
      return false;
    }
  }

  /// 친구 프로필 정보 가져오기 (5분 캐시)
  Future<List<PlayerProfile>> getFriendProfiles({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _friendProfilesCache != null &&
        _friendProfilesCacheTime != null &&
        DateTime.now().difference(_friendProfilesCacheTime!) < _cacheDuration) {
      debugPrint('친구 프로필 캐시 사용 (${_friendProfilesCache!.length}명)');
      return _friendProfilesCache!;
    }

    final friendIds = await getFriendIds();
    if (friendIds.isEmpty) {
      _friendProfilesCache = [];
      _friendProfilesCacheTime = DateTime.now();
      return [];
    }

    final profilesById = <String, PlayerProfile>{};

    try {
      final chunks = _chunkIds(friendIds, 10);
      final snapshots = await Future.wait(
        chunks.map((chunk) {
          return _firestore
              .collection(_publicUsersCollection)
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
        }),
      );

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          profilesById[doc.id] = PlayerProfile(
            userId: doc.id,
            nickname: data['nickname'] ?? '알 수 없음',
            swordId: data['equippedSwordId'] ?? 'sword_001',
            swordLevel: data['equippedSwordLevel'] ?? 1,
            swordBreakthroughLevel: data['equippedSwordBreakthroughLevel'] ?? 0,
            titleId: data['titleId'] ?? 't_01',
            updatedAt: _parseUpdatedAt(data['updatedAt']),
          );
        }
      }
    } catch (e) {
      debugPrint('친구 프로필 로드 실패: $e');
    }

    final missingIds = friendIds
        .where((id) => !profilesById.containsKey(id))
        .toList();
    for (final id in missingIds) {
      try {
        final legacyDoc = await _firestore.collection('users').doc(id).get();
        if (!legacyDoc.exists) continue;
        final data = legacyDoc.data()!;
        profilesById[id] = PlayerProfile(
          userId: id,
          nickname: data['nickname'] ?? '알 수 없음',
          swordId: data['equippedSwordId'] ?? 'sword_001',
          swordLevel: data['equippedSwordLevel'] ?? 1,
          swordBreakthroughLevel: data['equippedSwordBreakthroughLevel'] ?? 0,
          titleId: data['titleId'] ?? 't_01',
          updatedAt: _parseUpdatedAt(data['updatedAt']),
        );
      } catch (e) {
        debugPrint('친구 프로필 로드 실패(legacy): $id - $e');
      }
    }

    final profiles = <PlayerProfile>[];
    for (final id in friendIds) {
      final p = profilesById[id];
      if (p != null) profiles.add(p);
    }

    _friendProfilesCache = profiles;
    _friendProfilesCacheTime = DateTime.now();
    debugPrint('친구 프로필 새로고침 (${profiles.length}명)');

    return profiles;
  }

  /// 친구 캐시 무효화 (친구 추가/삭제 후 호출)
  void clearFriendCache() {
    _friendProfilesCache = null;
    _friendProfilesCacheTime = null;
    debugPrint('친구 프로필 캐시 삭제');
  }

  /// 닉네임 검색
  Future<List<PlayerProfile>> searchByNickname(String query) async {
    if (query.trim().length < 2) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('nickname', isGreaterThanOrEqualTo: query)
          .where('nickname', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      return snapshot.docs.where((doc) => doc.id != _uid).map((doc) {
        final data = doc.data();
        return PlayerProfile(
          userId: doc.id,
          nickname: data['nickname'] ?? '알 수 없음',
          swordId: data['equippedSwordId'] ?? 'sword_001',
          swordLevel: data['equippedSwordLevel'] ?? 1,
          swordBreakthroughLevel: data['equippedSwordBreakthroughLevel'] ?? 0,
          titleId: data['titleId'] ?? 't_01',
          updatedAt: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('닉네임 검색 실패: $e');
      return [];
    }
  }
}

class FriendResult {
  final bool isSuccess;
  final PlayerProfile? profile;
  final String? errorMessage;

  FriendResult._({required this.isSuccess, this.profile, this.errorMessage});

  factory FriendResult.success(PlayerProfile profile) =>
      FriendResult._(isSuccess: true, profile: profile);

  factory FriendResult.failure(String message) =>
      FriendResult._(isSuccess: false, errorMessage: message);
}
