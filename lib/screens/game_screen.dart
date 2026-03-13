import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math';
import '../enums/sword_grade.dart';
import '../enums/element.dart';
import '../enums/quest_type.dart';
import '../enums/skill_type.dart';
import '../enums/skill_effect.dart';
import '../models/sword_data.dart';
import '../models/owned_sword.dart';
import '../models/battle_record.dart';
import '../models/daily_quest.dart';
import '../models/boss_data.dart';
import '../models/title_data.dart';
import '../models/player_profile.dart';
import '../data/swords.dart';
import '../data/titles.dart';
import '../data/bosses.dart';
import '../data/npcs.dart';
import '../data/shop.dart';
import '../services/storage_service.dart';
import '../services/online_player_service.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';
import '../services/friend_service.dart'; // 👥 친구 서비스
import '../services/purchase_service.dart'; // 💰 인앱 결제
import '../services/remote_config_service.dart';
import '../services/event_log_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/battle_engine.dart';
import 'boss_raid_screen.dart';
import 'shop_screen.dart';
import 'battle_select_screen.dart';
import 'battle_arena_screen.dart';
import 'achievements_screen.dart';
import 'season_pass_screen.dart';
import 'friends_screen.dart'; // 👥 친구 화면
import '../models/achievement_data.dart';
import '../data/achievements.dart';
import '../data/season_pass_rewards.dart';
import '../widgets/dialogs/sword_detail_dialog.dart';
import '../widgets/dialogs/synthesis_dialog.dart';
import '../widgets/sword_image_widget.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart'; // 📊 Analytics
import 'tabs/home_tab.dart';
import 'tabs/inventory_tab.dart';
import 'tabs/enhance_tab.dart';
import 'tabs/battle_tab.dart';
import 'tabs/more_tab.dart';

// game_screen.dart
class GameScreen extends StatefulWidget {
  final String nickname;
  final String userId; // ✅ 추가

  const GameScreen({
    super.key,
    required this.nickname,
    required this.userId, // ✅ 추가
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _storage = StorageService();
  final _purchaseService = PurchaseService(); // 💰 시즌패스 인앱 결제용
  final _random = Random();

  // 현재 탭
  int _currentTab = 0;

  // 재화
  int _gold = 0;
  int _diamond = 0;
  int _enhanceStone = 0;
  int _bossCore = 0;

  // 인벤토리
  List<OwnedSword> _inventory = [];
  int _maxInventory = 10;
  OwnedSword? _equippedSword;

  // 배틀
  int _battleCount = 10;
  int _battleRefillCount = 0;
  int _battleWinStreak = 0;
  int _maxWinStreak = 0;
  List<BattleRecord> _battleRecords = [];

  // 보스 쿨다운
  Map<String, DateTime> _bossCooldowns = {};

  // 도감/칭호/업적
  Set<String> _codex = {};
  Set<String> _unlockedTitles = {'t_01'};
  String _equippedTitle = 't_01';
  Set<String> _unlockedAchievements = {};
  Set<String> _claimedAchievements = {};

  // 출석
  int _attendanceStreak = 0;
  DateTime? _lastAttendance;
  bool _canCheckAttendance = true;

  // 일일퀘스트
  List<DailyQuest> _dailyQuests = [];

  // 시즌패스
  int _seasonPassLevel = 1;
  int _seasonPassExp = 0;
  int _todaySeasonExp = 0; // ✅ 추가: 오늘 획득한 시즌패스 EXP
  static const int _maxDailySeasonExp = 300; // ✅ 추가: 하루 상한
  Set<int> _claimedSeasonRewards = {};
  bool _hasPremiumPass = false; // ✅ 추가
  Set<int> _claimedPremiumRewards = {}; // ✅ 추가

  // 합성 천장
  int _normalToRarePity = 0; // ✅ 노말→레어 천장 추가
  int _rareToUniquePity = 0;
  int _uniqueToLegendPity = 0;

  // 통계
  int _totalEnhanceAttempts = 0;
  int _totalEnhanceSuccess = 0;
  int _totalEnhanceFail = 0;
  int _totalDestroy = 0;
  int _consecutiveSuccess = 0;
  int _maxConsecutiveSuccess = 0;
  int _totalGacha = 0;
  int _totalSynthesis = 0;
  int _totalSell = 0;
  int _totalBattle = 0;
  int _totalBattleWin = 0;
  int _bossKills = 0;
  int _totalRevengeWins = 0;
  int _totalStoneUsed = 0;
  int _totalQuestsCompleted = 0; // ✅ 추가

  // 🔥 판매 이벤트 시스템
  int _currentSellEventIndex = 0; // 현재 이벤트 인덱스
  DateTime? _lastEventChange; // 마지막 이벤트 변경 시간

  // 판매 이벤트 목록 (이름, 배율, 색상, 이모지)
  static const List<Map<String, dynamic>> _sellEvents = [
    {'name': '일반', 'rate': 1.0, 'color': 0xFFFFFFFF, 'emoji': '💰'},
    {'name': '폭등', 'rate': 2.0, 'color': 0xFF4CAF50, 'emoji': '📈'},
    {'name': '대폭등', 'rate': 3.0, 'color': 0xFF00E676, 'emoji': '🚀'},
    {'name': '버블', 'rate': 4.0, 'color': 0xFFFFD700, 'emoji': '🫧'},
    {'name': '황금시대', 'rate': 5.0, 'color': 0xFFFF9800, 'emoji': '👑'},
    {'name': '폭락', 'rate': 0.5, 'color': 0xFFF44336, 'emoji': '📉'},
    {'name': '대폭락', 'rate': 0.3, 'color': 0xFFD32F2F, 'emoji': '💥'},
    {'name': '불경기', 'rate': 0.2, 'color': 0xFF9E9E9E, 'emoji': '😰'},
    {'name': '호황', 'rate': 2.5, 'color': 0xFF2196F3, 'emoji': '🎉'},
  ];

  // 랭킹
  List<Map<String, dynamic>> _rankings = [];
  List<Map<String, dynamic>> _battleRankings = [];
  int _myRank = 0;
  int _myBattleRank = 0;

  // UI 상태
  bool _useEnhanceStone = false;
  bool _showEnhanceEffect = false; // 🔥 강화 성공 애니메이션
  bool _isDestroyRecoveryInProgress = false;
  String? _notification;
  String? _notificationImage; // 알림에 표시할 에셋 이미지 경로

  // ✅ 데이터 로딩 완료 여부 (로드 완료 전 조작/저장으로 서버 덮어쓰기 방지)
  bool _dataReady = false;
  bool _deferredSaveAfterLoad = false;
  bool _snapshotLogged = false;

  // ✅ 로딩 타임아웃(10초) 및 재시도 UI
  Timer? _loadTimeoutTimer;
  bool _loadTimedOut = false;
  bool _loadingInProgress = false;
  int _loadGeneration = 0;

  // 친구 목록 (오프라인 모드에서는 빈 리스트)
  List<String> _friendIds = []; // ✅ 추가

  // ✅ 온라인 서비스 추가
  OnlinePlayerService? _onlineService;
  List<PlayerProfile> _onlineRankings = [];
  bool _isOnline = false;

  // ✅ 공지 팝업(세션 1회 체크)
  bool _noticeCheckedThisSession = false;
  final _remoteConfig = RemoteConfigService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 🔥 앱 라이프사이클 감지
    _loadGameData();
    _initOnlineService();
    _initPurchaseService(); // 💰 결제 서비스 초기화

    // 🎵 메인 BGM 재생
    SoundService().playMainBgm();
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this); // 🔥 옵저버 해제
    super.dispose();
  }

  // 🔥 앱 라이프사이클 변경 감지 - 백그라운드/종료 시 즉시 저장
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // 🔥 앱이 백그라운드로 가거나 종료될 때 즉시 저장 (force=true로 디바운싱 무시)
      debugPrint('📱 앱 상태 변경: $state - 데이터 저장 중...');

      // ✅ 로딩 중/로드 실패 상태에서 클라우드 저장을 하면 초기값이 서버를 덮어쓸 수 있어 차단
      if (_dataReady) {
        // 현재 UI 상태 → Storage 캐시에 먼저 반영 (클라우드 저장 전에 스냅샷 정합성 확보)
        _saveGameData(cloudSave: false);

        if (_storage.canSaveToCloudSafely) {
          _storage.saveToCloud(force: true);
        } else {
          // 클라우드 기준 데이터가 준비되지 않았으면 로컬 백업만 저장
          _storage.saveToLocalBackupNow();
        }
      } else {
        // 로딩 중에는 서버 덮어쓰기 위험 → 로컬만
        _storage.saveToLocalBackupNow();
      }

