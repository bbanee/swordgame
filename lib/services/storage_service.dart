// lib/services/storage_service.dart
// 🔥 Firebase Firestore 클라우드 저장 버전
// 기존 코드와 호환되도록 동일한 인터페이스 유지
// ✅ Firebase 실패 시 로컬 백업 지원

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/owned_sword.dart';
import '../models/battle_record.dart';
import '../models/daily_quest.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class StorageService {
  // Firestore 인스턴스
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // ✅ 로컬 캐시 (빠른 읽기용)
  Map<String, dynamic> _cache = {};
  bool _isLoaded = false;

  // ✅ 로드/동기화 상태 (로드 완료 전 저장으로 서버 덮어쓰기 방지)
  bool _loadInProgress = false;
  bool _loadedFromCloud = false; // Firestore read 성공(문서 없음 포함)
  bool _loadFailed = false; // Firestore read 예외
  bool _deferredCloudSave = false; // 로딩 중 save 요청 → 로드 완료 후 실행

  bool get loadInProgress => _loadInProgress;
  bool get loadedFromCloud => _loadedFromCloud;
  bool get loadFailed => _loadFailed;
  bool get isLoaded => _isLoaded;
  bool get canSaveToCloudSafely => _loadedFromCloud && !_loadInProgress;

  // ✅ 로컬 백업 관련 (Firebase 실패 시에만 사용)
  static const String _localBackupKey = 'firebase_backup_data';
  static const String _pendingSyncKey = 'firebase_pending_sync';
  bool _hasPendingSync = false;

  // ✅ 세션 세대 카운터: 로그아웃 시 증가 → 이전 세션의 비동기 저장 무효화
  int _sessionGeneration = 0;

  // ✅ 서버 시간 오프셋 (기기 시간 조작 방지)
  Duration _serverTimeOffset = Duration.zero;

  /// 서버 기준 현재 시간 (기기 시간 조작 무력화)
  DateTime get serverNow => DateTime.now().add(_serverTimeOffset);

  // 동기화 상태 확인용 getter
  bool get hasPendingSync => _hasPendingSync;

  // 싱글톤
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // ============================================================
  // ✅ Firestore 문서 참조
  // ============================================================
  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _authService.uid;
    if (uid == null || uid.isEmpty) return null;
    return _firestore.collection('users').doc(uid);
  }

  // 현재 로그인된 사용자 UID
  String? get currentUid => _authService.uid;

  // 로그인 상태 확인
  bool get isLoggedIn => _authService.isLoggedIn;

  // ============================================================
  // ✅ 초기화: Firestore에서 데이터 로드
  // ============================================================
  Future<void> init() async {
    // 먼저 보류 중인 동기화가 있는지 확인
    await _checkPendingSync();

    // Firebase에서 로드 시도
    await loadFromCloud();

    // 서버 시간 동기화는 백그라운드로 진행해 초기 로딩 지연을 줄임
    unawaited(_syncServerTime());

    // 보류 중인 동기화가 있으면 시도
    if (_hasPendingSync) {
      await syncPendingData();
    }
  }

  // ✅ 서버 시간 동기화
  Future<void> _syncServerTime() async {
    try {
      final uid = _authService.uid;
      if (uid == null || uid.isEmpty) return;

      final doc = _firestore.collection('users').doc(uid);
      await doc.set({
        '_serverTimeCheck': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final snapshot = await doc.get();
      final serverTime = (snapshot.data()?['_serverTimeCheck'] as Timestamp?)
          ?.toDate();
      if (serverTime != null) {
        _serverTimeOffset = serverTime.difference(DateTime.now());
        debugPrint('✅ 서버 시간 동기화: offset=${_serverTimeOffset.inSeconds}초');
      }
    } catch (e) {
      debugPrint('⚠️ 서버 시간 동기화 실패 (로컬 시간 사용): $e');
      _serverTimeOffset = Duration.zero;
    }
  }

  // ✅ 보류 중인 동기화 확인
  Future<void> _checkPendingSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasPendingSync = prefs.getBool(_pendingSyncKey) ?? false;
      if (_hasPendingSync) {
        debugPrint('⚠️ 보류 중인 Firebase 동기화 발견');
      }
    } catch (e) {
      debugPrint('❌ 보류 동기화 확인 실패: $e');
    }
  }

  // ✅ 클라우드에서 데이터 로드
  Future<void> loadFromCloud() async {
    _loadInProgress = true;
    _loadedFromCloud = false;
    _loadFailed = false;

    bool needsInitialCreate = false;

    try {
      final doc = _userDoc;
      if (doc == null) {
        debugPrint('⚠️ 로그인되지 않음 - 데이터 로드 스킵');
        return;
      }

      final snapshot = await doc.get();

      if (snapshot.exists && snapshot.data() != null) {
        _cache = Map<String, dynamic>.from(snapshot.data()!);
        debugPrint('✅ Firestore에서 데이터 로드 완료');
      } else {
        // 신규 사용자 - 기본값으로 초기화 (※ 여기서 바로 저장하면 로딩 중 덮어쓰기 위험이 있어 지연 저장)
        _cache = _getDefaultData();
        needsInitialCreate = true;
        debugPrint('✅ 신규 사용자 - 기본 데이터 준비');
      }

      _isLoaded = true;
      _loadedFromCloud = true;
    } catch (e) {
      debugPrint('❌ Firestore 로드 실패: $e');
      _loadFailed = true;

      // ✅ Firebase 실패 시 로컬 백업이 있으면 사용
      if (_hasPendingSync) {
        final localData = await _loadFromLocalBackup();
        if (localData != null) {
          _cache = localData;
          debugPrint('✅ 로컬 백업 데이터로 복구');
          _isLoaded = true;
          return;
        }
      }

      // 로컬 백업도 없으면 일단 기본값으로 시작 (단, 클라우드 저장은 차단됨)
      _cache = _getDefaultData();
      _isLoaded = true;
    } finally {
      _loadInProgress = false;
    }

    // ✅ 로딩 중 요청된 저장이 있거나, 신규 유저 문서 생성이 필요하면 로드 완료 후에만 저장
    if (_loadedFromCloud && (needsInitialCreate || _deferredCloudSave)) {
      _deferredCloudSave = false;
      // force=true로 디바운싱 무시 → (신규 생성/지연 저장) 즉시 반영
      await saveToCloud(force: true);
    }
  }

  // ✅ 클라우드에 데이터 저장
  Future<bool> saveToCloud({bool force = false}) async {
    // ✅ 이 저장이 시작된 세션 세대 기록
    final saveGeneration = _sessionGeneration;

    // ✅ 로딩 중에는 절대 서버에 저장하지 않음 (기본값 덮어쓰기 방지)
    if (_loadInProgress) {
      _deferredCloudSave = true;
      debugPrint('⏳ 데이터 로딩 중 - 클라우드 저장 지연');
      return true;
    }

    // ✅ Firestore에서 정상적으로 로드(문서 없음 포함)된 상태가 아닐 때는 클라우드 저장 차단
    //    (네트워크/권한 문제로 로드 실패한 상태에서 저장하면 서버 데이터를 덮어쓸 수 있음)
    if (!_loadedFromCloud) {
      debugPrint('⚠️ 클라우드 기준 데이터가 준비되지 않음 - 로컬 백업만 저장');
      // ✅ 세대가 바뀌었으면(로그아웃됨) 백업 차단
      if (_sessionGeneration != saveGeneration) return false;
      await _saveToLocalBackup();
      return false;
    }

    // 🔥 디바운싱: 2초 이내 연속 저장 방지 (force=true이면 무시)
    final now = DateTime.now();
    if (!force) {
      if (_lastSaveTime != null &&
          now.difference(_lastSaveTime!).inSeconds < 2) {
        // 2초 이내면 나중에 저장 예약
        _scheduleSave();
        return true;
      }
    }

    _lastSaveTime = now;
    _saveScheduled = false;

    try {
      final doc = _userDoc;
      if (doc == null) {
        debugPrint('⚠️ 로그인되지 않음 - 저장 스킵');
        return false;
      }

      // ✅ ownerId 추가 (권한 체크용)
      final authUid = AuthService().uid;
      if (authUid != null) {
        _cache['ownerId'] = authUid;
      }

      // 저장 시간 추가
      _cache['lastSaved'] = FieldValue.serverTimestamp();

      // ✅ friendIds는 FriendService에서 별도 관리하므로 제외
      final dataToSave = Map<String, dynamic>.from(_cache);
      dataToSave.remove('friendIds'); // friendIds 제외!
      dataToSave.remove('_serverTimeCheck'); // ✅ 서버 시간 체크 필드 제외

      await doc.set(dataToSave, SetOptions(merge: true));
      debugPrint('✅ Firestore에 데이터 저장 완료');

      await _firestore.collection('users_public').doc(doc.id).set({
        'nickname': _cache['nickname'],
        'equippedSwordId': _cache['equippedSwordId'],
        'equippedSwordLevel': _cache['equippedSwordLevel'] ?? 1,
        'equippedSwordBreakthroughLevel':
            _cache['equippedSwordBreakthroughLevel'] ?? 0,
        'titleId': _cache['equippedTitle'] ?? 't_01',
        'totalBattle': _cache['totalBattle'] ?? 0,
        'totalBattleWin': _cache['totalBattleWin'] ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ users_public 프로필 동기화 완료');

      // ✅ Firebase 성공 시 보류 플래그 해제
      if (_hasPendingSync) {
        await _clearPendingSync();
      }
      return true;
    } catch (e) {
      debugPrint('❌ Firestore 저장 실패: $e');

      // ✅ 세대가 바뀌었으면(로그아웃됨) 백업 차단!
      if (_sessionGeneration != saveGeneration) {
        debugPrint(
          '⚠️ 이전 세션 저장 실패 - 백업 차단 (gen $saveGeneration → $_sessionGeneration)',
        );
        return false;
      }

      // 같은 세션이면 로컬에 백업 저장
      await _saveToLocalBackup();
      return false;
    }
  }

  /// ✅ (긴급) 로컬 백업 즉시 저장
  /// - 클라우드 로드/저장 실패 또는 로딩 중 백그라운드 전환 시 사용
  Future<void> saveToLocalBackupNow() async {
    try {
      // 로그인 세션이 없으면 백업 스킵
      if (!isLoggedIn) return;
      await _saveToLocalBackup();
    } catch (_) {
      // ignore
    }
  }

  // ============================================================
  // ✅ 로컬 백업 시스템 (Firebase 실패 시에만 사용)
  // ============================================================

  // JSON 인코딩을 위해 Timestamp/DateTime 등을 안전하게 변환
  Map<String, dynamic> _makeJsonSafe(Map<String, dynamic> input) {
    dynamic sanitize(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate().toIso8601String();
      if (v is DateTime) return v.toIso8601String();
      if (v is FieldValue) return null; // FieldValue는 로컬 저장 불가
      if (v is Map) {
        return v.map((key, value) => MapEntry(key.toString(), sanitize(value)));
      }
      if (v is List) {
        return v.map((e) => sanitize(e)).toList();
      }
      return v;
    }

    final out = <String, dynamic>{};
    input.forEach((k, v) {
      final sv = sanitize(v);
      if (sv != null) out[k] = sv;
    });
    return out;
  }

  // 로컬에 백업 저장 (saveToCloud에서 세대 체크 후 호출됨)
  Future<void> _saveToLocalBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // lastSaved는 FieldValue라서 JSON 변환 불가 - 제거
      final dataToSave = Map<String, dynamic>.from(_cache);
      dataToSave.remove('lastSaved');
      dataToSave['localBackupTime'] = DateTime.now().toIso8601String();

      final jsonString = jsonEncode(_makeJsonSafe(dataToSave));
      await prefs.setString(_localBackupKey, jsonString);
      await prefs.setBool(_pendingSyncKey, true);
      _hasPendingSync = true;

      debugPrint('✅ 로컬 백업 저장 완료 (Firebase 복구 시 동기화 예정)');
    } catch (e) {
      debugPrint('❌ 로컬 백업 저장 실패: $e');
    }
  }

  // 로컬 백업에서 데이터 로드
  Future<Map<String, dynamic>?> _loadFromLocalBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_localBackupKey);

      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      debugPrint('✅ 로컬 백업 데이터 로드 완료');
      return data;
    } catch (e) {
      debugPrint('❌ 로컬 백업 로드 실패: $e');
      return null;
    }
  }

  // 보류 중인 동기화 플래그 해제
  Future<void> _clearPendingSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pendingSyncKey, false);
      await prefs.remove(_localBackupKey);
      _hasPendingSync = false;
      debugPrint('✅ 보류 동기화 플래그 해제');
    } catch (e) {
      debugPrint('❌ 보류 동기화 해제 실패: $e');
    }
  }

  // ✅ 보류 중인 로컬 데이터를 Firebase에 동기화
  Future<bool> syncPendingData() async {
    if (!_hasPendingSync) return true;

    debugPrint('🔄 보류 중인 데이터 동기화 시도...');

    try {
      // 로컬 백업 데이터 로드
      final localData = await _loadFromLocalBackup();
      if (localData == null) {
        await _clearPendingSync();
        return true;
      }

      // 현재 Firebase 데이터와 병합 (로컬이 더 최신이면 로컬 사용)
      final doc = _userDoc;
      if (doc == null) {
        debugPrint('⚠️ 로그인되지 않음 - 동기화 스킵');
        return false;
      }

      // 로컬 데이터를 캐시에 적용
      final localBackupTime = localData['localBackupTime'] as String?;
      if (localBackupTime != null) {
        localData.remove('localBackupTime');
      }

      // ownerId 추가
      final authUid = AuthService().uid;
      if (authUid != null) {
        localData['ownerId'] = authUid;
      }

      // Firebase에 저장 시도
      localData['lastSaved'] = FieldValue.serverTimestamp();
      localData.remove('friendIds');

      await doc.set(localData, SetOptions(merge: true));

      // 성공 시 캐시 업데이트 및 플래그 해제
      _cache = localData;
      await _clearPendingSync();

      debugPrint('✅ 보류 데이터 Firebase 동기화 완료!');
      return true;
    } catch (e) {
      debugPrint('❌ 보류 데이터 동기화 실패: $e');
      return false;
    }
  }

  // 🔥 디바운싱 변수
  DateTime? _lastSaveTime;
  bool _saveScheduled = false;

  // 🔥 저장 예약 (2초 후 저장)
  void _scheduleSave() async {
    if (_saveScheduled) return; // 이미 예약됨
    _saveScheduled = true;
    final gen = _sessionGeneration; // ✅ 현재 세대 기록

    await Future.delayed(const Duration(seconds: 2));

    // ✅ 세대가 바뀌었으면 로그아웃됨 → 저장 취소
    if (_saveScheduled && _sessionGeneration == gen) {
      _saveScheduled = false;
      _lastSaveTime = null; // 리셋해서 다음 저장 허용
      saveToCloud();
    }
  }

  // ✅ 기본 데이터
  Map<String, dynamic> _getDefaultData() {
    return {
      'nickname': '',
      'gold': AppConstants.startingGold,
      'diamond': AppConstants.startingDiamond,
      'enhanceStone': 0,
      'bossCore': 0,
      'maxInventory': AppConstants.startingInventory,
      'inventory': [],
      'equippedSwordUid': null,
      'equippedSwordId': null,
      'equippedSwordLevel': 1,
      'equippedSwordBreakthroughLevel': 0,
      'battleCount': AppConstants.dailyBattleCount,
      'battleRefillCount': 0,
      'battleWinStreak': 0,
      'maxWinStreak': 0,
      'lastBattleReset': null,
      'battleRecords': [],
      'bossCooldowns': {},
      'codex': [],
      'unlockedTitles': [],
      'equippedTitle': null,
      'unlockedAchievements': [],
      'claimedAchievements': [],
      'attendanceStreak': 0,
      'lastAttendance': null,
      'dailyQuests': [],
      'lastQuestReset': null,
      'seasonPassLevel': 1,
      'seasonPassExp': 0,
      'todaySeasonExp': 0, // ✅ 추가: 오늘 획득한 시즌패스 EXP
      'claimedSeasonRewards': [],
      'hasPremiumPass': false,
      'hasRemovedAds': false,
      'claimedPremiumRewards': [],
      'normalToRarePity': 0,
      'rareToUniquePity': 0,
      'uniqueToLegendPity': 0,
      // 통계
      'totalEnhanceAttempts': 0,
      'totalEnhanceSuccess': 0,
      'totalEnhanceFail': 0,
      'totalDestroy': 0,
      'maxConsecutiveSuccess': 0,
      'totalGacha': 0,
      'totalSynthesis': 0,
      'totalSell': 0,
      'totalBattle': 0,
      'totalBattleWin': 0,
      'bossKills': 0,
      'totalGoldEarned': 0,
      'totalDiamondEarned': 0,
      'totalQuestsCompleted': 0,
      'totalRevengeWins': 0,
      'totalStoneUsed': 0,
      // ✅ 광고 일일 횟수 (Firestore 동기화 — 재설치 악용 방지)
      'adDailyCounts': <String, dynamic>{},
      'adResetDate': null,

      // ✅ 공지 팝업 상태
      'ackNoticeIds': <String>[],
      'noticeLastPromptAt': <String, dynamic>{},
    };
  }

  // ============================================================
  // ✅ 캐시 헬퍼 메서드
  // ============================================================
  T _get<T>(String key, T defaultValue) {
    if (_cache.containsKey(key) && _cache[key] != null) {
      final value = _cache[key];
      // int 타입 변환 처리
      if (T == int && value is num) {
        return value.toInt() as T;
      }
      return value as T;
    }
    return defaultValue;
  }

  void _set(String key, dynamic value) {
    _cache[key] = value;
  }

  // ============================================================
  // ✅ 기본 데이터 Getter/Setter
  // ============================================================
  String? get playerId => _get<String?>('playerId', null);
  set playerId(String? value) => _set('playerId', value);

  String? get nickname => _get<String?>('nickname', null);
  set nickname(String? value) => _set('nickname', value);

  int get gold => _get<int>('gold', AppConstants.startingGold);
  set gold(int value) => _set('gold', value);

  int get diamond => _get<int>('diamond', AppConstants.startingDiamond);
  set diamond(int value) => _set('diamond', value);

  int get enhanceStone => _get<int>('enhanceStone', 0);
  set enhanceStone(int value) => _set('enhanceStone', value);

  int get bossCore => _get<int>('bossCore', 0);
  set bossCore(int value) => _set('bossCore', value);

  int get maxInventory =>
      _get<int>('maxInventory', AppConstants.startingInventory);
  set maxInventory(int value) => _set('maxInventory', value);

  String? get equippedSwordUid => _get<String?>('equippedSwordUid', null);
  set equippedSwordUid(String? value) => _set('equippedSwordUid', value);

  // 친구/랭킹용 검 정보
  String? get equippedSwordId => _get<String?>('equippedSwordId', null);
  set equippedSwordId(String? value) => _set('equippedSwordId', value);
  
  int get equippedSwordLevel => _get<int>('equippedSwordLevel', 1);
  set equippedSwordLevel(int value) => _set('equippedSwordLevel', value);

  int get equippedSwordBreakthroughLevel =>
      _get<int>('equippedSwordBreakthroughLevel', 0);
  set equippedSwordBreakthroughLevel(int value) =>
      _set('equippedSwordBreakthroughLevel', value);

  // ============================================================
  // ✅ 인벤토리
  // ============================================================
  List<OwnedSword> get inventory {
    try {
      final list = _get<List<dynamic>>('inventory', []);
      return list
          .map((e) => OwnedSword.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ 인벤토리 파싱 오류: $e');
      return [];
    }
  }

  set inventory(List<OwnedSword> value) {
    _set('inventory', value.map((e) => e.toJson()).toList());
  }

  // ============================================================
  // ✅ 배틀 관련
  // ============================================================
  int get battleCount =>
      _get<int>('battleCount', AppConstants.dailyBattleCount);
  set battleCount(int value) => _set('battleCount', value);

  int get battleRefillCount => _get<int>('battleRefillCount', 0);
  set battleRefillCount(int value) => _set('battleRefillCount', value);

  int get battleWinStreak => _get<int>('battleWinStreak', 0);
  set battleWinStreak(int value) => _set('battleWinStreak', value);

  int get maxWinStreak => _get<int>('maxWinStreak', 0);
  set maxWinStreak(int value) => _set('maxWinStreak', value);

  DateTime? get lastBattleReset {
    final value = _cache['lastBattleReset'];
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  set lastBattleReset(DateTime? value) {
    _set('lastBattleReset', value?.toIso8601String());
  }

  List<BattleRecord> get battleRecords {
    try {
      final list = _get<List<dynamic>>('battleRecords', []);
      return list
          .map((e) => BattleRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ 배틀 기록 파싱 오류: $e');
      return [];
    }
  }

  set battleRecords(List<BattleRecord> value) {
    _set('battleRecords', value.map((e) => e.toJson()).toList());
  }

  // ============================================================
  // ✅ 보스 쿨다운
  // ============================================================
  Map<String, DateTime> get bossCooldowns {
    try {
      final map = _get<Map<String, dynamic>>('bossCooldowns', {});
      return map.map((k, v) {
        if (v is Timestamp) return MapEntry(k, v.toDate());
        if (v is String) return MapEntry(k, DateTime.parse(v));
        return MapEntry(k, DateTime.now());
      });
    } catch (e) {
      debugPrint('❌ 보스 쿨다운 파싱 오류: $e');
      return {};
    }
  }

  set bossCooldowns(Map<String, DateTime> value) {
    _set(
      'bossCooldowns',
      value.map((k, v) => MapEntry(k, v.toIso8601String())),
    );
  }

  // ============================================================
  // ✅ 도감, 칭호, 업적
  // ============================================================
  Set<String> get codex {
    final list = _get<List<dynamic>>('codex', []);
    return list.map((e) => e.toString()).toSet();
  }

  set codex(Set<String> value) => _set('codex', value.toList());

  Set<String> get unlockedTitles {
    final list = _get<List<dynamic>>('unlockedTitles', []);
    return list.map((e) => e.toString()).toSet();
  }

  set unlockedTitles(Set<String> value) =>
      _set('unlockedTitles', value.toList());

  String? get equippedTitle => _get<String?>('equippedTitle', null);
  set equippedTitle(String? value) => _set('equippedTitle', value);

  Set<String> get unlockedAchievements {
    final list = _get<List<dynamic>>('unlockedAchievements', []);
    return list.map((e) => e.toString()).toSet();
  }

  set unlockedAchievements(Set<String> value) =>
      _set('unlockedAchievements', value.toList());

  Set<String> get claimedAchievements {
    final list = _get<List<dynamic>>('claimedAchievements', []);
    return list.map((e) => e.toString()).toSet();
  }

  set claimedAchievements(Set<String> value) =>
      _set('claimedAchievements', value.toList());

  // ============================================================
  // ✅ 출석
  // ============================================================
  int get attendanceStreak => _get<int>('attendanceStreak', 0);
  set attendanceStreak(int value) => _set('attendanceStreak', value);

  DateTime? get lastAttendance {
    final value = _cache['lastAttendance'];
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  set lastAttendance(DateTime? value) {
    _set('lastAttendance', value?.toIso8601String());
  }

  // ============================================================
  // ✅ 일일 퀘스트
  // ============================================================
  List<DailyQuest> get dailyQuests {
    try {
      final list = _get<List<dynamic>>('dailyQuests', []);
      return list
          .map((e) => DailyQuest.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ 일일 퀘스트 파싱 오류: $e');
      return [];
    }
  }

  set dailyQuests(List<DailyQuest> value) {
    _set('dailyQuests', value.map((e) => e.toJson()).toList());
  }

  DateTime? get lastQuestReset {
    final value = _cache['lastQuestReset'];
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  set lastQuestReset(DateTime? value) {
    _set('lastQuestReset', value?.toIso8601String());
  }

  // ============================================================
  // ✅ 시즌패스
  // ============================================================
  int get seasonPassLevel => _get<int>('seasonPassLevel', 1);
  set seasonPassLevel(int value) => _set('seasonPassLevel', value);

  int get seasonPassExp => _get<int>('seasonPassExp', 0);
  set seasonPassExp(int value) => _set('seasonPassExp', value);

  // ✅ 추가: 오늘 획득한 시즌패스 EXP
  int get todaySeasonExp => _get<int>('todaySeasonExp', 0);
  set todaySeasonExp(int value) => _set('todaySeasonExp', value);

  Set<int> get claimedSeasonRewards {
    final list = _get<List<dynamic>>('claimedSeasonRewards', []);
    return list.map((e) {
      if (e is int) return e;
      return int.tryParse(e.toString()) ?? 0;
    }).toSet();
  }

  set claimedSeasonRewards(Set<int> value) =>
      _set('claimedSeasonRewards', value.toList());

  bool get hasPremiumPass => _get<bool>('hasPremiumPass', false);
  set hasPremiumPass(bool value) => _set('hasPremiumPass', value);

  bool get hasRemovedAds => _get<bool>('hasRemovedAds', false);
  set hasRemovedAds(bool value) => _set('hasRemovedAds', value);

  Set<int> get claimedPremiumRewards {
    final list = _get<List<dynamic>>('claimedPremiumRewards', []);
    return list.map((e) {
      if (e is int) return e;
      return int.tryParse(e.toString()) ?? 0;
    }).toSet();
  }

  set claimedPremiumRewards(Set<int> value) =>
      _set('claimedPremiumRewards', value.toList());

  // ============================================================
  // ✅ 합성 천장
  // ============================================================
  int get normalToRarePity => _get<int>('normalToRarePity', 0);
  set normalToRarePity(int value) => _set('normalToRarePity', value);

  int get rareToUniquePity => _get<int>('rareToUniquePity', 0);
  set rareToUniquePity(int value) => _set('rareToUniquePity', value);

  int get uniqueToLegendPity => _get<int>('uniqueToLegendPity', 0);
  set uniqueToLegendPity(int value) => _set('uniqueToLegendPity', value);

  // ============================================================
  // ✅ 통계
  // ============================================================
  int get totalEnhanceAttempts => _get<int>('totalEnhanceAttempts', 0);
  set totalEnhanceAttempts(int value) => _set('totalEnhanceAttempts', value);

  int get totalEnhanceSuccess => _get<int>('totalEnhanceSuccess', 0);
  set totalEnhanceSuccess(int value) => _set('totalEnhanceSuccess', value);

  int get totalEnhanceFail => _get<int>('totalEnhanceFail', 0);
  set totalEnhanceFail(int value) => _set('totalEnhanceFail', value);

  int get totalDestroy => _get<int>('totalDestroy', 0);
  set totalDestroy(int value) => _set('totalDestroy', value);

  int get maxConsecutiveSuccess => _get<int>('maxConsecutiveSuccess', 0);
  set maxConsecutiveSuccess(int value) => _set('maxConsecutiveSuccess', value);

  int get totalGacha => _get<int>('totalGacha', 0);
  set totalGacha(int value) => _set('totalGacha', value);

  int get totalSynthesis => _get<int>('totalSynthesis', 0);
  set totalSynthesis(int value) => _set('totalSynthesis', value);

  int get totalSell => _get<int>('totalSell', 0);
  set totalSell(int value) => _set('totalSell', value);

  int get totalBattle => _get<int>('totalBattle', 0);
  set totalBattle(int value) => _set('totalBattle', value);

  int get totalBattleWin => _get<int>('totalBattleWin', 0);
  set totalBattleWin(int value) => _set('totalBattleWin', value);

  int get bossKills => _get<int>('bossKills', 0);
  set bossKills(int value) => _set('bossKills', value);

  int get totalGoldEarned => _get<int>('totalGoldEarned', 0);
  set totalGoldEarned(int value) => _set('totalGoldEarned', value);

  int get totalDiamondEarned => _get<int>('totalDiamondEarned', 0);
  set totalDiamondEarned(int value) => _set('totalDiamondEarned', value);

  int get totalQuestsCompleted => _get<int>('totalQuestsCompleted', 0);
  set totalQuestsCompleted(int value) => _set('totalQuestsCompleted', value);

  int get totalRevengeWins => _get<int>('totalRevengeWins', 0);
  set totalRevengeWins(int value) => _set('totalRevengeWins', value);

  int get totalStoneUsed => _get<int>('totalStoneUsed', 0);
  set totalStoneUsed(int value) => _set('totalStoneUsed', value);

  // ✅ 광고 일일 횟수 (Firestore 동기화)
  Map<String, int> get adDailyCounts {
    final data = _get<Map<String, dynamic>>('adDailyCounts', {});
    return data.map((k, v) => MapEntry(k, v is int ? v : 0));
  }

  set adDailyCounts(Map<String, int> value) =>
      _set('adDailyCounts', value.map((k, v) => MapEntry(k, v)));

  String? get adResetDate => _get<String?>('adResetDate', null);
  set adResetDate(String? value) => _set('adResetDate', value);

  // ============================================================
  // ✅ 공지 팝업 상태
  // ============================================================
  List<String> get ackNoticeIds {
    final list = _get<List<dynamic>>('ackNoticeIds', []);
    return list.map((e) => e.toString()).toList();
  }

  set ackNoticeIds(List<String> value) => _set('ackNoticeIds', value);

  Map<String, String> get noticeLastPromptAt {
    final data = _get<Map<String, dynamic>>('noticeLastPromptAt', {});
    return data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  set noticeLastPromptAt(Map<String, String> value) =>
      _set('noticeLastPromptAt', value.map((k, v) => MapEntry(k, v)));

  // ============================================================
  // ✅ 유틸리티
  // ============================================================

  // 현재 사용자 데이터 초기화
  Future<void> clearCurrentUser() async {
    try {
      final doc = _userDoc;
      if (doc == null) return;

      await doc.delete();
      _cache = _getDefaultData();
      debugPrint('✅ 사용자 데이터 초기화 완료');
    } catch (e) {
      debugPrint('❌ 데이터 초기화 실패: $e');
    }
  }

  // 모든 데이터 초기화 (캐시만)
  Future<void> clearAll() async {
    _cache = _getDefaultData();
  }

  // 안전한 저장
  Future<bool> saveAll({
    required int gold,
    required int diamond,
    required List<OwnedSword> inventory,
  }) async {
    try {
      _cache['gold'] = gold;
      _cache['diamond'] = diamond;
      _cache['inventory'] = inventory.map((e) => e.toJson()).toList();
      return await saveToCloud();
    } catch (e) {
      debugPrint('저장 실패: $e');
      return false;
    }
  }

  // 데이터 무결성 검사
  Future<bool> validateData() async {
    try {
      final inv = inventory;
      for (final sword in inv) {
        if (sword.uid.isEmpty || sword.data.id.isEmpty) {
          return false;
        }
      }

      if (gold < 0 || diamond < 0) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // 데이터 복구
  Future<void> repairData() async {
    if (gold < 0) gold = 0;
    if (diamond < 0) diamond = 0;
    if (enhanceStone < 0) enhanceStone = 0;

    final validInventory = inventory
        .where((s) => s.uid.isNotEmpty && s.data.id.isNotEmpty)
        .toList();
    inventory = validInventory;

    await saveToCloud();
  }

  // 오늘 날짜인지 확인
  bool isToday(DateTime? date) {
    if (date == null) return false;
    final now = serverNow; // ✅ 서버 시간 사용
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // 어제 날짜인지 확인
  bool isYesterday(DateTime? date) {
    if (date == null) return false;
    final yesterday = serverNow.subtract(const Duration(days: 1)); // ✅ 서버 시간 사용
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  // 디버깅용: 현재 사용자 정보 출력
  void debugUserInfo() {
    debugPrint('=== StorageService Debug (Firestore) ===');
    debugPrint('UID: ${_authService.uid}');
    debugPrint('로그인: ${_authService.isLoggedIn}');
    debugPrint('데이터 로드됨: $_isLoaded');
    debugPrint('Gold: $gold');
    debugPrint('Diamond: $diamond');
    debugPrint('인벤토리: ${inventory.length}개');
    debugPrint('========================================');
  }

  // ============================================================
  // ❌ 계정 삭제 관련 메서드
  // ============================================================

  /// Firestore에서 사용자 데이터 완전 삭제
  Future<void> deleteAllUserData(String uid) async {
    try {
      debugPrint('🗑️ Firestore 데이터 삭제 시작: $uid');

      // 사용자 문서 삭제
      await _firestore.collection('users').doc(uid).delete();
      debugPrint('   ✅ users 문서 삭제');

      // 온라인 플레이어 목록에서 삭제 (있다면)
      try {
        await _firestore.collection('online_players').doc(uid).delete();
        debugPrint('   ✅ online_players 문서 삭제');
      } catch (_) {}

      // 배틀 알림 삭제 (내가 보낸 것)
      try {
        final sentNotifications = await _firestore
            .collection('battle_notifications')
            .where('fromUserId', isEqualTo: uid)
            .get();
        for (final doc in sentNotifications.docs) {
          await doc.reference.delete();
        }
        debugPrint('   ✅ 보낸 배틀 알림 삭제: ${sentNotifications.docs.length}개');
      } catch (_) {}

      // 배틀 알림 삭제 (내가 받은 것)
      try {
        final receivedNotifications = await _firestore
            .collection('battle_notifications')
            .where('toUserId', isEqualTo: uid)
            .get();
        for (final doc in receivedNotifications.docs) {
          await doc.reference.delete();
        }
        debugPrint('   ✅ 받은 배틀 알림 삭제: ${receivedNotifications.docs.length}개');
      } catch (_) {}

      debugPrint('✅ Firestore 데이터 삭제 완료: $uid');
    } catch (e) {
      debugPrint('❌ Firestore 데이터 삭제 실패: $e');
      // 삭제 실패해도 계속 진행 (rethrow 제거)
    }
  }

  /// 로컬 캐시 및 데이터 초기화
  Future<void> clearAllData() async {
    _cache = {};
    _isLoaded = false;

    // ✅ 디바운싱 상태 초기화 (계정 전환 시 잔여 저장 방지)
    _lastSaveTime = null;
    _saveScheduled = false;

    debugPrint('✅ 로컬 캐시 초기화 완료');
  }

  /// ✅ 로그아웃 시 전체 초기화 (SharedPreferences 백업 포함!)
  Future<void> resetForLogout() async {
    // ✅ 세대 증가 → 이전 세션에서 진행 중인 모든 비동기 저장을 무효화!
    _sessionGeneration++;
    debugPrint('🔄 세션 세대 증가: $_sessionGeneration (이전 세션 저장 무효화)');

    // 1. 메모리 캐시 초기화
    _cache = {};
    _isLoaded = false;

    // 2. 디바운싱 상태 초기화
    _lastSaveTime = null;
    _saveScheduled = false;

    // 3. ✅ SharedPreferences 로컬 백업 완전 삭제 (핵심!)
    //    → 이전 계정의 백업 데이터가 다음 계정으로 누출되는 것 방지
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localBackupKey); // 'firebase_backup_data' 삭제
      await prefs.setBool(
        _pendingSyncKey,
        false,
      ); // 'firebase_pending_sync' = false
      _hasPendingSync = false;
      debugPrint('✅ 로그아웃: StorageService 전체 초기화 완료 (백업 데이터 삭제)');
    } catch (e) {
      debugPrint('❌ 로그아웃 초기화 실패: $e');
    }
  }
}
