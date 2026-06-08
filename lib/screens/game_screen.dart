import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../enums/sword_grade.dart';
import '../enums/element.dart';
import '../enums/quest_type.dart';
import '../enums/skill_type.dart';
import '../models/sword_data.dart';
import '../models/owned_sword.dart';
import '../models/battle_record.dart';
import '../models/daily_quest.dart';
import '../models/boss_data.dart';
import '../models/title_data.dart';
import '../models/player_profile.dart';
import '../data/swords.dart';
import '../data/titles.dart';
import '../data/npcs.dart';
import '../data/shop.dart';
import '../services/storage_service.dart';
import '../services/online_player_service.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';
import '../services/friend_service.dart'; // ?뫁 移쒓뎄 ?쒕퉬??
import '../services/purchase_service.dart'; // ?뮥 ?몄빋 寃곗젣
import '../services/remote_config_service.dart';
import '../services/event_log_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/battle_engine.dart';
import 'boss_raid_screen.dart';
import 'shop_screen.dart';
import 'season1_boss_select_dialog.dart';
import 'season1_settings_dialog.dart';
import 'battle_select_screen.dart';
import 'battle_arena_screen.dart';
import 'achievements_screen.dart';
import 'season_pass_screen.dart';
import 'friends_screen.dart'; // ?뫁 移쒓뎄 ?붾㈃
import '../models/achievement_data.dart';
import '../data/achievements.dart';
import '../data/season_pass_rewards.dart';
import '../widgets/dialogs/sword_detail_dialog.dart';
import '../widgets/dialogs/synthesis_dialog.dart';
import '../widgets/dialogs/season1_ranking_dialog.dart';
import '../widgets/dialogs/sword_image_test_dialog.dart';
import '../widgets/sword_image_widget.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart'; // ?뱤 Analytics
import 'tabs/home_tab.dart';
import 'tabs/inventory_tab.dart';
import 'tabs/enhance_tab.dart';
import 'tabs/battle_tab.dart';
import 'tabs/more_tab.dart';
import 'minigame/brick_breaker_screen.dart';
import 'infinite_tower_screen.dart';
part 'game_screen/gacha_dialog.dart';
part 'game_screen/image_shell.dart';

String _formatCompactBalance(int value) {
  if (value < 0) return '0';
  if (value >= 1000000000) return '${(value / 1000000000).round()}B';
  if (value >= 1000000) return '${(value / 1000000).round()}M';
  if (value >= 1000) return '${(value / 1000).round()}K';
  return '$value';
}

// game_screen.dart
class GameScreen extends StatefulWidget {
  final String nickname;
  final String userId; // ??異붽?

  const GameScreen({
    super.key,
    required this.nickname,
    required this.userId, // ??異붽?
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _storage = StorageService();
  final _purchaseService = PurchaseService(); // ?뮥 ?쒖쫵?⑥뒪 ?몄빋 寃곗젣??
  final _random = Random();

  // ?꾩옱 ??
  int _currentTab = 0;

  // ?ы솕
  int _gold = 0;
  int _diamond = 0;
  int _enhanceStone = 0;
  int _bossCore = 0;

  // ?몃깽?좊━
  List<OwnedSword> _inventory = [];
  int _maxInventory = 10;
  OwnedSword? _equippedSword;

  // 諛고?
  int _battleCount = 10;
  int _battleRefillCount = 0;
  int _battleWinStreak = 0;
  int _maxWinStreak = 0;
  List<BattleRecord> _battleRecords = [];

  // 蹂댁뒪 荑⑤떎??
  Map<String, DateTime> _bossCooldowns = {};

  // ?꾧컧/移?샇/?낆쟻
  Set<String> _codex = {};
  Set<String> _unlockedTitles = {'t_01'};
  String _equippedTitle = 't_01';
  Set<String> _unlockedAchievements = {};
  Set<String> _claimedAchievements = {};

  // 異쒖꽍
  int _attendanceStreak = 0;
  DateTime? _lastAttendance;
  bool _canCheckAttendance = true;

  // ?쇱씪?섏뒪??
  List<DailyQuest> _dailyQuests = [];

  // ?쒖쫵?⑥뒪
  int _seasonPassLevel = 1;
  int _seasonPassExp = 0;
  int _todaySeasonExp = 0; // ??異붽?: ?ㅻ뒛 ?띾뱷???쒖쫵?⑥뒪 EXP
  static const int _maxDailySeasonExp = 300; // ??異붽?: ?섎（ ?곹븳
  Set<int> _claimedSeasonRewards = {};
  bool _hasPremiumPass = false; // ??異붽?
  Set<int> _claimedPremiumRewards = {}; // ??異붽?

  // ?⑹꽦 泥쒖옣
  int _normalToRarePity = 0; // ???몃쭚?믩젅??泥쒖옣 異붽?
  int _rareToUniquePity = 0;
  int _uniqueToLegendPity = 0;

  // ?듦퀎
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
  int _totalQuestsCompleted = 0; // ??異붽?

  // ?뵦 ?먮ℓ ?대깽???쒖뒪??
  int _currentSellEventIndex = 0; // ?꾩옱 ?대깽???몃뜳??
  DateTime? _lastEventChange; // 留덉?留??대깽??蹂寃??쒓컙

  // ?먮ℓ ?대깽??紐⑸줉 (?대쫫, 諛곗쑉, ?됱긽, ?대え吏)
  static const List<Map<String, dynamic>> _sellEvents = [
    {'name': '일반', 'rate': 1.0, 'color': 0xFFFFFFFF, 'emoji': '💰'},
    {'name': '폭등', 'rate': 2.0, 'color': 0xFF4CAF50, 'emoji': '📈'},
    {'name': '대폭등', 'rate': 3.0, 'color': 0xFF00E676, 'emoji': '🚀'},
    {'name': '버블', 'rate': 4.0, 'color': 0xFFFFD700, 'emoji': '✨'},
    {'name': '황금 찬스', 'rate': 5.0, 'color': 0xFFFF9800, 'emoji': '👑'},
    {'name': '폭락', 'rate': 0.5, 'color': 0xFFF44336, 'emoji': '📉'},
    {'name': '대폭락', 'rate': 0.3, 'color': 0xFFD32F2F, 'emoji': '💥'},
    {'name': '불경기', 'rate': 0.2, 'color': 0xFF9E9E9E, 'emoji': '😰'},
    {'name': '호황', 'rate': 2.5, 'color': 0xFF2196F3, 'emoji': '🎉'},
  ];

  // ??궧
  List<Map<String, dynamic>> _rankings = [];
  List<Map<String, dynamic>> _battleRankings = [];
  List<Map<String, dynamic>> _towerRankings = [];
  List<PlayerProfile> _codexRankings = [];
  int _myRank = 0;
  int _myBattleRank = 0;

  // UI ?곹깭
  bool _useEnhanceStone = false;
  bool _showEnhanceEffect = false; // ?뵦 媛뺥솕 ?깃났 ?좊땲硫붿씠??
  bool _isDestroyRecoveryInProgress = false;
  String? _notification;
  String? _notificationImage; // ?뚮┝???쒖떆???먯뀑 ?대?吏 寃쎈줈

  // ???곗씠??濡쒕뵫 ?꾨즺 ?щ? (濡쒕뱶 ?꾨즺 ??議곗옉/??μ쑝濡??쒕쾭 ??뼱?곌린 諛⑹?)
  bool _dataReady = false;
  bool _deferredSaveAfterLoad = false;
  bool _snapshotLogged = false;

  // ??濡쒕뵫 ??꾩븘??10珥? 諛??ъ떆??UI
  Timer? _loadTimeoutTimer;
  bool _loadTimedOut = false;
  bool _loadingInProgress = false;
  int _loadGeneration = 0;

  // 移쒓뎄 紐⑸줉 (?ㅽ봽?쇱씤 紐⑤뱶?먯꽌??鍮?由ъ뒪??
  List<String> _friendIds = []; // ??異붽?

  // ???⑤씪???쒕퉬??異붽?
  OnlinePlayerService? _onlineService;
  List<PlayerProfile> _onlineRankings = [];
  bool _isOnline = false;

  // ??怨듭? ?앹뾽(?몄뀡 1??泥댄겕)
  bool _noticeCheckedThisSession = false;
  final _remoteConfig = RemoteConfigService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ?뵦 ???쇱씠?꾩궗?댄겢 媛먯?
    _loadGameData();
    _initOnlineService();
    _initPurchaseService(); // ?뮥 寃곗젣 ?쒕퉬??珥덇린??

    // ?렦 硫붿씤 BGM ?ъ깮
    SoundService().playMainBgm();
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this); // ?뵦 ?듭?踰??댁젣
    super.dispose();
  }

  // ?뵦 ???쇱씠?꾩궗?댄겢 蹂寃?媛먯? - 諛깃렇?쇱슫??醫낅즺 ??利됱떆 ???
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // ?뵦 ?깆씠 諛깃렇?쇱슫?쒕줈 媛嫄곕굹 醫낅즺????利됱떆 ???(force=true濡??붾컮?댁떛 臾댁떆)
      debugPrint('app lifecycle changed: $state, saving data...');

      // ??濡쒕뵫 以?濡쒕뱶 ?ㅽ뙣 ?곹깭?먯꽌 ?대씪?곕뱶 ??μ쓣 ?섎㈃ 珥덇린媛믪씠 ?쒕쾭瑜???뼱?????덉뼱 李⑤떒
      if (_dataReady) {
        // ?꾩옱 UI ?곹깭 ??Storage 罹먯떆??癒쇱? 諛섏쁺 (?대씪?곕뱶 ????꾩뿉 ?ㅻ깄???뺥빀???뺣낫)
        _saveGameData(cloudSave: false);

        if (_storage.canSaveToCloudSafely) {
          _storage.saveToCloud(force: true);
        } else {
          // ?대씪?곕뱶 湲곗? ?곗씠?곌? 以鍮꾨릺吏 ?딆븯?쇰㈃ 濡쒖뺄 諛깆뾽留????
          _storage.saveToLocalBackupNow();
        }
      } else {
        // 濡쒕뵫 以묒뿉???쒕쾭 ??뼱?곌린 ?꾪뿕 ??濡쒖뺄留?
        _storage.saveToLocalBackupNow();
      }