      // 🔇 백그라운드에서 BGM 일시정지
      SoundService().pauseBgm();
    } else if (state == AppLifecycleState.resumed) {
      // 🔊 포그라운드 복귀 시 BGM 재개
      debugPrint('📱 앱 복귀 - BGM 재개');
      SoundService().resumeBgm();
    }
  }

  // 💰 결제 서비스 초기화 (시즌패스 구매용)
  void _initPurchaseService() {
    _purchaseService.onPurchaseComplete = (result) {
      EventLogService().logPurchase(
        productId: result.productId,
        success: result.success,
        isPremiumPass: result.isPremiumPass,
        diamonds: result.diamonds,
        gold: result.gold,
        stones: result.stones,
      );
      if (result.success && result.isPremiumPass) {
        setState(() {
          _hasPremiumPass = true;
          _showNotification('👑 프리미엄 패스가 활성화되었습니다!');
          _saveGameData();
        });
      } else if (!result.success) {
        _showNotification('❌ ${result.errorMessage ?? "구매 실패"}');
      }
    };
    _purchaseService.onPurchaseError = (error) {
      _showNotification('❌ 결제 오류: $error');
    };
    _purchaseService.onPurchasePending = () {
      _showNotification('⏳ 결제 처리 중...');
    };
  }

  // ✅ 온라인 서비스 초기화
  Future<void> _initOnlineService() async {
    try {
      // ✅ Firebase Auth uid 직접 사용 (widget.userId 대신)
      final authUid = AuthService().uid;
      if (authUid == null || authUid.isEmpty) {
        debugPrint('❌ Firebase Auth uid가 없음 - 오프라인 모드');
        _isOnline = false;
        return;
      }

      _onlineService = OnlinePlayerService(myUserId: authUid);
      _isOnline = true;
      debugPrint('✅ 온라인 서비스 초기화: $authUid');

      await _syncMyProfile();
      await _fetchOnlineRankings();
      await _fetchBattleNotifications(); // 배틀 알림 수신
    } catch (e) {
      // Firebase 없으면 오프라인 모드
      _isOnline = false;
      debugPrint('오프라인 모드: $e');
    }
  }

  // ✅ 배틀 알림 수신 및 기록 추가
  Future<void> _fetchBattleNotifications() async {
    if (_onlineService == null) {
      debugPrint('❌ 배틀 알림 수신 실패: onlineService가 null');
      return;
    }

    try {
      debugPrint('🔄 배틀 알림 가져오기 시작...');
      final notifications = await _onlineService!.fetchBattleNotifications();
      debugPrint('📬 배틀 알림 ${notifications.length}개 수신됨');

      int addedCount = 0;
      for (final noti in notifications) {
        // 안전한 데이터 추출
        final fromUserId = (noti['fromUserId'] as String?) ?? '';
        final fromNickname = (noti['fromNickname'] as String?) ?? '알 수 없음';
        final fromLevel = (noti['fromLevel'] as int?) ?? 1;
        final fromGrade = (noti['fromGrade'] as String?) ?? 'normal';
        final fromElement = (noti['fromElement'] as String?) ?? 'fire';
        final toLevel = (noti['toLevel'] as int?) ?? 1;
        final toGrade = (noti['toGrade'] as String?) ?? 'normal';
        final toWon = (noti['toWon'] as bool?) ?? false;
        final timestamp = (noti['timestamp'] as DateTime?) ?? DateTime.now();

        debugPrint(
          '  - 알림: $fromNickname(Lv.$fromLevel) → 나, 내가 ${toWon ? "이김" : "짐"}',
        );

        if (fromUserId.isEmpty) {
          debugPrint('    ⚠️ fromUserId가 비어있어서 스킵');
          continue;
        }

        // ✅ 문서 ID로 중복 체크 (더 정확함)
        final notiId = noti['id'] as String?;
        final exists =
            notiId != null && _battleRecords.any((r) => r.uid == notiId);

        if (exists) {
          debugPrint('    ⚠️ 이미 존재하는 기록, 스킵');
          continue;
        }

        _battleRecords.insert(
          0,
          BattleRecord(
            uid: notiId ?? generateUid(), // 문서 ID를 uid로 사용
            opponentId: fromUserId,
            opponentName: fromNickname,
            myLevel: toLevel,
            opponentLevel: fromLevel,
            myGrade: toGrade,
            opponentGrade: fromGrade,
            opponentElement: fromElement,
            opponentIsNpc: false,
            isWin: toWon,
            timestamp: timestamp,
            goldEarned: 0,
            isRevengeable: !toWon,
            logs: [],
            isAttacker: false, // 내가 공격당함
          ),
        );
        addedCount++;
        debugPrint('    ✅ 배틀 기록 추가됨');
      }

      if (addedCount > 0) {
        // 시간순 정렬
        _battleRecords.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _saveGameData();

        if (mounted) {
          setState(() {}); // UI 갱신
          _showNotification('⚔️ $addedCount건의 배틀 기록이 도착했습니다!');
        }
      }
    } catch (e) {
      debugPrint('❌ 배틀 알림 수신 실패: $e');
    }
  }

  // ✅ 내 프로필 서버 동기화
  Future<void> _syncMyProfile() async {
    if (!_isOnline || _onlineService == null || _equippedSword == null) return;

    try {
      final profile = PlayerProfile(
        userId: widget.userId,
        nickname: widget.nickname,
        swordId: _equippedSword!.data.id,
        swordLevel: _equippedSword!.level,
        swordBreakthroughLevel: _equippedSword!.breakthroughLevel,
        titleId: _equippedTitle,
        updatedAt: DateTime.now(),
      );
      await _onlineService!.upsertMe(profile);
    } catch (e) {
      debugPrint('프로필 동기화 실패: $e');
    }
  }

  // ✅ 온라인 랭킹 가져오기
  Future<void> _fetchOnlineRankings({bool forceRefresh = false}) async {
    if (!_isOnline || _onlineService == null) return;

    try {
      _onlineRankings = await _onlineService!.fetchTopRankings(
        limit: 100,
        forceRefresh: forceRefresh,
      );
      _updateRankings(); // 로컬 랭킹과 병합
    } catch (e) {
      debugPrint('랭킹 조회 실패: $e');
    }
  }

  // 전투력 계산
  int get _totalPower {
    if (_equippedSword == null) return 0;
    final titleBonus = getTitleById(_equippedTitle).bonus;
    return _equippedSword!.totalPower + titleBonus;
  }

  // ===== 데이터 로드/저장 =====
  Future<void> _loadGameData() async {
    // 중복 호출 방지 (단, 타임아웃 이후에는 재시도 허용)
    if (_loadingInProgress && !_loadTimedOut) return;

    final int gen = ++_loadGeneration;
    _loadingInProgress = true;

    if (mounted) {
      setState(() {
        _dataReady = false;
        _loadTimedOut = false;
      });
    }

    // ✅ 10초 타임아웃: 로드가 오래 걸리면 재시도 버튼 노출
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      // 현재 로드 세대(gen)에서만 타임아웃 표시
      if (gen == _loadGeneration && !_dataReady) {
        setState(() {
          _loadTimedOut = true;
        });
      }
    });

    try {
      try {
        await _storage.init();

        // ✅ 유저별 광고 시청 횟수 로드
        await AdService().loadForCurrentUser();

        // 친구 목록은 초기 화면 렌더 후 백그라운드 로드
        unawaited(_loadFriendIdsInBackground(gen));
      } catch (e) {
        // StorageService init 자체가 실패해도 앱은 오프라인 모드로 진행 가능
        debugPrint('❌ 게임 데이터 초기화 실패(오프라인 모드로 진행): $e');
      }

      if (!mounted || gen != _loadGeneration) return;

      setState(() {
        _gold = _storage.gold;
        _diamond = _storage.diamond;
        _enhanceStone = _storage.enhanceStone;
        _bossCore = _storage.bossCore;
        _inventory = _storage.inventory;
        _maxInventory = _storage.maxInventory;
        _battleCount = _storage.battleCount;
        _battleRefillCount = _storage.battleRefillCount;
        _battleWinStreak = _storage.battleWinStreak;
        _maxWinStreak = _storage.maxWinStreak;
        _battleRecords = _storage.battleRecords;
        _bossCooldowns = _storage.bossCooldowns;
        _codex = _storage.codex;
        _unlockedTitles = _storage.unlockedTitles;
        _equippedTitle = _storage.equippedTitle ?? 't_01'; // ✅ 기본값 추가
        _unlockedAchievements = _storage.unlockedAchievements;
        _claimedAchievements = _storage.claimedAchievements;
        _attendanceStreak = _storage.attendanceStreak;
        _lastAttendance = _storage.lastAttendance;
        _seasonPassLevel = _storage.seasonPassLevel;
        _seasonPassExp = _storage.seasonPassExp;
        _todaySeasonExp = _storage.todaySeasonExp; // ✅ 추가
        _claimedSeasonRewards = _storage.claimedSeasonRewards;
        _hasPremiumPass = _storage.hasPremiumPass; // ✅ 추가
        _claimedPremiumRewards = _storage.claimedPremiumRewards; // ✅ 추가
        _normalToRarePity = _storage.normalToRarePity; // ✅ 노말→레어 천장
        _rareToUniquePity = _storage.rareToUniquePity;
        _uniqueToLegendPity = _storage.uniqueToLegendPity;

        // 통계
        _totalEnhanceAttempts = _storage.totalEnhanceAttempts;
        _totalEnhanceSuccess = _storage.totalEnhanceSuccess;
        _totalEnhanceFail = _storage.totalEnhanceFail;
        _totalDestroy = _storage.totalDestroy;
        _maxConsecutiveSuccess = _storage.maxConsecutiveSuccess;
        _totalGacha = _storage.totalGacha;
        _totalSynthesis = _storage.totalSynthesis;
        _totalSell = _storage.totalSell;
        _totalBattle = _storage.totalBattle;
        _totalBattleWin = _storage.totalBattleWin;
        _bossKills = _storage.bossKills;
        _totalRevengeWins = _storage.totalRevengeWins;
        _totalStoneUsed = _storage.totalStoneUsed;
        _totalQuestsCompleted = _storage.totalQuestsCompleted;

        // ✅ 신규 유저면 시작 검 지급
        if (_inventory.isEmpty) {
          _giveStarterSword();
        }

        // 장착 검 복원
        final equippedUid = _storage.equippedSwordUid;
        if (equippedUid != null) {
          _equippedSword = _inventory
              .where((s) => s.uid == equippedUid)
              .firstOrNull;
        }

        // 출석 체크 가능 여부
        _canCheckAttendance = !_storage.isToday(_lastAttendance);

        // ✅ 일일 퀘스트 로드
        final savedQuests = _storage.dailyQuests;
        if (savedQuests.isNotEmpty) {
          _dailyQuests = savedQuests;
        }

        // 일일 리셋 체크
        _checkDailyReset();

        // ✅ 로드 완료: UI 조작 허용
        _dataReady = true;
        _loadTimedOut = false;
      });

      // 로드 완료 후 초기화 로직
      _initDailyQuests();
      _updateRankings();
      _logLoginSnapshotOnce();
      _scheduleNoticeCheckAfterLoad();

      // 로딩 중 발생한 저장 요청이 있으면, 로드 완료 후 1회만 저장
      if (_deferredSaveAfterLoad) {
        _deferredSaveAfterLoad = false;
        _saveGameData();
      }
    } finally {
      // 최신 로드 세대에서만 상태 정리
      if (gen == _loadGeneration) {
        _loadTimeoutTimer?.cancel();
        _loadingInProgress = false;
      }
    }
  }

  Future<void> _loadFriendIdsInBackground(int gen) async {
    try {
      final friendService = FriendService();
      final ids = await friendService.getFriendIds();
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _friendIds = ids;
      });
    } catch (e) {
      debugPrint('⚠️ 친구 목록 로드 실패: $e');
    }
  }

  // ✅ 시작 검 지급
  void _giveStarterSword() {
    // 일반 등급 중 랜덤 검 지급
    final normalSwords = getSwordsByGrade(SwordGrade.normal);
    final starterSword = normalSwords[Random().nextInt(normalSwords.length)];
    final newSword = createNewSword(starterSword);

    _inventory.add(newSword);
    _equippedSword = newSword;
    _codex.add(starterSword.id);

    // 저장
    _storage.inventory = _inventory;
    _storage.equippedSwordUid = newSword.uid;
    _storage.codex = _codex;

    // 알림은 UI가 빌드된 후에
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNotification('🎁 시작 검 지급: ${starterSword.name}');
    });
  }

  Future<void> _logLoginSnapshotOnce() async {
    if (_snapshotLogged || !_dataReady) return;
    if (!AuthService().isLoggedIn) return;

    _snapshotLogged = true;

    final bestGrade = _getBestSwordGradeName();

    await EventLogService().logSnapshot(
      gold: _gold,
      diamond: _diamond,
      seasonPassLevel: _seasonPassLevel,
      ownedSwordCount: _inventory.length,
      bestSwordGrade: bestGrade,
      totalEnhanceAttempts: _totalEnhanceAttempts,
      totalEnhanceSuccess: _totalEnhanceSuccess,
      totalDestroy: _totalDestroy,
      achievementCount: _unlockedAchievements.length,
    );
  }

  String _getBestSwordGradeName() {
    if (_inventory.isEmpty) return 'none';
    SwordGrade best = _inventory.first.data.grade;
    for (final sword in _inventory) {
      if (sword.data.grade.index > best.index) {
        best = sword.data.grade;
      }
    }
    return best.name;
  }

  void _saveGameData({bool cloudSave = true}) {
    // ✅ 데이터 로딩 완료 전 저장은 서버 덮어쓰기 위험 → 로드 완료 후로 지연
    if (!_dataReady) {
      _deferredSaveAfterLoad = true;
      debugPrint('⏳ 데이터 로딩 중 저장 요청 - 로드 완료 후 저장 예정');
      return;
    }

    _storage.nickname = widget.nickname; // 🔥 닉네임 저장 추가
    _storage.gold = _gold;
    _storage.diamond = _diamond;
    _storage.enhanceStone = _enhanceStone;
    _storage.bossCore = _bossCore;
    _storage.inventory = _inventory;
    _storage.maxInventory = _maxInventory;
    _storage.equippedSwordUid = _equippedSword?.uid;
    _storage.equippedSwordId = _equippedSword?.data.id; // 친구/랭킹용
    _storage.equippedSwordLevel = _equippedSword?.level ?? 1; // 친구/랭킹용
    _storage.equippedSwordBreakthroughLevel =
        _equippedSword?.breakthroughLevel ?? 0;
    _storage.battleCount = _battleCount;
    _storage.battleRefillCount = _battleRefillCount;
    _storage.battleWinStreak = _battleWinStreak;
    _storage.maxWinStreak = _maxWinStreak;
    _storage.battleRecords = _battleRecords;
    _storage.bossCooldowns = _bossCooldowns;
    _storage.codex = _codex;
    _storage.unlockedTitles = _unlockedTitles;
    _storage.equippedTitle = _equippedTitle;
    _storage.unlockedAchievements = _unlockedAchievements;
    _storage.claimedAchievements = _claimedAchievements;
    _storage.attendanceStreak = _attendanceStreak;
    _storage.lastAttendance = _lastAttendance;
    _storage.seasonPassLevel = _seasonPassLevel;
    _storage.seasonPassExp = _seasonPassExp;
    _storage.todaySeasonExp = _todaySeasonExp; // ✅ 추가
    _storage.claimedSeasonRewards = _claimedSeasonRewards;
    _storage.hasPremiumPass = _hasPremiumPass; // ✅ 추가
    _storage.claimedPremiumRewards = _claimedPremiumRewards; // ✅ 추가
    _storage.normalToRarePity = _normalToRarePity; // ✅ 노말→레어 천장
    _storage.rareToUniquePity = _rareToUniquePity;
    _storage.uniqueToLegendPity = _uniqueToLegendPity;

    // 통계
    _storage.totalEnhanceAttempts = _totalEnhanceAttempts;
    _storage.totalEnhanceSuccess = _totalEnhanceSuccess;
    _storage.totalEnhanceFail = _totalEnhanceFail;
    _storage.totalDestroy = _totalDestroy;
    _storage.maxConsecutiveSuccess = _maxConsecutiveSuccess;
    _storage.totalGacha = _totalGacha;
    _storage.totalSynthesis = _totalSynthesis;
    _storage.totalSell = _totalSell;
    _storage.totalBattle = _totalBattle;
    _storage.totalBattleWin = _totalBattleWin;
    _storage.bossKills = _bossKills;
    _storage.totalRevengeWins = _totalRevengeWins;
    _storage.totalStoneUsed = _totalStoneUsed;
    _storage.totalQuestsCompleted = _totalQuestsCompleted;

    // ✅ 일일 퀘스트 저장
    _storage.dailyQuests = _dailyQuests;

    // 🔥 Firestore에 저장 (비동기) - 로그아웃 시에는 스킵
    if (cloudSave) {
      _storage.saveToCloud();
    }

    // 🔥 프로필 동기화는 장비/칭호 변경 시에만 호출 (Firebase 비용 절감)
    // _syncMyProfile() 제거 - 대신 _equipSword(), _setTitle() 등에서 직접 호출
  }

  // _checkDailyReset()에 추가
  void _checkDailyReset() {
    final lastReset = _storage.lastBattleReset;
    if (lastReset == null || !_storage.isToday(lastReset)) {
      setState(() {
        _battleCount = AppConstants.dailyBattleCount;
        _battleRefillCount = 0;
        _todaySeasonExp = 0; // ✅ 추가: 시즌패스 일일 EXP 초기화
        _storage.battleCount = _battleCount;
        _storage.battleRefillCount = _battleRefillCount;
        _storage.todaySeasonExp = 0; // ✅ 추가
        _storage.lastBattleReset = _storage.serverNow; // ✅ 서버 시간

        // ✅ 퀘스트 리셋
        final lastQuestReset = _storage.lastQuestReset;
        if (lastQuestReset == null || !_storage.isToday(lastQuestReset)) {
          _resetDailyQuests();
          _storage.lastQuestReset = _storage.serverNow; // ✅ 서버 시간
        }
      });
    }
  }

  // ✅ 일일 퀘스트 초기화 (새 퀘스트 생성)
  // _initDailyQuests 수정 - 저장된 데이터 로드
  void _initDailyQuests() {
    // ✅ 저장된 퀘스트 로드 시도
    final savedQuests = _storage.dailyQuests;

    if (savedQuests.isNotEmpty && _isQuestsFromToday()) {
      _dailyQuests = savedQuests;
      return;
    }

    // ✅ 새 퀘스트 생성
    _dailyQuests = [
      DailyQuest(
        id: 'dq_enhance',
        name: '강화 5회',
        description: '강화를 5회 시도하세요',
        type: QuestType.enhance,
        target: 5,
        rewardGold: 500,
        rewardSeasonExp: 15,
      ),
      DailyQuest(
        id: 'dq_battle',
        name: '배틀 3회',
        description: '배틀을 3회 진행하세요',
        type: QuestType.battle,
        target: 3,
        rewardGold: 500,
        rewardSeasonExp: 15,
      ),
      DailyQuest(
        id: 'dq_boss',
        name: '보스 처치 1회',
        description: '보스를 1회 처치하세요',
        type: QuestType.boss,
        target: 1,
        rewardGold: 300,
        rewardDiamond: 10,
        rewardSeasonExp: 20,
      ),
      DailyQuest(
        id: 'dq_gacha',
        name: '뽑기 3회',
        description: '검을 3회 뽑으세요',
        type: QuestType.gacha,
        target: 3,
        rewardGold: 500,
        rewardSeasonExp: 15,
      ),
      DailyQuest(
        id: 'dq_sell',
        name: '판매 2회',
        description: '검을 2개 판매하세요',
        type: QuestType.sell,
        target: 2,
        rewardGold: 300,
        rewardStone: 5,
        rewardSeasonExp: 10,
      ),
      DailyQuest(
        id: 'dq_login',
        name: '오늘의 접속',
        description: '게임에 접속하세요',
        type: QuestType.login,
        target: 1,
        rewardGold: 500,
        rewardSeasonExp: 10,
        progress: 1, // 접속 즉시 완료
      ),
    ];

    _storage.dailyQuests = _dailyQuests;
    _storage.lastQuestReset = _storage.serverNow; // ✅ 서버 시간
  }

  bool _isQuestsFromToday() {
    final lastReset = _storage.lastQuestReset;
    return lastReset != null && _storage.isToday(lastReset);
  }

  // ✅ 퀘스트 리셋 함수 (분리)
  void _resetDailyQuests() {
    _dailyQuests = [
      DailyQuest(
        id: 'dq_enhance',
        name: '강화 5회',
        description: '강화를 5회 시도하세요',
        type: QuestType.enhance,
        target: 5,
        rewardGold: 500,
      ),
      DailyQuest(
        id: 'dq_battle',
        name: '배틀 3회',
        description: '배틀을 3회 진행하세요',
        type: QuestType.battle,
        target: 3,
        rewardGold: 500,
      ),
      DailyQuest(
        id: 'dq_boss',
        name: '보스 처치 1회',
        description: '보스를 1회 처치하세요',
        type: QuestType.boss,
        target: 1,
        rewardGold: 500,
      ),
      DailyQuest(
        id: 'dq_gacha',
        name: '뽑기 3회',
        description: '검을 3회 뽑으세요',
        type: QuestType.gacha,
        target: 3,
        rewardGold: 500,
      ),
      DailyQuest(
        id: 'dq_sell',
        name: '판매 2회',
        description: '검을 2개 판매하세요',
        type: QuestType.sell,
        target: 2,
        rewardGold: 500,
      ),
      DailyQuest(
        id: 'dq_login',
        name: '접속',
        description: '게임에 접속하세요',
        type: QuestType.login,
        target: 1,
        rewardGold: 500,
        progress: 1,
      ),
    ];
    _storage.dailyQuests = _dailyQuests;
  }

  void _updateRankings() {
    _rankings = [];

    // ✅ 온라인 플레이어 추가 (있다면)
    for (final player in _onlineRankings) {
      // 이미 추가된 유저인지 체크 (중복 방지)
      final alreadyExists = _rankings.any((r) => r['id'] == player.userId);
      if (alreadyExists) continue;

      final isSelf = player.userId == widget.userId && _equippedSword != null;
      _rankings.add({
        'id': player.userId,
        'name': player.nickname,
        'power': isSelf ? _totalPower : player.powerWithTitle,
        'swordGrade': isSelf ? _equippedSword!.data.grade : player.grade,
        'swordName': isSelf ? _equippedSword!.data.name : player.sword.name,
        'swordId': isSelf
            ? _equippedSword!.data.id
            : player.swordId, // ✅ 검 ID 추가
        'swordLevel': isSelf ? _equippedSword!.level : player.swordLevel,
        'swordBreakthroughLevel': isSelf
            ? _equippedSword!.breakthroughLevel
            : player.swordBreakthroughLevel,
        'element': isSelf ? _equippedSword!.data.element : player.element,
        'totalBattle': isSelf ? _totalBattle : player.totalBattle,
        'totalBattleWin': isSelf ? _totalBattleWin : player.totalBattleWin,
        'isNpc': false,
        'isOnline': true,
      });
    }

    // ✅ v10.4: 검레벨 > 검전투력 > 검등급 순 정렬
    _rankings.sort((a, b) {
      final levelCmp = (b['swordLevel'] as int).compareTo(
        a['swordLevel'] as int,
      );
      if (levelCmp != 0) return levelCmp;
      final powerCmp = (b['power'] as int).compareTo(a['power'] as int);
      if (powerCmp != 0) return powerCmp;
      return (b['swordGrade'] as SwordGrade).index.compareTo(
        (a['swordGrade'] as SwordGrade).index,
      );
    });

    // 내 순위 찾기 (온라인 랭킹 기준)
    _myRank = _rankings.indexWhere((r) => r['id'] == widget.userId) + 1;

    // 전적 랭킹 (승수 > 승률 > 총 배틀 > 전투력)
    _battleRankings = List<Map<String, dynamic>>.from(_rankings);
    _battleRankings.sort((a, b) {
      final aWin = a['totalBattleWin'] as int? ?? 0;
      final bWin = b['totalBattleWin'] as int? ?? 0;
      final winCmp = bWin.compareTo(aWin);
      if (winCmp != 0) return winCmp;

      final aTotal = a['totalBattle'] as int? ?? 0;
      final bTotal = b['totalBattle'] as int? ?? 0;
      final aRate = aTotal > 0 ? aWin / aTotal : 0.0;
      final bRate = bTotal > 0 ? bWin / bTotal : 0.0;
      final rateCmp = bRate.compareTo(aRate);
      if (rateCmp != 0) return rateCmp;

      final totalCmp = bTotal.compareTo(aTotal);
      if (totalCmp != 0) return totalCmp;

      return (b['power'] as int).compareTo(a['power'] as int);
    });
    _myBattleRank =
        _battleRankings.indexWhere((r) => r['id'] == widget.userId) + 1;
  }

  void _showNotification(String message) {
    setState(() {
      _notification = message;
      _notificationImage = null;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _notification = null);
    });
  }

  void _scheduleNoticeCheckAfterLoad() {
    if (!_dataReady || _noticeCheckedThisSession) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshAndCheckNoticeIfNeeded());
    });
  }

  Future<void> _refreshAndCheckNoticeIfNeeded() async {
    await _remoteConfig.refresh();
    if (!mounted) return;
    _checkAndShowNoticeIfNeeded();
  }

  void _checkAndShowNoticeIfNeeded() {
    if (!mounted || _noticeCheckedThisSession) return;
    _noticeCheckedThisSession = true;

    final noticeActive = _remoteConfig.noticeActive;
    final noticeId = _remoteConfig.noticeId.trim();
    final rawTitle = _remoteConfig.noticeTitle.trim();
    final noticeTitle = rawTitle.isEmpty ? '업데이트 안내' : rawTitle;
    final noticeBody = _remoteConfig.noticeBody.trim().replaceAll('\\n', '\n');
    final remindHours = _remoteConfig.noticeRemindHours;

    if (!noticeActive || noticeId.isEmpty || noticeBody.isEmpty) return;

    final ackIds = _storage.ackNoticeIds;
    if (ackIds.contains(noticeId)) return;

    final promptMap = _storage.noticeLastPromptAt;
    final lastPromptStr = promptMap[noticeId];
    final lastPrompt = lastPromptStr != null && lastPromptStr.isNotEmpty
        ? DateTime.tryParse(lastPromptStr)
        : null;
    final now = _storage.serverNow;

    if (lastPrompt != null &&
        now.difference(lastPrompt) < Duration(hours: remindHours)) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: Text(
          '📢 $noticeTitle',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          noticeBody,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final map = _storage.noticeLastPromptAt;
              map[noticeId] = _storage.serverNow.toIso8601String();
              _storage.noticeLastPromptAt = map;
              _saveGameData();
              Navigator.pop(context);
            },
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () {
              final ack = _storage.ackNoticeIds;
              if (!ack.contains(noticeId)) {
                ack.add(noticeId);
                _storage.ackNoticeIds = ack;
              }
              final map = _storage.noticeLastPromptAt;
              map[noticeId] = _storage.serverNow.toIso8601String();
              _storage.noticeLastPromptAt = map;
              _saveGameData();
              Navigator.pop(context);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showAchievementNoticeDialog({required String kind}) {
    if (!mounted) return;
    final title = kind == 'achievement' ? '업적 달성' : '칭호 획득';
    final message = kind == 'achievement' ? '업적란을 확인해주세요.' : '칭호란을 확인해주세요.';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showImageNotification(String message, String assetPath) {
    setState(() {
      _notification = message;
      _notificationImage = assetPath;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted)
        setState(() {
          _notification = null;
          _notificationImage = null;
        });
    });
  }

  // ✅ 전설/불멸 획득 축하 다이얼로그
  void _showCongratulationDialog(OwnedSword sword) {
    final grade = sword.data.grade;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [grade.color.withOpacity(0.9), const Color(0xFF1a1a2e)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: grade.color, width: 3),
            boxShadow: [
              BoxShadow(
                color: grade.color.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 축하 텍스트
              const Text(
                '🎊 축하합니다! 🎊',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${grade.displayName} 등급 획득!',
                style: TextStyle(
                  color: grade.color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // 검 이미지 (SwordImageWidget)
              SwordImageWidget(
                grade: grade,
                element: sword.data.element,
                level: sword.level,
                breakthroughLevel: sword.breakthroughLevel,
                size: 120,
                showPulse: true,
              ),
              const SizedBox(height: 16),

              // 검 이름
              Text(
                sword.data.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // 전투력
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flash_on, color: Colors.amber, size: 20),
                  Text(
                    ' 전투력: ${sword.totalPower}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 확인 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: grade.color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addSeasonPassExp(int exp) {
    // ✅ 하루 상한 체크
    if (_todaySeasonExp >= _maxDailySeasonExp) {
      // 이미 상한 도달 - 추가 EXP 없음
      return;
    }

    // ✅ 상한 초과 시 잘라내기
    final actualExp = (_todaySeasonExp + exp > _maxDailySeasonExp)
        ? _maxDailySeasonExp - _todaySeasonExp
        : exp;

    if (actualExp <= 0) return;

    _todaySeasonExp += actualExp; // ✅ 오늘 획득량 기록

    final prevLevel = _seasonPassLevel;
    _seasonPassExp += actualExp;

    while (_seasonPassExp >= _seasonPassLevel * AppConstants.expPerLevel &&
        _seasonPassLevel < AppConstants.maxSeasonPassLevel) {
      _seasonPassExp -= _seasonPassLevel * AppConstants.expPerLevel;
      _seasonPassLevel++;
    }

    // ✅ 레벨업 시 알림
    if (_seasonPassLevel > prevLevel) {
      if (_seasonPassLevel >= AppConstants.maxSeasonPassLevel) {
        _showNotification('🎉 시즌패스 최대 레벨 달성! Lv.$_seasonPassLevel');
      } else {
        _showNotification('🎟️ 시즌패스 레벨 업! Lv.$_seasonPassLevel');
      }
    }

    // ✅ 상한 도달 알림 (최초 1회)
    if (_todaySeasonExp >= _maxDailySeasonExp &&
        _todaySeasonExp - actualExp < _maxDailySeasonExp) {
      _showNotification('📌 오늘의 시즌패스 EXP 상한(${_maxDailySeasonExp}) 도달!');
    }

    // 🔥 저장 제거 - 호출한 액션에서 이미 저장함 (Firebase 비용 절감)
  }

  int _getSwordMaxEnhanceLevel(OwnedSword sword) {
    return AppConstants.maxEnhanceLevel +
        (sword.breakthroughLevel * AppConstants.breakthroughLevelStep);
  }

  int _getBreakthroughCoreCost(int breakthroughLevel) {
    const costs = [10, 25, 50];
    if (breakthroughLevel < 0 || breakthroughLevel >= costs.length) {
      return costs.last;
    }
    return costs[breakthroughLevel];
  }

  int _getBreakthroughGoldCost(int breakthroughLevel) {
    const costs = [10000000, 50000000, 1000000000];
    if (breakthroughLevel < 0 || breakthroughLevel >= costs.length) {
      return costs.last;
    }
    return costs[breakthroughLevel];
  }

  List<OwnedSword> _getEligibleBreakthroughMaterials(OwnedSword targetSword) {
    return _inventory.where((sword) {
      if (sword.uid == targetSword.uid) return false;
      if (_equippedSword?.uid == sword.uid) return false;
      if (sword.data.grade != targetSword.data.grade) return false;
      return sword.level >= 20;
    }).toList();
  }

  void _showBreakthroughDialog() {
    final sword = _equippedSword;
    if (sword == null) {
      _showNotification('장착된 검이 없습니다');
      return;
    }

    if (sword.breakthroughLevel >= AppConstants.maxBreakthroughLevel) {
      _showNotification('최대 돌파 단계입니다');
      return;
    }

    final requiredLevel = _getSwordMaxEnhanceLevel(sword);
    if (sword.level < requiredLevel) {
      _showNotification('+${requiredLevel} 달성 후 돌파할 수 있습니다');
      return;
    }

    final materials = _getEligibleBreakthroughMaterials(sword);
    final coreCost = _getBreakthroughCoreCost(sword.breakthroughLevel);
    final goldCost = _getBreakthroughGoldCost(sword.breakthroughLevel);
    final nextMaxLevel = requiredLevel + AppConstants.breakthroughLevelStep;
    final hasEnoughGold = _gold >= goldCost;
    final hasEnoughCore = _bossCore >= coreCost;
    OwnedSword? selectedMaterial = materials.isNotEmpty
        ? materials.first
        : null;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a4a),
          title: const Text('🧿 돌파', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.68,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${sword.data.name} +${sword.level}',
                      style: TextStyle(
                        color: sword.data.grade.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '돌파 ${sword.breakthroughLevel} → ${sword.breakthroughLevel + 1}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '최대 강화: +$requiredLevel → +$nextMaxLevel',
                      style: const TextStyle(color: Colors.amber),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '필요 재료: 동일 등급 20강 이상 검 1개',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '필요 재화: ${formatNumber(goldCost)}G, 보스코어 $coreCost개',
                      style: const TextStyle(
                        color: Color(0xFF80DEEA),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '보유 골드: ${formatNumber(_gold)}G',
                            style: TextStyle(
                              color: hasEnoughGold
                                  ? Colors.amber
                                  : Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '보유 보스코어: $_bossCore',
                            style: TextStyle(
                              color: hasEnoughCore
                                  ? const Color(0xFF80DEEA)
                                  : Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!hasEnoughGold)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                '골드가 부족합니다.',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (!hasEnoughCore)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                '보스코어가 부족합니다.',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (materials.isEmpty)
                      const Text(
                        '사용 가능한 재료 검이 없습니다.',
                        style: TextStyle(color: Colors.redAccent),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '재료 검 선택',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 180),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: materials.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final material = materials[index];
                                final isSelected =
                                    selectedMaterial?.uid == material.uid;
                                return InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedMaterial = material;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? material.data.grade.color
                                                .withOpacity(0.16)
                                          : Colors.white.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? material.data.grade.color
                                            : Colors.white.withOpacity(0.08),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SwordImageWidget(
                                          grade: material.data.grade,
                                          element: material.data.element,
                                          level: material.level,
                                          breakthroughLevel:
                                              material.breakthroughLevel,
                                          size: 40,
                                          showPulse: false,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                material.data.name,
                                                style: TextStyle(
                                                  color:
                                                      material.data.grade.color,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '+${material.level}  ⚡ ${material.totalPower}',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            color: Color(0xFF80DEEA),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (selectedMaterial != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: selectedMaterial!.data.grade.color
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedMaterial!.data.grade.color
                                      .withOpacity(0.35),
                                ),
                              ),
                              child: Text(
                                '선택 재료: ${selectedMaterial!.data.name} +${selectedMaterial!.level}'
                                ' / 전투력 ${selectedMaterial!.totalPower}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed:
                  selectedMaterial == null ||
                      _gold < goldCost ||
                      _bossCore < coreCost
                  ? null
                  : () {
                      setState(() {
                        _gold -= goldCost;
                        _bossCore -= coreCost;
                        _inventory.removeWhere(
                          (item) => item.uid == selectedMaterial!.uid,
                        );
                        sword.breakthroughLevel++;
                        _saveGameData();
                        _showNotification(
                          '🧿 돌파 성공! 최대 강화가 +${_getSwordMaxEnhanceLevel(sword)}로 증가했습니다',
                        );
                      });
                      Navigator.pop(dialogContext);
                    },
              child: const Text('돌파'),
            ),
          ],
        ),
      ),
    );
  }

  // _updateQuestProgress 수정
  void _updateQuestProgress(QuestType type, [int amount = 1]) {
    bool updated = false;

    for (final quest in _dailyQuests) {
      if (quest.type == type && !quest.claimed) {
        final newProgress = (quest.progress + amount).clamp(0, quest.target);
        if (newProgress != quest.progress) {
          quest.progress = newProgress;
          updated = true;

          // ✅ 완료 시 알림
          if (quest.isCompleted && quest.progress == quest.target) {
            _showNotification('🎯 퀘스트 완료: ${quest.name}');
          }
        }
      }
    }

    if (updated) {
      setState(() {});
      // 🔥 저장 제거 - 퀘스트를 트리거한 액션에서 이미 저장함 (Firebase 비용 절감)
    }
  }

  // 다음 파트에서 계속...

  // ===== 강화 =====
  void _enhance() {
    if (_equippedSword == null) {
      _showNotification('장착된 검이 없습니다');
      return;
    }
    if (_equippedSword!.level >= _getSwordMaxEnhanceLevel(_equippedSword!)) {
      _showNotification('최대 강화 레벨입니다');
      return;
    }

    final currentLevel = _equippedSword!.level;
    final cost = getEnhanceCost(currentLevel);

    if (_gold < cost) {
      _showNotification('골드가 부족합니다');
      return;
    }

    // 강화석 사용 체크
    if (_useEnhanceStone && _enhanceStone <= 0) {
      _showNotification('강화석이 부족합니다');
      return;
    }

    // 📊 Analytics용 - setState 전에 저장
    final swordName = _equippedSword!.data.name;
    final swordGrade = _equippedSword!.data.grade.name;
    bool? enhanceSuccess;
    bool? destroyed;

    setState(() {
      _gold -= cost;
      _totalEnhanceAttempts++;
      _updateQuestProgress(QuestType.enhance);

      double successRate = getEnhanceSuccessRate(currentLevel);
      double destroyRate = getEnhanceDestroyRate(currentLevel);

      // 강화석 보너스 (레벨별 차등 적용)
      if (_useEnhanceStone) {
        _enhanceStone--;
        _totalStoneUsed++;
        final bonus = getStoneBonus(
          successRate,
          destroyRate,
          level: currentLevel + 1,
        );
        successRate = bonus.$1;
        destroyRate = bonus.$2;
      }

      final roll = _random.nextDouble() * 100;

      if (roll < successRate) {
        // 성공
        enhanceSuccess = true;
        destroyed = false;
        _equippedSword!.level++;
        _totalEnhanceSuccess++;
        _consecutiveSuccess++;
        _maxConsecutiveSuccess = max(
          _maxConsecutiveSuccess,
          _consecutiveSuccess,
        );
        _showNotification('🎉 강화 성공! +${_equippedSword!.level}');
        _addSeasonPassExp(10);
        _checkAchievements();

        // 🔊 강화 성공 사운드
        SoundService().playEnhanceSuccess();

        // 🔥 강화 성공 애니메이션 트리거
        _showEnhanceEffect = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showEnhanceEffect = false);
        });
      } else if (roll < successRate + destroyRate) {
        // 파괴
        enhanceSuccess = false;
        destroyed = true;
        _totalDestroy++;
        _consecutiveSuccess = 0;
        final destroyedSword = _equippedSword!;

        // 🔊 파괴 사운드
        SoundService().playDestroy();

        // 파괴는 즉시 확정 저장하고, 광고 성공 시에만 복구한다.
        _confirmDestroy(destroyedSword, showNotification: false);
        _showDestroyRecoveryDialog(destroyedSword);
      } else {
        // 실패
        enhanceSuccess = false;
        destroyed = false;
        _totalEnhanceFail++;
        _consecutiveSuccess = 0;
        _showNotification('❌ 강화 실패');

        // 🔊 강화 실패 사운드
        SoundService().playEnhanceFail();
      }

      _updateRankings();
      _saveGameData();
    });

    // 📊 Analytics (fire-and-forget)
    AnalyticsService().logEnhance(
      swordName: swordName,
      grade: swordGrade,
      level: currentLevel,
      success: enhanceSuccess ?? false,
      destroyed: destroyed ?? false,
    );
  }

  // 🎬 파괴 복구 광고 다이얼로그
  void _showDestroyRecoveryDialog(OwnedSword destroyedSword) {
    final adService = AdService();
    final canWatch = adService.canWatchAd(AdRewardType.destroyRevive);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Text('💔', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '검이 파괴되었습니다!',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 파괴된 검 정보
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: destroyedSword.data.grade.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: destroyedSword.data.grade.color),
              ),
              child: Column(
                children: [
                  SwordImageWidget(
                    grade: destroyedSword.data.grade,
                    element: destroyedSword.data.element,
                    level: destroyedSword.level,
                    breakthroughLevel: destroyedSword.breakthroughLevel,
                    size: 80,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${destroyedSword.data.name} +${destroyedSword.level}',
                    style: TextStyle(
                      color: destroyedSword.data.grade.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '⚡ ${formatNumber(destroyedSword.totalPower)}',
                    style: const TextStyle(color: Colors.amber),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 광고 복구 안내
            if (canWatch)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Text('🎬', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '광고를 시청하면 검을 복구할 수 있습니다!',
                            style: TextStyle(color: Colors.green, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '오늘 남은 횟수: ${adService.getRemainingAdCount(AdRewardType.destroyRevive)}/3',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '오늘 광고 복구 횟수를 모두 사용했습니다.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          // 포기 버튼
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('포기', style: TextStyle(color: Colors.red)),
          ),
          // 광고 복구 버튼
          if (canWatch)
            ElevatedButton.icon(
              onPressed: _isDestroyRecoveryInProgress
                  ? null
                  : () async {
                      Navigator.pop(context);
                      if (!mounted) return;
                      setState(() => _isDestroyRecoveryInProgress = true);
                      try {
                        await _watchAdToRecoverSword(destroyedSword);
                      } finally {
                        if (mounted) {
                          setState(() => _isDestroyRecoveryInProgress = false);
                        }
                      }
                    },
              icon: const Text('🎬'),
              label: Text(
                '복구 (${adService.getRemainingAdCount(AdRewardType.destroyRevive)}/3)',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  // 파괴 적용. 광고 성공 시 이 상태를 되돌린다.
  void _confirmDestroy(
    OwnedSword destroyedSword, {
    bool showNotification = true,
  }) {
    setState(() {
      final removed = _inventory.any((s) => s.uid == destroyedSword.uid);
      _inventory.removeWhere((s) => s.uid == destroyedSword.uid);

      if (_equippedSword?.uid == destroyedSword.uid) {
        if (_inventory.isNotEmpty) {
          _inventory.sort((a, b) => b.totalPower.compareTo(a.totalPower));
          _equippedSword = _inventory.first;
        } else {
          _equippedSword = null;
        }
      }

      if (showNotification) {
        if (_equippedSword != null) {
          _showNotification(
            '💥 검이 파괴되었습니다... (${_equippedSword!.data.name} 자동 장착)',
          );
        } else {
          _showNotification('💥 검이 파괴되었습니다...');
        }
      }

      if (removed) {
        _saveGameData();
      }
    });
  }

  // 광고 보고 검 복구
  Future<void> _watchAdToRecoverSword(OwnedSword destroyedSword) async {
    final adService = AdService();

    if (!adService.isRewardedAdReady) {
      adService.loadRewardedAd();
      _showNotification('광고를 불러오는 중입니다... 검은 아직 파괴되지 않았습니다.');
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _showDestroyRecoveryDialog(destroyedSword);
        });
      }
      return;
    }

    bool hadAdError = false;
    final success = await adService.showRewardedAd(
      type: AdRewardType.destroyRevive,
      onRewarded: () {
        if (!mounted) return;
        setState(() {
          // 이미 인벤토리에 남아있으므로 파괴만 취소 처리
          if (!_inventory.any((s) => s.uid == destroyedSword.uid)) {
            _inventory.add(destroyedSword);
          }
          _equippedSword = destroyedSword;
          _showNotification('✨ ${destroyedSword.data.name} 파괴가 취소되었습니다!');
          _saveGameData();
        });
      },
      onError: (msg) {
        hadAdError = true;
        _showNotification(msg);
      },
    );

    // 광고 시스템 오류 시에는 파괴 확정하지 않고 재시도 기회 제공
    if (!success && hadAdError) {
      if (mounted) _showDestroyRecoveryDialog(destroyedSword);
      return;
    }

    // 광고를 끝까지 안 봤으면 이미 적용된 파괴 상태를 그대로 유지한다.
    if (!success && !hadAdError) {
      _confirmDestroy(destroyedSword);
    }
  }

  // ===== 뽑기 =====

  // 🔥 빠른 가챠 (강화 화면용 - 팝업 없이 바로 뽑기)
  void _quickGacha(int count) {
    final cost = count == 1
        ? AppConstants.singleGachaCostGold
        : (AppConstants.singleGachaCostGold *
                  count *
                  AppConstants.multiGachaDiscount)
              .floor();

    if (_gold < cost) {
      _showNotification('골드가 부족합니다 (${formatNumber(cost)}G 필요)');
      return;
    }
    if (_inventory.length + count > _maxInventory) {
      _showNotification('인벤토리가 가득 찼습니다');
      return;
    }

    // 📊 Analytics용
    final List<OwnedSword> newSwords = [];
    OwnedSword? bestSword;

    setState(() {
      _gold -= cost;
      _totalGacha += count;
      _updateQuestProgress(QuestType.gacha, count);

      SwordGrade? highestGrade;

      for (int i = 0; i < count; i++) {
        final swordData = _rollGachaWithPity();
        final newSword = createNewSword(swordData);

        _inventory.add(newSword);
        newSwords.add(newSword);
        _codex.add(swordData.id);

        if (highestGrade == null ||
            swordData.grade.index > highestGrade.index) {
          highestGrade = swordData.grade;
          bestSword = newSword;
        }
      }

      // 첫 검 자동 장착
      if (_equippedSword == null && newSwords.isNotEmpty) {
        _equippedSword = newSwords.first;
      }

      _addSeasonPassExp(count * 5);

      // 간단한 알림만 (팝업 없이)
      if (count == 1) {
        _showNotification(
          '🎰 ${newSwords.first.data.grade.emoji} ${newSwords.first.data.name} 획득!',
        );
      } else {
        final gradeEmojis = newSwords.map((s) => s.data.grade.emoji).join('');
        _showNotification('🎰 ${count}개 획득! $gradeEmojis');
      }

      _updateRankings();
      _checkAchievements();
      _saveGameData();
    });

    // 📊 Analytics (fire-and-forget)
    if (bestSword != null) {
      AnalyticsService().logGacha(
        type: 'normal',
        resultGrade: bestSword!.data.grade.name,
        resultName: bestSword!.data.name,
      );
    }
  }

  void _doGacha(int count) {
    final cost = count == 1
        ? AppConstants.singleGachaCostGold
        : (AppConstants.singleGachaCostGold *
                  count *
                  AppConstants.multiGachaDiscount)
              .floor();

    if (_gold < cost) {
      _showNotification('골드가 부족합니다');
      return;
    }
    if (_inventory.length + count > _maxInventory) {
      _showNotification('인벤토리가 가득 찼습니다');
      return;
    }

    // 📊 Analytics용 - setState 밖에서 선언
    final List<OwnedSword> newSwords = [];
    OwnedSword? bestSword;

    setState(() {
      _gold -= cost;
      _totalGacha += count;
      _updateQuestProgress(QuestType.gacha, count);

      SwordGrade? highestGrade;

      for (int i = 0; i < count; i++) {
        // ✅ 천장 적용된 뽑기
        final swordData = _rollGachaWithPity();
        final newSword = createNewSword(swordData);

        _inventory.add(newSword);
        newSwords.add(newSword);
        _codex.add(swordData.id);

        // 최고 등급 추적
        if (highestGrade == null ||
            swordData.grade.index > highestGrade.index) {
          highestGrade = swordData.grade;
          bestSword = newSword;
        }
      }

      // 첫 검 자동 장착
      if (_equippedSword == null && newSwords.isNotEmpty) {
        _equippedSword = newSwords.first;
      }

      _addSeasonPassExp(count * 5);

      // 🔥 뽑기 결과 다이얼로그 표시 (새 검 이미지 적용)
      if (count == 1) {
        _showGachaResultDialog(newSwords.first, isPremium: false);
      } else {
        _showMultiGachaResultDialog(
          newSwords,
          isPremium: false,
          guaranteed: false,
        );
      }

      _updateRankings();
      _checkAchievements();
      _saveGameData();
    });

    // 📊 Analytics (fire-and-forget) - 최고 등급 검만 로깅
    if (bestSword != null) {
      AnalyticsService().logGacha(
        type: 'normal',
        resultGrade: bestSword!.data.grade.name,
        resultName: bestSword!.data.name,
      );
    }
  }

  // ✅ 단순 확률 뽑기 (천장 없음 - 천장은 합성에만 적용)
  SwordData _rollGachaWithPity() {
    final roll = _random.nextDouble() * 100;
    double cumulative = 0;

    for (final entry in gachaProbability.entries) {
      cumulative += entry.value;
      if (roll < cumulative) {
        final swords = getSwordsByGrade(entry.key);
        return swords[_random.nextInt(swords.length)];
      }
    }

    // 기본: 노말 등급
    final normalSwords = getSwordsByGrade(SwordGrade.normal);
    return normalSwords[_random.nextInt(normalSwords.length)];
  }

  // ===== 합성 =====
  void _synthesize(List<OwnedSword> materials, {bool showResult = true}) {
    if (materials.length != AppConstants.synthesisRequiredCount) {
      _showNotification('검 3개를 선택하세요');
      return;
    }

    final grade = materials.first.data.grade;

    // 불멸은 합성 불가(최상위)
    if (!canSynthesize(grade)) {
      _showNotification('불멸 등급은 합성할 수 없습니다');
      return;
    }

    // 같은 등급 체크
    if (!materials.every((s) => s.data.grade == grade)) {
      _showNotification('같은 등급만 합성할 수 있습니다');
      return;
    }

    final resultGrade = getSynthesisResultGrade(grade);
    if (resultGrade == null) {
      _showNotification('합성할 수 없는 등급입니다');
      return;
    }

    // ✅ 골드 비용 체크
    if (_gold < AppConstants.synthesisCostGold) {
      _showNotification('골드가 부족합니다 (${AppConstants.synthesisCostGold}G 필요)');
      return;
    }

    setState(() {
      // ✅ 골드 차감
      _gold -= AppConstants.synthesisCostGold;

      // ✅ 장착 검이 재료로 사용되었는지 체크
      bool equippedWasUsed = materials.any((s) => s.uid == _equippedSword?.uid);

      // 재료 제거
      for (final sword in materials) {
        _inventory.remove(sword);
      }

      if (equippedWasUsed) {
        _equippedSword = null;
      }

      _totalSynthesis++;

      // 천장 로직: 노말(10) / 레어(50) / 유니크(100)
      bool isCeiling = false;
      final ceiling = getSynthesisCeiling(grade);

      if (grade == SwordGrade.normal) {
        _normalToRarePity++;
        if (ceiling != null && _normalToRarePity >= ceiling) {
          isCeiling = true;
        }
      } else if (grade == SwordGrade.rare) {
        _rareToUniquePity++;
        if (ceiling != null && _rareToUniquePity >= ceiling) {
          isCeiling = true;
        }
      } else if (grade == SwordGrade.unique) {
        _uniqueToLegendPity++;
        if (ceiling != null && _uniqueToLegendPity >= ceiling) {
          isCeiling = true;
        }
      }

      // 확률 체크
      final probability = getSynthesisProbability(grade) ?? 0;
      final success = isCeiling || checkProbability(probability);

      if (success) {
        final resultSwords = getSwordsByGrade(resultGrade);
        final resultData = resultSwords[_random.nextInt(resultSwords.length)];
        final newSword = createNewSword(resultData);

        _inventory.add(newSword);
        _codex.add(resultData.id);

        // ✅ 장착 검이 재료로 사용되었으면 새 검 자동 장착
        if (equippedWasUsed) {
          _equippedSword = newSword;
        }

        // 성공 시 천장 카운트 리셋(해당 구간만)
        if (grade == SwordGrade.normal) _normalToRarePity = 0;
        if (grade == SwordGrade.rare) _rareToUniquePity = 0;
        if (grade == SwordGrade.unique) _uniqueToLegendPity = 0;

        // ✅ 합성 성공 다이얼로그
        if (showResult) {
          _showSynthesisResultDialog(
            isSuccess: true,
            isCeiling: isCeiling,
            resultSword: newSword,
            fromGrade: grade,
            toGrade: resultGrade,
          );
        }
      } else {
        // 실패: 같은 등급 1개 반환
        final sameGradeSwords = getSwordsByGrade(grade);
        final resultData =
            sameGradeSwords[_random.nextInt(sameGradeSwords.length)];
        final newSword = createNewSword(resultData);

        _inventory.add(newSword);

        // ✅ 장착 검이 재료로 사용되었으면 반환된 검 자동 장착
        if (equippedWasUsed) {
          _equippedSword = newSword;
        }

        // ✅ 합성 실패 다이얼로그 (같은 등급 반환)
        if (showResult) {
          _showSynthesisResultDialog(
            isSuccess: false,
            isCeiling: false,
            resultSword: newSword,
            fromGrade: grade,
            toGrade: grade,
          );
        }
      }

      // 천장 “발동”이면 카운터 리셋(여기서 확정 처리)
      if (isCeiling) {
        if (grade == SwordGrade.rare) _rareToUniquePity = 0;
        if (grade == SwordGrade.normal) _normalToRarePity = 0;
        if (grade == SwordGrade.unique) _uniqueToLegendPity = 0;
      }

      _addSeasonPassExp(15);
      _updateRankings();
      _checkAchievements();
      _saveGameData();
    });
  }

  // ✅ 합성 결과 다이얼로그
  void _showSynthesisResultDialog({
    required bool isSuccess,
    required bool isCeiling,
    required OwnedSword resultSword,
    required SwordGrade fromGrade,
    required SwordGrade toGrade,
  }) {
    final grade = resultSword.data.grade;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                isSuccess
                    ? grade.color.withOpacity(0.8)
                    : Colors.grey.withOpacity(0.6),
                const Color(0xFF1a1a2e),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSuccess ? grade.color : Colors.grey,
              width: 2,
            ),
            boxShadow: isSuccess
                ? [
                    BoxShadow(
                      color: grade.color.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 결과 텍스트
              if (isCeiling)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🎯 천장 달성!',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              Text(
                isSuccess ? '✨ 합성 성공!' : '😅 등급 상승 실패',
                style: TextStyle(
                  color: isSuccess ? Colors.white : Colors.white70,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),

              // 등급 변화 표시
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(fromGrade.emoji, style: const TextStyle(fontSize: 24)),
                  Text(
                    isSuccess ? ' → ' : ' → ',
                    style: TextStyle(
                      color: isSuccess ? Colors.green : Colors.grey,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    isSuccess ? toGrade.emoji : fromGrade.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 결과 검 이미지 (SwordImageWidget)
              SwordImageWidget(
                grade: grade,
                element: resultSword.data.element,
                level: resultSword.level,
                breakthroughLevel: resultSword.breakthroughLevel,
                size: 100,
                showPulse: true,
              ),
              const SizedBox(height: 8),

              // 등급 배지
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: grade.color.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  grade.displayName,
                  style: TextStyle(
                    color: grade.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 검 이름
              Text(
                resultSword.data.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),

              // 전투력
              Text(
                '⚡ 전투력: ${resultSword.totalPower}',
                style: const TextStyle(color: Colors.amber),
              ),

              if (!isSuccess) ...[
                const SizedBox(height: 12),
                Text(
                  '3개 → 1개로 합쳐졌습니다',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],

              const SizedBox(height: 20),

              // 확인 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuccess ? grade.color : Colors.grey[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 판매 =====

  // 🔥 현재 판매 이벤트 정보
  Map<String, dynamic> get _currentSellEvent =>
      _sellEvents[_currentSellEventIndex];
  double get _sellEventRate => (_currentSellEvent['rate'] as num).toDouble();
  String get _sellEventName => _currentSellEvent['name'] as String;
  String get _sellEventEmoji => _currentSellEvent['emoji'] as String;
  Color get _sellEventColor => Color(_currentSellEvent['color'] as int);

  // 🔥 판매 시 매번 랜덤 이벤트 적용
  void _randomizeSellEvent() {
    final random = Random();

    // 가중치 기반 랜덤 (좋은 이벤트는 낮은 확률)
    // [일반, 폭등, 대폭등, 버블, 황금시대, 폭락, 대폭락, 불경기, 호황]
    final weights = [30, 18, 8, 4, 2, 18, 10, 5, 15]; // 총 110
    final totalWeight = weights.reduce((a, b) => a + b);
    int roll = random.nextInt(totalWeight);

    int newIndex = 0;
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) {
        newIndex = i;
        break;
      }
    }

    _currentSellEventIndex = newIndex;
  }

  // 🔥 홈 화면용 이벤트 변경 (미리보기)
  void _changeSellEvent() {
    _randomizeSellEvent();
    setState(() {});
  }

  void _sellSword(OwnedSword sword) {
    // 🎬 광고 2배 판매 옵션 다이얼로그
    _showSellOptionsDialog(sword);
  }

  // 🎬 판매 옵션 다이얼로그
  void _showSellOptionsDialog(OwnedSword sword) {
    final adService = AdService();
    final canWatchAd = adService.canWatchAd(AdRewardType.sellBonus);
    final basePrice = sword.sellPrice;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Text('💰', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            const Text(
              '검 판매',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 검 정보
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sword.data.grade.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sword.data.grade.color.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  SwordImageWidget(
                    grade: sword.data.grade,
                    element: sword.data.element,
                    level: sword.level,
                    breakthroughLevel: sword.breakthroughLevel,
                    size: 50,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sword.data.name,
                          style: TextStyle(
                            color: sword.data.grade.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '+${sword.level}',
                          style: const TextStyle(color: Colors.amber),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 판매 옵션
            Row(
              children: [
                // 일반 판매
                Expanded(
                  child: _buildSellOptionButton(
                    label: '일반 판매',
                    price: basePrice,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _executeSell(sword, bonusMultiplier: 1);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // 광고 2배 판매
                Expanded(
                  child: _buildSellOptionButton(
                    label: '🎬 광고 2배',
                    price: basePrice * 2,
                    color: Colors.green,
                    isAd: true,
                    remaining: adService.getRemainingAdCount(
                      AdRewardType.sellBonus,
                    ),
                    enabled: canWatchAd,
                    onTap: () {
                      Navigator.pop(context);
                      _watchAdToSellDouble(sword);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  Widget _buildSellOptionButton({
    required String label,
    required int price,
    required Color color,
    required VoidCallback onTap,
    bool isAd = false,
    int remaining = 0,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: enabled
              ? color.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: enabled ? color : Colors.grey),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatNumber(price)}G',
              style: TextStyle(
                color: enabled ? Colors.amber : Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isAd) ...[
              const SizedBox(height: 2),
              Text(
                '($remaining/5)',
                style: TextStyle(
                  color: enabled ? Colors.white54 : Colors.grey,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 🎬 광고 보고 2배 판매
  void _watchAdToSellDouble(OwnedSword sword) async {
    final adService = AdService();

    if (!adService.isRewardedAdReady) {
      _showNotification('광고를 불러오는 중...');
      _executeSell(sword, bonusMultiplier: 1); // 일반 판매로 대체
      return;
    }

    await adService.showRewardedAd(
      type: AdRewardType.sellBonus,
      onRewarded: () {
        _executeSell(sword, bonusMultiplier: 2);
      },
      onError: (msg) {
        _showNotification(msg);
        _executeSell(sword, bonusMultiplier: 1);
      },
    );
  }

  // 🔥 실제 판매 실행
  void _executeSell(OwnedSword sword, {int bonusMultiplier = 1}) {
    // 🔥 판매할 때마다 랜덤 이벤트 적용!
    _randomizeSellEvent();

    // 🔥 이벤트 배율 + 광고 배율 적용한 판매가
    final basePrice = sword.sellPrice;
    final eventPrice = (basePrice * _sellEventRate * bonusMultiplier).round();

    // 📊 Analytics용 - setState 전에 저장
    final swordGrade = sword.data.grade.name;

    setState(() {
      _inventory.remove(sword);

      // 장착 중인 검을 판매한 경우 자동 장착
      if (_equippedSword?.uid == sword.uid) {
        if (_inventory.isNotEmpty) {
          _inventory.sort((a, b) => b.totalPower.compareTo(a.totalPower));
          _equippedSword = _inventory.first;
          _showNotification(
            '${bonusMultiplier > 1 ? "🎬x2 " : ""}$_sellEventEmoji +${formatNumber(eventPrice)}G (${_equippedSword!.data.name} 자동 장착)',
          );
        } else {
          _equippedSword = null;
          _showNotification(
            '${bonusMultiplier > 1 ? "🎬x2 " : ""}$_sellEventEmoji +${formatNumber(eventPrice)}G',
          );
        }
      } else {
        if (bonusMultiplier > 1) {
          _showNotification(
            '🎬x2 $_sellEventEmoji +${formatNumber(eventPrice)}G!',
          );
        } else if (_sellEventRate != 1.0) {
          _showNotification(
            '$_sellEventEmoji +${formatNumber(eventPrice)}G ($_sellEventName ${_sellEventRate}배!)',
          );
        } else {
          _showNotification('💰 +${formatNumber(eventPrice)}G');
        }
      }

      _gold += eventPrice;
      _totalSell++;
      _updateQuestProgress(QuestType.sell);

      _updateRankings();
      _checkAchievements();
      _saveGameData();
    });

    // 📊 Analytics (fire-and-forget)
    AnalyticsService().logSellSword(grade: swordGrade, goldEarned: eventPrice);
  }

  // ===== 인벤토리 확장 (인벤토리 탭에서) =====
  void _showExpandInventoryDialog() {
    if (_maxInventory >= AppConstants.maxInventoryLimit) {
      _showNotification('최대 인벤토리입니다 (${AppConstants.maxInventoryLimit}칸)');
      return;
    }
    final nextSlot = _maxInventory + 1;
    final price = inventoryPrices.firstWhere(
      (p) => p.$1 == nextSlot,
      orElse: () => (0, 0, ''),
    );
    if (price.$1 == 0) {
      _showNotification('더 이상 확장할 수 없습니다');
      return;
    }
    final cost = price.$2;
    final type = price.$3;
    final isGold = type == 'gold';
    final currencyName = isGold ? '골드' : '다이아';
    final currencyIcon = isGold ? '💰' : '💎';
    final hasEnough = isGold ? _gold >= cost : _diamond >= cost;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '📦 인벤토리 확장',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_maxInventory}칸 → ${_maxInventory + 1}칸',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('비용: ', style: TextStyle(color: Colors.white70)),
                Text(
                  '$currencyIcon ${formatNumber(cost)} $currencyName',
                  style: TextStyle(
                    color: isGold ? Colors.amber : Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (!hasEnough)
              Text(
                '($currencyName 부족)',
                style: TextStyle(color: Colors.red[300], fontSize: 12),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: hasEnough
                ? () {
                    Navigator.pop(context);
                    setState(() {
                      if (isGold)
                        _gold -= cost;
                      else
                        _diamond -= cost;
                      _maxInventory += 1;
                      _saveGameData();
                    });
                    _showNotification('📦 인벤토리 확장! (${_maxInventory}칸)');
                  }
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('확장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ===== 일괄 판매 =====
  void _bulkSellSwords(List<OwnedSword> swords) {
    if (swords.isEmpty) return;

    int totalEarned = 0;
    setState(() {
      for (final sword in swords) {
        _randomizeSellEvent();
        final eventPrice = (sword.sellPrice * _sellEventRate).round();
        _inventory.remove(sword);
        _gold += eventPrice;
        totalEarned += eventPrice;
        _totalSell++;
        _updateQuestProgress(QuestType.sell);
      }

      // 장착 중인 검이 판매됐으면 자동 장착
      if (_equippedSword != null && !_inventory.contains(_equippedSword)) {
        if (_inventory.isNotEmpty) {
          _inventory.sort((a, b) => b.totalPower.compareTo(a.totalPower));
          _equippedSword = _inventory.first;
        } else {
          _equippedSword = null;
        }
      }

      _updateRankings();
      _checkAchievements();
      _saveGameData();
    });

    _showNotification(
      '💰 ${swords.length}개 판매! +${formatNumber(totalEarned)}G',
    );
  }

  // ===== 배틀 =====
  void _startBattle({
    NPCData? npc,
    Map<String, dynamic>? playerOpponent,
    bool isRevenge = false,
  }) {
    if (_battleCount <= 0) {
      _showNotification('배틀 횟수가 부족합니다');
      return;
    }
    if (_equippedSword == null) {
      _showNotification('장착된 검이 없습니다');
      return;
    }

    // 상대 선택
    Map<String, dynamic> opponent;
    if (npc != null) {
      opponent = {
        'id': npc.id,
        'name': npc.name,
        'power': npc.power,
        'swordGrade': npc.sword.grade,
        'swordId': npc.sword.id, // ✅ 검 ID 추가
        'element': npc.sword.element,
        'swordLevel': npc.swordLevel,
        'isNpc': true,
      };
    } else if (playerOpponent != null) {
      opponent = playerOpponent;
    } else {
      // ✅ 레벨 기반 랜덤 매칭
      final allCandidates = _rankings
          .where((r) => r['id'] != widget.userId)
          .toList();
      if (allCandidates.isEmpty) {
        _showNotification('상대를 찾을 수 없습니다');
        return;
      }

      final myLevel = _equippedSword?.level ?? 1;
      const int preferredRange = 3; // ±3 레벨 범위

      // 1차: 비슷한 레벨 유저 필터링
      var candidates = allCandidates.where((r) {
        final oppLevel = (r['swordLevel'] as int?) ?? 1;
        return (oppLevel - myLevel).abs() <= preferredRange;
      }).toList();

      // 2차: 비슷한 레벨이 없으면 전체에서 선택
      if (candidates.isEmpty) {
        candidates = allCandidates;
      }

      // 3차: 레벨 차이가 적은 순으로 정렬 후 상위 50%에서 랜덤 선택 (더 공정한 매칭)
      candidates.sort((a, b) {
        final levelDiffA = ((a['swordLevel'] as int?) ?? 1 - myLevel).abs();
        final levelDiffB = ((b['swordLevel'] as int?) ?? 1 - myLevel).abs();
        return levelDiffA.compareTo(levelDiffB);
      });

      final topHalf = candidates
          .take((candidates.length / 2).ceil().clamp(1, candidates.length))
          .toList();
      opponent = topHalf[_random.nextInt(topHalf.length)];
    }

    setState(() {
      _battleCount--;
      _totalBattle++;
      _updateQuestProgress(QuestType.battle);

      // ✅ BattleEngine을 사용하여 실제 배틀 시뮬레이션
      final mySword = _equippedSword!;
      final oppGrade =
          (opponent['swordGrade'] as SwordGrade?) ?? SwordGrade.normal;
      final oppLevel = (opponent['swordLevel'] as int?) ?? 1;
      final oppElement =
          (opponent['element'] as GameElement?) ?? GameElement.fire;
      final oppId = (opponent['id'] as String?) ?? 'unknown';
      final oppName = (opponent['name'] as String?) ?? '알 수 없음';
      final oppIsNpc = (opponent['isNpc'] as bool?) ?? true;
      final oppSwordId = opponent['swordId'] as String?;

      // 상대 검 데이터 가져오기 (swordId가 있으면 실제 검, 없으면 등급에서 랜덤)
      SwordData oppSwordData;
      if (oppSwordId != null && oppSwordId.isNotEmpty) {
        // ✅ 실제 검 ID로 검 데이터 가져오기
        oppSwordData = allSwords.firstWhere(
          (s) => s.id == oppSwordId,
          orElse: () => getSwordsByGrade(oppGrade).first,
        );
      } else {
        // NPC나 검 ID가 없는 경우 등급에서 랜덤 선택
        final oppSwords = getSwordsByGrade(oppGrade);
        oppSwordData = oppSwords[_random.nextInt(oppSwords.length)];
      }

      final me = BattleParticipant(
        id: 'player',
        name: widget.nickname,
        grade: mySword.data.grade,
        swordLevel: mySword.level,
        baseAtk: mySword.data.baseAtk,
        element: mySword.data.element,
        primarySkillType: mySword.data.primarySkillType, // ✅ 안전한 getter 사용
        skills: mySword.data.skills,
        swordName: mySword.data.name,
        titleBonus: getTitleById(_equippedTitle).bonus, // ✅ 칭호 보너스 적용
      );

      final opp = BattleParticipant(
        id: oppId,
        name: oppName,
        grade: oppGrade,
        swordLevel: oppLevel,
        baseAtk: oppSwordData.baseAtk,
        element: oppElement,
        primarySkillType: oppSwordData.primarySkillType, // ✅ 안전한 getter 사용
        skills: oppSwordData.skills,
        swordName: oppSwordData.name,
      );

      // ✅ 배틀 엔진으로 시뮬레이션 실행
      final result = BattleEngine.simulate(me: me, opponent: opp);
      final isWin = result.iWin;

      int goldReward = 0;
      int stoneReward = 0; // 🔮 강화석 드롭
      if (isWin) {
        _totalBattleWin++;
        _battleWinStreak++;
        _maxWinStreak = max(_maxWinStreak, _battleWinStreak);
        goldReward = result.rewardGold;
        _gold += goldReward;

        // 🔮 강화석 30% 확률 드롭
        if (Random().nextInt(100) < 30) {
          stoneReward = 1;
          _enhanceStone += stoneReward;
        }

        if (isRevenge) _totalRevengeWins++;
      } else {
        _battleWinStreak = 0;
      }

      // 🔥 새로운 배틀 아레나 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BattleArenaScreen(
            me: me,
            opponent: opp,
            result: result,
            stoneReward: stoneReward, // 🔮 강화석 드롭
          ),
        ),
      ).then((_) {
        // 🔮 배틀 종료 후 강화석 획득 알림
        if (stoneReward > 0) {
          _showImageNotification(
            '빛나는 강화석 $stoneReward개 획득!',
            'assets/images/home/header/enhance_mythic.png',
          );
        }
      });

      // ✅ 배틀 로그 포함하여 기록 저장
      _battleRecords.insert(
        0,
        BattleRecord(
          uid: generateUid(),
          opponentId: oppId,
          opponentName: oppName,
          myLevel: mySword.level,
          opponentLevel: oppLevel,
          myGrade: mySword.data.grade.name,
          opponentGrade: oppGrade.name,
          opponentElement: oppElement.name,
          opponentIsNpc: oppIsNpc,
          isWin: isWin,
          timestamp: DateTime.now(),
          goldEarned: goldReward,
          isRevengeable: !isWin && !oppIsNpc,
          logs: result.logs,
          isAttacker: true,
        ),
      );

      // ✅ 상대방에게 배틀 알림 전송 (NPC가 아닌 경우)
      if (!oppIsNpc && _onlineService != null) {
        _onlineService!.sendBattleNotification(
          toUserId: oppId,
          myNickname: widget.nickname,
          myLevel: mySword.level,
          myGrade: mySword.data.grade.name,
          myElement: mySword.data.element.name,
          opponentLevel: oppLevel,
          opponentGrade: oppGrade.name,
          opponentWon: !isWin,
        );
      }

      _addSeasonPassExp(isWin ? 20 : 5);
      _updateRankings();
      _checkAchievements();
      _saveGameData();

      // 📊 Analytics (fire-and-forget)
      AnalyticsService().logBattle(
        isWin: isWin,
        swordGrade: mySword.data.grade.name,
        playerPower: me.power,
        enemyPower: opp.power,
      );
    });
  }

  // ===== 보스 레이드 =====
  void _startBossRaid(BossData boss) {
    if (_equippedSword == null) {
      _showNotification('장착된 검이 없습니다');
      return;
    }

    // 쿨다운 체크
    final cooldown = _bossCooldowns[boss.id];
    if (cooldown != null && cooldown.isAfter(_storage.serverNow)) {
      // ✅ 서버 시간
      _showNotification('쿨다운 중입니다');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BossRaidScreen(
          boss: boss,
          playerSword: _equippedSword!,
          playerPower: _totalPower,
          onComplete: (isWin) => _onBossComplete(boss, isWin),
        ),
      ),
    );
  }

  void _onBossComplete(BossData boss, bool isWin) {
    setState(() {
      if (isWin) {
        int coreReward = 0;
        if (_random.nextDouble() < boss.coreDropChance) {
          coreReward = boss.coreDropMin;
          if (boss.coreDropMax > boss.coreDropMin) {
            coreReward += _random.nextInt(
              boss.coreDropMax - boss.coreDropMin + 1,
            );
          }
          _bossCore += coreReward;
        }

        // ✅ 승리 시에만 쿨다운 설정
        _bossCooldowns[boss.id] = _storage.serverNow.add(
          boss.cooldownDuration,
        ); // ✅ 서버 시간
        _gold += boss.goldReward;
        _diamond += boss.diamondReward;
        _bossKills++;
        _updateQuestProgress(QuestType.boss); // ✅ 승리 시에만 퀘스트 진행
        _showNotification(
          '🎉 보스 처치! +${boss.goldReward}G +${boss.diamondReward}💎'
          '${coreReward > 0 ? ' +$coreReward🧿' : ''}',
        );
        if (coreReward > 0) {
          _showImageNotification(
            '보스코어 $coreReward개 획득!',
            'assets/images/home/header/enhance_mythic.png',
          );
        } else {
          _showNotification('🧿 이번에는 보스코어가 드랍되지 않았습니다.');
        }
        _addSeasonPassExp(50);
      } else {
        // ✅ 패배 시 쿨다운 없음 (또는 짧은 쿨다운)
        _bossCooldowns[boss.id] = _storage.serverNow.add(
          const Duration(minutes: 5),
        ); // ✅ 서버 시간
        _showNotification('💀 패배... 5분 후 재도전 가능');
      }

      _checkAchievements();
      _saveGameData();
    });

    // 📊 Analytics (fire-and-forget)
    AnalyticsService().logBossBattle(isWin: isWin, bossFloor: boss.minLevel);
  }

  // ===== 출석 =====
  void _checkAttendance() {
    if (!_canCheckAttendance) return;

    // 🎬 출석 보상 다이얼로그 표시
    _showAttendanceRewardDialog();
  }

  // 🎬 출석 보상 다이얼로그
  void _showAttendanceRewardDialog() {
    // ✅ 연속 출석 끊김 체크
    bool streakBroken = false;
    int newStreak = _attendanceStreak;

    if (_lastAttendance != null &&
        !_storage.isYesterday(_lastAttendance) &&
        !_storage.isToday(_lastAttendance)) {
      streakBroken = _attendanceStreak > 1;
      newStreak = 1;
    } else if (_storage.isYesterday(_lastAttendance)) {
      newStreak = _attendanceStreak + 1;
    } else {
      newStreak = 1;
    }

    // 보상 계산
    final goldReward = AppConstants.getAttendanceGold(newStreak);
    final hasDiamondBonus = newStreak % 7 == 0;
    final adService = AdService();
    final canWatchAd = adService.canWatchAd(AdRewardType.attendanceBonus);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Text('📅', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Text(
              streakBroken ? '출석 체크' : '$newStreak일 연속 출석!',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (streakBroken)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '😢 연속 출석이 끊겼습니다...\n다시 1일차부터 시작!',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),

            // 보상 정보
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text(
                    '오늘의 보상',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '💰 ${formatNumber(goldReward)}G',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasDiamondBonus) ...[
                        const SizedBox(width: 12),
                        Text(
                          '+${AppConstants.weeklyAttendanceDiamond}💎',
                          style: const TextStyle(
                            color: Colors.cyan,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 버튼들
            Row(
              children: [
                // 일반 수령
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _executeAttendance(
                        newStreak,
                        goldReward,
                        hasDiamondBonus,
                        1,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text(
                      '수령',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 광고 2배 수령
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canWatchAd
                        ? () {
                            Navigator.pop(context);
                            _watchAdForDoubleAttendance(
                              newStreak,
                              goldReward,
                              hasDiamondBonus,
                            );
                          }
                        : null,
                    icon: const Text('🎬', style: TextStyle(fontSize: 14)),
                    label: const Text('2배'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (canWatchAd)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '오늘 남은 횟수: ${adService.getRemainingAdCount(AdRewardType.attendanceBonus)}/1',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 출석 보상 지급
  void _executeAttendance(
    int newStreak,
    int goldReward,
    bool hasDiamondBonus,
    int multiplier,
  ) {
    setState(() {
      _attendanceStreak = newStreak;
      _lastAttendance = _storage.serverNow; // ✅ 서버 시간
      _canCheckAttendance = false;

      final finalGold = goldReward * multiplier;
      _gold += finalGold;

      String message =
          '${multiplier > 1 ? "🎬x2 " : ""}${_attendanceStreak}일 연속 출석! +${formatNumber(finalGold)}G';

      if (hasDiamondBonus) {
        final finalDiamond = AppConstants.weeklyAttendanceDiamond * multiplier;
        _diamond += finalDiamond;
        message += ' +$finalDiamond💎 (주간 보너스!)';
      }

      _showNotification(message);
      _checkAchievements();
      _saveGameData();
    });

    // 📊 Analytics (fire-and-forget)
    AnalyticsService().logAttendance(streak: newStreak, day: newStreak);
  }

  // 광고로 출석 보상 2배
  void _watchAdForDoubleAttendance(
    int newStreak,
    int goldReward,
    bool hasDiamondBonus,
  ) async {
    final adService = AdService();

    if (!adService.isRewardedAdReady) {
      _showNotification('광고를 불러오는 중...');
      _executeAttendance(newStreak, goldReward, hasDiamondBonus, 1);
      return;
    }

    await adService.showRewardedAd(
      type: AdRewardType.attendanceBonus,
      onRewarded: () {
        _executeAttendance(newStreak, goldReward, hasDiamondBonus, 2);
      },
      onError: (msg) {
        _showNotification(msg);
        _executeAttendance(newStreak, goldReward, hasDiamondBonus, 1);
      },
    );
  }

  // ===== 업적 체크 =====
  // ===== 업적 체크(전체 데이터 기반) =====
  void _checkAchievementsFull() {
    final prevAchievementCount = _unlockedAchievements.length;
    final prevTitleCount = _unlockedTitles.length;
    final maxSwordLevel = _inventory.fold<int>(
      _equippedSword?.level ?? 0,
      (maxLevel, sword) => sword.level > maxLevel ? sword.level : maxLevel,
    );
    final breakthroughSwordCount = _inventory
        .where((sword) => sword.breakthroughLevel > 0)
        .length;

    final stats = <String, int>{
      'totalEnhanceAttempts': _totalEnhanceAttempts,
      'totalEnhanceSuccess': _totalEnhanceSuccess,
      'totalDestroy': _totalDestroy,
      'maxConsecutiveSuccess': _maxConsecutiveSuccess,
      'totalStoneUsed': _totalStoneUsed,
      'maxSwordLevel': maxSwordLevel,
      'breakthroughSwordCount': breakthroughSwordCount,

      'totalBattle': _totalBattle,
      'totalBattleWin': _totalBattleWin,
      'maxWinStreak': _maxWinStreak,
      'totalRevengeWins': _totalRevengeWins,

      'bossKills': _bossKills,

      'codexCount': _codex.length,

      'totalSell': _totalSell,
      'totalGacha': _totalGacha,
      'totalSynthesis': _totalSynthesis,
      'totalQuestsCompleted': _totalQuestsCompleted,

      'attendanceStreak': _attendanceStreak,
    };

    final all = getAllAchievements();
    for (final a in all) {
      final v = stats[a.statsKey] ?? 0;
      if (v >= a.target) {
        _unlockedAchievements.add(a.id);
      }
    }

    // ===== 칭호 체크 (30개 전체) =====

    // t_01: 초보 강화사 (게임 시작 - 자동 부여)
    _unlockedTitles.add('t_01');

    // t_02: 강화 입문자 (첫 강화 성공)
    if (_totalEnhanceSuccess >= 1) _unlockedTitles.add('t_02');

    // 강화 단계 칭호
    if (maxSwordLevel >= 5) _unlockedTitles.add('t_03'); // 5강 달성자
    if (maxSwordLevel >= 10) _unlockedTitles.add('t_04'); // 10강 달성자
    if (maxSwordLevel >= 15) _unlockedTitles.add('t_05'); // 15강 달성자
    if (maxSwordLevel >= 20) _unlockedTitles.add('t_06'); // 20강 달성자
    if (maxSwordLevel >= 25) _unlockedTitles.add('t_21'); // 🌟 숙련 강화사
    if (maxSwordLevel >= 30) _unlockedTitles.add('t_26'); // 👑 전설의 강화사
    if (maxSwordLevel >= 35) _unlockedTitles.add('t_32'); // 🌠 초월 강화사
    if (maxSwordLevel >= 45) _unlockedTitles.add('t_33'); // 🌌 한계 초월

    // 돌파 칭호
    if (breakthroughSwordCount >= 1) _unlockedTitles.add('t_31'); // 🧿 돌파자

    // 배틀 관련 칭호
    if (_totalBattleWin >= 1) _unlockedTitles.add('t_07'); // 전투 초보
    if (_battleWinStreak >= 10) _unlockedTitles.add('t_08'); // 10연승
    if (_totalBattle >= 100) _unlockedTitles.add('t_09'); // 배틀 마니아
    if (_totalBattle >= 500) _unlockedTitles.add('t_22'); // ⚔️ 백전노장
    if (_totalRevengeWins >= 10) _unlockedTitles.add('t_20'); // 복수의 칼날

    // 보스 관련 칭호
    if (_bossKills >= 10) _unlockedTitles.add('t_10'); // 보스 헌터
    if (_bossKills >= 100) _unlockedTitles.add('t_23'); // 🐉 보스 슬레이어

    // 도감 관련 칭호
    if (_codex.length >= 20) _unlockedTitles.add('t_11'); // 도감 수집가
    if (_codex.length >= 50) _unlockedTitles.add('t_12'); // 도감 마니아
    if (_codex.length >= 100) _unlockedTitles.add('t_25'); // 📚 도감 마스터

    // 재화 관련 칭호
    if (_gold >= 100000) _unlockedTitles.add('t_13'); // 부자의 시작
    if (_gold >= 1000000) _unlockedTitles.add('t_24'); // 💰 갑부
    if (_diamond >= 10000) _unlockedTitles.add('t_28'); // 💎 다이아 수집가

    // 출석 관련 칭호
    if (_attendanceStreak >= 7) _unlockedTitles.add('t_14'); // 개근상

    // 퀘스트 관련 칭호
    if (_totalQuestsCompleted >= 100) _unlockedTitles.add('t_15'); // 퀘스트 마스터

    // 합성/판매 관련 칭호
    if (_totalSynthesis >= 50) _unlockedTitles.add('t_17'); // 합성 장인
    if (_totalSell >= 100) _unlockedTitles.add('t_18'); // 판매왕

    // 시즌패스 관련 칭호
    if (_seasonPassLevel >= 50) _unlockedTitles.add('t_19'); // 시즌패스 완료

    // 레어 수집가 (레어 이상 검 10개 보유)
    final rareOrHigherCount = _inventory
        .where((s) => s.data.grade.index >= SwordGrade.rare.index)
        .length;
    if (rareOrHigherCount >= 10) _unlockedTitles.add('t_16'); // 레어 수집가

    // 랭킹 1위
    if (_myRank == 1) _unlockedTitles.add('t_27'); // 🏆 그랜드 마스터

    // 히든 칭호: 불멸의 검 획득
    final hasImmortal =
        _inventory.any((s) => s.data.grade == SwordGrade.immortal) ||
        _codex.any(
          (id) => allSwords.any(
            (s) => s.id == id && s.grade == SwordGrade.immortal,
          ),
        );
    if (hasImmortal) _unlockedTitles.add('t_29'); // 🔮 히든 (불멸의 검)

    // 히든 칭호: 100연승
    if (_maxWinStreak >= 100) _unlockedTitles.add('t_30'); // ⚡ 히든 (100연승)

    final hasNewAchievements =
        _unlockedAchievements.length > prevAchievementCount;
    final hasNewTitles = _unlockedTitles.length > prevTitleCount;
    if (hasNewAchievements && hasNewTitles) {
      _showAchievementNoticeDialog(kind: 'achievement');
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _showAchievementNoticeDialog(kind: 'title');
      });
    } else if (hasNewAchievements) {
      _showAchievementNoticeDialog(kind: 'achievement');
    } else if (hasNewTitles) {
      _showAchievementNoticeDialog(kind: 'title');
    }
  }

  // 기존 코드에서 호출하던 _checkAchievements()는 아래처럼 연결(호환용)
  void _checkAchievements() {
    _checkAchievementsFull();
  }

  // 다음 파트에서 계속...

  // ===== UI BUILD =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundDark, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildCurrentPage()),
                  _buildBottomNav(),
                ],
              ),

              // 알림
              if (_notification != null)
                Positioned(
                  top: 100,
                  left: 20,
                  right: 20,
                  child: _buildNotification(),
                ),

              // ✅ 데이터 로딩 오버레이 (로딩 중 조작으로 서버 덮어쓰기 방지)
              if (!_dataReady)
                Positioned.fill(
                  child: Stack(
                    children: [
                      const ModalBarrier(
                        dismissible: false,
                        color: Colors.black54,
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!_loadTimedOut) ...[
                              const CircularProgressIndicator(),
                              const SizedBox(height: 12),
                              const Text(
                                '데이터 불러오는 중...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ] else ...[
                              const Text(
                                '불러오는데 시간이 걸리고 있어요.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  // 재시도 시 타임아웃 상태 해제 후 다시 로드
                                  if (!mounted) return;
                                  setState(() {
                                    _loadTimedOut = false;
                                  });
                                  _loadGameData();
                                },
                                child: const Text('다시 시도'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = getTitleById(_equippedTitle);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ), // ✅ 16 → 12
      child: Column(
        children: [
          // 닉네임 & 칭호
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.nickname,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ), // ✅ 18 → 16
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      title.name,
                      style: TextStyle(
                        color: title.grade.color,
                        fontSize: 11,
                      ), // ✅ 12 → 11
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 전투력
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ), // ✅ 12,6 → 10,4
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/home/fighting_power.png',
                      width: 14,
                      height: 14,
                    ),
                    const SizedBox(width: 2), // ✅ 4 → 2
                    Text(
                      formatNumber(_totalPower),
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ), // ✅ 크기 지정
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // 🌐 공식 홈페이지 버튼
              GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse('https://www.opentheday.site/'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.language,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ✅ 재화 바 - 완전히 새로 작성
          Row(
            children: [
              // 골드, 다이아, 강화석을 Expanded로 균등 분배
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    _currencyItemAsset(
                      'assets/images/home/header/gold.png',
                      _formatCompact(_gold),
                      Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    _currencyItemAsset(
                      'assets/images/home/header/diamond.png',
                      _formatCompact(_diamond),
                      Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    _currencyItemAsset(
                      'assets/images/home/header/enhance_mythic.png',
                      '$_enhanceStone',
                      Colors.purple,
                    ),
                    const SizedBox(width: 4),
                    _currencyItem('🧿', '$_bossCore', const Color(0xFF80DEEA)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 배틀 카운트는 오른쪽 고정
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/home/header/battle_ticket.png',
                      width: 14,
                      height: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$_battleCount',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ 새로운 재화 아이템 위젯 (클래스 내부에 추가)
  Widget _currencyItem(String icon, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 에셋 이미지 재화 아이템 위젯
  Widget _currencyItemAsset(String assetPath, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(assetPath, width: 14, height: 14),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 숫자 압축 포맷 (클래스 내부에 추가)
  String _formatCompact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$value';
  }

  Widget _buildCurrentPage() {
    switch (_currentTab) {
      case 0:
        return HomeTab(
          equippedSword: _equippedSword,
          attendanceStreak: _attendanceStreak,
          canCheckAttendance: _canCheckAttendance,
          dailyQuests: _dailyQuests,
          sellEventRate: _sellEventRate,
          sellEventName: _sellEventName,
          sellEventEmoji: _sellEventEmoji,
          sellEventColor: _sellEventColor,
          titleBonus: getTitleById(_equippedTitle).bonus,
          titleName: getTitleById(_equippedTitle).name,
          onCheckAttendance: _checkAttendance,
          onShowGachaDialog: _showGachaDialog,
          onShowSynthesisDialog: _showSynthesisDialog,
          onShowBossSelectDialog: _showBossSelectDialog,
          onShowRankingDialog: _showRankingDialog,
          onClaimQuestReward: _claimQuestReward,
        );
      case 1:
        return InventoryTab(
          inventory: _inventory,
          maxInventory: _maxInventory,
          equippedSword: _equippedSword,
          gold: _gold,
          diamond: _diamond,
          onSwordTap: _showSwordDetailDialog,
          onExpandInventory: _showExpandInventoryDialog,
          onBulkSell: _bulkSellSwords,
        );
      case 2:
        return EnhanceTab(
          equippedSword: _equippedSword,
          gold: _gold,
          enhanceStone: _enhanceStone,
          bossCore: _bossCore,
          inventoryLength: _inventory.length,
          maxInventory: _maxInventory,
          useEnhanceStone: _useEnhanceStone,
          showEnhanceEffect: _showEnhanceEffect,
          maxEnhanceLevel: _equippedSword == null
              ? AppConstants.maxEnhanceLevel
              : _getSwordMaxEnhanceLevel(_equippedSword!),
          canBreakthrough:
              _equippedSword != null &&
              _equippedSword!.breakthroughLevel <
                  AppConstants.maxBreakthroughLevel &&
              _equippedSword!.level >=
                  _getSwordMaxEnhanceLevel(_equippedSword!),
          onEnhance: _enhance,
          onBreakthrough: _showBreakthroughDialog,
          onSellSword: _sellSword,
          onQuickGacha: () => _quickGacha(1),
          onToggleEnhanceStone: (v) => setState(() => _useEnhanceStone = v),
        );
      case 3:
        return BattleTab(
          battleCount: _battleCount,
          battleWinStreak: _battleWinStreak,
          battleRecords: _battleRecords,
          equippedSword: _equippedSword,
          onRandomBattle: () => _startBattle(),
          onSelectBattle: _showBattleSelectScreen,
          onRefreshRecords: () async {
            _showNotification('배틀 기록을 새로고침 중...');
            await _fetchBattleNotifications();
            if (mounted) setState(() {});
          },
          onRevengeBattle: _startRevengeMatch,
        );
      case 4:
        return MoreTab(
          onShowGachaDialog: _showGachaDialog,
          onShowSynthesisDialog: _showSynthesisDialog,
          onShowBossSelectDialog: _showBossSelectDialog,
          onOpenShopScreen: _openShopScreen,
          onOpenSeasonPassScreen: _openSeasonPassScreen,
          onOpenAchievementsScreen: _openAchievementsScreen,
          onShowRankingDialog: _showRankingDialog,
          onOpenFriendsScreen: _openFriendsScreen,
          onShowTitleDialog: _showTitleDialog,
          onShowCodexDialog: _showCodexDialog,
          onShowStatsDialog: _showStatsDialog,
          onShowHelpDialog: _showHelpDialog,
          onShowSettingsDialog: _showSettingsDialog,
          onShowLogoutDialog: _showLogoutDialog,
          onShowDeleteAccountDialog: _showDeleteAccountDialog,
          onWatchAdForFreeGacha: _watchAdForFreeGacha,
          onWatchAdForStones: _watchAdForStones,
        );
      default:
        return HomeTab(
          equippedSword: _equippedSword,
          attendanceStreak: _attendanceStreak,
          canCheckAttendance: _canCheckAttendance,
          dailyQuests: _dailyQuests,
          sellEventRate: _sellEventRate,
          sellEventName: _sellEventName,
          sellEventEmoji: _sellEventEmoji,
          sellEventColor: _sellEventColor,
          titleBonus: getTitleById(_equippedTitle).bonus,
          titleName: getTitleById(_equippedTitle).name,
          onCheckAttendance: _checkAttendance,
          onShowGachaDialog: _showGachaDialog,
          onShowSynthesisDialog: _showSynthesisDialog,
          onShowBossSelectDialog: _showBossSelectDialog,
          onShowRankingDialog: _showRankingDialog,
          onClaimQuestReward: _claimQuestReward,
        );
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home, '홈'),
          _buildNavItem(1, Icons.inventory_2, '인벤토리'),
          _buildNavItem(2, Icons.auto_awesome, '강화'),
          _buildNavItem(3, Icons.sports_mma, '배틀'),
          _buildNavItem(4, Icons.more_horiz, '더보기'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.amber : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.amber : Colors.grey,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotification() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_notificationImage != null) ...[
            Image.asset(_notificationImage!, width: 20, height: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              _notification!,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 홈 페이지 =====
  Widget _buildHomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 장착 검 카드
          if (_equippedSword != null) _buildEquippedSwordCard(),

          const SizedBox(height: 16),

          // 🔥 판매 이벤트 배너
          _buildSellEventBanner(),

          const SizedBox(height: 16),

          // 출석 체크
          if (_canCheckAttendance) _buildAttendanceCard(),

          const SizedBox(height: 16),

          // 퀵 메뉴
          _buildQuickMenu(),

          const SizedBox(height: 16),

          // 일일퀘스트 미리보기
          _buildQuestPreview(),
        ],
      ),
    );
  }

  // 🔥 판매 이벤트 배너 (마지막 판매 결과 표시)
  Widget _buildSellEventBanner() {
    final isGoodEvent = _sellEventRate >= 1.5;
    final isBadEvent = _sellEventRate < 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGoodEvent
              ? [Colors.green.withOpacity(0.3), Colors.green.withOpacity(0.1)]
              : isBadEvent
              ? [Colors.red.withOpacity(0.3), Colors.red.withOpacity(0.1)]
              : [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _sellEventColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Text(_sellEventEmoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '마지막 판매: $_sellEventName',
                      style: TextStyle(
                        color: _sellEventColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _sellEventColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_sellEventRate}배',
                        style: TextStyle(
                          color: _sellEventColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '💡 판매할 때마다 랜덤 이벤트 적용!',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(
            Icons.casino, // 랜덤 아이콘
            color: _sellEventColor,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildEquippedSwordCard() {
    final sword = _equippedSword!;
    final grade = sword.data.grade;
    final element = sword.data.element;
    final skills = sword.data.skills;
    final enhanceBonus = sword.level * sword.powerPerLevel;

    return Container(
      decoration: AppDecorations.glowCard(grade.color, blurRadius: 20),
      child: Column(
        children: [
          // ✅ 상단: 검 기본 정보
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // 검 이미지 (SwordImageWidget)
                SwordImageWidget(
                  grade: grade,
                  element: element,
                  level: sword.level,
                  size: 80,
                  showPulse: true,
                ),
                const SizedBox(width: 16),
                // 검 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 등급 배지
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: grade.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          grade.displayName,
                          style: TextStyle(
                            color: grade.color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 검 이름
                      Text(
                        sword.data.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // 강화 레벨
                      Text(
                        '+${sword.level}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ✅ 중간: 스탯 정보
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.2)),
            child: Row(
              children: [
                // 속성
                Expanded(
                  child: _buildStatItem(
                    Text(element.emoji, style: const TextStyle(fontSize: 16)),
                    '속성',
                    element.nameKr,
                    Colors.cyan,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white10),
                // 전투력
                Expanded(
                  child: _buildStatItem(
                    Image.asset('assets/images/home/fighting_power.png'),
                    '전투력',
                    '${sword.totalPower}',
                    Colors.amber,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white10),
                // 기본 공격력
                Expanded(
                  child: _buildStatItem(
                    Image.asset('assets/images/home/fighting_basic.png'),
                    '기본ATK',
                    '${sword.data.baseAtk}',
                    Colors.red,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white10),
                // 강화 보너스
                Expanded(
                  child: _buildStatItem(
                    Image.asset('assets/images/home/fighting_enhance.png'),
                    '강화',
                    '+$enhanceBonus',
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ),

          // ✅ 하단: 스킬 정보
          if (skills.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.purple[300],
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '스킬 (${skills.length}개)',
                        style: TextStyle(
                          color: Colors.purple[300],
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...skills.map((skill) => _buildSkillRow(skill)),
                ],
              ),
            ),

          // ✅ 판매가 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '💰 판매가: ${formatNumber(sword.sellPrice)}G',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 스탯 아이템 위젯
  Widget _buildStatItem(Widget icon, String label, String value, Color color) {
    return Column(
      children: [
        SizedBox(width: 20, height: 20, child: icon),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ✅ 스킬 행 위젯
  Widget _buildSkillRow(SkillData skill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(skill.type.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${skill.type.nameKr} · ${skill.effect.nameKr}',
                  style: TextStyle(color: Colors.purple[200], fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${skill.procRate}%',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard() {
    // ✅ 예상 보상 계산
    final expectedReward = AppConstants.getAttendanceGold(
      _attendanceStreak + 1,
    );
    final isWeeklyBonus = (_attendanceStreak + 1) % 7 == 0;

    return GestureDetector(
      onTap: _checkAttendance,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.gradientCard([
          Colors.green.withOpacity(0.6),
          Colors.green,
        ]),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '출석 체크',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // ✅ 0일일 때 다른 메시지
                  Text(
                    _attendanceStreak > 0
                        ? '$_attendanceStreak일 연속 출석 중!'
                        : '첫 출석 보상을 받으세요!',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  // ✅ 예상 보상 표시
                  Text(
                    '보상: ${formatNumber(expectedReward)}G${isWeeklyBonus ? " + ${AppConstants.weeklyAttendanceDiamond}💎" : ""}',
                    style: const TextStyle(color: Colors.amber, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '받기',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMenu() {
    return Row(
      children: [
        _buildQuickMenuItem('🎰', '뽑기', () => _showGachaDialog()),
        const SizedBox(width: 8),
        _buildQuickMenuItem('🔄', '합성', () => _showSynthesisDialog()),
        const SizedBox(width: 8),
        _buildQuickMenuItem('🐉', '보스', () => _showBossSelectDialog()),
        const SizedBox(width: 8),
        _buildQuickMenuItem('🏆', '랭킹', () => _showRankingDialog()),
      ],
    );
  }

  Widget _buildQuickMenuItem(String icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: AppDecorations.card(),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestPreview() {
    final incomplete = _dailyQuests.where((q) => !q.claimed).take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '일일 퀘스트',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...incomplete.map(
          (quest) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: AppDecorations.card(),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        quest.progressText,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (quest.isCompleted && !quest.claimed)
                  ElevatedButton(
                    onPressed: () => _claimQuestReward(quest),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      '수령',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // _claimQuestReward 수정
  void _claimQuestReward(DailyQuest quest) {
    if (!quest.isCompleted || quest.claimed) return;

    setState(() {
      quest.claimed = true;

      // ✅ 다양한 보상 지급
      if (quest.rewardGold > 0) {
        _gold += quest.rewardGold;
      }
      if (quest.rewardDiamond > 0) {
        _diamond += quest.rewardDiamond;
      }
      if (quest.rewardStone > 0) {
        _enhanceStone += quest.rewardStone;
      }

      // ✅ 시즌패스 경험치
      if (quest.rewardSeasonExp > 0) {
        _addSeasonPassExp(quest.rewardSeasonExp);
      }

      // ✅ 통계 업데이트
      _totalQuestsCompleted++;

      _showNotification('🎁 보상 획득: ${quest.rewardText}');
      _checkAchievements();
      _saveGameData();
    });
  }

  // ===== 인벤토리/강화/배틀/더보기 페이지 (간략화) =====
  Widget _buildInventoryPage() {
    final itemCount = _inventory.length;
    final maxCount = _maxInventory;
    final isFull = itemCount >= maxCount;

    return Column(
      children: [
        // ✅ 상단: 인벤토리 용량 표시
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.inventory_2,
                color: isFull ? Colors.red : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '인벤토리',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isFull
                      ? Colors.red.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFull ? Colors.red : Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  '$itemCount / $maxCount',
                  style: TextStyle(
                    color: isFull ? Colors.red : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isFull) ...[
                const SizedBox(width: 8),
                Text(
                  '가득 참!',
                  style: TextStyle(
                    color: Colors.red[300],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),

        // ✅ 그리드 목록
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: _inventory.length,
            itemBuilder: (_, i) {
              final sword = _inventory[i];
              final isEquipped = _equippedSword?.uid == sword.uid;
              return GestureDetector(
                onTap: () => _showSwordDetailDialog(sword),
                child: Container(
                  decoration: BoxDecoration(
                    color: sword.data.grade.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isEquipped
                          ? Colors.amber
                          : sword.data.grade.color.withOpacity(0.5),
                      width: isEquipped ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 검 이미지
                      SwordImageWidget(
                        grade: sword.data.grade,
                        element: sword.data.element,
                        level: sword.level,
                        breakthroughLevel: sword.breakthroughLevel,
                        size: 60,
                        showPulse: false,
                      ),
                      // 장착 표시
                      if (isEquipped)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 10,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      // 검 이름
                      Positioned(
                        bottom: 4,
                        child: Text(
                          sword.data.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancePage() {
    if (_equippedSword == null) {
      return const Center(
        child: Text('장착된 검이 없습니다', style: TextStyle(color: Colors.white54)),
      );
    }

    final sword = _equippedSword!;
    final cost = getEnhanceCost(sword.level);
    final successRate = getEnhanceSuccessRate(sword.level);
    final destroyRate = getEnhanceDestroyRate(sword.level);
    final canSell = true; // 🔥 검 1개여도 판매 가능

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // 검 정보 카드 (콤팩트)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AppDecorations.glowCard(
              sword.data.grade.color,
              blurRadius: 20,
            ),
            child: Row(
              children: [
                // 🔥 SwordImageWidget (작게)
                SwordImageWidget(
                  grade: sword.data.grade,
                  element: sword.data.element,
                  level: sword.level,
                  breakthroughLevel: sword.breakthroughLevel,
                  size: 100,
                  showPulse: true,
                  showEnhanceEffect: _showEnhanceEffect,
                ),
                const SizedBox(width: 12),
                // 검 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sword.data.name,
                        style: TextStyle(
                          color: sword.data.grade.color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '⚡ ${sword.totalPower}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '💰 ${formatNumber(sword.sellPrice)}G',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 비용
                      Row(
                        children: [
                          const Text(
                            '강화 비용: ',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '$cost G',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 확률 표시 (성공 / 유지 / 파괴)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildProbBox(
                    '✅ 성공',
                    formatPercent(successRate),
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildProbBox(
                    '➖ 유지',
                    formatPercent(100 - successRate - destroyRate),
                    Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildProbBox(
                    '💥 파괴',
                    formatPercent(destroyRate),
                    destroyRate > 0 ? Colors.red : Colors.grey[700]!,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 강화석 (콤팩트)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _useEnhanceStone,
                  onChanged: (v) =>
                      setState(() => _useEnhanceStone = v ?? false),
                  activeColor: Colors.purple,
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Text(
                    '강화석 사용 (성공+10%, 파괴-5%) 보유: $_enhanceStone개',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ✅ 판매 + 구매 + 강화 버튼
          Row(
            children: [
              // 판매 버튼
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canSell ? () => _sellSword(sword) : null,
                  icon: const Icon(Icons.sell, size: 16),
                  label: const Text('판매'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 🔥 구매 버튼 (1회)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _gold >= 500 && _inventory.length < _maxInventory
                      ? () => _quickGacha(1)
                      : null,
                  icon: const Icon(Icons.add_box, size: 16),
                  label: const Text('구매'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 강화 버튼
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _gold >= cost && sword.level < 30
                      ? _enhance
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    '강화하기',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhanceInfo(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildProbBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattlePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 남은 배틀 횟수
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.card(
              borderColor: Colors.red.withOpacity(0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sports_mma, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  '남은 배틀: $_battleCount/${AppConstants.dailyBattleCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          if (_battleWinStreak > 0) ...[
            const SizedBox(height: 12),
            Text(
              '🔥 $_battleWinStreak연승 중!',
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ✅ 배틀 버튼들 (가로 배치)
          Row(
            children: [
              // 랜덤 배틀
              Expanded(
                child: ElevatedButton(
                  onPressed: _battleCount > 0 && _equippedSword != null
                      ? () => _startBattle()
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.casino, size: 28, color: Colors.white),
                      SizedBox(height: 4),
                      Text(
                        '랜덤 배틀',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ✅ 지정 배틀 버튼 추가
              Expanded(
                child: ElevatedButton(
                  onPressed: _battleCount > 0 && _equippedSword != null
                      ? _showBattleSelectScreen
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.person_search, size: 28, color: Colors.white),
                      SizedBox(height: 4),
                      Text(
                        '지정 배틀',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ✅ 배틀 기록 섹션
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '최근 배틀 기록',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${_battleRecords.length}건',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(width: 8),
                  // 🔄 새로고침 버튼
                  GestureDetector(
                    onTap: () async {
                      _showNotification('배틀 기록을 새로고침 중...');
                      await _fetchBattleNotifications();
                      if (mounted) setState(() {});
                    },
                    child: const Icon(
                      Icons.refresh,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ✅ 배틀 기록 목록
          if (_battleRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '배틀 기록이 없습니다',
                style: TextStyle(color: Colors.white54),
              ),
            )
          else
            ..._battleRecords
                .take(10)
                .map((record) => _buildBattleRecordItem(record)),
        ],
      ),
    );
  }

  // ✅ 배틀 기록 아이템 위젯
  Widget _buildBattleRecordItem(BattleRecord record) {
    // 공격/방어에 따른 결과 텍스트
    String resultText;
    if (record.isAttacker) {
      resultText = record.isWin ? '승리' : '패배';
    } else {
      resultText = record.isWin ? '방어 성공' : '방어 실패';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(
        borderColor: record.isWin
            ? Colors.green.withOpacity(0.3)
            : Colors.red.withOpacity(0.3),
      ),
      child: Row(
        children: [
          // 승패 아이콘
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: record.isWin
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    record.isWin ? '승' : '패',
                    style: TextStyle(
                      color: record.isWin ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    record.isAttacker ? '공격' : '방어',
                    style: TextStyle(
                      color: record.isAttacker ? Colors.orange : Colors.blue,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 상대 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.opponentName} ${record.opponentIsNpc ? "(AI)" : ""}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Lv.${record.opponentLevel} • ${record.timeAgo}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 2),
                // 결과 텍스트
                Text(
                  resultText,
                  style: TextStyle(
                    color: record.isWin ? Colors.green : Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 보상 또는 복수전 버튼
          if (record.isWin && record.goldEarned > 0)
            Text(
              '+${formatNumber(record.goldEarned)}G',
              style: const TextStyle(color: Colors.amber),
            )
          else if (record.isWin && !record.isAttacker)
            const Text('🛡️', style: TextStyle(fontSize: 20)) // 방어 성공
          else if (record.isRevengeable)
            ElevatedButton(
              onPressed: _battleCount > 0
                  ? () => _startRevengeMatch(record)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              child: const Text(
                '복수전',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ 배틀 결과 다이얼로그 (로그 포함)
  void _showBattleResultDialog({
    required bool isWin,
    required String opponentName,
    required int goldReward,
    required List<String> logs,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isWin
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isWin ? Colors.green : Colors.red),
              ),
              child: Text(
                isWin ? '🎉 승리!' : '😢 패배',
                style: TextStyle(
                  color: isWin ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'vs $opponentName',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 보상 표시
              if (isWin)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        '+${formatNumber(goldReward)} 골드 획득!',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              const Text(
                '📜 배틀 로그',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),

              // 배틀 로그
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (_, i) {
                      final log = logs[i];
                      Color logColor = Colors.white70;
                      if (log.contains('크리티컬') || log.contains('치명타')) {
                        logColor = Colors.orange;
                      } else if (log.contains('회복') || log.contains('흡혈')) {
                        logColor = Colors.green;
                      } else if (log.contains('기절') || log.contains('실패')) {
                        logColor = Colors.red;
                      } else if (log.contains('승리')) {
                        logColor = Colors.amber;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${i + 1}. $log',
                          style: TextStyle(
                            color: logColor,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // ✅ 복수전 시작 함수 (상대방 실시간 정보 사용)
  Future<void> _startRevengeMatch(BattleRecord record) async {
    // NPC면 바로 배틀
    if (record.opponentIsNpc) {
      final oppElement = GameElement.values.firstWhere(
        (e) => e.name == record.opponentElement,
        orElse: () => GameElement.fire,
      );
      _startBattle(
        playerOpponent: {
          'id': record.opponentId,
          'name': record.opponentName,
          'swordLevel': record.opponentLevel,
          'swordGrade': SwordGrade.values.firstWhere(
            (g) => g.name == record.opponentGrade,
            orElse: () => SwordGrade.normal,
          ),
          'isNpc': true,
          'power': 100 + record.opponentLevel * 10,
          'element': oppElement,
        },
        isRevenge: true,
      );
      return;
    }

    // 온라인 플레이어면 실시간 정보 가져오기
    if (_onlineService == null) {
      _showNotification('오프라인 상태에서는 복수전이 불가능합니다');
      return;
    }

    _showNotification('상대방 정보를 불러오는 중...');

    try {
      final profile = await _onlineService!.fetchById(record.opponentId);

      if (profile == null) {
        _showNotification('상대방을 찾을 수 없습니다');
        return;
      }

      // 검이 없는 경우 체크
      if (profile.swordId.isEmpty ||
          profile.swordId == 'sword_001' && profile.swordLevel == 0) {
        _showNotification('현재 상대방이 장착중인 검이 없습니다');
        return;
      }

      // 실시간 정보로 배틀 시작
      _startBattle(
        playerOpponent: {
          'id': profile.userId,
          'name': profile.nickname,
          'swordLevel': profile.swordLevel,
          'swordGrade': profile.grade,
          'swordId': profile.swordId,
          'isNpc': false,
          'power': profile.power,
          'element': profile.element,
        },
        isRevenge: true,
      );
    } catch (e) {
      debugPrint('복수전 상대 정보 로드 실패: $e');
      _showNotification('상대방 정보를 불러오지 못했습니다');
    }
  }

  // ✅ 지정 배틀 화면 열기
  Future<void> _showBattleSelectScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BattleSelectScreen(
          online: _onlineService,
          myUserId: widget.userId,
          friendIds: _friendIds,
          myElement: _equippedSword?.data.element,
        ),
      ),
    );

    if (result != null && result is OpponentEntry) {
      // 🔥 NPC가 아니면 실시간 정보 조회 (복수전과 동일)
      if (!result.isNpc && _onlineService != null) {
        try {
          final profile = await _onlineService!.fetchById(result.id);
          if (profile == null) {
            _showNotification('상대방 정보를 불러오지 못했습니다');
            return;
          }

          // 검이 없는 경우 체크
          if (profile.swordId.isEmpty) {
            _showNotification('현재 상대방이 장착중인 검이 없습니다');
            return;
          }

          // 🔥 실시간 정보로 배틀 시작
          _startBattle(
            playerOpponent: {
              'id': profile.userId,
              'name': profile.nickname,
              'swordLevel': profile.swordLevel,
              'swordGrade': profile.grade,
              'swordId': profile.swordId,
              'isNpc': false,
              'power': profile.power,
              'element': profile.element,
            },
          );
        } catch (e) {
          debugPrint('지정 배틀 상대 정보 로드 실패: $e');
          _showNotification('상대방 정보를 불러오지 못했습니다');
        }
      } else {
        // NPC는 기존 데이터 사용
        _startBattle(
          playerOpponent: {
            'id': result.id,
            'name': result.name,
            'swordLevel': result.swordLevel,
            'swordGrade': result.sword.grade,
            'swordId': result.sword.id,
            'isNpc': result.isNpc,
            'power': result.power,
            'element': result.sword.element,
          },
        );
      }
    }
  }

  Widget _buildMorePage() {
    final adService = AdService();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMoreItem('🎰', '검 뽑기', '새로운 검을 뽑아보세요', _showGachaDialog),
        _buildMoreItem('🔄', '합성', '검 3개로 상위 등급 도전', _showSynthesisDialog),
        _buildMoreItem('🐉', '보스 레이드', '강력한 보스에 도전', _showBossSelectDialog),

        _buildMoreItem('🏪', '상점', '아이템 구매/인벤 확장', _openShopScreen),
        _buildMoreItem('🎟️', '시즌 패스', '보상 확인 및 수령', _openSeasonPassScreen),
        _buildMoreItem('🏅', '업적', '업적/보상 확인', _openAchievementsScreen),

        _buildMoreItem('🏆', '랭킹', '전체 순위 확인', _showRankingDialog),
        _buildMoreItem(
          '👥',
          '친구',
          '친구 추가/관리',
          _openFriendsScreen,
        ), // 👥 친구 메뉴 추가
        _buildMoreItem('🎖️', '칭호', '획득한 칭호 관리', _showTitleDialog),
        _buildMoreItem('📚', '도감', '수집한 검 도감', _showCodexDialog),
        _buildMoreItem('📊', '통계', '게임 통계', _showStatsDialog),

        const SizedBox(height: 16),
        const Divider(color: Colors.white24),

        // 🎬 광고 보상 섹션
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '🎬 광고 보상',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),

        // 무료 고급 뽑기
        _buildAdRewardItem(
          Image.asset(
            'assets/images/home/header/diamond.png',
            width: 28,
            height: 28,
          ),
          '무료 고급 뽑기',
          '광고 보고 다이아 뽑기 1회!',
          adService.getRemainingAdCount(AdRewardType.freeGacha),
          1,
          adService.canWatchAd(AdRewardType.freeGacha),
          _watchAdForFreeGacha,
        ),

        // 강화석 획득
        _buildAdRewardItem(
          Image.asset(
            'assets/images/home/header/enhance_mythic.png',
            width: 28,
            height: 28,
          ),
          '강화석 획득',
          '광고 보고 강화석 3개 획득!',
          adService.getRemainingAdCount(AdRewardType.stoneReward),
          3,
          adService.canWatchAd(AdRewardType.stoneReward),
          _watchAdForStones,
        ),

        const SizedBox(height: 16),
        const Divider(color: Colors.white24),
        const SizedBox(height: 8),

        // 🌐 공식 웹사이트
        _buildMoreItem(
          '🌐',
          '공식 웹사이트',
          '공지사항 및 업데이트 정보',
          () => launchUrl(
            Uri.parse('https://www.opentheday.site/'),
            mode: LaunchMode.externalApplication,
          ),
        ),

        // 🔥 도움말 추가
        _buildMoreItem('❓', '도움말', '게임 가이드 및 속성 상성표', _showHelpDialog),

        // ⚙️ 설정 추가
        _buildMoreItem('⚙️', '설정', '사운드, 알림 설정', _showSettingsDialog),

        // ✅ 로그아웃 버튼
        _buildMoreItem('🚪', '로그아웃', '계정에서 로그아웃', _showLogoutDialog),

        // ❌ 계정 삭제 버튼
        _buildMoreItem(
          '❌',
          '계정 삭제',
          '계정 및 모든 데이터 삭제',
          _showDeleteAccountDialog,
        ),
      ],
    );
  }

  // 🎬 광고 보상 아이템 위젯
  Widget _buildAdRewardItem(
    Widget icon,
    String title,
    String sub,
    int remaining,
    int max,
    bool canWatch,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: canWatch ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: canWatch
              ? LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.2),
                    Colors.blue.withOpacity(0.2),
                  ],
                )
              : null,
          color: canWatch ? null : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canWatch
                ? Colors.green.withOpacity(0.5)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 32, height: 32, child: Center(child: icon)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: canWatch ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      color: canWatch ? Colors.white54 : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: canWatch ? Colors.green : Colors.grey,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                canWatch ? '🎬 $remaining/$max' : '완료',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎬 광고로 무료 고급 뽑기
  void _watchAdForFreeGacha() async {
    // ⚠️ 인벤토리 체크 (광고 소모 전 차단)
    if (_inventory.length >= _maxInventory) {
      _showNotification('인벤토리가 가득 찼습니다! 검을 판매하거나 확장하세요.');
      return;
    }

    final adService = AdService();

    if (!adService.isRewardedAdReady) {
      _showNotification('광고를 불러오는 중...');
      return;
    }

    await adService.showRewardedAd(
      type: AdRewardType.freeGacha,
      onRewarded: () {
        // 고급 뽑기 1회 실행
        _doPremiumGacha(1, isFree: true);
      },
      onError: (msg) => _showNotification(msg),
    );
  }

  // 🎬 광고로 강화석 획득
  void _watchAdForStones() async {
    final adService = AdService();

    if (!adService.isRewardedAdReady) {
      _showNotification('광고를 불러오는 중...');
      return;
    }

    await adService.showRewardedAd(
      type: AdRewardType.stoneReward,
      onRewarded: () {
        setState(() {
          _enhanceStone += 3;
          _showImageNotification(
            '강화석 3개 획득!',
            'assets/images/home/header/enhance_mythic.png',
          );
          _saveGameData();
        });
      },
      onError: (msg) => _showNotification(msg),
    );
  }

  Widget _buildMoreItem(
    String icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  // ✅ 로그아웃 확인 다이얼로그
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: const Text('🚪 로그아웃', style: TextStyle(color: Colors.white)),
        content: const Text(
          '정말 로그아웃 하시겠습니까?\n\n게임 데이터는 저장되어 있으며,\n다시 로그인하면 이어서 플레이할 수 있습니다.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('로그아웃', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ✅ 실제 로그아웃 처리
  Future<void> _performLogout() async {
    try {
      // ✅ 1단계: 캐시에만 쓰기 (saveToCloud 호출 안 함!)
      //    → fire-and-forget 저장이 signOut 후 실패하여
      //      _saveToLocalBackup으로 데이터 누출되는 것 방지
      _saveGameData(cloudSave: false);

      // ✅ 2단계: 단 한 번만 강제 저장 (디바운싱 무시, await 완료 보장)
      await _storage.saveToCloud(force: true);

      // ✅ 3단계: Firebase 로그아웃
      await AuthService().signOut();

      // ✅ 4단계: 모든 서비스의 로컬 상태 완전 초기화
      await StorageService().resetForLogout();
      await AdService().resetForLogout();
      await PurchaseService().resetForLogout();

      // 로그인 화면으로 이동 (모든 화면 제거)
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      _showNotification('로그아웃 실패: $e');
    }
  }

  // ❌ 계정 삭제 확인 다이얼로그
  void _showDeleteAccountDialog() {
    final TextEditingController confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: const Text('❌ 계정 삭제', style: TextStyle(color: Colors.red)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚠️ 경고: 이 작업은 되돌릴 수 없습니다!\n\n'
                '계정을 삭제하면 모든 데이터가 삭제됩니다.\n\n'
                '정말 삭제하시려면 "삭제합니다"를 입력하세요:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '삭제합니다',
                  hintStyle: TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (confirmController.text == '삭제합니다') {
                Navigator.pop(context);
                _performDeleteAccount();
              } else {
                _showNotification('정확히 "삭제합니다"를 입력해주세요');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('계정 삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ❌ 실제 계정 삭제 처리
  Future<void> _performDeleteAccount() async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // 1. Firestore 데이터 삭제
      final uid = AuthService().uid;
      if (uid != null) {
        await _storage.deleteAllUserData(uid);
      }

      // 2. Firebase Auth 계정 삭제
      final result = await AuthService().deleteAccount();

      // 로딩 닫기
      if (mounted) Navigator.pop(context);

      if (result.isSuccess) {
        // 3. 로컬 데이터 초기화
        await _storage.resetForLogout(); // ✅ SharedPreferences 백업 포함 삭제
        await AdService().resetForLogout();
        await PurchaseService().resetForLogout();

        // 4. 로그인 화면으로 이동
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else if (result.errorMessage == 'REQUIRES_RECENT_LOGIN') {
        // ✅ 재인증 필요 - 비밀번호 입력 다이얼로그 표시
        _showReauthenticateDialog();
      } else {
        _showNotification('계정 삭제 실패: ${result.errorMessage}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // 로딩 닫기
      _showNotification('계정 삭제 실패: $e');
    }
  }

  // ✅ 재인증 다이얼로그
  void _showReauthenticateDialog() {
    final passwordController = TextEditingController();
    final user = AuthService().currentUser;
    final email = user?.email ?? '';

    // 익명 계정이면 바로 재로그인 안내
    if (user?.isAnonymous == true) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a4a),
          title: const Text('재로그인 필요', style: TextStyle(color: Colors.white)),
          content: const Text(
            '보안을 위해 다시 로그인이 필요합니다.\n\n'
            '로그아웃 후 다시 로그인해주세요.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await AuthService().signOut();
                // ✅ 로컬 캐시 초기화 (SharedPreferences 백업 포함 삭제)
                await StorageService().resetForLogout();
                await AdService().resetForLogout();
                await PurchaseService().resetForLogout();
                if (mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('로그아웃', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: const Text('비밀번호 확인', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '보안을 위해 비밀번호를 다시 입력해주세요.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '계정: $email',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '비밀번호',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _reauthenticateAndDelete(email, passwordController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('확인 후 삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ✅ 재인증 후 삭제
  Future<void> _reauthenticateAndDelete(String email, String password) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // 재인증
      final reauthResult = await AuthService().reauthenticateWithEmail(
        email: email,
        password: password,
      );

      if (!reauthResult.isSuccess) {
        if (mounted) Navigator.pop(context);
        _showNotification('비밀번호가 틀렸습니다');
        return;
      }

      // 재인증 성공 → 계정 삭제
      final deleteResult = await AuthService().deleteAccount();

      if (mounted) Navigator.pop(context);

      if (deleteResult.isSuccess) {
        await _storage.resetForLogout(); // ✅ SharedPreferences 백업 포함 삭제
        await AdService().resetForLogout();
        await PurchaseService().resetForLogout();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        _showNotification('계정 삭제 실패: ${deleteResult.errorMessage}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showNotification('계정 삭제 실패: $e');
    }
  }

  Future<void> _openShopScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopScreen(
          gold: _gold,
          diamond: _diamond,
          enhanceStone: _enhanceStone,
          battleCount: _battleCount,
          battleRefillCount: _battleRefillCount,
          maxInventory: _maxInventory,
          hasPremiumPass: _hasPremiumPass,
        ),
      ),
    );

    if (result is Map) {
      setState(() {
        _gold = result['gold'] as int;
        _diamond = result['diamond'] as int;
        _enhanceStone = result['stone'] as int;
        _battleCount = result['battleCount'] as int;
        _battleRefillCount = result['battleRefillCount'] as int;
        _maxInventory = result['maxInventory'] as int;
        _hasPremiumPass = result['hasPremiumPass'] as bool? ?? _hasPremiumPass;
        _saveGameData();
      });
    }
  }

  Future<void> _openSeasonPassScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeasonPassScreen(
          level: _seasonPassLevel,
          exp: _seasonPassExp,
          expPerLevel: AppConstants.expPerLevel,
          maxLevel: AppConstants.maxSeasonPassLevel,
          claimedRewards: _claimedSeasonRewards,
          hasPremiumPass: _hasPremiumPass,
          claimedPremiumRewards: _claimedPremiumRewards,
          diamond: _diamond,
          todaySeasonExp: _todaySeasonExp, // ✅ 추가
          maxDailySeasonExp: _maxDailySeasonExp, // ✅ 추가
          onClaimFreeReward: (int level) {
            if (_claimedSeasonRewards.contains(level)) return;
            if (_seasonPassLevel < level) return;

            final rewards = getSeasonPassRewards(
              maxLevel: AppConstants.maxSeasonPassLevel,
            );
            final reward = rewards.firstWhere((r) => r.level == level);

            setState(() {
              _claimedSeasonRewards.add(level);
              _gold += reward.gold;
              _diamond += reward.diamond;
              _enhanceStone += reward.stone;
              _showNotification(
                '일반 보상 수령! '
                '+${formatNumber(reward.gold)}G'
                '${reward.diamond > 0 ? ' +${reward.diamond}💎' : ''}'
                '${reward.stone > 0 ? ' +${reward.stone}🔮' : ''}',
              );
              _saveGameData();
            });
          },
          onClaimPremiumReward: (int level) {
            if (!_hasPremiumPass) return;
            if (_claimedPremiumRewards.contains(level)) return;
            if (_seasonPassLevel < level) return;

            final rewards = getSeasonPassRewards(
              maxLevel: AppConstants.maxSeasonPassLevel,
            );
            final reward = rewards.firstWhere((r) => r.level == level);

            setState(() {
              _claimedPremiumRewards.add(level);
              _gold += reward.premiumGold;
              _diamond += reward.premiumDiamond;
              _enhanceStone += reward.premiumStone;
              _showNotification(
                '👑 프리미엄 보상 수령! '
                '+${formatNumber(reward.premiumGold)}G'
                '${reward.premiumDiamond > 0 ? ' +${reward.premiumDiamond}💎' : ''}'
                '${reward.premiumStone > 0 ? ' +${reward.premiumStone}🔮' : ''}',
              );
              _saveGameData();
            });
          },
          onBuyPremiumPass: () {
            if (_hasPremiumPass) {
              _showNotification('이미 프리미엄 패스를 보유하고 있습니다');
              return;
            }
            // 💰 인앱 결제 시작
            _purchaseService.purchaseByShopId('premium_pass');
          },
        ),
      ),
    );
  }

  Future<void> _openAchievementsScreen() async {
    // 최신 언락 갱신 (변경 시에만 저장 - Firebase 비용 절감)
    final prevCount = _unlockedAchievements.length;
    _checkAchievementsFull();
    if (_unlockedAchievements.length > prevCount) {
      _saveGameData();
    }

    final maxSwordLevel = _inventory.fold<int>(
      _equippedSword?.level ?? 0,
      (maxLevel, sword) => sword.level > maxLevel ? sword.level : maxLevel,
    );
    final breakthroughSwordCount = _inventory
        .where((sword) => sword.breakthroughLevel > 0)
        .length;

    final stats = <String, int>{
      'totalEnhanceAttempts': _totalEnhanceAttempts,
      'totalEnhanceSuccess': _totalEnhanceSuccess,
      'totalDestroy': _totalDestroy,
      'maxConsecutiveSuccess': _maxConsecutiveSuccess,
      'totalStoneUsed': _totalStoneUsed,
      'maxSwordLevel': maxSwordLevel,
      'breakthroughSwordCount': breakthroughSwordCount,
      'totalBattle': _totalBattle,
      'totalBattleWin': _totalBattleWin,
      'maxWinStreak': _maxWinStreak,
      'totalRevengeWins': _totalRevengeWins,
      'bossKills': _bossKills,
      'codexCount': _codex.length,
      'totalSell': _totalSell,
      'totalGacha': _totalGacha,
      'totalSynthesis': _totalSynthesis,
      'totalQuestsCompleted': _totalQuestsCompleted,
      'attendanceStreak': _attendanceStreak,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AchievementsScreen(
          stats: stats,
          unlocked: _unlockedAchievements,
          claimed: _claimedAchievements,
          onClaim: (AchievementData ach) {
            if (!_unlockedAchievements.contains(ach.id)) return;
            if (_claimedAchievements.contains(ach.id)) return;
            setState(() {
              _claimedAchievements.add(ach.id);
              _gold += ach.rewardGold;
              _diamond += ach.rewardDiamond;
              _enhanceStone += ach.rewardStone;
              _showNotification(
                '업적 보상 수령! +${formatNumber(ach.rewardGold)}G'
                '${ach.rewardDiamond > 0 ? ' +${ach.rewardDiamond}💎' : ''}'
                '${ach.rewardStone > 0 ? ' +${ach.rewardStone}🔮' : ''}',
              );
              _saveGameData();
            });
          },
        ),
      ),
    );
  }

  // 👥 친구 화면 열기
  void _openFriendsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendsScreen(
          onFriendListChanged: (newFriendIds) {
            setState(() {
              _friendIds = newFriendIds;
            });
            _saveGameData();
          },
        ),
      ),
    );
  }

  void _showSwordDetailDialog(OwnedSword sword) {
    final isEquipped = _equippedSword?.uid == sword.uid;
    final canSell = true; // 🔥 검 1개여도 판매 가능

    showDialog(
      context: context,
      builder: (_) => SwordDetailDialog(
        sword: sword,
        isEquipped: isEquipped,
        canSell: canSell, // ✅ 추가
        onEquip: () {
          setState(() => _equippedSword = sword);
          _storage.equippedSwordUid = sword.uid;
          _updateRankings();
          _saveGameData();
          _syncMyProfile(); // 🔥 장비 변경 시에만 프로필 동기화
          _showNotification('${sword.data.name} 장착!');
        },
        onSell: () => _sellSword(sword),
      ),
    );
  }

  void _showGachaDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => _GachaDialog(
          gold: _gold,
          diamond: _diamond,
          inventoryCount: _inventory.length,
          maxInventory: _maxInventory,
          onNormalGacha: (count) {
            _doGacha(count);
            setDialogState(() {});
          },
          onPremiumGacha: (count) {
            _doPremiumGacha(count);
            setDialogState(() {});
          },
        ),
      ),
    );
  }

  // =====================================================
  // 🎰 뽑기 결과 다이얼로그 (단일)
  // =====================================================
  void _showGachaResultDialog(
    OwnedSword sword, {
    bool isPremium = false,
    bool isFree = false,
  }) {
    final grade = sword.data.grade;

    // 🔊 뽑기 사운드 (유니크 이상이면 레어 사운드)
    if (grade.index >= SwordGrade.unique.index) {
      SoundService().playGachaRare();
    } else {
      SoundService().playGacha();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a2e),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: grade.color, width: 2),
            boxShadow: [
              BoxShadow(
                color: grade.color.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      grade.color.withOpacity(0.4),
                      grade.color.withOpacity(0.1),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      isFree
                          ? '🎬 무료 고급 뽑기!'
                          : (isPremium ? '💎 고급 뽑기 결과!' : '🎰 뽑기 결과!'),
                      style: TextStyle(
                        color: grade.color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: grade.color.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        grade.displayName,
                        style: TextStyle(
                          color: grade.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 검 이미지
              Padding(
                padding: const EdgeInsets.all(24),
                child: SwordImageWidget(
                  grade: grade,
                  element: sword.data.element,
                  level: sword.level,
                  size: 140,
                  showPulse: true,
                ),
              ),

              // 검 정보
              Text(
                sword.data.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '⚡ ${sword.totalPower}',
                    style: const TextStyle(color: Colors.amber, fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${sword.data.element.emoji} ${sword.data.element.nameKr}',
                    style: const TextStyle(color: Colors.cyan, fontSize: 14),
                  ),
                ],
              ),

              // 확인 버튼
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: grade.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // 💎 고급 뽑기
  // =====================================================
  void _doPremiumGacha(int count, {bool isFree = false}) {
    // 비용 계산
    int cost;
    bool guaranteeUnique = false;

    if (count == 1) {
      cost = premiumGachaCostSingle;
    } else if (count == 5) {
      cost = premiumGachaCost5x;
    } else {
      cost = premiumGachaCost10x;
      guaranteeUnique = true; // 10회시 유니크 이상 1개 확정
    }

    // 무료가 아닐 때만 비용 체크
    if (!isFree && _diamond < cost) {
      _showNotification('다이아몬드가 부족합니다!');
      return;
    }

    if (_inventory.length + count > _maxInventory) {
      _showNotification('인벤토리가 가득 찼습니다!');
      return;
    }

    // 📊 Analytics용
    final newSwords = <OwnedSword>[];
    OwnedSword? bestSword;

    setState(() {
      // 무료가 아닐 때만 비용 차감
      if (!isFree) {
        _diamond -= cost;
      }
      _totalGacha += count;
      _updateQuestProgress(QuestType.gacha, count);

      bool hasUniqueOrHigher = false;
      SwordGrade? highestGrade;

      for (int i = 0; i < count; i++) {
        final swordData = _rollPremiumGacha();
        final newSword = createNewSword(swordData);
        newSwords.add(newSword);
        _inventory.add(newSword);
        _codex.add(swordData.id);

        // 유니크 이상 체크
        if (swordData.grade.index >= SwordGrade.unique.index) {
          hasUniqueOrHigher = true;
        }

        // 📊 최고 등급 추적
        if (highestGrade == null ||
            swordData.grade.index > highestGrade.index) {
          highestGrade = swordData.grade;
          bestSword = newSword;
        }
      }

      // 10회 뽑기인데 유니크 이상이 없으면 마지막 검을 유니크로 교체
      if (guaranteeUnique && !hasUniqueOrHigher) {
        // 마지막 검 제거
        _inventory.remove(newSwords.last);

        // 유니크 이상 확정 뽑기
        final guaranteedSword = _rollGuaranteedUniqueOrHigher();
        final newSword = createNewSword(guaranteedSword);
        newSwords[newSwords.length - 1] = newSword;
        _inventory.add(newSword);
        _codex.add(guaranteedSword.id);
        bestSword = newSword; // 📊 확정 뽑기가 최고 등급
      }

      // 결과 표시 (무료면 메시지 추가)
      if (count == 1) {
        _showGachaResultDialog(
          newSwords.first,
          isPremium: true,
          isFree: isFree,
        );
      } else {
        _showMultiGachaResultDialog(
          newSwords,
          isPremium: true,
          guaranteed: guaranteeUnique,
        );
      }

      _saveGameData();
    });

    // 📊 Analytics (fire-and-forget)
    if (bestSword != null) {
      AnalyticsService().logGacha(
        type: 'premium',
        resultGrade: bestSword!.data.grade.name,
        resultName: bestSword!.data.name,
      );
    }
  }

  // 💎 고급 뽑기 확률
  SwordData _rollPremiumGacha() {
    final roll = _random.nextDouble() * 100;
    double cumulative = 0;

    for (final entry in premiumGachaProbability.entries) {
      cumulative += entry.value;
      if (roll < cumulative) {
        final swords = getSwordsByGrade(entry.key);
        return swords[_random.nextInt(swords.length)];
      }
    }

    // 기본값: 레어
    final rareSwords = getSwordsByGrade(SwordGrade.rare);
    return rareSwords[_random.nextInt(rareSwords.length)];
  }

  // 유니크 이상 확정 뽑기 (10회 보너스용)
  SwordData _rollGuaranteedUniqueOrHigher() {
    // 유니크 이상만 있는 확률 테이블
    const guaranteedProbability = {
      SwordGrade.unique: 80.0,
      SwordGrade.legend: 15.0,
      SwordGrade.hidden: 4.0,
      SwordGrade.immortal: 1.0,
    };

    final roll = _random.nextDouble() * 100;
    double cumulative = 0;

    for (final entry in guaranteedProbability.entries) {
      cumulative += entry.value;
      if (roll < cumulative) {
        final swords = getSwordsByGrade(entry.key);
        return swords[_random.nextInt(swords.length)];
      }
    }

    // 기본값: 유니크
    final uniqueSwords = getSwordsByGrade(SwordGrade.unique);
    return uniqueSwords[_random.nextInt(uniqueSwords.length)];
  }

  // 다중 뽑기 결과 다이얼로그 (고급 뽑기용 확장)
  void _showMultiGachaResultDialog(
    List<OwnedSword> swords, {
    bool isPremium = false,
    bool guaranteed = false,
  }) {
    final highestGrade = swords
        .map((s) => s.data.grade)
        .reduce((a, b) => a.index > b.index ? a : b);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Flexible(
              child: Text(
                isPremium ? '💎 고급 뽑기' : '🎰 뽑기 결과',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (guaranteed) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '✨ 확정',
                  style: TextStyle(color: Colors.amber, fontSize: 10),
                ),
              ),
            ],
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 최고 등급 표시
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: highestGrade.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: highestGrade.color),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('최고 등급: ', style: TextStyle(color: Colors.white70)),
                    Text(
                      highestGrade.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      highestGrade.displayName,
                      style: TextStyle(
                        color: highestGrade.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 검 그리드
              SizedBox(
                height: 200,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: swords.length,
                  itemBuilder: (_, i) {
                    final sword = swords[i];
                    final isHighGrade =
                        sword.data.grade.index >= SwordGrade.unique.index;
                    return Container(
                      decoration: BoxDecoration(
                        color: sword.data.grade.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sword.data.grade.color,
                          width: isHighGrade ? 2 : 1,
                        ),
                        boxShadow: isHighGrade
                            ? [
                                BoxShadow(
                                  color: sword.data.grade.color.withOpacity(
                                    0.5,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ✅ 이모지 대신 SwordImageWidget 사용
                          SwordImageWidget(
                            grade: sword.data.grade,
                            element: sword.data.element,
                            level: sword.level,
                            size: 32,
                            showPulse: false,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sword.data.grade.displayName,
                            style: TextStyle(
                              color: sword.data.grade.color,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // 등급별 카운트
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: SwordGrade.values
                    .where((g) => swords.any((s) => s.data.grade == g))
                    .map((grade) {
                      final count = swords
                          .where((s) => s.data.grade == grade)
                          .length;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: grade.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${grade.emoji} x$count',
                          style: TextStyle(color: grade.color, fontSize: 12),
                        ),
                      );
                    })
                    .toList(),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: highestGrade.color,
              foregroundColor: Colors.white,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildPityBar(String label, int current, int max, Color color) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: current / max,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$current/$max',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  void _showSynthesisDialog() {
    showDialog(
      context: context,
      builder: (_) => SynthesisDialog(
        inventory: _inventory,
        equippedSwordUid: _equippedSword?.uid,
        normalToRarePity: _normalToRarePity,
        rareToUniquePity: _rareToUniquePity,
        uniqueToLegendPity: _uniqueToLegendPity,
        // 🔥 합성 후 새 pity 값 반환
        onSynthesize: (selectedSwords, {bool showResult = true}) {
          _synthesize(selectedSwords, showResult: showResult);
          return {
            'normalToRare': _normalToRarePity,
            'rareToUnique': _rareToUniquePity,
            'uniqueToLegend': _uniqueToLegendPity,
          };
        },
      ),
    );
  }

  void _showBossSelectDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: Row(
          children: [
            const Expanded(
              child: Text('🐉 보스 레이드', style: TextStyle(color: Colors.white)),
            ),
            Text(
              '🧿 $_bossCore',
              style: const TextStyle(color: Color(0xFF80DEEA), fontSize: 14),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allBosses.length,
            itemBuilder: (_, i) {
              final boss = allBosses[i];
              final cd = _bossCooldowns[boss.id];
              final now = _storage.serverNow; // ✅ 서버 시간
              final onCooldown = cd != null && cd.isAfter(now);

              // ✅ 최소 레벨 조건
              final myLevel = _equippedSword?.level ?? 0;
              final canChallenge =
                  (myLevel >= boss.minLevel) && _equippedSword != null;

              // 🔥 상성 계산
              final myElement = _equippedSword?.data.element;
              String? advantageText;
              Color? advantageColor;
              if (myElement != null) {
                if (myElement.strongAgainst == boss.element) {
                  advantageText = '유리 ▲';
                  advantageColor = Colors.green;
                } else if (myElement.weakAgainst == boss.element) {
                  advantageText = '불리 ▼';
                  advantageColor = Colors.red;
                }
              }

              // ✅ 쿨다운 남은 시간 계산
              String cooldownText = '';
              if (onCooldown) {
                final remaining = cd!.difference(now);
                if (remaining.inHours > 0) {
                  cooldownText =
                      '${remaining.inHours}시간 ${remaining.inMinutes % 60}분';
                } else {
                  cooldownText = '${remaining.inMinutes}분';
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: boss.element.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: boss.element.color.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 보스 이름 & 난이도
                    Row(
                      children: [
                        // 보스 이미지 또는 이모지
                        boss.hasImage
                            ? ClipOval(
                                child: Image.asset(
                                  boss.imagePath!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text(
                                      boss.element.emoji,
                                      style: const TextStyle(fontSize: 28),
                                    );
                                  },
                                ),
                              )
                            : Text(
                                boss.element.emoji,
                                style: const TextStyle(fontSize: 28),
                              ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      boss.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // 🔥 상성 표시
                                  if (advantageText != null) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: advantageColor!.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: advantageColor.withOpacity(
                                            0.5,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        advantageText,
                                        style: TextStyle(
                                          color: advantageColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '난이도: ${boss.difficulty}',
                                style: TextStyle(
                                  color: boss.element.color,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ✅ 보스 스탯 표시 (Wrap으로 오버플로우 방지)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _bossStatChip('HP', '${boss.hp}'),
                        _bossStatChip('ATK', '${boss.atk}'),
                        _bossStatChip('Lv', '+${boss.minLevel}'),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 보상
                    Text(
                      '보상: ${boss.goldReward}G + ${boss.diamondReward}💎'
                      ' / 코어 ${boss.coreDropMin}~${boss.coreDropMax}개 (${(boss.coreDropChance * 100).round()}%)',
                      style: const TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    // 도전 버튼 또는 광고 스킵 버튼
                    if (onCooldown && canChallenge) ...[
                      // 🎬 광고로 쿨다운 스킵
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                              ),
                              child: Text(
                                '쿨다운 ($cooldownText)',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  AdService().canWatchAd(AdRewardType.bossSkip)
                                  ? () {
                                      Navigator.pop(context);
                                      _watchAdToSkipBossCooldown(boss);
                                    }
                                  : null,
                              icon: const Text(
                                '🎬',
                                style: TextStyle(fontSize: 14),
                              ),
                              label: Text(
                                '광고로 스킵 (${AdService().getRemainingAdCount(AdRewardType.bossSkip)}/3)',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (!onCooldown && canChallenge)
                              ? () {
                                  Navigator.pop(context);
                                  _startBossRaid(boss);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: boss.element.color,
                          ),
                          child: Text(
                            !canChallenge
                                ? '레벨 부족 (+${boss.minLevel} 필요)'
                                : '도전!',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 🎬 광고로 보스 쿨다운 스킵
  void _watchAdToSkipBossCooldown(BossData boss) async {
    final adService = AdService();

    if (!adService.isRewardedAdReady) {
      _showNotification('광고를 불러오는 중...');
      return;
    }

    await adService.showRewardedAd(
      type: AdRewardType.bossSkip,
      onRewarded: () {
        setState(() {
          _bossCooldowns.remove(boss.id); // 쿨다운 제거
          _showNotification('✨ 쿨다운이 초기화되었습니다!');
        });
        // 바로 보스 도전
        _startBossRaid(boss);
      },
      onError: (msg) => _showNotification(msg),
    );
  }

  Widget _bossStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }

  bool _isRankingDialogOpen = false;

  void _showRankingDialog() {
    if (_isRankingDialogOpen) return; // 중복 탭 방지
    _isRankingDialogOpen = true;

    // 백그라운드에서 랭킹 갱신 (다이얼로그는 즉시 열림)
    _fetchOnlineRankings(forceRefresh: true);

    bool dialogOpen = true;
    bool isRefreshing = false;
    int selectedTab = 0; // 0: 검 랭킹, 1: 배틀 전적

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a4a),
          title: Row(
            children: [
              const Text('🏆 랭킹', style: TextStyle(color: Colors.white)),
              const Spacer(),
              // ✅ 온라인/오프라인 상태 표시
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? Colors.green.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: _isOnline ? Colors.green : Colors.grey,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isOnline ? '온라인' : '오프라인',
                      style: TextStyle(
                        color: _isOnline ? Colors.green : Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: selectedTab == 0
                                  ? Colors.amber.withOpacity(0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '검 랭킹',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selectedTab == 0
                                    ? Colors.amber
                                    : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: selectedTab == 1
                                  ? Colors.amber.withOpacity(0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '배틀 전적',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selectedTab == 1
                                    ? Colors.amber
                                    : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // ✅ 내 순위 하이라이트
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Row(
                    children: [
                      Text(
                        selectedTab == 0
                            ? (_myRank > 0 ? '#$_myRank' : '-')
                            : (_myBattleRank > 0 ? '#$_myBattleRank' : '-'),
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.nickname,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              selectedTab == 0
                                  ? '전투력: ${formatNumber(_totalPower)}'
                                  : '$_totalBattleWin승 ${_totalBattle - _totalBattleWin}패',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            if (selectedTab == 1)
                              Text(
                                '승률 ${_totalBattle > 0 ? ((_totalBattleWin / _totalBattle) * 100).toStringAsFixed(1) : '0.0'}%',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ✅ 전체 랭킹 목록 (100위까지)
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final currentRankings = selectedTab == 0
                          ? _rankings
                          : _battleRankings;
                      return ListView.builder(
                        itemCount: currentRankings.take(100).length,
                        itemBuilder: (_, i) {
                          final r = currentRankings[i];
                          final isMe = r['id'] == widget.userId;
                          final isOnlinePlayer = r['isOnline'] == true;
                          final grade = r['swordGrade'] as SwordGrade;
                          final element = r['element'] as GameElement;
                          final swordLevel = r['swordLevel'] as int;
                          final wins = r['totalBattleWin'] as int? ?? 0;
                          final total = r['totalBattle'] as int? ?? 0;
                          final winRate = total > 0
                              ? (wins / total) * 100
                              : 0.0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.amber.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                // 순위
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '#${i + 1}',
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: i < 3
                                          ? Colors.amber
                                          : Colors.white54,
                                      fontWeight: i < 3
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                // ✅ 검 이미지 (SwordImageWidget으로 변경)
                                SwordImageWidget(
                                  grade: grade,
                                  element: element,
                                  level: swordLevel,
                                  breakthroughLevel:
                                      (r['swordBreakthroughLevel'] as int?) ??
                                      0,
                                  size: 28, // ✅ 36 → 28로 줄임
                                  showPulse: false,
                                ),
                                const SizedBox(width: 8),
                                // 이름
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              r['name'] as String,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isMe
                                                    ? Colors.amber
                                                    : Colors.white,
                                                fontWeight: isMe
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          // ✅ 플레이어 유형 표시
                                          if (r['isNpc'] == true)
                                            const Text(
                                              '🤖',
                                              style: TextStyle(fontSize: 10),
                                            )
                                          else if (isOnlinePlayer)
                                            const Text(
                                              '🌐',
                                              style: TextStyle(fontSize: 10),
                                            ),
                                        ],
                                      ),
                                      Text(
                                        selectedTab == 0
                                            ? '${r['swordName']} +${r['swordLevel']}'
                                            : '$wins승 ${total - wins}패',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                        ),
                                      ),
                                      if (selectedTab == 1)
                                        Text(
                                          '승률 ${winRate.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                            color: Colors.white30,
                                            fontSize: 10,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // 우측 지표
                                Text(
                                  selectedTab == 0
                                      ? formatNumber(r['power'] as int)
                                      : '$wins승',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // ✅ 새로고침 버튼
            if (_isOnline)
              TextButton.icon(
                onPressed: isRefreshing
                    ? null
                    : () async {
                        if (!dialogOpen) return;
                        setDialogState(() => isRefreshing = true);
                        await _fetchOnlineRankings(forceRefresh: true);
                        if (!mounted || !dialogOpen) return;
                        setDialogState(() => isRefreshing = false);
                      },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('새로고침'),
              ),
            TextButton(
              onPressed: isRefreshing
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    ).then((_) {
      dialogOpen = false;
      _isRankingDialogOpen = false;
    }); // 닫힐 때 플래그 해제
  }

  void _showTitleDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: Row(
          children: [
            const Text('🎖️ 칭호 관리', style: TextStyle(color: Colors.white)),
            const Spacer(),
            Text(
              '${_unlockedTitles.length}/${allTitles.length}',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: allTitles.length,
            itemBuilder: (_, i) {
              final title = allTitles[i];
              final unlocked = _unlockedTitles.contains(title.id);
              final equipped = _equippedTitle == title.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: equipped
                      ? title.grade.color.withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: equipped
                      ? Border.all(color: title.grade.color)
                      : null,
                ),
                child: Row(
                  children: [
                    // 칭호 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.name,
                            style: TextStyle(
                              color: unlocked
                                  ? title.grade.color
                                  : Colors.white38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            unlocked ? title.description : '???',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          if (unlocked && title.bonus > 0)
                            Text(
                              '보너스: 전투력 +${title.bonus}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 장착 버튼
                    if (unlocked && !equipped)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _equippedTitle = title.id;
                            _saveGameData();
                            _syncMyProfile(); // 🔥 칭호 변경 시에만 프로필 동기화
                            _updateRankings(); // 랭킹 표시 전투력 즉시 갱신
                          });
                          Navigator.pop(context);
                          _showNotification('칭호 장착: ${title.name}');
                        },
                        child: const Text('장착'),
                      )
                    else if (equipped)
                      const Text(
                        '장착중',
                        style: TextStyle(color: Colors.greenAccent),
                      )
                    else
                      const Icon(Icons.lock, color: Colors.white30),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showCodexDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: Row(
          children: [
            const Text('📚 검 도감', style: TextStyle(color: Colors.white)),
            const Spacer(),
            Text(
              '${_codex.length}/${allSwords.length}',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 450,
          child: ListView.builder(
            itemCount: SwordGrade.values.length,
            itemBuilder: (_, gradeIndex) {
              final grade = SwordGrade.values[gradeIndex];
              final swordsOfGrade = getSwordsByGrade(grade);
              final collectedCount = swordsOfGrade
                  .where((s) => _codex.contains(s.id))
                  .length;

              return ExpansionTile(
                title: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: SwordImageWidget(
                        grade: grade,
                        element: GameElement.fire,
                        level: 0,
                        size: 28,
                        showPulse: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        grade.displayName,
                        style: TextStyle(color: grade.color),
                      ),
                    ),
                    Text(
                      '$collectedCount/${swordsOfGrade.length}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                children: swordsOfGrade.map((sword) {
                  final collected = _codex.contains(sword.id);
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: collected
                          ? sword.grade.color.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: collected
                            ? sword.grade.color.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 검 이미지
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: collected
                              ? SwordImageWidget(
                                  grade: sword.grade,
                                  element: sword.element,
                                  level: 0,
                                  size: 48,
                                  showPulse: false,
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '❓',
                                      style: TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        // 검 정보
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 이름 + 속성
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      collected ? sword.name : '???',
                                      style: TextStyle(
                                        color: collected
                                            ? Colors.white
                                            : Colors.white30,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (collected) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      sword.element.emoji,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ],
                              ),
                              if (collected) ...[
                                const SizedBox(height: 4),
                                // 기본 스탯
                                Text(
                                  '공격력: ${sword.baseAtk}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // 스킬 정보
                                ...sword.skills
                                    .take(2)
                                    .map(
                                      (skill) => Padding(
                                        padding: const EdgeInsets.only(top: 1),
                                        child: Text(
                                          '${skill.name} (${skill.type.nameKr}) ${skill.procRate}%',
                                          style: TextStyle(
                                            color: Colors.amber.withOpacity(
                                              0.8,
                                            ),
                                            fontSize: 10,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: const Text('📊 게임 통계', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statSection('⚔️ 강화', [
                ('총 시도', _totalEnhanceAttempts),
                ('성공', _totalEnhanceSuccess),
                ('실패', _totalEnhanceFail),
                ('파괴', _totalDestroy),
                ('최대 연속 성공', _maxConsecutiveSuccess),
                ('강화석 사용', _totalStoneUsed),
              ]),
              const SizedBox(height: 16),
              _statSection('🎮 배틀', [
                ('총 배틀', _totalBattle),
                ('승리', _totalBattleWin),
                ('패배', _totalBattle - _totalBattleWin), // 🔥 패배 횟수 추가
                (
                  '승률',
                  _totalBattle > 0
                      ? '${(_totalBattleWin / _totalBattle * 100).toStringAsFixed(1)}%'
                      : '-',
                ),
                ('최대 연승', _maxWinStreak),
                ('복수 성공', _totalRevengeWins),
              ]),
              const SizedBox(height: 16),
              _statSection('🐉 보스', [('처치 수', _bossKills)]),
              const SizedBox(height: 16),
              _statSection('💰 경제', [
                ('뽑기 횟수', _totalGacha),
                ('합성 횟수', _totalSynthesis),
                ('판매 횟수', _totalSell),
              ]),
              const SizedBox(height: 16),
              _statSection('📅 기타', [
                ('출석 연속', '$_attendanceStreak일'),
                ('도감 수집', '${_codex.length}/${allSwords.length}'),
                ('칭호 획득', '${_unlockedTitles.length}/${allTitles.length}'),
                ('업적 달성', '${_unlockedAchievements.length}개'),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ❓ 도움말 다이얼로그
  // =====================================================
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.3),
                      Colors.purple.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: const Row(
                  children: [
                    Text('❓', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12),
                    Text(
                      '게임 도움말',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // 내용
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 속성 상성표
                      _buildHelpSection(
                        '⚔️ 속성 상성',
                        '전투에서 속성 상성에 따라 데미지가 변합니다.',
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // 상성 도표
                              _buildElementRow(
                                '🔥 불',
                                '→',
                                '🌿 자연',
                                '유리 (+25%)',
                                Colors.green,
                              ),
                              _buildElementRow(
                                '💧 물',
                                '→',
                                '🔥 불',
                                '유리 (+25%)',
                                Colors.green,
                              ),
                              _buildElementRow(
                                '🌿 자연',
                                '→',
                                '💧 물',
                                '유리 (+25%)',
                                Colors.green,
                              ),
                              const Divider(color: Colors.white24, height: 16),
                              _buildElementRow(
                                '✨ 빛',
                                '↔',
                                '🌑 암흑',
                                '서로 상극',
                                Colors.amber,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '💡 반대로 맞으면 -20% 데미지!',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 등급 설명
                      _buildHelpSection(
                        '🗡️ 검 등급',
                        '',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: SwordGrade.values
                              .map(
                                (grade) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: grade.color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: grade.color.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/images/swords/sword_${grade.name}.webp',
                                        width: 24,
                                        height: 24,
                                        errorBuilder: (_, __, ___) => Text(
                                          grade.emoji,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        grade.displayName,
                                        style: TextStyle(
                                          color: grade.color,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 강화 팁
                      _buildHelpSection(
                        '⚡ 강화 팁',
                        '',
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• +1~+10: 파괴 없음, 실패 시 유지 (성공 92%→65%)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• +11~+14: 파괴 시작 (파괴 2~8%)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• +15~+20: 파괴 30% 고정 (성공 30%→20%)',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• +21~+25: 파괴 35% 고정 (성공 18%→8%)',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• +26~+30: 파괴 40% 고정 (성공 6%→1%)',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '• 강화석 (~+24): 성공률 +10%, 파괴율 -5%',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• 강화석 (+25~+27): 성공률 +3%, 파괴율 -2%',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• 강화석 (+28~+30): 성공률 +1%, 파괴율 -1%',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 돌파 팁
                      _buildHelpSection(
                        '🧿 돌파 가이드',
                        '',
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• 30강에 도달하면 돌파가 열리고 최대 강화치가 +5 증가합니다.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• 돌파 재료: 동일 등급 20강 이상 검 1개 + 보스코어 + 골드',
                              style: TextStyle(
                                color: Color(0xFF80DEEA),
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• 보스코어는 보스 처치 시 확률적으로 드랍되며, 높은 보스일수록 더 잘 나옵니다.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '• 31~35강: 성공 1.0% / 유지 89.0% / 파괴 10.0%',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• 36~40강: 성공 0.5% / 유지 89.5% / 파괴 10.0%',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• 41~45강: 성공 0.1% / 유지 89.9% / 파괴 10.0%',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 합성 팁
                      _buildHelpSection(
                        '🔄 합성 천장',
                        '',
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• 노말 10회 합성 → 레어 확정',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• 레어 50회 합성 → 유니크 확정',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• 유니크 100회 합성 → 전설 확정',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 닫기 버튼
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // ⚙️ 설정 다이얼로그
  // =====================================================
  void _showSettingsDialog() {
    final soundService = SoundService();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a4a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Text('⚙️', style: TextStyle(fontSize: 24)),
              SizedBox(width: 12),
              Text('설정', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🔊 배경음악 설정
              _buildSettingRow(
                icon: '🎵',
                label: '배경음악',
                value: soundService.bgmEnabled,
                onChanged: (value) {
                  soundService.setBgmEnabled(value);
                  setDialogState(() {});
                },
              ),
              const SizedBox(height: 12),

              // 🔊 효과음 설정
              _buildSettingRow(
                icon: '🔊',
                label: '효과음',
                value: soundService.sfxEnabled,
                onChanged: (value) {
                  soundService.setSfxEnabled(value);
                  setDialogState(() {});
                },
              ),
              const SizedBox(height: 20),

              // 버전 정보
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('버전', style: TextStyle(color: Colors.white70)),
                    Text('1.0.0', style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 📄 개인정보처리방침
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(
                    'https://sites.google.com/view/sword-game-privacy',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📄 개인정보처리방침',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Icon(Icons.open_in_new, color: Colors.white54, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required String icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.green),
        ],
      ),
    );
  }

  Widget _buildHelpSection(
    String title,
    String description, {
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildElementRow(
    String from,
    String arrow,
    String to,
    String effect,
    Color effectColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              from,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Text(
            arrow,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          Expanded(
            flex: 3,
            child: Text(
              to,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: effectColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                effect,
                style: TextStyle(color: effectColor, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statSection(String title, List<(String, dynamic)> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.$1, style: const TextStyle(color: Colors.white70)),
                Text('${item.$2}', style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================
// 🎰 종합 뽑기 다이얼로그 (일반 + 고급)
// =====================================================
class _GachaDialog extends StatefulWidget {
  final int gold;
  final int diamond;
  final int inventoryCount;
  final int maxInventory;
  final Function(int) onNormalGacha;
  final Function(int) onPremiumGacha;

  const _GachaDialog({
    required this.gold,
    required this.diamond,
    required this.inventoryCount,
    required this.maxInventory,
    required this.onNormalGacha,
    required this.onPremiumGacha,
  });

  @override
  State<_GachaDialog> createState() => _GachaDialogState();
}

class _GachaDialogState extends State<_GachaDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 340,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.withOpacity(0.3),
                    Colors.blue.withOpacity(0.3),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    '🎰 검 뽑기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 🔥 FittedBox로 감싸서 오버플로우 방지
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCurrencyChip(
                          '💰',
                          formatNumber(widget.gold),
                          Colors.amber,
                        ),
                        const SizedBox(width: 6),
                        _buildCurrencyChip(
                          '💎',
                          '${widget.diamond}',
                          Colors.cyan,
                        ),
                        const SizedBox(width: 6),
                        _buildCurrencyChip(
                          '📦',
                          '${widget.inventoryCount}/${widget.maxInventory}',
                          Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 탭 바
            Container(
              color: Colors.black26,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.amber,
                labelColor: Colors.amber,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontSize: 13),
                tabs: const [
                  Tab(text: '🪙 일반 뽑기'),
                  Tab(text: '💎 고급 뽑기'),
                ],
              ),
            ),

            // 탭 뷰
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [_buildNormalGachaTab(), _buildPremiumGachaTab()],
              ),
            ),

            // 닫기 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyChip(String icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 일반 뽑기 탭 =====
  Widget _buildNormalGachaTab() {
    final inventoryFull = widget.inventoryCount >= widget.maxInventory;
    final canGacha1 = widget.gold >= 500 && !inventoryFull;
    final canGacha5 =
        widget.gold >= 2250 && widget.inventoryCount + 5 <= widget.maxInventory;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚠️ 인벤토리 가득 참 경고
          if (inventoryFull)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '인벤토리가 가득 찼습니다!\n검을 판매하거나 인벤토리를 확장하세요.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // 설명
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Text('🪙', style: TextStyle(fontSize: 18)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '골드로 검을 뽑습니다\n모든 등급 획득 가능!',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 획득 가능 등급
          const Text(
            '획득 가능 등급',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: gachaProbability.keys
                .map((grade) => _buildGradeChip(grade))
                .toList(),
          ),
          const SizedBox(height: 16),

          // 뽑기 버튼들
          Row(
            children: [
              Expanded(
                child: _buildGachaButton(
                  '1회',
                  '500G',
                  Colors.amber,
                  canGacha1,
                  () => widget.onNormalGacha(1),
                  requiredSlots: 1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildGachaButton(
                  '5회',
                  '2,250G',
                  Colors.purple,
                  canGacha5,
                  () => widget.onNormalGacha(5),
                  subtitle: '10% 할인',
                  requiredSlots: 5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== 고급 뽑기 탭 =====
  Widget _buildPremiumGachaTab() {
    final inventoryFull = widget.inventoryCount >= widget.maxInventory;
    final canPremium1 =
        widget.diamond >= premiumGachaCostSingle && !inventoryFull;
    final canPremium5 =
        widget.diamond >= premiumGachaCost5x &&
        widget.inventoryCount + 5 <= widget.maxInventory;
    final canPremium10 =
        widget.diamond >= premiumGachaCost10x &&
        widget.inventoryCount + 10 <= widget.maxInventory;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚠️ 인벤토리 가득 참 경고
          if (inventoryFull)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '인벤토리가 가득 찼습니다!\n검을 판매하거나 인벤토리를 확장하세요.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // 설명 (프리미엄 강조)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.withOpacity(0.2),
                  Colors.cyan.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.cyan.withOpacity(0.5)),
            ),
            child: const Row(
              children: [
                Text('💎', style: TextStyle(fontSize: 18)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '다이아몬드로 고급 검을 뽑습니다\n⭐ 최소 레어 등급 보장!',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 획득 가능 등급 (노말 제외) - 확률 표시 없음
          const Text(
            '획득 가능 등급',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: premiumGachaProbability.keys
                .map((grade) => _buildGradeChip(grade))
                .toList(),
          ),
          const SizedBox(height: 16),

          // 뽑기 버튼들
          _buildGachaButton(
            '1회',
            '$premiumGachaCostSingle💎',
            Colors.cyan,
            canPremium1,
            () => widget.onPremiumGacha(1),
            requiredSlots: 1,
          ),
          const SizedBox(height: 8),
          _buildGachaButton(
            '5회',
            '$premiumGachaCost5x💎',
            Colors.purple,
            canPremium5,
            () => widget.onPremiumGacha(5),
            subtitle: '1회당 ${premiumGachaCost5x ~/ 5}💎',
            requiredSlots: 5,
          ),
          const SizedBox(height: 8),
          _buildGachaButton(
            '10회',
            '$premiumGachaCost10x💎',
            Colors.amber,
            canPremium10,
            () => widget.onPremiumGacha(10),
            subtitle: '✨ 유니크 이상 1개 확정!',
            isSpecial: true,
            requiredSlots: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildGradeChip(SwordGrade grade) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: grade.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: grade.color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: SwordImageWidget(
              grade: grade,
              element: GameElement.fire,
              level: 0,
              size: 18,
              showPulse: false,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            grade.displayName,
            style: TextStyle(
              color: grade.color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGachaButton(
    String title,
    String cost,
    Color color,
    bool enabled,
    VoidCallback onPressed, {
    String? subtitle,
    bool isSpecial = false,
    int? requiredSlots,
  }) {
    // 인벤토리 부족 여부 판단
    final slotsAvailable = widget.maxInventory - widget.inventoryCount;
    final isInventoryBlock =
        requiredSlots != null && slotsAvailable < requiredSlots;

    return Container(
      decoration: isSpecial && enabled
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey[800],
          foregroundColor: Colors.white,
          disabledBackgroundColor: isInventoryBlock
              ? Colors.red.withOpacity(0.15)
              : Colors.grey[800],
          disabledForegroundColor: isInventoryBlock
              ? Colors.redAccent.withOpacity(0.7)
              : Colors.white38,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: !enabled && isInventoryBlock
                ? BorderSide(color: Colors.red.withOpacity(0.4))
                : BorderSide.none,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(cost, style: const TextStyle(fontSize: 14)),
              ],
            ),
            if (!enabled && isInventoryBlock)
              Text(
                '📦 빈 칸 ${requiredSlots}개 필요 (현재 $slotsAvailable칸)',
                style: const TextStyle(fontSize: 10, color: Colors.redAccent),
              )
            else if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isSpecial ? Colors.yellow : Colors.white70,
                  fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