      // ?뵁 諛깃렇?쇱슫?쒖뿉??BGM ?쇱떆?뺤?
      SoundService().pauseBgm();
    } else if (state == AppLifecycleState.resumed) {
      // ?뵄 ?ш렇?쇱슫??蹂듦? ??BGM ?ш컻
      debugPrint('app resumed, restarting BGM');
      SoundService().resumeBgm();
    }
  }

  // ?뮥 寃곗젣 ?쒕퉬??珥덇린??(?쒖쫵?⑥뒪 援щℓ??
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
          _showNotification('프리미엄 패스가 활성화되었습니다!');
          _saveGameData();
        });
      } else if (!result.success) {
        _showNotification(result.errorMessage ?? '결제 실패');
      }
    };
    _purchaseService.onPurchaseError = (error) {
      _showNotification('결제 오류: $error');
    };
    _purchaseService.onPurchasePending = () {
      _showNotification('결제 처리 중...');
    };
  }

  // ???⑤씪???쒕퉬??珥덇린??
  Future<void> _initOnlineService() async {
    try {
      // ??Firebase Auth uid 吏곸젒 ?ъ슜 (widget.userId ???
      final authUid = AuthService().uid;
      if (authUid == null || authUid.isEmpty) {
        debugPrint('Firebase Auth uid is missing; offline mode');
        _isOnline = false;
        return;
      }

      _onlineService = OnlinePlayerService(myUserId: authUid);
      _isOnline = true;
      debugPrint('online service initialized: $authUid');

      await _syncMyProfile();
      await _fetchOnlineRankings();
      await _fetchBattleNotifications(); // 諛고? ?뚮┝ ?섏떊
    } catch (e) {
      // Firebase ?놁쑝硫??ㅽ봽?쇱씤 紐⑤뱶
      _isOnline = false;
      debugPrint('offline mode: $e');
    }
  }

  // ??諛고? ?뚮┝ ?섏떊 諛?湲곕줉 異붽?
  Future<void> _fetchBattleNotifications() async {
    if (_onlineService == null) {
      debugPrint('battle notification fetch failed: onlineService is null');
      return;
    }

    try {
      debugPrint('fetching battle notifications...');
      final notifications = await _onlineService!.fetchBattleNotifications();
      debugPrint('battle notifications fetched: ${notifications.length}');

      int addedCount = 0;
      for (final noti in notifications) {
        // ?덉쟾???곗씠??異붿텧
        final fromUserId = (noti['fromUserId'] as String?) ?? '';
        final fromNickname = (noti['fromNickname'] as String?) ?? '?????놁쓬';
        final fromLevel = (noti['fromLevel'] as int?) ?? 1;
        final fromGrade = (noti['fromGrade'] as String?) ?? 'normal';
        final fromElement = (noti['fromElement'] as String?) ?? 'fire';
        final toLevel = (noti['toLevel'] as int?) ?? 1;
        final toGrade = (noti['toGrade'] as String?) ?? 'normal';
        final toWon = (noti['toWon'] as bool?) ?? false;
        final timestamp = (noti['timestamp'] as DateTime?) ?? DateTime.now();

        debugPrint(
          '  - battle: $fromNickname(Lv.$fromLevel) vs me ${toWon ? "win" : "lose"}',
        );

        if (fromUserId.isEmpty) {
          debugPrint('    skipped: empty fromUserId');
          continue;
        }

        // ??臾몄꽌 ID濡?以묐났 泥댄겕 (???뺥솗??
        final notiId = noti['id'] as String?;
        final exists =
            notiId != null && _battleRecords.any((r) => r.uid == notiId);

        if (exists) {
          debugPrint('    skipped: duplicate record');
          continue;
        }

        _battleRecords.insert(
          0,
          BattleRecord(
            uid: notiId ?? generateUid(), // 臾몄꽌 ID瑜?uid濡??ъ슜
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
            isAttacker: false, // ?닿? 怨듦꺽?뱁븿
          ),
        );
        addedCount++;
        debugPrint('    battle history added');
      }

      if (addedCount > 0) {
        // ?쒓컙???뺣젹
        _battleRecords.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _saveGameData();

        if (mounted) {
          setState(() {}); // UI 媛깆떊
          _showNotification('$addedCount건의 배틀 기록을 가져왔습니다!');
        }
      }
    } catch (e) {
      debugPrint('battle notification fetch failed: $e');
    }
  }

  // ?????꾨줈???쒕쾭 ?숆린??
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
        totalBattle: _totalBattle,
        totalBattleWin: _totalBattleWin,
        codexCount: _codex.length,
      );
      await _onlineService!.upsertMe(profile);
    } catch (e) {
      debugPrint('profile sync failed: $e');
    }
  }

  // ???⑤씪????궧 媛?몄삤湲?
  Future<void> _fetchOnlineRankings({bool forceRefresh = false}) async {
    if (!_isOnline || _onlineService == null) return;

    try {
      _onlineRankings = await _onlineService!.fetchTopRankings(
        limit: 100,
        forceRefresh: forceRefresh,
      );
      _updateRankings(); // 濡쒖뺄 ??궧怨?蹂묓빀
    } catch (e) {
      debugPrint('ranking fetch failed: $e');
    }
  }

  Future<void> _fetchExtendedRankings({bool forceRefresh = false}) async {
    await _fetchOnlineRankings(forceRefresh: forceRefresh);

    if (_isOnline && _onlineService != null) {
      try {
        _towerRankings = await _onlineService!.fetchInfiniteTowerRankings(
          limit: 100,
        );
      } catch (e) {
        debugPrint('tower ranking fetch failed: $e');
      }

      try {
        _codexRankings = await _onlineService!.fetchCodexRankings(limit: 100);
      } catch (e) {
        debugPrint('codex ranking fetch failed: $e');
      }
    }

    _mergeLocalRankingData();
  }

  void _mergeLocalRankingData() {
    if (_equippedSword != null) {
      final localCodexProfile = PlayerProfile(
        userId: widget.userId,
        nickname: widget.nickname,
        swordId: _equippedSword!.data.id,
        swordLevel: _equippedSword!.level,
        swordBreakthroughLevel: _equippedSword!.breakthroughLevel,
        titleId: _equippedTitle,
        updatedAt: DateTime.now(),
        totalBattle: _totalBattle,
        totalBattleWin: _totalBattleWin,
        codexCount: _codex.length,
        platform: _isOnline ? 'google' : 'local',
      );

      final codexIndex = _codexRankings.indexWhere(
        (p) => p.userId == widget.userId,
      );
      if (codexIndex >= 0) {
        _codexRankings[codexIndex] = localCodexProfile;
      } else {
        _codexRankings.add(localCodexProfile);
      }
      _codexRankings.sort((a, b) {
        final codexCmp = b.codexCount.compareTo(a.codexCount);
        if (codexCmp != 0) return codexCmp;
        return b.powerWithTitle.compareTo(a.powerWithTitle);
      });
    }

    final bestFloor = _storage.infiniteTowerBestFloor;
    if (bestFloor > 0 && _equippedSword != null) {
      final localTower = {
        'id': widget.userId,
        'name': widget.nickname,
        'floor': bestFloor,
        'reachedAt': DateTime.now(),
        'power': _totalPower,
        'swordId': _equippedSword!.data.id,
        'swordName': _equippedSword!.data.name,
        'swordLevel': _equippedSword!.level,
        'swordBreakthroughLevel': _equippedSword!.breakthroughLevel,
        'platform': _isOnline ? 'google' : 'local',
        'isOnline': _isOnline,
      };

      final towerIndex = _towerRankings.indexWhere(
        (r) => r['id'] == widget.userId,
      );
      if (towerIndex >= 0) {
        _towerRankings[towerIndex] = localTower;
      } else {
        _towerRankings.add(localTower);
      }
      _towerRankings.sort((a, b) {
        final floorCmp = (b['floor'] as int).compareTo(a['floor'] as int);
        if (floorCmp != 0) return floorCmp;
        return (a['power'] as int).compareTo(b['power'] as int);
      });
    }
  }

  // ?꾪닾??怨꾩궛
  int get _totalPower {
    if (_equippedSword == null) return 0;
    final titleBonus = getTitleById(_equippedTitle).bonus;
    return _equippedSword!.totalPower + titleBonus;
  }

  // ===== ?곗씠??濡쒕뱶/???=====
  Future<void> _loadGameData() async {
    // 以묐났 ?몄텧 諛⑹? (?? ??꾩븘???댄썑?먮뒗 ?ъ떆???덉슜)
    if (_loadingInProgress && !_loadTimedOut) return;

    final int gen = ++_loadGeneration;
    _loadingInProgress = true;

    if (mounted) {
      setState(() {
        _dataReady = false;
        _loadTimedOut = false;
      });
    }

    // ??10珥???꾩븘?? 濡쒕뱶媛 ?ㅻ옒 嫄몃━硫??ъ떆??踰꾪듉 ?몄텧
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      // ?꾩옱 濡쒕뱶 ?몃?(gen)?먯꽌留???꾩븘???쒖떆
      if (gen == _loadGeneration && !_dataReady) {
        setState(() {
          _loadTimedOut = true;
        });
      }
    });

    try {
      try {
        await _storage.init();

        // ???좎?蹂?愿묎퀬 ?쒖껌 ?잛닔 濡쒕뱶
        await AdService().loadForCurrentUser();

        // 移쒓뎄 紐⑸줉? 珥덇린 ?붾㈃ ?뚮뜑 ??諛깃렇?쇱슫??濡쒕뱶
        unawaited(_loadFriendIdsInBackground(gen));
      } catch (e) {
        // StorageService init ?먯껜媛 ?ㅽ뙣?대룄 ?깆? ?ㅽ봽?쇱씤 紐⑤뱶濡?吏꾪뻾 媛??
        debugPrint('game data init failed, continuing offline: $e');
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
        _equippedTitle = _storage.equippedTitle ?? 't_01'; // ??湲곕낯媛?異붽?
        _unlockedAchievements = _storage.unlockedAchievements;
        _claimedAchievements = _storage.claimedAchievements;
        _attendanceStreak = _storage.attendanceStreak;
        _lastAttendance = _storage.lastAttendance;
        _seasonPassLevel = _storage.seasonPassLevel;
        _seasonPassExp = _storage.seasonPassExp;
        _todaySeasonExp = _storage.todaySeasonExp; // ??異붽?
        _claimedSeasonRewards = _storage.claimedSeasonRewards;
        _hasPremiumPass = _storage.hasPremiumPass; // ??異붽?
        _claimedPremiumRewards = _storage.claimedPremiumRewards; // ??異붽?
        _normalToRarePity = _storage.normalToRarePity; // ???몃쭚?믩젅??泥쒖옣
        _rareToUniquePity = _storage.rareToUniquePity;
        _uniqueToLegendPity = _storage.uniqueToLegendPity;

        // ?듦퀎
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

        // ???좉퇋 ?좎?硫??쒖옉 寃 吏湲?
        if (_inventory.isEmpty) {
          _giveStarterSword();
        }

        // ?μ갑 寃 蹂듭썝
        final equippedUid = _storage.equippedSwordUid;
        if (equippedUid != null) {
          _equippedSword = _inventory
              .where((s) => s.uid == equippedUid)
              .firstOrNull;
        }

        // 異쒖꽍 泥댄겕 媛???щ?
        _canCheckAttendance = !_storage.isToday(_lastAttendance);

        // ???쇱씪 ?섏뒪??濡쒕뱶
        final savedQuests = _storage.dailyQuests;
        if (savedQuests.isNotEmpty) {
          _dailyQuests = savedQuests;
        }

        // ?쇱씪 由ъ뀑 泥댄겕
        _checkDailyReset();

        // ??濡쒕뱶 ?꾨즺: UI 議곗옉 ?덉슜
        _dataReady = true;
        _loadTimedOut = false;
      });

      // 濡쒕뱶 ?꾨즺 ??珥덇린??濡쒖쭅
      _initDailyQuests();
      _updateRankings();
      _logLoginSnapshotOnce();
      _scheduleNoticeCheckAfterLoad();

      // 濡쒕뵫 以?諛쒖깮??????붿껌???덉쑝硫? 濡쒕뱶 ?꾨즺 ??1?뚮쭔 ???
      if (_deferredSaveAfterLoad) {
        _deferredSaveAfterLoad = false;
        _saveGameData();
      }
    } finally {
      // 理쒖떊 濡쒕뱶 ?몃??먯꽌留??곹깭 ?뺣━
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
      debugPrint('friend list load failed: $e');
    }
  }

  // ???쒖옉 寃 吏湲?
  void _giveStarterSword() {
    // ?쇰컲 ?깃툒 以??쒕뜡 寃 吏湲?
    final normalSwords = getSwordsByGrade(SwordGrade.normal);
    final starterSword = normalSwords[Random().nextInt(normalSwords.length)];
    final newSword = createNewSword(starterSword);

    _inventory.add(newSword);
    _equippedSword = newSword;
    _codex.add(starterSword.id);

    // ???
    _storage.inventory = _inventory;
    _storage.equippedSwordUid = newSword.uid;
    _storage.codex = _codex;

    // ?뚮┝? UI媛 鍮뚮뱶???꾩뿉
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNotification('시작 검 지급: ${starterSword.name}');
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
    // ???곗씠??濡쒕뵫 ?꾨즺 ????μ? ?쒕쾭 ??뼱?곌린 ?꾪뿕 ??濡쒕뱶 ?꾨즺 ?꾨줈 吏??
    if (!_dataReady) {
      _deferredSaveAfterLoad = true;
      debugPrint('save requested while loading; deferred until load completes');
      return;
    }

    _storage.nickname = widget.nickname; // ?뵦 ?됰꽕?????異붽?
    _storage.gold = _gold;
    _storage.diamond = _diamond;
    _storage.enhanceStone = _enhanceStone;
    _storage.bossCore = _bossCore;
    _storage.inventory = _inventory;
    _storage.maxInventory = _maxInventory;
    _storage.equippedSwordUid = _equippedSword?.uid;
    _storage.equippedSwordId = _equippedSword?.data.id; // 移쒓뎄/??궧??
    _storage.equippedSwordLevel = _equippedSword?.level ?? 1; // 移쒓뎄/??궧??
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
    _storage.todaySeasonExp = _todaySeasonExp; // ??異붽?
    _storage.claimedSeasonRewards = _claimedSeasonRewards;
    _storage.hasPremiumPass = _hasPremiumPass; // ??異붽?
    _storage.claimedPremiumRewards = _claimedPremiumRewards; // ??異붽?
    _storage.normalToRarePity = _normalToRarePity; // ???몃쭚?믩젅??泥쒖옣
    _storage.rareToUniquePity = _rareToUniquePity;
    _storage.uniqueToLegendPity = _uniqueToLegendPity;

    // ?듦퀎
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

    // ???쇱씪 ?섏뒪?????
    _storage.dailyQuests = _dailyQuests;

    // ?뵦 Firestore?????(鍮꾨룞湲? - 濡쒓렇?꾩썐 ?쒖뿉???ㅽ궢
    if (cloudSave) {
      _storage.saveToCloud();
    }

    // ?뵦 ?꾨줈???숆린?붾뒗 ?λ퉬/移?샇 蹂寃??쒖뿉留??몄텧 (Firebase 鍮꾩슜 ?덇컧)
    // _syncMyProfile() ?쒓굅 - ???_equipSword(), _setTitle() ?깆뿉??吏곸젒 ?몄텧
  }

  // _checkDailyReset()??異붽?
  void _checkDailyReset() {
    final lastReset = _storage.lastBattleReset;
    if (lastReset == null || !_storage.isToday(lastReset)) {
      setState(() {
        _battleCount = AppConstants.dailyBattleCount;
        _battleRefillCount = 0;
        _todaySeasonExp = 0; // ??異붽?: ?쒖쫵?⑥뒪 ?쇱씪 EXP 珥덇린??
        _storage.battleCount = _battleCount;
        _storage.battleRefillCount = _battleRefillCount;
        _storage.todaySeasonExp = 0; // ??異붽?
        _storage.lastBattleReset = _storage.serverNow; // ???쒕쾭 ?쒓컙

        // ???섏뒪??由ъ뀑
        final lastQuestReset = _storage.lastQuestReset;
        if (lastQuestReset == null || !_storage.isToday(lastQuestReset)) {
          _resetDailyQuests();
          _storage.lastQuestReset = _storage.serverNow; // ???쒕쾭 ?쒓컙
        }
      });
    }
  }

  // ???쇱씪 ?섏뒪??珥덇린??(???섏뒪???앹꽦)
  // _initDailyQuests ?섏젙 - ??λ맂 ?곗씠??濡쒕뱶
  void _initDailyQuests() {
    // ????λ맂 ?섏뒪??濡쒕뱶 ?쒕룄
    final savedQuests = _storage.dailyQuests;

    if (savedQuests.isNotEmpty && _isQuestsFromToday()) {
      _dailyQuests = savedQuests;
      return;
    }

    // ?????섏뒪???앹꽦
    _dailyQuests = [
      DailyQuest(
        id: 'dq_enhance',
        name: '\uAC15\uD654 5\uD68C',
        description:
            '\uAC15\uD654\uB97C 5\uD68C \uC2DC\uB3C4\uD558\uC138\uC694',
        type: QuestType.enhance,
        target: 5,
        rewardGold: 500,
        rewardSeasonExp: 15,
      ),
      DailyQuest(
        id: 'dq_battle',
        name: '\uBC30\uD2C0 3\uD68C',
        description:
            '\uBC30\uD2C0\uC744 3\uD68C \uC9C4\uD589\uD558\uC138\uC694',
        type: QuestType.battle,
        target: 3,
        rewardGold: 500,
        rewardSeasonExp: 15,
      ),
      DailyQuest(
        id: 'dq_boss',
        name: '\uBCF4\uC2A4 \uCC98\uCE58 1\uD68C',
        description:
            '\uBCF4\uC2A4\uB97C 1\uD68C \uCC98\uCE58\uD558\uC138\uC694',
        type: QuestType.boss,
        target: 1,
        rewardGold: 300,
        rewardDiamond: 10,
        rewardSeasonExp: 20,
      ),
      DailyQuest(
        id: 'dq_gacha',
        name: '\uBF51\uAE30 3\uD68C',
        description: '\uAC80\uC744 3\uD68C \uBF51\uC73C\uC138\uC694',
        type: QuestType.gacha,
        target: 3,
        rewardGold: 500,
        rewardSeasonExp: 15,
      ),
      DailyQuest(
        id: 'dq_sell',
        name: '\uD310\uB9E4 2\uD68C',
        description: '\uAC80\uC744 2\uAC1C \uD310\uB9E4\uD558\uC138\uC694',
        type: QuestType.sell,
        target: 2,
        rewardGold: 300,
        rewardStone: 5,
        rewardSeasonExp: 10,
      ),
      DailyQuest(
        id: 'dq_login',
        name: '\uC624\uB298\uC758 \uC811\uC18D',
        description: '\uAC8C\uC784\uC5D0 \uC811\uC18D\uD558\uC138\uC694',
        type: QuestType.login,
        target: 1,
        rewardGold: 500,
        rewardSeasonExp: 10,
        progress: 1, // ?묒냽 利됱떆 ?꾨즺
      ),
    ];

    _storage.dailyQuests = _dailyQuests;
    _storage.lastQuestReset = _storage.serverNow; // ???쒕쾭 ?쒓컙
  }

  bool _isQuestsFromToday() {
    final lastReset = _storage.lastQuestReset;
    return lastReset != null && _storage.isToday(lastReset);
  }

  // ???섏뒪??由ъ뀑 ?⑥닔 (遺꾨━)
  void _resetDailyQuests() {
    _dailyQuests = [
      DailyQuest(
        id: 'dq_enhance',
        name: '\uAC15\uD654 5\uD68C',
        description:
            '\uAC15\uD654\uB97C 5\uD68C \uC2DC\uB3C4\uD558\uC138\uC694',
        type: QuestType.enhance,
        target: 5,
        rewardGold: 500,
      ),
      DailyQuest(
        id: 'dq_battle',
        name: '\uBC30\uD2C0 3\uD68C',
        description:
            '\uBC30\uD2C0\uC744 3\uD68C \uC9C4\uD589\uD558\uC138\uC694',
        type: QuestType.battle,
        target: 3,
        rewardGold: 500,
      ),
      DailyQuest(
        id: 'dq_boss',
        name: '\uBCF4\uC2A4 \uCC98\uCE58 1\uD68C',
        description:
            '\uBCF4\uC2A4\uB97C 1\uD68C \uCC98\uCE58\uD558\uC138\uC694',
        type: QuestType.boss,
        target: 1,
        rewardGold: 500,
      ),
      DailyQuest(
        id: 'dq_gacha',
        name: '\uBF51\uAE30 3\uD68C',
        description: '\uAC80\uC744 3\uD68C \uBF51\uC73C\uC138\uC694',
        type: QuestType.gacha,
        target: 3,
        rewardGold: 500,
      ),
      DailyQuest(
        id: 'dq_sell',
        name: '\uD310\uB9E4 2\uD68C',
        description: '\uAC80\uC744 2\uAC1C \uD310\uB9E4\uD558\uC138\uC694',
        type: QuestType.sell,
        target: 2,
        rewardGold: 500,
      ),
      DailyQuest(
        id: 'dq_login',
        name: '\uC811\uC18D',
        description: '\uAC8C\uC784\uC5D0 \uC811\uC18D\uD558\uC138\uC694',
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

    // ???⑤씪???뚮젅?댁뼱 異붽? (?덈떎硫?
    for (final player in _onlineRankings) {
      // ?대? 異붽????좎??몄? 泥댄겕 (以묐났 諛⑹?)
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
            : player.swordId, // ??寃 ID 異붽?
        'swordLevel': isSelf ? _equippedSword!.level : player.swordLevel,
        'swordBreakthroughLevel': isSelf
            ? _equippedSword!.breakthroughLevel
            : player.swordBreakthroughLevel,
        'element': isSelf ? _equippedSword!.data.element : player.element,
        'totalBattle': isSelf ? _totalBattle : player.totalBattle,
        'totalBattleWin': isSelf ? _totalBattleWin : player.totalBattleWin,
        'codexCount': isSelf ? _codex.length : player.codexCount,
        'isNpc': false,
        'isOnline': true,
      });
    }

    if (_equippedSword != null &&
        !_rankings.any((r) => r['id'] == widget.userId)) {
      _rankings.add({
        'id': widget.userId,
        'name': widget.nickname,
        'power': _totalPower,
        'swordGrade': _equippedSword!.data.grade,
        'swordName': _equippedSword!.data.name,
        'swordId': _equippedSword!.data.id,
        'swordLevel': _equippedSword!.level,
        'swordBreakthroughLevel': _equippedSword!.breakthroughLevel,
        'element': _equippedSword!.data.element,
        'totalBattle': _totalBattle,
        'totalBattleWin': _totalBattleWin,
        'codexCount': _codex.length,
        'isNpc': false,
        'isOnline': _isOnline,
      });
    }

    // ??v10.4: 寃?덈꺼 > 寃?꾪닾??> 寃?깃툒 ???뺣젹
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

    // ???쒖쐞 李얘린 (?⑤씪????궧 湲곗?)
    _myRank = _rankings.indexWhere((r) => r['id'] == widget.userId) + 1;

    // ?꾩쟻 ??궧 (?뱀닔 > ?밸쪧 > 珥?諛고? > ?꾪닾??
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
          '공지 $noticeTitle',
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
            child: const Text('\uB098\uC911\uC5D0'),
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
    final message = kind == 'achievement' ? '업적을 확인해주세요.' : '칭호를 확인해주세요.';

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

  // ???꾩꽕/遺덈㈇ ?띾뱷 異뺥븯 ?ㅼ씠?쇰줈洹?
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
              // 異뺥븯 ?띿뒪??
              const Text(
                '?럧 異뺥븯?⑸땲?? ?럧',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${grade.displayName} ?깃툒 ?띾뱷!',
                style: TextStyle(
                  color: grade.color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // 寃 ?대?吏 (SwordImageWidget)
              SwordImageWidget(
                grade: grade,
                element: sword.data.element,
                swordId: sword.data.id,
                level: sword.level,
                breakthroughLevel: sword.breakthroughLevel,
                size: 120,
                showPulse: true,
              ),
              const SizedBox(height: 16),

              // 寃 ?대쫫
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

              // ?꾪닾??
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flash_on, color: Colors.amber, size: 20),
                  Text(
                    ' ?꾪닾?? ${sword.totalPower}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ?뺤씤 踰꾪듉
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
                    '?뺤씤',
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
    // ???섎（ ?곹븳 泥댄겕
    if (_todaySeasonExp >= _maxDailySeasonExp) {
      // ?대? ?곹븳 ?꾨떖 - 異붽? EXP ?놁쓬
      return;
    }

    // ???곹븳 珥덇낵 ???섎씪?닿린
    final actualExp = (_todaySeasonExp + exp > _maxDailySeasonExp)
        ? _maxDailySeasonExp - _todaySeasonExp
        : exp;

    if (actualExp <= 0) return;

    _todaySeasonExp += actualExp; // ???ㅻ뒛 ?띾뱷??湲곕줉

    final prevLevel = _seasonPassLevel;
    _seasonPassExp += actualExp;

    while (_seasonPassExp >= _seasonPassLevel * AppConstants.expPerLevel &&
        _seasonPassLevel < AppConstants.maxSeasonPassLevel) {
      _seasonPassExp -= _seasonPassLevel * AppConstants.expPerLevel;
      _seasonPassLevel++;
    }

    // ???덈꺼?????뚮┝
    if (_seasonPassLevel > prevLevel) {
      if (_seasonPassLevel >= AppConstants.maxSeasonPassLevel) {
        _showNotification('시즌패스 최대 레벨 달성! Lv.$_seasonPassLevel');
      } else {
        _showNotification('시즌패스 레벨 업! Lv.$_seasonPassLevel');
      }
    }

    // ???곹븳 ?꾨떖 ?뚮┝ (理쒖큹 1??
    if (_todaySeasonExp >= _maxDailySeasonExp &&
        _todaySeasonExp - actualExp < _maxDailySeasonExp) {
      _showNotification('오늘의 시즌패스 EXP 상한(${_maxDailySeasonExp}) 도달!');
    }

    // ?뵦 ????쒓굅 - ?몄텧???≪뀡?먯꽌 ?대? ??ν븿 (Firebase 鍮꾩슜 ?덇컧)
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
      _showNotification('장착한 검이 없습니다');
      return;
    }

    if (sword.breakthroughLevel >= AppConstants.maxBreakthroughLevel) {
      _showNotification('최대 돌파 단계입니다');
      return;
    }

    final requiredLevel = _getSwordMaxEnhanceLevel(sword);
    if (sword.level < requiredLevel) {
      _showNotification('+$requiredLevel 달성 후 돌파할 수 있습니다');
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
          title: const Text('돌파', style: TextStyle(color: Colors.white)),
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
                      '?? ${sword.breakthroughLevel} -> ${sword.breakthroughLevel + 1}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '?? ??: +$requiredLevel -> +$nextMaxLevel',
                      style: const TextStyle(color: Colors.amber),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '?? ??: ?? ?? 20? ?? ? 1?',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '?? ??: ${formatNumber(goldCost)}G, ???? $coreCost?',
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
                            '?? ??: ${formatNumber(_gold)}G',
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
                            '?? ????: $_bossCore',
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
                                '??? ?????.',
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
                                '????? ?????.',
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
                        '?? ??? ?? ?? ????.',
                        style: TextStyle(color: Colors.redAccent),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '?? ? ??',
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
                                          swordId: material.data.id,
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
                                                '+${material.level}  ??${material.totalPower}',
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
                                '?? ??: ${selectedMaterial!.data.name} +${selectedMaterial!.level}'
                                ' / ??? ${selectedMaterial!.totalPower}',
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
              child: const Text('痍⑥냼'),
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
                          '?? ??! ?? ??? +${_getSwordMaxEnhanceLevel(sword)}? ??????',
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

  // _updateQuestProgress ?섏젙
  void _updateQuestProgress(QuestType type, [int amount = 1]) {
    bool updated = false;

    for (final quest in _dailyQuests) {
      if (quest.type == type && !quest.claimed) {
        final newProgress = (quest.progress + amount).clamp(0, quest.target);
        if (newProgress != quest.progress) {
          quest.progress = newProgress;
          updated = true;

          // ???꾨즺 ???뚮┝
          if (quest.isCompleted && quest.progress == quest.target) {
            _showNotification('퀘스트 완료: ${quest.name}');
          }
        }
      }
    }

    if (updated) {
      setState(() {});
      // ?뵦 ????쒓굅 - ?섏뒪?몃? ?몃━嫄고븳 ?≪뀡?먯꽌 ?대? ??ν븿 (Firebase 鍮꾩슜 ?덇컧)
    }
  }

  // ?ㅼ쓬 ?뚰듃?먯꽌 怨꾩냽...

  // ===== 媛뺥솕 =====
  void _enhance() {
    if (_equippedSword == null) {
      _showNotification('장착한 검이 없습니다');
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

    // 媛뺥솕???ъ슜 泥댄겕
    if (_useEnhanceStone && _enhanceStone <= 0) {
      _showNotification('강화석이 부족합니다');
      return;
    }

    // ?뱤 Analytics??- setState ?꾩뿉 ???
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

      // 媛뺥솕??蹂대꼫??(?덈꺼蹂?李⑤벑 ?곸슜)
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
        // ?깃났
        enhanceSuccess = true;
        destroyed = false;
        _equippedSword!.level++;
        _totalEnhanceSuccess++;
        _consecutiveSuccess++;
        _maxConsecutiveSuccess = max(
          _maxConsecutiveSuccess,
          _consecutiveSuccess,
        );
        _showNotification('강화 성공! +${_equippedSword!.level}');
        _addSeasonPassExp(10);
        _checkAchievements();

        // ?뵄 媛뺥솕 ?깃났 ?ъ슫??
        SoundService().playEnhanceSuccess();

        // ?뵦 媛뺥솕 ?깃났 ?좊땲硫붿씠???몃━嫄?
        _showEnhanceEffect = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showEnhanceEffect = false);
        });
      } else if (roll < successRate + destroyRate) {
        // ?뚭눼
        enhanceSuccess = false;
        destroyed = true;
        _totalDestroy++;
        _consecutiveSuccess = 0;
        final destroyedSword = _equippedSword!;

        // ?뵄 ?뚭눼 ?ъ슫??
        SoundService().playDestroy();

        // ?뚭눼??利됱떆 ?뺤젙 ??ν븯怨? 愿묎퀬 ?깃났 ?쒖뿉留?蹂듦뎄?쒕떎.
        _confirmDestroy(destroyedSword, showNotification: false);
        _showDestroyRecoveryDialog(destroyedSword);
      } else {
        // ?ㅽ뙣
        enhanceSuccess = false;
        destroyed = false;
        _totalEnhanceFail++;
        _consecutiveSuccess = 0;
        _showNotification('강화 실패');

        // ?뵄 媛뺥솕 ?ㅽ뙣 ?ъ슫??
        SoundService().playEnhanceFail();
      }

      _updateRankings();
      _saveGameData();
    });

    // ?뱤 Analytics (fire-and-forget)
    AnalyticsService().logEnhance(
      swordName: swordName,
      grade: swordGrade,
      level: currentLevel,
      success: enhanceSuccess ?? false,
      destroyed: destroyed ?? false,
    );
  }

  // ?렗 ?뚭눼 蹂듦뎄 愿묎퀬 ?ㅼ씠?쇰줈洹?
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
            const Text('🎁', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '?? ???????',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ?뚭눼??寃 ?뺣낫
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
                    swordId: destroyedSword.data.id,
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
                    '??? ${formatNumber(destroyedSword.totalPower)}',
                    style: const TextStyle(color: Colors.amber),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 愿묎퀬 蹂듦뎄 ?덈궡
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
                    const Text('AD', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '??? ???? ?? ??? ? ????!',
                            style: TextStyle(color: Colors.green, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '?? ?? ??: ${adService.getRemainingAdCount(AdRewardType.destroyRevive)}/3',
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
                  '?? ?? ?? ??? ?? ??????.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          // ?ш린 踰꾪듉
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('포기', style: TextStyle(color: Colors.red)),
          ),
          // 愿묎퀬 蹂듦뎄 踰꾪듉
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
              icon: const Text('AD'),
              label: Text(
                '?? (${adService.getRemainingAdCount(AdRewardType.destroyRevive)}/3)',
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

  // ?뚭눼 ?곸슜. 愿묎퀬 ?깃났 ?????곹깭瑜??섎룎由곕떎.
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
            '?뮙 寃???뚭눼?섏뿀?듬땲??.. (${_equippedSword!.data.name} ?먮룞 ?μ갑)',
          );
        } else {
          _showNotification('검이 파괴되었습니다...');
        }
      }

      if (removed) {
        _saveGameData();
      }
    });
  }

  // 愿묎퀬 蹂닿퀬 寃 蹂듦뎄
  Future<void> _watchAdToRecoverSword(OwnedSword destroyedSword) async {
    final adService = AdService();

    if (!adService.isRewardedAdReady) {
      adService.loadRewardedAd();
      _showNotification('광고를 불러오는 중입니다... 검은 아직 파괴되지 않았습니다');
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
          // ?대? ?몃깽?좊━???⑥븘?덉쑝誘濡??뚭눼留?痍⑥냼 泥섎━
          if (!_inventory.any((s) => s.uid == destroyedSword.uid)) {
            _inventory.add(destroyedSword);
          }
          _equippedSword = destroyedSword;
          _showNotification('${destroyedSword.data.name} 파괴가 취소되었습니다');
          _saveGameData();
        });
      },
      onError: (msg) {
        hadAdError = true;
        _showNotification(msg);
      },
    );

    // 愿묎퀬 ?쒖뒪???ㅻ쪟 ?쒖뿉???뚭눼 ?뺤젙?섏? ?딄퀬 ?ъ떆??湲고쉶 ?쒓났
    if (!success && hadAdError) {
      if (mounted) _showDestroyRecoveryDialog(destroyedSword);
      return;
    }

    // 愿묎퀬瑜??앷퉴吏 ??遊ㅼ쑝硫??대? ?곸슜???뚭눼 ?곹깭瑜?洹몃?濡??좎??쒕떎.
    if (!success && !hadAdError) {
      _confirmDestroy(destroyedSword);
    }
  }

  // ===== 戮묎린 =====

  // ?뵦 鍮좊Ⅸ 媛梨?(媛뺥솕 ?붾㈃??- ?앹뾽 ?놁씠 諛붾줈 戮묎린)
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

    // ?뱤 Analytics??
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

      // 泥?寃 ?먮룞 ?μ갑
      if (_equippedSword == null && newSwords.isNotEmpty) {
        _equippedSword = newSwords.first;
      }

      _addSeasonPassExp(count * 5);

      // 媛꾨떒???뚮┝留?(?앹뾽 ?놁씠)
      if (count == 1) {
        _showNotification(
          '?렟 ${newSwords.first.data.grade.emoji} ${newSwords.first.data.name} ?띾뱷!',
        );
      } else {
        final gradeEmojis = newSwords.map((s) => s.data.grade.emoji).join('');
        _showNotification('${count}개 획득! $gradeEmojis');
      }

      _updateRankings();
      _checkAchievements();
      _saveGameData();
    });

    // ?뱤 Analytics (fire-and-forget)
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

    // ?뱤 Analytics??- setState 諛뽰뿉???좎뼵
    final List<OwnedSword> newSwords = [];
    OwnedSword? bestSword;

    setState(() {
      _gold -= cost;
      _totalGacha += count;
      _updateQuestProgress(QuestType.gacha, count);

      SwordGrade? highestGrade;

      for (int i = 0; i < count; i++) {
        // ??泥쒖옣 ?곸슜??戮묎린
        final swordData = _rollGachaWithPity();
        final newSword = createNewSword(swordData);

        _inventory.add(newSword);
        newSwords.add(newSword);
        _codex.add(swordData.id);

        // 理쒓퀬 ?깃툒 異붿쟻
        if (highestGrade == null ||
            swordData.grade.index > highestGrade.index) {
          highestGrade = swordData.grade;
          bestSword = newSword;
        }
      }

      // 泥?寃 ?먮룞 ?μ갑
      if (_equippedSword == null && newSwords.isNotEmpty) {
        _equippedSword = newSwords.first;
      }

      _addSeasonPassExp(count * 5);

      // ?뵦 戮묎린 寃곌낵 ?ㅼ씠?쇰줈洹??쒖떆 (??寃 ?대?吏 ?곸슜)
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

    // ?뱤 Analytics (fire-and-forget) - 理쒓퀬 ?깃툒 寃留?濡쒓퉭
    if (bestSword != null) {
      AnalyticsService().logGacha(
        type: 'normal',
        resultGrade: bestSword!.data.grade.name,
        resultName: bestSword!.data.name,
      );
    }
  }

  // ???⑥닚 ?뺣쪧 戮묎린 (泥쒖옣 ?놁쓬 - 泥쒖옣? ?⑹꽦?먮쭔 ?곸슜)
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

    // 湲곕낯: ?몃쭚 ?깃툒
    final normalSwords = getSwordsByGrade(SwordGrade.normal);
    return normalSwords[_random.nextInt(normalSwords.length)];
  }

  // ===== ?⑹꽦 =====
  void _synthesize(List<OwnedSword> materials, {bool showResult = true}) {
    if (materials.length != AppConstants.synthesisRequiredCount) {
      _showNotification('검 3개를 선택하세요');
      return;
    }

    final grade = materials.first.data.grade;

    // 遺덈㈇? ?⑹꽦 遺덇?(理쒖긽??
    if (!canSynthesize(grade)) {
      _showNotification('불멸 등급은 합성할 수 없습니다');
      return;
    }

    // 媛숈? ?깃툒 泥댄겕
    if (!materials.every((s) => s.data.grade == grade)) {
      _showNotification('같은 등급만 합성할 수 있습니다');
      return;
    }

    final resultGrade = getSynthesisResultGrade(grade);
    if (resultGrade == null) {
      _showNotification('합성할 수 없는 등급입니다');
      return;
    }

    // ??怨⑤뱶 鍮꾩슜 泥댄겕
    if (_gold < AppConstants.synthesisCostGold) {
      _showNotification('골드가 부족합니다 (${AppConstants.synthesisCostGold}G 필요)');
      return;
    }

    setState(() {
      // ??怨⑤뱶 李④컧
      _gold -= AppConstants.synthesisCostGold;

      // ???μ갑 寃???щ즺濡??ъ슜?섏뿀?붿? 泥댄겕
      bool equippedWasUsed = materials.any((s) => s.uid == _equippedSword?.uid);

      // ?щ즺 ?쒓굅
      for (final sword in materials) {
        _inventory.remove(sword);
      }

      if (equippedWasUsed) {
        _equippedSword = null;
      }

      _totalSynthesis++;

      // 泥쒖옣 濡쒖쭅: ?몃쭚(10) / ?덉뼱(50) / ?좊땲??100)
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

      // ?뺣쪧 泥댄겕
      final probability = getSynthesisProbability(grade) ?? 0;
      final success = isCeiling || checkProbability(probability);

      if (success) {
        final resultSwords = getSwordsByGrade(resultGrade);
        final resultData = resultSwords[_random.nextInt(resultSwords.length)];
        final newSword = createNewSword(resultData);

        _inventory.add(newSword);
        _codex.add(resultData.id);

        // ???μ갑 寃???щ즺濡??ъ슜?섏뿀?쇰㈃ ??寃 ?먮룞 ?μ갑
        if (equippedWasUsed) {
          _equippedSword = newSword;
        }

        // ?깃났 ??泥쒖옣 移댁슫??由ъ뀑(?대떦 援ш컙留?
        if (grade == SwordGrade.normal) _normalToRarePity = 0;
        if (grade == SwordGrade.rare) _rareToUniquePity = 0;
        if (grade == SwordGrade.unique) _uniqueToLegendPity = 0;

        // ???⑹꽦 ?깃났 ?ㅼ씠?쇰줈洹?
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
        // ?ㅽ뙣: 媛숈? ?깃툒 1媛?諛섑솚
        final sameGradeSwords = getSwordsByGrade(grade);
        final resultData =
            sameGradeSwords[_random.nextInt(sameGradeSwords.length)];
        final newSword = createNewSword(resultData);

        _inventory.add(newSword);

        // ???μ갑 寃???щ즺濡??ъ슜?섏뿀?쇰㈃ 諛섑솚??寃 ?먮룞 ?μ갑
        if (equippedWasUsed) {
          _equippedSword = newSword;
        }

        // ???⑹꽦 ?ㅽ뙣 ?ㅼ씠?쇰줈洹?(媛숈? ?깃툒 諛섑솚)
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

      // 泥쒖옣 ?쒕컻?쇺앹씠硫?移댁슫??由ъ뀑(?ш린???뺤젙 泥섎━)
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

  // ???⑹꽦 寃곌낵 ?ㅼ씠?쇰줈洹?
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
              // 寃곌낵 ?띿뒪??
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
                    '?렞 泥쒖옣 ?ъ꽦!',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              Text(
                isSuccess ? '???⑹꽦 ?깃났!' : '?쁾 ?깃툒 ?곸듅 ?ㅽ뙣',
                style: TextStyle(
                  color: isSuccess ? Colors.white : Colors.white70,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),

              // ?깃툒 蹂???쒖떆
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(fromGrade.emoji, style: const TextStyle(fontSize: 24)),
                  Text(
                    isSuccess ? ' ??' : ' ??',
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

              // 寃곌낵 寃 ?대?吏 (SwordImageWidget)
              SwordImageWidget(
                grade: grade,
                element: resultSword.data.element,
                swordId: resultSword.data.id,
                level: resultSword.level,
                breakthroughLevel: resultSword.breakthroughLevel,
                size: 100,
                showPulse: true,
              ),
              const SizedBox(height: 8),

              // ?깃툒 諛곗?
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

              // 寃 ?대쫫
              Text(
                resultSword.data.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),

              // ?꾪닾??
              Text(
                '???꾪닾?? ${resultSword.totalPower}',
                style: const TextStyle(color: Colors.amber),
              ),

              if (!isSuccess) ...[
                const SizedBox(height: 12),
                Text(
                  '3媛???1媛쒕줈 ?⑹퀜議뚯뒿?덈떎',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],

              const SizedBox(height: 20),

              // ?뺤씤 踰꾪듉
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
                    '?뺤씤',
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

  // ===== ?먮ℓ =====

  // ?뵦 ?꾩옱 ?먮ℓ ?대깽???뺣낫
  Map<String, dynamic> get _currentSellEvent =>
      _sellEvents[_currentSellEventIndex];
  double get _sellEventRate => (_currentSellEvent['rate'] as num).toDouble();
  String get _sellEventName => _currentSellEvent['name'] as String;
  String get _sellEventEmoji => _currentSellEvent['emoji'] as String;
  Color get _sellEventColor => Color(_currentSellEvent['color'] as int);

  // ?뵦 ?먮ℓ ??留ㅻ쾲 ?쒕뜡 ?대깽???곸슜
  void _randomizeSellEvent() {
    final random = Random();

    // 媛以묒튂 湲곕컲 ?쒕뜡 (醫뗭? ?대깽?몃뒗 ??? ?뺣쪧)
    // [?쇰컲, ??벑, ???벑, 踰꾨툝, ?⑷툑?쒕?, ??씫, ???씫, 遺덇꼍湲? ?명솴]
    final weights = [30, 18, 8, 4, 2, 18, 10, 5, 15]; // 珥?110
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

  // ?뵦 ???붾㈃???대깽??蹂寃?(誘몃━蹂닿린)
  void _changeSellEvent() {
    _randomizeSellEvent();
    setState(() {});
  }

  void _sellSword(OwnedSword sword) {
    // ?렗 愿묎퀬 2諛??먮ℓ ?듭뀡 ?ㅼ씠?쇰줈洹?
    _showSellOptionsDialog(sword);
  }

  // ?렗 ?먮ℓ ?듭뀡 ?ㅼ씠?쇰줈洹?
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
            // 寃 ?뺣낫
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
                    swordId: sword.data.id,
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

            // ?먮ℓ ?듭뀡
            Row(
              children: [
                // ?쇰컲 ?먮ℓ
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
                // 愿묎퀬 2諛??먮ℓ
                Expanded(
                  child: _buildSellOptionButton(
                    label: '광고 2배',
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

  // ?렗 愿묎퀬 蹂닿퀬 2諛??먮ℓ
  void _watchAdToSellDouble(OwnedSword sword) async {
    final adService = AdService();

    if (!adService.isRewardedAdReady) {
      _showNotification('광고를 불러오는 중...');
      _executeSell(sword, bonusMultiplier: 1); // ?쇰컲 ?먮ℓ濡??泥?
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

  // ?뵦 ?ㅼ젣 ?먮ℓ ?ㅽ뻾
  void _executeSell(OwnedSword sword, {int bonusMultiplier = 1}) {
    // ?뵦 ?먮ℓ???뚮쭏???쒕뜡 ?대깽???곸슜!
    _randomizeSellEvent();

    // ?뵦 ?대깽??諛곗쑉 + 愿묎퀬 諛곗쑉 ?곸슜???먮ℓ媛
    final basePrice = sword.sellPrice;
    final eventPrice = (basePrice * _sellEventRate * bonusMultiplier).round();

    // ?뱤 Analytics??- setState ?꾩뿉 ???
    final swordGrade = sword.data.grade.name;

    setState(() {
      _inventory.remove(sword);

      // ?μ갑 以묒씤 寃???먮ℓ??寃쎌슦 ?먮룞 ?μ갑
      if (_equippedSword?.uid == sword.uid) {
        if (_inventory.isNotEmpty) {
          _inventory.sort((a, b) => b.totalPower.compareTo(a.totalPower));
          _equippedSword = _inventory.first;
          _showNotification(
            '${bonusMultiplier > 1 ? "?렗x2 " : ""}$_sellEventEmoji +${formatNumber(eventPrice)}G (${_equippedSword!.data.name} ?먮룞 ?μ갑)',
          );
        } else {
          _equippedSword = null;
          _showNotification(
            '${bonusMultiplier > 1 ? "?렗x2 " : ""}$_sellEventEmoji +${formatNumber(eventPrice)}G',
          );
        }
      } else {
        if (bonusMultiplier > 1) {
          _showNotification(
            '?렗x2 $_sellEventEmoji +${formatNumber(eventPrice)}G!',
          );
        } else if (_sellEventRate != 1.0) {
          _showNotification(
            '$_sellEventEmoji +${formatNumber(eventPrice)}G ($_sellEventName ${_sellEventRate}諛?)',
          );
        } else {
          _showNotification('+${formatNumber(eventPrice)}G');
        }
      }

      _gold += eventPrice;
      _totalSell++;
      _updateQuestProgress(QuestType.sell);

      _updateRankings();
      _checkAchievements();
      _saveGameData();
    });

    // ?뱤 Analytics (fire-and-forget)
    AnalyticsService().logSellSword(grade: swordGrade, goldEarned: eventPrice);
  }

  // ===== ?몃깽?좊━ ?뺤옣 (?몃깽?좊━ ??뿉?? =====
  void _showExpandInventoryDialog() {
    if (_maxInventory >= AppConstants.maxInventoryLimit) {
      _showNotification('최대 인벤토리입니다 (${AppConstants.maxInventoryLimit}개)');
      return;
    }
    final nextSlot = _maxInventory + 1;
    final price = inventoryPrices.firstWhere(
      (p) => p.$1 == nextSlot,
      orElse: () => (0, 0, ''),
    );
    if (price.$1 == 0) {
      _showNotification('가격 정보를 찾을 수 없습니다');
      return;
    }
    final cost = price.$2;
    final type = price.$3;
    final isGold = type == 'gold';
    final currencyName = isGold ? '골드' : '다이아';
    final currencyIcon = isGold ? '?뮥' : '?뭿';
    final hasEnough = isGold ? _gold >= cost : _diamond >= cost;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '인벤토리 확장',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_maxInventory}? -> ${_maxInventory + 1}?',
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
                    _showNotification('인벤토리 확장! (${_maxInventory}개)');
                  }
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('확장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ===== ?쇨큵 ?먮ℓ =====
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

      // ?μ갑 以묒씤 寃???먮ℓ?먯쑝硫??먮룞 ?μ갑
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
      '?뮥 ${swords.length}媛??먮ℓ! +${formatNumber(totalEarned)}G',
    );
  }

  // ===== 諛고? =====
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
      _showNotification('장착한 검이 없습니다');
      return;
    }

    // ?곷? ?좏깮
    Map<String, dynamic> opponent;
    if (npc != null) {
      opponent = {
        'id': npc.id,
        'name': npc.name,
        'power': npc.power,
        'swordGrade': npc.sword.grade,
        'swordId': npc.sword.id, // ??寃 ID 異붽?
        'element': npc.sword.element,
        'swordLevel': npc.swordLevel,
        'isNpc': true,
      };
    } else if (playerOpponent != null) {
      opponent = playerOpponent;
    } else {
      // ???덈꺼 湲곕컲 ?쒕뜡 留ㅼ묶
      final allCandidates = _rankings
          .where((r) => r['id'] != widget.userId)
          .toList();
      if (allCandidates.isEmpty) {
        _showNotification('상대를 찾을 수 없습니다');
        return;
      }

      final myLevel = _equippedSword?.level ?? 1;
      const int preferredRange = 3; // 짹3 ?덈꺼 踰붿쐞

      // 1李? 鍮꾩듂???덈꺼 ?좎? ?꾪꽣留?
      var candidates = allCandidates.where((r) {
        final oppLevel = (r['swordLevel'] as int?) ?? 1;
        return (oppLevel - myLevel).abs() <= preferredRange;
      }).toList();

      // 2李? 鍮꾩듂???덈꺼???놁쑝硫??꾩껜?먯꽌 ?좏깮
      if (candidates.isEmpty) {
        candidates = allCandidates;
      }

      // 3李? ?덈꺼 李⑥씠媛 ?곸? ?쒖쑝濡??뺣젹 ???곸쐞 50%?먯꽌 ?쒕뜡 ?좏깮 (??怨듭젙??留ㅼ묶)
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

      // ??BattleEngine???ъ슜?섏뿬 ?ㅼ젣 諛고? ?쒕??덉씠??
      final mySword = _equippedSword!;
      final oppGrade =
          (opponent['swordGrade'] as SwordGrade?) ?? SwordGrade.normal;
      final oppLevel = (opponent['swordLevel'] as int?) ?? 1;
      final oppElement =
          (opponent['element'] as GameElement?) ?? GameElement.fire;
      final oppId = (opponent['id'] as String?) ?? 'unknown';
      final oppName = (opponent['name'] as String?) ?? '?????놁쓬';
      final oppIsNpc = (opponent['isNpc'] as bool?) ?? true;
      final oppSwordId = opponent['swordId'] as String?;

      // ?곷? 寃 ?곗씠??媛?몄삤湲?(swordId媛 ?덉쑝硫??ㅼ젣 寃, ?놁쑝硫??깃툒?먯꽌 ?쒕뜡)
      SwordData oppSwordData;
      if (oppSwordId != null && oppSwordId.isNotEmpty) {
        // ???ㅼ젣 寃 ID濡?寃 ?곗씠??媛?몄삤湲?
        oppSwordData = allSwords.firstWhere(
          (s) => s.id == oppSwordId,
          orElse: () => getSwordsByGrade(oppGrade).first,
        );
      } else {
        // NPC??寃 ID媛 ?녿뒗 寃쎌슦 ?깃툒?먯꽌 ?쒕뜡 ?좏깮
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
        primarySkillType: mySword.data.primarySkillType, // ???덉쟾??getter ?ъ슜
        skills: mySword.data.skills,
        swordName: mySword.data.name,
        swordId: mySword.data.id,
        titleBonus: getTitleById(_equippedTitle).bonus, // ??移?샇 蹂대꼫???곸슜
      );

      final opp = BattleParticipant(
        id: oppId,
        name: oppName,
        grade: oppGrade,
        swordLevel: oppLevel,
        baseAtk: oppSwordData.baseAtk,
        element: oppElement,
        primarySkillType: oppSwordData.primarySkillType, // ???덉쟾??getter ?ъ슜
        skills: oppSwordData.skills,
        swordName: oppSwordData.name,
        swordId: oppSwordData.id,
      );

      // ??諛고? ?붿쭊?쇰줈 ?쒕??덉씠???ㅽ뻾
      final result = BattleEngine.simulate(me: me, opponent: opp);
      final isWin = result.iWin;

      int goldReward = 0;
      int stoneReward = 0; // ?뵰 媛뺥솕???쒕∼
      if (isWin) {
        _totalBattleWin++;
        _battleWinStreak++;
        _maxWinStreak = max(_maxWinStreak, _battleWinStreak);
        goldReward = result.rewardGold;
        _gold += goldReward;

        // ?뵰 媛뺥솕??30% ?뺣쪧 ?쒕∼
        if (Random().nextInt(100) < 30) {
          stoneReward = 1;
          _enhanceStone += stoneReward;
        }

        if (isRevenge) _totalRevengeWins++;
      } else {
        _battleWinStreak = 0;
      }

      // ?뵦 ?덈줈??諛고? ?꾨젅???붾㈃?쇰줈 ?대룞
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BattleArenaScreen(
            me: me,
            opponent: opp,
            result: result,
            stoneReward: stoneReward, // ?뵰 媛뺥솕???쒕∼
          ),
        ),
      ).then((_) {
        // ?뵰 諛고? 醫낅즺 ??媛뺥솕???띾뱷 ?뚮┝
        if (stoneReward > 0) {
          _showImageNotification(
            '鍮쏅굹??媛뺥솕??$stoneReward媛??띾뱷!',
            'assets/images/home/header/enhance_mythic.png',
          );
        }
      });

      // ??諛고? 濡쒓렇 ?ы븿?섏뿬 湲곕줉 ???
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

      // ???곷?諛⑹뿉寃?諛고? ?뚮┝ ?꾩넚 (NPC媛 ?꾨땶 寃쎌슦)
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

      // ?뱤 Analytics (fire-and-forget)
      AnalyticsService().logBattle(
        isWin: isWin,
        swordGrade: mySword.data.grade.name,
        playerPower: me.power,
        enemyPower: opp.power,
      );
    });
  }

  // ===== 蹂댁뒪 ?덉씠??=====
  void _startBossRaid(BossData boss) {
    if (_equippedSword == null) {
      _showNotification('장착한 검이 없습니다');
      return;
    }

    // 荑⑤떎??泥댄겕
    final cooldown = _bossCooldowns[boss.id];
    if (cooldown != null && cooldown.isAfter(_storage.serverNow)) {
      // ???쒕쾭 ?쒓컙
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

        // ???밸━ ?쒖뿉留?荑⑤떎???ㅼ젙
        _bossCooldowns[boss.id] = _storage.serverNow.add(
          boss.cooldownDuration,
        ); // ???쒕쾭 ?쒓컙
        _gold += boss.goldReward;
        _diamond += boss.diamondReward;
        _bossKills++;
        _updateQuestProgress(QuestType.boss); // ???밸━ ?쒖뿉留??섏뒪??吏꾪뻾
        _showNotification(
          '?럦 蹂댁뒪 泥섏튂! +${boss.goldReward}G +${boss.diamondReward}?뭿'
          '${coreReward > 0 ? ' +$coreReward?㎰' : ''}',
        );
        if (coreReward > 0) {
          _showImageNotification(
            '蹂댁뒪肄붿뼱 $coreReward媛??띾뱷!',
            'assets/images/home/header/enhance_mythic.png',
          );
        } else {
          _showNotification('파괴된 보스코어가 아직 없습니다');
        }
        _addSeasonPassExp(50);
      } else {
        // ???⑤같 ??荑⑤떎???놁쓬 (?먮뒗 吏㏃? 荑⑤떎??
        _bossCooldowns[boss.id] = _storage.serverNow.add(
          const Duration(minutes: 5),
        ); // ???쒕쾭 ?쒓컙
        _showNotification('휴식 중... 5분 후 시도 가능');
      }

      _checkAchievements();
      _saveGameData();
    });

    // ?뱤 Analytics (fire-and-forget)
    AnalyticsService().logBossBattle(isWin: isWin, bossFloor: boss.minLevel);
  }

  // ===== 異쒖꽍 =====
  void _checkAttendance() {
    if (!_canCheckAttendance) return;

    // ?렗 異쒖꽍 蹂댁긽 ?ㅼ씠?쇰줈洹??쒖떆
    _showAttendanceRewardDialog();
  }

  // ?렗 異쒖꽍 蹂댁긽 ?ㅼ씠?쇰줈洹?
  void _showAttendanceRewardDialog() {
    // ???곗냽 異쒖꽍 ?딄? 泥댄겕
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

    // 蹂댁긽 怨꾩궛
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
            const Text('★', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Text(
              streakBroken ? '연속 출석 초기화' : '$newStreak일 연속 출석!',
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
                  '연속 출석이 끊겼습니다.\\n다시 1일차부터 시작!',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),

            // 蹂댁긽 ?뺣낫
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
                        '${formatNumber(goldReward)}G',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasDiamondBonus) ...[
                        const SizedBox(width: 12),
                        Text(
                          '+${AppConstants.weeklyAttendanceDiamond} ???',
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

            // 踰꾪듉??
            Row(
              children: [
                // ?쇰컲 ?섎졊
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
                      '받기',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 愿묎퀬 2諛??섎졊
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
                  '?? ?? ??: ${adService.getRemainingAdCount(AdRewardType.attendanceBonus)}/1',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 異쒖꽍 蹂댁긽 吏湲?
  void _executeAttendance(
    int newStreak,
    int goldReward,
    bool hasDiamondBonus,
    int multiplier,
  ) {
    setState(() {
      _attendanceStreak = newStreak;
      _lastAttendance = _storage.serverNow; // ???쒕쾭 ?쒓컙
      _canCheckAttendance = false;

      final finalGold = goldReward * multiplier;
      _gold += finalGold;

      String message =
          '${multiplier > 1 ? "?렗x2 " : ""}${_attendanceStreak}???곗냽 異쒖꽍! +${formatNumber(finalGold)}G';

      if (hasDiamondBonus) {
        final finalDiamond = AppConstants.weeklyAttendanceDiamond * multiplier;
        _diamond += finalDiamond;
        message += ' +$finalDiamond 다이아 (주간 보너스)';
      }

      _showNotification(message);
      _checkAchievements();
      _saveGameData();
    });

    // ?뱤 Analytics (fire-and-forget)
    AnalyticsService().logAttendance(streak: newStreak, day: newStreak);
  }

  // 愿묎퀬濡?異쒖꽍 蹂댁긽 2諛?
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

  // ===== ?낆쟻 泥댄겕 =====
  // ===== ?낆쟻 泥댄겕(?꾩껜 ?곗씠??湲곕컲) =====
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

    // ===== 移?샇 泥댄겕 (30媛??꾩껜) =====

    // t_01: 珥덈낫 媛뺥솕??(寃뚯엫 ?쒖옉 - ?먮룞 遺??
    _unlockedTitles.add('t_01');

    // t_02: 媛뺥솕 ?낅Ц??(泥?媛뺥솕 ?깃났)
    if (_totalEnhanceSuccess >= 1) _unlockedTitles.add('t_02');

    // 媛뺥솕 ?④퀎 移?샇
    if (maxSwordLevel >= 5) _unlockedTitles.add('t_03'); // 5媛??ъ꽦??
    if (maxSwordLevel >= 10) _unlockedTitles.add('t_04'); // 10媛??ъ꽦??
    if (maxSwordLevel >= 15) _unlockedTitles.add('t_05'); // 15媛??ъ꽦??
    if (maxSwordLevel >= 20) _unlockedTitles.add('t_06'); // 20媛??ъ꽦??
    if (maxSwordLevel >= 25) _unlockedTitles.add('t_21'); // ?뙚 ?숇젴 媛뺥솕??
    if (maxSwordLevel >= 30) _unlockedTitles.add('t_26'); // ?몣 ?꾩꽕??媛뺥솕??
    if (maxSwordLevel >= 35) _unlockedTitles.add('t_32'); // ?뙛 珥덉썡 媛뺥솕??
    if (maxSwordLevel >= 45) _unlockedTitles.add('t_33'); // ?뙆 ?쒓퀎 珥덉썡

    // ?뚰뙆 移?샇
    if (breakthroughSwordCount >= 1) _unlockedTitles.add('t_31'); // ?㎰ ?뚰뙆??

    // 諛고? 愿??移?샇
    if (_totalBattleWin >= 1) _unlockedTitles.add('t_07'); // ?꾪닾 珥덈낫
    if (_battleWinStreak >= 10) _unlockedTitles.add('t_08'); // 10?곗듅
    if (_totalBattle >= 100) _unlockedTitles.add('t_09'); // 諛고? 留덈땲??
    if (_totalBattle >= 500) _unlockedTitles.add('t_22'); // ?뷂툘 諛깆쟾?몄옣
    if (_totalRevengeWins >= 10) _unlockedTitles.add('t_20'); // 蹂듭닔??移쇰궇

    // 蹂댁뒪 愿??移?샇
    if (_bossKills >= 10) _unlockedTitles.add('t_10'); // 蹂댁뒪 ?뚰꽣
    if (_bossKills >= 100) _unlockedTitles.add('t_23'); // ?릧 蹂댁뒪 ?щ젅?댁뼱

    // ?꾧컧 愿??移?샇
    if (_codex.length >= 20) _unlockedTitles.add('t_11'); // ?꾧컧 ?섏쭛媛
    if (_codex.length >= 50) _unlockedTitles.add('t_12'); // ?꾧컧 留덈땲??
    if (_codex.length >= 100) _unlockedTitles.add('t_25'); // ?뱴 ?꾧컧 留덉뒪??

    // ?ы솕 愿??移?샇
    if (_gold >= 100000) _unlockedTitles.add('t_13'); // 遺?먯쓽 ?쒖옉
    if (_gold >= 1000000) _unlockedTitles.add('t_24'); // ?뮥 媛묐?
    if (_diamond >= 10000) _unlockedTitles.add('t_28'); // ?뭿 ?ㅼ씠???섏쭛媛

    // 異쒖꽍 愿??移?샇
    if (_attendanceStreak >= 7) _unlockedTitles.add('t_14'); // 媛쒓렐??

    // ?섏뒪??愿??移?샇
    if (_totalQuestsCompleted >= 100) _unlockedTitles.add('t_15'); // ?섏뒪??留덉뒪??

    // ?⑹꽦/?먮ℓ 愿??移?샇
    if (_totalSynthesis >= 50) _unlockedTitles.add('t_17'); // ?⑹꽦 ?μ씤
    if (_totalSell >= 100) _unlockedTitles.add('t_18'); // ?먮ℓ??

    // ?쒖쫵?⑥뒪 愿??移?샇
    if (_seasonPassLevel >= 50) _unlockedTitles.add('t_19'); // ?쒖쫵?⑥뒪 ?꾨즺

    // ?덉뼱 ?섏쭛媛 (?덉뼱 ?댁긽 寃 10媛?蹂댁쑀)
    final rareOrHigherCount = _inventory
        .where((s) => s.data.grade.index >= SwordGrade.rare.index)
        .length;
    if (rareOrHigherCount >= 10) _unlockedTitles.add('t_16'); // ?덉뼱 ?섏쭛媛

    // ??궧 1??
    if (_myRank == 1) _unlockedTitles.add('t_27'); // ?룇 洹몃옖??留덉뒪??

    // ?덈뱺 移?샇: 遺덈㈇??寃 ?띾뱷
    final hasImmortal =
        _inventory.any((s) => s.data.grade == SwordGrade.immortal) ||
        _codex.any(
          (id) => allSwords.any(
            (s) => s.id == id && s.grade == SwordGrade.immortal,
          ),
        );
    if (hasImmortal) _unlockedTitles.add('t_29'); // ?뵰 ?덈뱺 (遺덈㈇??寃)

    // ?덈뱺 移?샇: 100?곗듅
    if (_maxWinStreak >= 100) _unlockedTitles.add('t_30'); // ???덈뱺 (100?곗듅)

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

  // 湲곗〈 肄붾뱶?먯꽌 ?몄텧?섎뜕 _checkAchievements()???꾨옒泥섎읆 ?곌껐(?명솚??
  void _checkAchievements() {
    _checkAchievementsFull();
  }

  // ?ㅼ쓬 ?뚰듃?먯꽌 怨꾩냽...

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
              Positioned.fill(
                child: _GameImageShell(
                  currentTab: _currentTab,
                  body: _buildCurrentPage(),
                  nickname: widget.nickname,
                  totalPower: _totalPower,
                  gold: _gold,
                  diamond: _diamond,
                  onHome: () => setState(() => _currentTab = 0),
                  onInventory: () => setState(() => _currentTab = 1),
                  onEnhance: () => setState(() => _currentTab = 2),
                  onBattle: () => setState(() => _currentTab = 3),
                  onShop: _openShopScreen,
                  onMenu: _showSettingsDialog,
                ),
              ),

              // ?뚮┝
              if (_notification != null)
                Positioned(
                  top: 100,
                  left: 20,
                  right: 20,
                  child: _buildNotification(),
                ),

              // ???곗씠??濡쒕뵫 ?ㅻ쾭?덉씠 (濡쒕뵫 以?議곗옉?쇰줈 ?쒕쾭 ??뼱?곌린 諛⑹?)
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
                                '데이터를 불러오는 중...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ] else ...[
                              const Text(
                                '불러오는 데 시간이 걸리고 있어요.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  // 다시 시도할 수 있도록 대기 상태를 해제하고 재로딩한다.
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

  Widget _buildCurrentPage() {
    switch (_currentTab) {
      case 0:
        return HomeTab(
          nickname: widget.nickname,
          gold: _gold,
          diamond: _diamond,
          enhanceStone: _enhanceStone,
          totalPower: _totalPower,
          equippedSword: _equippedSword,
          dailyQuests: _dailyQuests,
          titleBonus: getTitleById(_equippedTitle).bonus,
          titleName: getTitleById(_equippedTitle).name,
          onShowGachaDialog: _showGachaDialog,
          onShowSynthesisDialog: _showSynthesisDialog,
          onShowBossSelectDialog: _showBossSelectDialog,
          onShowRankingDialog: _showRankingDialog,
          onOpenMinigame: _openMinigame,
          onOpenInfiniteTower: _openInfiniteTower,
          onOpenHome: () => setState(() => _currentTab = 0),
          onOpenInventory: () => setState(() => _currentTab = 1),
          onOpenEnhance: () => setState(() => _currentTab = 2),
          onOpenBattle: () => setState(() => _currentTab = 3),
          onOpenShop: _openShopScreen,
          onShowSwordTestDialog: _showSwordImageTestDialog,
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
          nickname: widget.nickname,
          equippedSword: _equippedSword,
          gold: _gold,
          diamond: _diamond,
          totalPower: _totalPower,
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
          onOpenHome: () => setState(() => _currentTab = 0),
          onOpenInventory: () => setState(() => _currentTab = 1),
          onOpenEnhance: () => setState(() => _currentTab = 2),
          onOpenBattle: () => setState(() => _currentTab = 3),
          onOpenShop: _openShopScreen,
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
          onOpenMinigame: _openMinigame,
        );
      default:
        return HomeTab(
          nickname: widget.nickname,
          gold: _gold,
          diamond: _diamond,
          enhanceStone: _enhanceStone,
          totalPower: _totalPower,
          equippedSword: _equippedSword,
          dailyQuests: _dailyQuests,
          titleBonus: getTitleById(_equippedTitle).bonus,
          titleName: getTitleById(_equippedTitle).name,
          onShowGachaDialog: _showGachaDialog,
          onShowSynthesisDialog: _showSynthesisDialog,
          onShowBossSelectDialog: _showBossSelectDialog,
          onShowRankingDialog: _showRankingDialog,
          onOpenMinigame: _openMinigame,
          onOpenInfiniteTower: _openInfiniteTower,
          onOpenHome: () => setState(() => _currentTab = 0),
          onOpenInventory: () => setState(() => _currentTab = 1),
          onOpenEnhance: () => setState(() => _currentTab = 2),
          onOpenBattle: () => setState(() => _currentTab = 3),
          onOpenShop: _openShopScreen,
          onShowSwordTestDialog: _showSwordImageTestDialog,
          onClaimQuestReward: _claimQuestReward,
        );
    }
  }

  void _showSwordImageTestDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => const SwordImageTestDialog(),
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

  // ===== ???섏씠吏 =====
  void _claimQuestReward(DailyQuest quest) {
    if (!quest.isCompleted || quest.claimed) return;

    setState(() {
      quest.claimed = true;

      // ???ㅼ뼇??蹂댁긽 吏湲?
      if (quest.rewardGold > 0) {
        _gold += quest.rewardGold;
      }
      if (quest.rewardDiamond > 0) {
        _diamond += quest.rewardDiamond;
      }
      if (quest.rewardStone > 0) {
        _enhanceStone += quest.rewardStone;
      }

      // ???쒖쫵?⑥뒪 寃쏀뿕移?
      if (quest.rewardSeasonExp > 0) {
        _addSeasonPassExp(quest.rewardSeasonExp);
      }

      // ???듦퀎 ?낅뜲?댄듃
      _totalQuestsCompleted++;

      _showNotification('보상 획득: ${quest.rewardText}');
      _checkAchievements();
      _saveGameData();
    });
  }

  // ===== ?몃깽?좊━/媛뺥솕/諛고?/?붾낫湲??섏씠吏 (媛꾨왂?? =====
  Future<void> _showBattleSelectScreen() async {
    final selected = await Navigator.push(
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

    if (selected is! OpponentEntry) return;
    _startBattle(
      playerOpponent: {
        'id': selected.id,
        'name': selected.name,
        'power': selected.power,
        'swordGrade': selected.sword.grade,
        'swordId': selected.sword.id,
        'element': selected.sword.element,
        'swordLevel': selected.swordLevel,
        'isNpc': selected.isNpc,
      },
    );
  }

  Future<void> _startRevengeMatch(BattleRecord record) async {
    final grade = SwordGrade.values.firstWhere(
      (g) => g.name == record.opponentGrade,
      orElse: () => SwordGrade.normal,
    );
    final element = GameElement.values.firstWhere(
      (e) => e.name == record.opponentElement,
      orElse: () => GameElement.fire,
    );

    _startBattle(
      playerOpponent: {
        'id': record.opponentId,
        'name': record.opponentName,
        'swordGrade': grade,
        'element': element,
        'swordLevel': record.opponentLevel,
        'isNpc': record.opponentIsNpc,
      },
      isRevenge: true,
    );
  }

  void _watchAdForFreeGacha() {
    AdService().showRewardedAd(
      type: AdRewardType.freeGacha,
      onRewarded: () => _doPremiumGacha(1, isFree: true),
      onError: (err) => _showNotification(err),
    );
  }

  void _watchAdForStones() {
    const rewardStones = 10;
    AdService().showRewardedAd(
      type: AdRewardType.stoneReward,
      onRewarded: () {
        setState(() {
          _enhanceStone += rewardStones;
          _saveGameData();
        });
        _showNotification('강화석 $rewardStones개 획득!');
      },
      onError: (err) => _showNotification(err),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: const Text('로그아웃', style: TextStyle(color: Colors.white)),
        content: const Text(
          '?뺣쭚 濡쒓렇?꾩썐 ?섏떆寃좎뒿?덇퉴?\n\n寃뚯엫 ?곗씠?곕뒗 ??λ릺???덉쑝硫?\n?ㅼ떆 濡쒓렇?명븯硫??댁뼱???뚮젅?댄븷 ???덉뒿?덈떎.',
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

  // ???ㅼ젣 濡쒓렇?꾩썐 泥섎━
  Future<void> _performLogout() async {
    try {
      // ??1?④퀎: 罹먯떆?먮쭔 ?곌린 (saveToCloud ?몄텧 ????)
      //    ??fire-and-forget ??μ씠 signOut ???ㅽ뙣?섏뿬
      //      _saveToLocalBackup?쇰줈 ?곗씠???꾩텧?섎뒗 寃?諛⑹?
      _saveGameData(cloudSave: false);

      // ??2?④퀎: ????踰덈쭔 媛뺤젣 ???(?붾컮?댁떛 臾댁떆, await ?꾨즺 蹂댁옣)
      await _storage.saveToCloud(force: true);

      // ??3?④퀎: Firebase 濡쒓렇?꾩썐
      await AuthService().signOut();

      // ??4?④퀎: 紐⑤뱺 ?쒕퉬?ㅼ쓽 濡쒖뺄 ?곹깭 ?꾩쟾 珥덇린??
      await StorageService().resetForLogout();
      await AdService().resetForLogout();
      await PurchaseService().resetForLogout();

      // 濡쒓렇???붾㈃?쇰줈 ?대룞 (紐⑤뱺 ?붾㈃ ?쒓굅)
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      _showNotification('로그아웃 실패: $e');
    }
  }

  // ??怨꾩젙 ??젣 ?뺤씤 ?ㅼ씠?쇰줈洹?
  void _showDeleteAccountDialog() {
    final TextEditingController confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: const Text('계정 삭제', style: TextStyle(color: Colors.red)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '?좑툘 寃쎄퀬: ???묒뾽? ?섎룎由????놁뒿?덈떎!\n\n'
                '怨꾩젙????젣?섎㈃ 紐⑤뱺 ?곗씠?곌? ??젣?⑸땲??\n\n'
                '?뺣쭚 ??젣?섏떆?ㅻ㈃ "??젣?⑸땲??瑜??낅젰?섏꽭??',
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
              if (confirmController.text == '\uC0AD\uC81C\uD569\uB2C8\uB2E4') {
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

  // ???ㅼ젣 怨꾩젙 ??젣 泥섎━
  Future<void> _performDeleteAccount() async {
    try {
      // 濡쒕뵫 ?쒖떆
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // 1. Firestore ?곗씠????젣
      final uid = AuthService().uid;
      if (uid != null) {
        await _storage.deleteAllUserData(uid);
      }

      // 2. Firebase Auth 怨꾩젙 ??젣
      final result = await AuthService().deleteAccount();

      // 濡쒕뵫 ?リ린
      if (mounted) Navigator.pop(context);

      if (result.isSuccess) {
        // 3. 濡쒖뺄 ?곗씠??珥덇린??
        await _storage.resetForLogout(); // ??SharedPreferences 諛깆뾽 ?ы븿 ??젣
        await AdService().resetForLogout();
        await PurchaseService().resetForLogout();

        // 4. 濡쒓렇???붾㈃?쇰줈 ?대룞
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else if (result.errorMessage == 'REQUIRES_RECENT_LOGIN') {
        // ???ъ씤利??꾩슂 - 鍮꾨?踰덊샇 ?낅젰 ?ㅼ씠?쇰줈洹??쒖떆
        _showReauthenticateDialog();
      } else {
        _showNotification('계정 삭제 실패: ${result.errorMessage}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // 濡쒕뵫 ?リ린
      _showNotification('계정 삭제 실패: $e');
    }
  }

  // ???ъ씤利??ㅼ씠?쇰줈洹?
  void _showReauthenticateDialog() {
    final passwordController = TextEditingController();
    final user = AuthService().currentUser;
    final email = user?.email ?? '';

    // ?듬챸 怨꾩젙?대㈃ 諛붾줈 ?щ줈洹몄씤 ?덈궡
    if (user?.isAnonymous == true) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a4a),
          title: const Text('재로그인 필요', style: TextStyle(color: Colors.white)),
          content: const Text(
            '蹂댁븞???꾪빐 ?ㅼ떆 濡쒓렇?몄씠 ?꾩슂?⑸땲??\n\n'
            '濡쒓렇?꾩썐 ???ㅼ떆 濡쒓렇?명빐二쇱꽭??',
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
                // ??濡쒖뺄 罹먯떆 珥덇린??(SharedPreferences 諛깆뾽 ?ы븿 ??젣)
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
              '蹂댁븞???꾪빐 鍮꾨?踰덊샇瑜??ㅼ떆 ?낅젰?댁＜?몄슂.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '怨꾩젙: $email',
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

  // ???ъ씤利?????젣
  Future<void> _reauthenticateAndDelete(String email, String password) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // ?ъ씤利?
      final reauthResult = await AuthService().reauthenticateWithEmail(
        email: email,
        password: password,
      );

      if (!reauthResult.isSuccess) {
        if (mounted) Navigator.pop(context);
        _showNotification('비밀번호가 틀렸습니다');
        return;
      }

      // ?ъ씤利??깃났 ??怨꾩젙 ??젣
      final deleteResult = await AuthService().deleteAccount();

      if (mounted) Navigator.pop(context);

      if (deleteResult.isSuccess) {
        await _storage.resetForLogout(); // ??SharedPreferences 諛깆뾽 ?ы븿 ??젣
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

  Future<void> _openMinigame() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrickBreakerScreen(
          inventory: _inventory,
          gold: _gold,
          diamond: _diamond,
          enhanceStone: _enhanceStone,
        ),
      ),
    );

    if (result is Map) {
      setState(() {
        _gold = result['gold'] as int? ?? _gold;
        _diamond = result['diamond'] as int? ?? _diamond;
        _enhanceStone = result['enhanceStone'] as int? ?? _enhanceStone;
        _saveGameData();
      });
    }
  }

  Future<void> _openInfiniteTower() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InfiniteTowerScreen(
          inventory: _inventory,
          gold: _gold,
          diamond: _diamond,
          enhanceStone: _enhanceStone,
        ),
      ),
    );

    if (result is Map) {
      setState(() {
        _gold = result['gold'] as int? ?? _gold;
        _diamond = result['diamond'] as int? ?? _diamond;
        _enhanceStone = result['enhanceStone'] as int? ?? _enhanceStone;
        _saveGameData();
      });
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
          todaySeasonExp: _todaySeasonExp, // ??異붽?
          maxDailySeasonExp: _maxDailySeasonExp, // ??異붽?
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
                '?쇰컲 蹂댁긽 ?섎졊! '
                '+${formatNumber(reward.gold)}G'
                '${reward.diamond > 0 ? ' +${reward.diamond}?뭿' : ''}'
                '${reward.stone > 0 ? ' +${reward.stone}?뵰' : ''}',
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
                '?몣 ?꾨━誘몄뾼 蹂댁긽 ?섎졊! '
                '+${formatNumber(reward.premiumGold)}G'
                '${reward.premiumDiamond > 0 ? ' +${reward.premiumDiamond}?뭿' : ''}'
                '${reward.premiumStone > 0 ? ' +${reward.premiumStone}?뵰' : ''}',
              );
              _saveGameData();
            });
          },
          onBuyPremiumPass: () {
            if (_hasPremiumPass) {
              _showNotification('이미 프리미엄 패스를 보유하고 있습니다');
              return;
            }
            // ?뮥 ?몄빋 寃곗젣 ?쒖옉
            _purchaseService.purchaseByShopId('premium_pass');
          },
        ),
      ),
    );
  }

  Future<void> _openAchievementsScreen() async {
    // 理쒖떊 ?몃씫 媛깆떊 (蹂寃??쒖뿉留????- Firebase 鍮꾩슜 ?덇컧)
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
                '?낆쟻 蹂댁긽 ?섎졊! +${formatNumber(ach.rewardGold)}G'
                '${ach.rewardDiamond > 0 ? ' +${ach.rewardDiamond}?뭿' : ''}'
                '${ach.rewardStone > 0 ? ' +${ach.rewardStone}?뵰' : ''}',
              );
              _saveGameData();
            });
          },
        ),
      ),
    );
  }

  // ?뫁 移쒓뎄 ?붾㈃ ?닿린
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
    final canSell = true; // ?뵦 寃 1媛쒖뿬???먮ℓ 媛??

    showDialog(
      context: context,
      builder: (_) => SwordDetailDialog(
        sword: sword,
        isEquipped: isEquipped,
        canSell: canSell, // ??異붽?
        onEquip: () {
          setState(() => _equippedSword = sword);
          _storage.equippedSwordUid = sword.uid;
          _updateRankings();
          _saveGameData();
          _syncMyProfile(); // ?뵦 ?λ퉬 蹂寃??쒖뿉留??꾨줈???숆린??
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
  // ?렟 戮묎린 寃곌낵 ?ㅼ씠?쇰줈洹?(?⑥씪)
  // =====================================================
  void _showGachaResultDialog(
    OwnedSword sword, {
    bool isPremium = false,
    bool isFree = false,
  }) {
    final grade = sword.data.grade;

    // ?뵄 戮묎린 ?ъ슫??(?좊땲???댁긽?대㈃ ?덉뼱 ?ъ슫??
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
              // ?ㅻ뜑
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
                          ? '?렗 臾대즺 怨좉툒 戮묎린!'
                          : (isPremium ? '?뭿 怨좉툒 戮묎린 寃곌낵!' : '?렟 戮묎린 寃곌낵!'),
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

              // 寃 ?대?吏
              Padding(
                padding: const EdgeInsets.all(24),
                child: SwordImageWidget(
                  grade: grade,
                  element: sword.data.element,
                  swordId: sword.data.id,
                  level: sword.level,
                  size: 140,
                  showPulse: true,
                ),
              ),

              // 寃 ?뺣낫
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
                    '??${sword.totalPower}',
                    style: const TextStyle(color: Colors.amber, fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${sword.data.element.emoji} ${sword.data.element.nameKr}',
                    style: const TextStyle(color: Colors.cyan, fontSize: 14),
                  ),
                ],
              ),

              // ?뺤씤 踰꾪듉
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
                      '?뺤씤',
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
  // ?뭿 怨좉툒 戮묎린
  // =====================================================
  void _doPremiumGacha(int count, {bool isFree = false}) {
    // 鍮꾩슜 怨꾩궛
    int cost;
    bool guaranteeUnique = false;

    if (count == 1) {
      cost = premiumGachaCostSingle;
    } else if (count == 5) {
      cost = premiumGachaCost5x;
    } else {
      cost = premiumGachaCost10x;
      guaranteeUnique = true; // 10?뚯떆 ?좊땲???댁긽 1媛??뺤젙
    }

    // 臾대즺媛 ?꾨땺 ?뚮쭔 鍮꾩슜 泥댄겕
    if (!isFree && _diamond < cost) {
      _showNotification('다이아가 부족합니다!');
      return;
    }

    if (_inventory.length + count > _maxInventory) {
      _showNotification('인벤토리가 가득 찼습니다!');
      return;
    }

    // ?뱤 Analytics??
    final newSwords = <OwnedSword>[];
    OwnedSword? bestSword;

    setState(() {
      // 臾대즺媛 ?꾨땺 ?뚮쭔 鍮꾩슜 李④컧
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

        // ?좊땲???댁긽 泥댄겕
        if (swordData.grade.index >= SwordGrade.unique.index) {
          hasUniqueOrHigher = true;
        }

        // ?뱤 理쒓퀬 ?깃툒 異붿쟻
        if (highestGrade == null ||
            swordData.grade.index > highestGrade.index) {
          highestGrade = swordData.grade;
          bestSword = newSword;
        }
      }

      // 10??戮묎린?몃뜲 ?좊땲???댁긽???놁쑝硫?留덉?留?寃???좊땲?щ줈 援먯껜
      if (guaranteeUnique && !hasUniqueOrHigher) {
        // 留덉?留?寃 ?쒓굅
        _inventory.remove(newSwords.last);

        // ?좊땲???댁긽 ?뺤젙 戮묎린
        final guaranteedSword = _rollGuaranteedUniqueOrHigher();
        final newSword = createNewSword(guaranteedSword);
        newSwords[newSwords.length - 1] = newSword;
        _inventory.add(newSword);
        _codex.add(guaranteedSword.id);
        bestSword = newSword; // ?뱤 ?뺤젙 戮묎린媛 理쒓퀬 ?깃툒
      }

      // 寃곌낵 ?쒖떆 (臾대즺硫?硫붿떆吏 異붽?)
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

    // ?뱤 Analytics (fire-and-forget)
    if (bestSword != null) {
      AnalyticsService().logGacha(
        type: 'premium',
        resultGrade: bestSword!.data.grade.name,
        resultName: bestSword!.data.name,
      );
    }
  }

  // ?뭿 怨좉툒 戮묎린 ?뺣쪧
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

    // 湲곕낯媛? ?덉뼱
    final rareSwords = getSwordsByGrade(SwordGrade.rare);
    return rareSwords[_random.nextInt(rareSwords.length)];
  }

  // ?좊땲???댁긽 ?뺤젙 戮묎린 (10??蹂대꼫?ㅼ슜)
  SwordData _rollGuaranteedUniqueOrHigher() {
    // ?좊땲???댁긽留??덈뒗 ?뺣쪧 ?뚯씠釉?
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

    // 湲곕낯媛? ?좊땲??
    final uniqueSwords = getSwordsByGrade(SwordGrade.unique);
    return uniqueSwords[_random.nextInt(uniqueSwords.length)];
  }

  // ?ㅼ쨷 戮묎린 寃곌낵 ?ㅼ씠?쇰줈洹?(怨좉툒 戮묎린???뺤옣)
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
                isPremium ? '?뭿 怨좉툒 戮묎린' : '?렟 戮묎린 寃곌낵',
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
                  '???뺤젙',
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
              // 理쒓퀬 ?깃툒 ?쒖떆
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

              // 寃 洹몃━??
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
                          // ???대え吏 ???SwordImageWidget ?ъ슜
                          SwordImageWidget(
                            grade: sword.data.grade,
                            element: sword.data.element,
                            swordId: sword.data.id,
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

              // ?깃툒蹂?移댁슫??
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
        // ?뵦 ?⑹꽦 ????pity 媛?諛섑솚
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
      useSafeArea: false,
      builder: (_) => Season1BossSelectDialog(
        equippedSword: _equippedSword,
        bossCooldowns: _bossCooldowns,
        serverNow: _storage.serverNow,
        bossCore: _bossCore,
        onChallenge: (boss) {
          Navigator.pop(context);
          _startBossRaid(boss);
        },
        onSkipCooldown: (boss) {
          Navigator.pop(context);
          _watchAdToSkipBossCooldown(boss);
        },
      ),
    );
  }

  // ?렗 愿묎퀬濡?蹂댁뒪 荑⑤떎???ㅽ궢
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
          _bossCooldowns.remove(boss.id); // 荑⑤떎???쒓굅
          _showNotification('쿨다운이 초기화되었습니다!');
        });
        // 諛붾줈 蹂댁뒪 ?꾩쟾
        _startBossRaid(boss);
      },
      onError: (msg) => _showNotification(msg),
    );
  }

  bool _isRankingDialogOpen = false;

  void _showRankingDialog() {
    if (_isRankingDialogOpen) return; // 以묐났 ??諛⑹?
    if (_tryOpenSeason1RankingDialog()) return;
    _isRankingDialogOpen = true;

    // 諛깃렇?쇱슫?쒖뿉????궧 媛깆떊 (?ㅼ씠?쇰줈洹몃뒗 利됱떆 ?대┝)
    _fetchOnlineRankings(forceRefresh: true);

    bool dialogOpen = true;
    bool isRefreshing = false;
    int selectedTab = 0; // 0: 寃 ??궧, 1: 諛고? ?꾩쟻

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a4a),
          title: Row(
            children: [
              const Text('랭킹', style: TextStyle(color: Colors.white)),
              const Spacer(),
              // ???⑤씪???ㅽ봽?쇱씤 ?곹깭 ?쒖떆
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
                      _isOnline
                          ? '\uC628\uB77C\uC778'
                          : '\uC624\uD504\uB77C\uC778',
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
                              '? ??',
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
                              '?? ??',
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
                // ?????쒖쐞 ?섏씠?쇱씠??
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
                                  ? '?꾪닾?? ${formatNumber(_totalPower)}'
                                  : '$_totalBattleWin? ${_totalBattle - _totalBattleWin}?',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            if (selectedTab == 1)
                              Text(
                                "\uC2B9\uB960 ${_totalBattle > 0 ? ((_totalBattleWin / _totalBattle) * 100).toStringAsFixed(1) : '0.0'}%",
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

                // ???꾩껜 ??궧 紐⑸줉 (100?꾧퉴吏)
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
                                // ?쒖쐞
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
                                // ??寃 ?대?吏 (SwordImageWidget?쇰줈 蹂寃?
                                SwordImageWidget(
                                  grade: grade,
                                  element: element,
                                  swordId: r['swordId'] as String?,
                                  level: swordLevel,
                                  breakthroughLevel:
                                      (r['swordBreakthroughLevel'] as int?) ??
                                      0,
                                  size: 28, // ??36 ??28濡?以꾩엫
                                  showPulse: false,
                                ),
                                const SizedBox(width: 8),
                                // ?대쫫
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
                                          // ???뚮젅?댁뼱 ?좏삎 ?쒖떆
                                          if (r['isNpc'] == true)
                                            const Text(
                                              '?쨼',
                                              style: TextStyle(fontSize: 10),
                                            )
                                          else if (isOnlinePlayer)
                                            const Text(
                                              '??',
                                              style: TextStyle(fontSize: 10),
                                            ),
                                        ],
                                      ),
                                      Text(
                                        selectedTab == 0
                                            ? '${r['swordName']} +${r['swordLevel']}'
                                            : '$wins\uC2B9 ${total - wins}\uD328',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                        ),
                                      ),
                                      if (selectedTab == 1)
                                        Text(
                                          '?? ${winRate.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                            color: Colors.white30,
                                            fontSize: 10,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // ?곗륫 吏??
                                Text(
                                  selectedTab == 0
                                      ? formatNumber(r['power'] as int)
                                      : '$wins?',
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
            // ???덈줈怨좎묠 踰꾪듉
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
    }); // ?ロ옄 ???뚮옒洹??댁젣
  }

  bool _tryOpenSeason1RankingDialog() {
    _isRankingDialogOpen = true;
    unawaited(_openSeason1RankingDialog());
    return true;
  }

  Future<void> _openSeason1RankingDialog() async {
    try {
      await _fetchExtendedRankings(forceRefresh: true);
      if (!mounted) return;
      await showDialog(
        context: context,
        useSafeArea: false,
        builder: (_) => Season1RankingDialog(
          userId: widget.userId,
          swordRankings: _rankings,
          battleRankings: _battleRankings,
          towerRankings: _towerRankings,
          codexRankings: _codexRankings,
        ),
      );
    } finally {
      _isRankingDialogOpen = false;
    }
  }

  void _showTitleDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: Row(
          children: [
            const Text('칭호 관리', style: TextStyle(color: Colors.white)),
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
                    // 移?샇 ?뺣낫
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
                              '蹂대꼫?? ?꾪닾??+${title.bonus}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ?μ갑 踰꾪듉
                    if (unlocked && !equipped)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _equippedTitle = title.id;
                            _saveGameData();
                            _syncMyProfile(); // ?뵦 移?샇 蹂寃??쒖뿉留??꾨줈???숆린??
                            _updateRankings(); // ??궧 ?쒖떆 ?꾪닾??利됱떆 媛깆떊
                          });
                          Navigator.pop(context);
                          _showNotification('칭호 장착: ${title.name}');
                        },
                        child: const Text('장착'),
                      )
                    else if (equipped)
                      const Text(
                        '\uC7A5\uCC29',
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
            const Text('검 도감', style: TextStyle(color: Colors.white)),
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
                        // 寃 ?대?吏
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: collected
                              ? SwordImageWidget(
                                  grade: sword.grade,
                                  element: sword.element,
                                  swordId: sword.id,
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
                                      '',
                                      style: TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        // 寃 ?뺣낫
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ?대쫫 + ?띿꽦
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
                                // 湲곕낯 ?ㅽ꺈
                                Text(
                                  '怨듦꺽?? ${sword.baseAtk}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // ?ㅽ궗 ?뺣낫
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
        title: const Text('게임 통계', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statSection('강화', [
                ('? ??', _totalEnhanceAttempts),
                ('??', _totalEnhanceSuccess),
                ('??', _totalEnhanceFail),
                ('??', _totalDestroy),
                ('?? ?? ??', _maxConsecutiveSuccess),
                ('??? ??', _totalStoneUsed),
              ]),
              const SizedBox(height: 16),
              _statSection('배틀', [
                ('? ??', _totalBattle),
                ('??', _totalBattleWin),
                ('??', _totalBattle - _totalBattleWin),
                (
                  '??',
                  _totalBattle > 0
                      ? '${(_totalBattleWin / _totalBattle * 100).toStringAsFixed(1)}%'
                      : '-',
                ),
                ('?? ??', _maxWinStreak),
                ('?? ??', _totalRevengeWins),
              ]),
              const SizedBox(height: 16),
              _statSection('보스', [('처치', _bossKills)]),
              const SizedBox(height: 16),
              _statSection('경제', [
                ('?? ??', _totalGacha),
                ('?? ??', _totalSynthesis),
                ('?? ??', _totalSell),
              ]),
              const SizedBox(height: 16),
              _statSection('기타', [
                ('?? ??', '$_attendanceStreak?'),
                ('?? ??', '${_codex.length}/${allSwords.length}'),
                ('?? ??', '${_unlockedTitles.length}/${allTitles.length}'),
                ('?? ??', '${_unlockedAchievements.length}?'),
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
  // ???꾩?留??ㅼ씠?쇰줈洹?
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
              // ?ㅻ뜑
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
                    Text('📘', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12),
                    Text(
                      '게임 가이드',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // ?댁슜
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ?띿꽦 ?곸꽦??
                      _buildHelpSection(
                        '속성 상성',
                        '???? ?? ??? ?? ???? ????.',
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // ?곸꽦 ?꾪몴
                              _buildElementRow(
                                '?',
                                '>',
                                '??',
                                '?? (+25%)',
                                Colors.green,
                              ),
                              _buildElementRow(
                                '?',
                                '>',
                                '\uBD88',
                                '?? (+25%)',
                                Colors.green,
                              ),
                              _buildElementRow(
                                '??',
                                '>',
                                '\uBB3C',
                                '?? (+25%)',
                                Colors.green,
                              ),
                              const Divider(color: Colors.white24, height: 16),
                              _buildElementRow(
                                '?',
                                '<>',
                                '??',
                                '?? ??',
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
                                  '??? ??? -20% ??!',
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

                      // ?깃툒 ?ㅻ챸
                      _buildHelpSection(
                        '? ??',
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

                      // 媛뺥솕 ??
                      _buildHelpSection(
                        '강화 가이드',
                        '',
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '+1~+10: ?? ??, ?? ? ?? (?? 92% -> 50%)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '+11~+14: ?? ?? (?? 2~8%)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '+15~+20: ?? 30% ?? (?? 30% -> 0%)',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '+21~+25: ?? 35% ?? (?? 18% -> 2%)',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '+26~+30: ?? 40% ?? (?? 6% -> 1%)',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '???(~+24): ??? +10%, ??? -5%',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '???(+25~+27): ??? +3%, ??? -2%',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '???(+28~+30): ??? +1%, ??? -1%',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ?뚰뙆 ??
                      _buildHelpSection(
                        '돌파 가이드',
                        '',
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '30?? ???? ??? ??? ?? ???? +5 ?????.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '?? ??: ?? ?? 20? ?? ? 1? + ???? + ??',
                              style: TextStyle(
                                color: Color(0xFF80DEEA),
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '????? ?? ?? ? ????? ????, ?? ????? ? ?? ????.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '+31~+35: ?? 1.0% / ?? 89.0% / ?? 10.0%',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '+36~+40: ?? 0.5% / ?? 89.5% / ?? 10.0%',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '+41~+45: ?? 0.1% / ?? 89.9% / ?? 10.0%',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ?⑹꽦 ??
                      _buildHelpSection(
                        '합성 천장',
                        '',
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '?? 10? ?? ? ?? ??',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '?? 50? ?? ? ??? ??',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '??? 100? ?? ? ?? ??',
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

              // ?リ린 踰꾪듉
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
  // ?숋툘 ?ㅼ젙 ?ㅼ씠?쇰줈洹?
  // =====================================================
  void _showSettingsDialog() {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (_) => const Season1SettingsDialog(),
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
// ?렟 醫낇빀 戮묎린 ?ㅼ씠?쇰줈洹?(?쇰컲 + 怨좉툒)
// =====================================================
