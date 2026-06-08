import 'dart:math';

import 'package:flutter/material.dart';

import '../data/swords.dart';
import '../data/tower_rewards.dart';
import '../enums/element.dart';
import '../enums/sword_grade.dart';
import '../models/owned_sword.dart';
import '../services/ad_service.dart';
import '../services/storage_service.dart';
import '../utils/battle_engine.dart';
import '../utils/helpers.dart';
import '../widgets/sword_image_widget.dart';
import 'battle_arena_screen.dart';

class InfiniteTowerScreen extends StatefulWidget {
  final List<OwnedSword> inventory;
  final int gold;
  final int diamond;
  final int enhanceStone;

  const InfiniteTowerScreen({
    super.key,
    required this.inventory,
    required this.gold,
    required this.diamond,
    required this.enhanceStone,
  });

  @override
  State<InfiniteTowerScreen> createState() => _InfiniteTowerScreenState();
}

class _InfiniteTowerScreenState extends State<InfiniteTowerScreen> {
  static const int _dailyFreePlayLimit = 3;
  static const int _dailyAdPlayLimit = 3;
  static const int _maxFloor = 100;
  static const _baseAsset =
      'assets/images/home/season1_tower_scene_body_v1.png';
  static const _baseWidth = 941.0;
  static const _baseHeight = 1671.0;

  final StorageService _storage = StorageService();
  final Random _rng = Random();

  OwnedSword? _selectedSword;
  BattleParticipant? _currentOpponent;
  Set<int> _firstClearFloors = <int>{};
  int _bestFloor = 0;
  int _currentFloor = 1;
  int _goldEarned = 0;
  int _diamondsEarned = 0;
  int _stonesEarned = 0;
  int _selectedStartFloor = 1;
  int _freePlaysUsedToday = 0;
  int _adPlaysUsedToday = 0;
  String? _bestRunSwordId;
  String? _bestRunSwordName;
  int _bestRunSwordLevel = 0;
  int _bestRunSwordBreakthroughLevel = 0;
  int _bestRunSwordPower = 0;
  bool _playsLoaded = false;
  bool _runActive = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.inventory.isNotEmpty) {
      final sorted = [...widget.inventory]
        ..sort((a, b) => b.totalPower.compareTo(a.totalPower));
      _selectedSword = sorted.first;
    }
    _loadTowerState();
  }

  int get _remainingFreePlays =>
      (_dailyFreePlayLimit - _freePlaysUsedToday).clamp(0, _dailyFreePlayLimit);
  int get _remainingAdPlays =>
      (_dailyAdPlayLimit - _adPlaysUsedToday).clamp(0, _dailyAdPlayLimit);
  bool get _hasFreePlays => _remainingFreePlays > 0;
  bool get _hasAdPlays => _remainingAdPlays > 0;
  List<int> get _availableStartFloors {
    final floors = <int>[1];
    for (
      var checkpoint = 5;
      checkpoint < _bestFloor && checkpoint < _maxFloor;
      checkpoint += 5
    ) {
      final startFloor = checkpoint + 1;
      if (startFloor <= _maxFloor) floors.add(startFloor);
    }
    return floors;
  }

  bool get _isCurrentFloorFirstClear =>
      !_firstClearFloors.contains(_currentFloor);
  TowerRewardResult get _currentFloorReward =>
      resolveTowerReward(_currentFloor);

  String get _todayKey {
    final now = _storage.serverNow;
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<void> _loadTowerState() async {
    final today = _todayKey;
    var freePlaysUsed = _storage.infiniteTowerDailyPlaysUsed;
    var adPlaysUsed = _storage.infiniteTowerAdPlaysUsed;
    final savedDate = _storage.infiniteTowerPlayResetDate;

    if (savedDate != today) {
      freePlaysUsed = 0;
      adPlaysUsed = 0;
      _storage.infiniteTowerDailyPlaysUsed = 0;
      _storage.infiniteTowerAdPlaysUsed = 0;
      _storage.infiniteTowerPlayResetDate = today;
      await _storage.saveToCloud(force: true);
    }

    if (!mounted) return;
    setState(() {
      _bestFloor = _storage.infiniteTowerBestFloor.clamp(0, _maxFloor);
      _freePlaysUsedToday = freePlaysUsed;
      _adPlaysUsedToday = adPlaysUsed;
      _firstClearFloors = _storage.infiniteTowerFirstClearFloors
          .where((floor) => floor >= 1 && floor <= _maxFloor)
          .toSet();
      final availableStartFloors = _availableStartFloors;
      if (!availableStartFloors.contains(_selectedStartFloor)) {
        _selectedStartFloor = availableStartFloors.last;
      }
      _playsLoaded = true;
    });
  }

  Future<void> _saveBestFloor(int floor) async {
    _storage.infiniteTowerBestFloor = floor.clamp(0, _maxFloor);
    await _storage.saveToCloud(force: true);
  }

  Future<void> _saveFirstClearFloor(int floor) async {
    _firstClearFloors = {
      ..._firstClearFloors.where((value) => value >= 1 && value <= _maxFloor),
      floor,
    };
    _storage.infiniteTowerFirstClearFloors = _firstClearFloors;
    await _storage.saveToCloud(force: true);
  }

  Future<void> _consumeFreePlay() async {
    _freePlaysUsedToday = (_freePlaysUsedToday + 1).clamp(
      0,
      _dailyFreePlayLimit,
    );
    _storage.infiniteTowerDailyPlaysUsed = _freePlaysUsedToday;
    _storage.infiniteTowerPlayResetDate = _todayKey;
    await _storage.saveToCloud(force: true);
    if (mounted) setState(() {});
  }

  Future<void> _consumeAdPlay() async {
    _adPlaysUsedToday = (_adPlaysUsedToday + 1).clamp(0, _dailyAdPlayLimit);
    _storage.infiniteTowerAdPlaysUsed = _adPlaysUsedToday;
    _storage.infiniteTowerPlayResetDate = _todayKey;
    await _storage.saveToCloud(force: true);
    if (mounted) setState(() {});
  }

  Map<String, dynamic> get _result => {
    'gold': widget.gold + _goldEarned,
    'diamond': widget.diamond + _diamondsEarned,
    'enhanceStone': widget.enhanceStone + _stonesEarned,
    'infiniteTowerBestFloor': _bestFloor,
    'infiniteTowerSwordId': _bestRunSwordId ?? _selectedSword?.data.id,
    'infiniteTowerSwordName': _bestRunSwordName ?? _selectedSword?.data.name,
    'infiniteTowerSwordLevel': _bestRunSwordLevel > 0
        ? _bestRunSwordLevel
        : _selectedSword?.level ?? 0,
    'infiniteTowerSwordBreakthroughLevel': _bestRunSwordBreakthroughLevel > 0
        ? _bestRunSwordBreakthroughLevel
        : _selectedSword?.breakthroughLevel ?? 0,
    'infiniteTowerSwordPower': _bestRunSwordPower > 0
        ? _bestRunSwordPower
        : _selectedSword?.totalPower ?? 0,
  };

  void _startRun() {
    if (_selectedSword == null) return;
    setState(() {
      _runActive = true;
      _busy = false;
      _currentFloor = _selectedStartFloor;
      _goldEarned = 0;
      _diamondsEarned = 0;
      _stonesEarned = 0;
      _currentOpponent = _buildOpponent(_selectedStartFloor);
    });
  }

  Future<void> _startRunWithFreePlay() async {
    if (_selectedSword == null || _busy || _runActive || !_playsLoaded) return;
    if (!_hasFreePlays) {
      _showNoPlaysDialog();
      return;
    }
    await _consumeFreePlay();
    _startRun();
  }

  void _startRunAfterAd() {
    if (_selectedSword == null || _busy || _runActive) return;
    _startRun();
  }

  void _watchAdForPlay() {
    if (_selectedSword == null || _busy || _runActive || !_hasAdPlays) return;
    final adService = AdService();
    adService.showRewardedAd(
      type: AdRewardType.infiniteTowerPlay,
      onRewarded: () async {
        await _consumeAdPlay();
        if (mounted) _startRunAfterAd();
      },
      onError: (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      },
    );
  }

  void _showNoPlaysDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('오늘 도전 완료', style: TextStyle(color: Colors.white)),
        content: Text(
          _hasAdPlays
              ? '무료 도전 3회를 모두 사용했습니다. 광고를 보고 추가로 $_remainingAdPlays회 더 도전할 수 있습니다.'
              : '오늘 무한의 탑 도전 횟수를 모두 사용했습니다. 내일 다시 도전할 수 있습니다.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          if (_hasAdPlays)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              onPressed: () {
                Navigator.pop(context);
                _watchAdForPlay();
              },
              icon: const Text('🎬', style: TextStyle(fontSize: 16)),
              label: Text(
                '광고 보고 도전 ($_remainingAdPlays/$_dailyAdPlayLimit)',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  BattleParticipant _buildMyParticipant() {
    final sword = _selectedSword!;
    return BattleParticipant(
      id: sword.uid,
      name: '플레이어',
      grade: sword.data.grade,
      swordLevel: sword.level,
      baseAtk: sword.data.baseAtk,
      element: sword.data.element,
      primarySkillType: sword.data.primarySkillType,
      skills: sword.data.skills,
      swordName: sword.data.name,
      swordId: sword.data.id,
      titleBonus: 0,
    );
  }

  BattleParticipant _buildOpponent(int floor) {
    final gradeRange = switch (floor) {
      <= 10 => (min: SwordGrade.normal, max: SwordGrade.rare),
      <= 25 => (min: SwordGrade.rare, max: SwordGrade.unique),
      <= 45 => (min: SwordGrade.unique, max: SwordGrade.legend),
      <= 65 => (min: SwordGrade.legend, max: SwordGrade.hidden),
      <= 85 => (min: SwordGrade.hidden, max: SwordGrade.immortal),
      _ => (min: SwordGrade.immortal, max: SwordGrade.immortal),
    };

    final candidates = allSwords
        .where(
          (s) =>
              s.grade.index >= gradeRange.min.index &&
              s.grade.index <= gradeRange.max.index,
        )
        .toList();
    final sword = candidates[_rng.nextInt(candidates.length)];
    final isMiniBossFloor = floor % 5 == 0;
    final isBossFloor = floor % 10 == 0;
    final level =
        (floor * 1.6).round() +
        (isBossFloor
            ? 22
            : isMiniBossFloor
            ? 12
            : 4);
    final title = isBossFloor
        ? '탑의 군주'
        : isMiniBossFloor
        ? '탑의 수호자'
        : '탑의 전사';

    return BattleParticipant(
      id: 'tower_$floor',
      name: '$title $floor층',
      grade: sword.grade,
      swordLevel: level,
      baseAtk:
          sword.baseAtk +
          (isBossFloor
              ? 60
              : isMiniBossFloor
              ? 28
              : 0),
      element: sword.element,
      primarySkillType: sword.primarySkillType,
      skills: sword.skills,
      swordName: sword.name,
      swordId: sword.id,
    );
  }

  String _formatRewardEntry(TowerRewardEntry reward) {
    final parts = <String>[];
    if (reward.gold > 0) parts.add('${formatNumber(reward.gold)}G');
    if (reward.diamonds > 0) parts.add('${reward.diamonds}💎');
    if (reward.stones > 0) parts.add('${reward.stones}🪨');
    return parts.isEmpty ? '없음' : parts.join('  /  ');
  }

  Future<void> _showFloorClearDialog({
    required int floor,
    required TowerRewardEntry repeatReward,
    required TowerRewardEntry firstClearReward,
    required bool grantedFirstClear,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$floor층 클리어', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRewardLine(
              title: '반복 클리어 보상',
              value: _formatRewardEntry(repeatReward),
              color: Colors.lightBlueAccent,
            ),
            const SizedBox(height: 10),
            _buildRewardLine(
              title: '최초 클리어 추가 보상',
              value: grantedFirstClear
                  ? _formatRewardEntry(firstClearReward)
                  : '이미 획득 완료',
              color: grantedFirstClear ? Colors.amberAccent : Colors.white54,
            ),
          ],
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

  Future<void> _showTowerCompleteDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('무한의 탑 정복', style: TextStyle(color: Colors.white)),
        content: Text(
          '100층을 돌파해 무한의 탑을 모두 클리어했습니다.\n획득 보상: ${formatNumber(_goldEarned)}G${_diamondsEarned > 0 ? ' / $_diamondsEarned💎' : ''}${_stonesEarned > 0 ? ' / $_stonesEarned🪨' : ''}',
          style: const TextStyle(color: Colors.white70),
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

  Future<void> _challengeFloor() async {
    if (!_runActive ||
        _busy ||
        _selectedSword == null ||
        _currentOpponent == null) {
      return;
    }

    setState(() => _busy = true);
    final me = _buildMyParticipant();
    final opponent = _currentOpponent!;
    final result = BattleEngine.simulate(me: me, opponent: opponent);
    final floor = _currentFloor;
    final reward = resolveTowerReward(floor);
    final repeatReward = reward.repeatReward;
    final isFirstClear = !_firstClearFloors.contains(floor);
    final firstClearReward = isFirstClear
        ? reward.firstClearReward
        : const TowerRewardEntry(gold: 0, stones: 0);
    final floorGold = repeatReward.gold + firstClearReward.gold;
    final floorDiamonds = repeatReward.diamonds + firstClearReward.diamonds;
    final floorStones = repeatReward.stones + firstClearReward.stones;
    final arenaLogs = [...result.logs];

    if (result.iWin && arenaLogs.isNotEmpty) {
      final parts = <String>['+${formatNumber(floorGold)}G'];
      if (floorDiamonds > 0) parts.add('+$floorDiamonds💎');
      if (floorStones > 0) parts.add('+$floorStones🪨');
      arenaLogs[arenaLogs.length - 1] = '🎉 승리! 탑 보상 ${parts.join(' / ')}';
    }

    final arenaResult = BattleResult(
      iWin: result.iWin,
      rewardGold: floorGold,
      logs: arenaLogs,
      myHpEnd: result.myHpEnd,
      oppHpEnd: result.oppHpEnd,
      myMaxHp: result.myMaxHp,
      oppMaxHp: result.oppMaxHp,
      totalTurns: result.totalTurns,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BattleArenaScreen(
          me: me,
          opponent: opponent,
          result: arenaResult,
          stoneReward: 0,
          showLootReward: false,
        ),
      ),
    );

    if (!mounted) return;

    if (result.iWin) {
      final clearedFloor = floor;
      final nextFloor = floor + 1;
      final newBest = max(_bestFloor, clearedFloor);
      final clearedTower = clearedFloor >= _maxFloor;

      if (newBest != _bestFloor) {
        _bestRunSwordId = _selectedSword?.data.id;
        _bestRunSwordName = _selectedSword?.data.name;
        _bestRunSwordLevel = _selectedSword?.level ?? 0;
        _bestRunSwordBreakthroughLevel = _selectedSword?.breakthroughLevel ?? 0;
        _bestRunSwordPower = _selectedSword?.totalPower ?? 0;
        _bestFloor = newBest;
        await _saveBestFloor(newBest);
      }
      if (isFirstClear) {
        await _saveFirstClearFloor(floor);
      }

      setState(() {
        _goldEarned += floorGold;
        _diamondsEarned += floorDiamonds;
        _stonesEarned += floorStones;
        _runActive = !clearedTower;
        _currentFloor = clearedTower ? _maxFloor : nextFloor;
        _currentOpponent = clearedTower ? null : _buildOpponent(nextFloor);
        _busy = false;
      });

      if (!mounted) return;
      await _showFloorClearDialog(
        floor: floor,
        repeatReward: repeatReward,
        firstClearReward: reward.firstClearReward,
        grantedFirstClear: isFirstClear,
      );
      if (!mounted) return;
      if (clearedTower) {
        await _showTowerCompleteDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 900),
            content: Text(
              '$nextFloor층 입장 준비 완료  •  이번 획득 +${formatNumber(floorGold)}G${floorDiamonds > 0 ? '  +$floorDiamonds💎' : ''}${floorStones > 0 ? '  +$floorStones🪨' : ''}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    setState(() {
      _runActive = false;
      _busy = false;
    });

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('무한의 탑 실패', style: TextStyle(color: Colors.white)),
        content: Text(
          '$floor층에서 패배했습니다.\n획득 보상: ${formatNumber(_goldEarned)}G${_diamondsEarned > 0 ? ' / $_diamondsEarned💎' : ''}${_stonesEarned > 0 ? ' / $_stonesEarned🪨' : ''}',
          style: const TextStyle(color: Colors.white70),
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

  Future<bool> _handleBack() async {
    if (_busy) return false;
    Navigator.pop(context, _result);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = _TowerLayout(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              return ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        _baseAsset,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    ..._buildImageOverlays(layout),
                    _towerTap(layout, _TowerRects.close, _handleBack),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildImageOverlays(_TowerLayout layout) {
    if (widget.inventory.isEmpty) {
      return [
        _towerBox(
          layout,
          _TowerRects.title,
          _towerText(layout, '무한의 탑', 43, fontWeight: FontWeight.w900),
        ),
        _towerBox(
          layout,
          _TowerRects.info,
          _towerText(layout, '검이 없어 입장할 수 없습니다', 27, color: Colors.white70),
        ),
      ];
    }

    return [
      _towerBox(
        layout,
        _TowerRects.title,
        _towerText(layout, '무한의 탑', 43, fontWeight: FontWeight.w900),
      ),
      _towerBox(
        layout,
        _TowerRects.statBest,
        _towerStat(layout, '최고 층', '$_bestFloor'),
      ),
      _towerBox(
        layout,
        _TowerRects.statCurrent,
        _towerStat(layout, _runActive ? '현재 층' : '시작 층', '$_currentFloor'),
      ),
      _towerBox(
        layout,
        _TowerRects.statEntry,
        _towerStat(
          layout,
          '도전',
          _playsLoaded ? '$_remainingFreePlays/$_dailyFreePlayLimit' : '확인 중',
        ),
      ),
      _towerBox(layout, _TowerRects.swordArt, _selectedSwordArt(layout)),
      _towerBox(layout, _TowerRects.info, _towerInfoPanel(layout)),
      _towerBox(
        layout,
        _TowerRects.slotOne,
        _towerSlot(layout, '누적 골드', formatGold(_goldEarned)),
      ),
      _towerBox(
        layout,
        _TowerRects.slotTwo,
        _towerSlot(layout, '다이아', '$_diamondsEarned'),
      ),
      _towerBox(
        layout,
        _TowerRects.slotThree,
        _towerSlot(layout, '강화석', '$_stonesEarned'),
      ),
      _towerBox(layout, _TowerRects.list, _towerRewardList(layout)),
      _towerBox(layout, _TowerRects.leftButton, _startButton(layout)),
      _towerBox(layout, _TowerRects.rightButton, _exitButton(layout)),
      _towerTap(
        layout,
        _TowerRects.leftButton,
        _busy || (!_runActive && !_playsLoaded)
            ? null
            : _runActive
            ? _challengeFloor
            : _hasFreePlays
            ? _startRunWithFreePlay
            : _hasAdPlays
            ? _watchAdForPlay
            : _showNoPlaysDialog,
      ),
      _towerTap(layout, _TowerRects.rightButton, _busy ? null : _handleBack),
    ];
  }

  Widget _towerStat(_TowerLayout layout, String label, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _towerText(layout, label, 18, color: Colors.white70),
        SizedBox(height: layout.u(6)),
        _towerText(
          layout,
          value,
          30,
          color: const Color(0xFFFFD86B),
          fontWeight: FontWeight.w900,
        ),
      ],
    );
  }

  Widget _selectedSwordArt(_TowerLayout layout) {
    final sword = _selectedSword;
    if (sword == null) return const SizedBox.shrink();
    return Center(
      child: SwordImageWidget(
        grade: sword.data.grade,
        element: sword.data.element,
        swordId: sword.data.id,
        level: sword.level,
        breakthroughLevel: sword.breakthroughLevel,
        size: layout.u(170),
        showPulse: false,
      ),
    );
  }

  Widget _towerInfoPanel(_TowerLayout layout) {
    if (_runActive && _currentOpponent != null) {
      final opponent = _currentOpponent!;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: layout.u(22)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _towerPlainText(layout, '$_currentFloor층 적', 26),
            SizedBox(height: layout.u(12)),
            _towerPlainText(layout, opponent.name, 22, color: Colors.white),
            SizedBox(height: layout.u(6)),
            _towerPlainText(
              layout,
              '${opponent.swordName} +${opponent.swordLevel}  전투력 ${formatNumber(opponent.power)}',
              17,
              color: Colors.white70,
            ),
            SizedBox(height: layout.u(10)),
            _towerPlainText(
              layout,
              '반복 보상 ${_formatRewardEntry(_currentFloorReward.repeatReward)}',
              17,
              color: const Color(0xFFFFD86B),
            ),
          ],
        ),
      );
    }

    final sword = _selectedSword;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: layout.u(22)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _towerPlainText(layout, '도전 검', 25),
          SizedBox(height: layout.u(10)),
          _towerPlainText(
            layout,
            sword == null ? '-' : '${sword.data.name} +${sword.level}',
            22,
            color: sword?.data.grade.color ?? Colors.white,
          ),
          SizedBox(height: layout.u(8)),
          _towerPlainText(
            layout,
            sword == null
                ? '도전할 검을 선택하세요'
                : '${sword.data.element.nameKr}  전투력 ${formatNumber(sword.totalPower)}',
            17,
            color: Colors.white70,
          ),
          SizedBox(height: layout.u(12)),
          _startFloorSelectorCompact(layout),
        ],
      ),
    );
  }

  Widget _startFloorSelectorCompact(_TowerLayout layout) {
    final floors = _availableStartFloors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: floors.map((floor) {
          final selected = floor == _selectedStartFloor;
          return Padding(
            padding: EdgeInsets.only(right: layout.u(8)),
            child: GestureDetector(
              onTap: _busy || _runActive
                  ? null
                  : () => setState(() => _selectedStartFloor = floor),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFFD86B).withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: selected ? const Color(0xFFFFD86B) : Colors.white24,
                  ),
                  borderRadius: BorderRadius.circular(layout.u(6)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.u(10),
                    vertical: layout.u(7),
                  ),
                  child: _towerPlainText(
                    layout,
                    '${floor}층',
                    14,
                    color: selected ? const Color(0xFFFFD86B) : Colors.white70,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _towerSlot(_TowerLayout layout, String label, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _towerText(layout, label, 16, color: Colors.white70),
        SizedBox(height: layout.u(5)),
        _towerText(
          layout,
          value,
          21,
          color: const Color(0xFFFFD86B),
          fontWeight: FontWeight.w900,
        ),
      ],
    );
  }

  Widget _towerRewardList(_TowerLayout layout) {
    final start = _runActive ? _currentFloor : _selectedStartFloor;
    final floors = List.generate(
      12,
      (i) => (start + i).clamp(1, _maxFloor),
    ).toSet().toList();

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        layout.u(26),
        layout.u(28),
        layout.u(26),
        layout.u(28),
      ),
      itemCount: floors.length,
      itemBuilder: (_, index) {
        final floor = floors[index];
        final reward = resolveTowerReward(floor);
        final cleared = _firstClearFloors.contains(floor);
        return Padding(
          padding: EdgeInsets.only(bottom: layout.u(13)),
          child: Row(
            children: [
              SizedBox(
                width: layout.u(78),
                child: _towerText(layout, '$floor층', 20),
              ),
              Expanded(
                child: _towerPlainText(
                  layout,
                  '반복 ${_formatRewardEntry(reward.repeatReward)}',
                  16,
                  color: Colors.white70,
                ),
              ),
              SizedBox(width: layout.u(8)),
              SizedBox(
                width: layout.u(205),
                child: _towerPlainText(
                  layout,
                  cleared
                      ? '최초 완료'
                      : '최초 ${_formatRewardEntry(reward.firstClearReward)}',
                  15,
                  color: cleared ? Colors.white38 : const Color(0xFFFFD86B),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _startButton(_TowerLayout layout) {
    final text = _busy
        ? '전투 처리 중'
        : _runActive
        ? '$_currentFloor층 도전'
        : !_playsLoaded
        ? '도전 정보 확인'
        : _hasFreePlays
        ? '탑 도전 시작'
        : _hasAdPlays
        ? '광고 보고 도전'
        : '오늘 도전 완료';
    return _towerText(layout, text, 28, fontWeight: FontWeight.w900);
  }

  Widget _exitButton(_TowerLayout layout) {
    return _towerText(layout, '나가기', 28, fontWeight: FontWeight.w900);
  }

  // ignore: unused_element
  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.withValues(alpha: 0.28),
            Colors.black.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '현재 기록',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatChip('최고 층', '$_bestFloor'),
              const SizedBox(width: 8),
              _buildStatChip('현재 층', _runActive ? '$_currentFloor' : '-'),
              const SizedBox(width: 8),
              _buildStatChip('누적 골드', formatNumber(_goldEarned)),
            ],
          ),
          const SizedBox(height: 8),
          if (_playsLoaded)
            Row(
              children: [
                _buildStatChip(
                  '무료 도전',
                  '$_remainingFreePlays/$_dailyFreePlayLimit',
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  '광고 도전',
                  '$_remainingAdPlays/$_dailyAdPlayLimit',
                ),
              ],
            ),
          if (_playsLoaded) const SizedBox(height: 8),
          Text(
            _runActive
                ? '5층마다 미니보스, 10층마다 대형 보스가 등장합니다. 목표는 100층 돌파입니다.'
                : _bestFloor >= _maxFloor
                ? '100층을 모두 클리어했습니다. 다시 도전해 최초 보상과 반복 보상을 확인할 수 있습니다.'
                : '강한 검을 골라 도전하세요. 100층까지 돌파하면 탑을 정복합니다.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSwordSelector() {
    final sorted = [...widget.inventory]
      ..sort((a, b) => b.totalPower.compareTo(a.totalPower));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '도전 검 선택',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildStartFloorSelector(),
          const SizedBox(height: 12),
          ...sorted.take(8).map((sword) {
            final selected = _selectedSword?.uid == sword.uid;
            return GestureDetector(
              onTap: _busy
                  ? null
                  : () => setState(() => _selectedSword = sword),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected
                      ? sword.data.grade.color.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? sword.data.grade.color : Colors.white12,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: Image.asset(
                        'assets/images/swords/sword_${sword.data.grade.name}.webp',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(
                          sword.data.grade.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${sword.data.name} +${sword.level}',
                            style: TextStyle(
                              color: sword.data.grade.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${sword.data.element.emoji} ${sword.data.grade.displayName}  •  전투력 ${formatNumber(sword.totalPower)}',
                            style: const TextStyle(
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
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStartFloorSelector() {
    final floors = _availableStartFloors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '시작 층 선택',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: floors.map((floor) {
            final selected = _selectedStartFloor == floor;
            final isCheckpoint = floor > 1;
            return GestureDetector(
              onTap: _busy || _runActive
                  ? null
                  : () => setState(() => _selectedStartFloor = floor),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.amber.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? Colors.amberAccent : Colors.white12,
                  ),
                ),
                child: Text(
                  isCheckpoint ? '$floor층부터' : '1층부터',
                  style: TextStyle(
                    color: selected ? Colors.amberAccent : Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedStartFloor == 1
              ? '처음부터 차근차근 올라갑니다.'
              : '${_selectedStartFloor - 1}층까지의 체크포인트를 건너뛰고 바로 도전합니다.',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRewardLine({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildOpponentCard(BattleParticipant opponent) {
    final reward = _currentFloorReward;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepOrange.withValues(alpha: 0.18),
            Colors.red.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepOrangeAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_currentFloor층 적${_currentFloor >= _maxFloor ? ' (최종)' : ''}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Image.asset(
                  'assets/images/swords/sword_${opponent.grade.name}.webp',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    opponent.element.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opponent.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${opponent.swordName}  •  ${opponent.grade.displayName} +${opponent.swordLevel}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '전투력 ${formatNumber(opponent.power)}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'HP ${formatNumber(opponent.hp)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _currentFloor % 10 == 0
                ? _currentFloor >= _maxFloor
                      ? '최종 보스 층입니다. 승리하면 무한의 탑을 모두 클리어합니다.'
                      : '보스 층입니다. 매우 강한 적이 등장합니다.'
                : _currentFloor % 5 == 0
                ? '미니보스 층입니다. 돌파당하면 큰 피해를 받습니다.'
                : '승리하면 다음 층과 추가 보상을 얻습니다.',
            style: TextStyle(
              color: _currentFloor % 5 == 0
                  ? Colors.orangeAccent
                  : Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          _buildRewardLine(
            title: '반복 클리어 보상',
            value: _formatRewardEntry(reward.repeatReward),
            color: Colors.lightBlueAccent,
          ),
          const SizedBox(height: 8),
          _buildRewardLine(
            title: '최초 클리어 추가 보상',
            value: _isCurrentFloorFirstClear
                ? _formatRewardEntry(reward.firstClearReward)
                : '최초 클리어 달성 완료',
            color: _isCurrentFloorFirstClear
                ? Colors.amberAccent
                : Colors.white54,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildActionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          if (_runActive)
            Text(
              '현재 누적 보상  •  ${formatNumber(_goldEarned)}G${_diamondsEarned > 0 ? '  /  $_diamondsEarned💎' : ''}${_stonesEarned > 0 ? '  /  $_stonesEarned🪨' : ''}',
              style: const TextStyle(color: Colors.white70),
            )
          else if (!_playsLoaded)
            const Text(
              '도전 정보를 불러오는 중입니다.',
              style: TextStyle(color: Colors.white70),
            )
          else
            Text(
              _hasFreePlays
                  ? '오늘 무료 도전이 $_remainingFreePlays회 남아 있습니다.'
                  : _hasAdPlays
                  ? '무료 도전 소진. 광고를 보고 $_remainingAdPlays회 추가 도전할 수 있습니다.'
                  : '오늘 도전 횟수를 모두 사용했습니다.',
              style: const TextStyle(color: Colors.white70),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy || (!_runActive && !_playsLoaded)
                  ? null
                  : _runActive
                  ? _challengeFloor
                  : _hasFreePlays
                  ? _startRunWithFreePlay
                  : _hasAdPlays
                  ? _watchAdForPlay
                  : _showNoPlaysDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: _runActive
                    ? Colors.deepOrange
                    : Colors.indigoAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _busy
                    ? '전투 처리 중...'
                    : _runActive
                    ? '$_currentFloor층 도전'
                    : !_playsLoaded
                    ? '도전 정보 확인 중...'
                    : _hasFreePlays
                    ? '탑 도전 시작 ($_remainingFreePlays/$_dailyFreePlayLimit)'
                    : _hasAdPlays
                    ? '광고 보고 도전 ($_remainingAdPlays/$_dailyAdPlayLimit)'
                    : '오늘 도전 완료',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy ? null : () => Navigator.pop(context, _result),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('나가기', style: TextStyle(color: Colors.white70)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _towerText(
    _TowerLayout layout,
    String text,
    double baseSize, {
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    final fontSize = layout.u(baseSize);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: layout.u(5)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            strutStyle: StrutStyle(
              fontSize: fontSize,
              height: 1,
              forceStrutHeight: true,
            ),
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: fontWeight,
              height: 1,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _towerPlainText(
    _TowerLayout layout,
    String text,
    double baseSize, {
    Color color = Colors.white,
  }) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: layout.u(baseSize),
        fontWeight: FontWeight.w800,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
  }

  Widget _towerBox(_TowerLayout layout, Rect rect, Widget child) {
    return Positioned.fromRect(rect: layout.r(rect), child: child);
  }

  Widget _towerTap(_TowerLayout layout, Rect rect, VoidCallback? onTap) {
    return _towerBox(
      layout,
      rect,
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TowerLayout {
  final double width;
  final double height;
  late final double sx = width / _InfiniteTowerScreenState._baseWidth;
  late final double sy = height / _InfiniteTowerScreenState._baseHeight;
  late final double s = min(sx, sy);

  _TowerLayout(this.width, this.height);

  double u(double value) => value * s;

  Rect r(Rect rect) => Rect.fromLTWH(
    rect.left * sx,
    rect.top * sy,
    rect.width * sx,
    rect.height * sy,
  );
}

class _TowerRects {
  static const close = Rect.fromLTWH(27, 31, 105, 105);
  static const title = Rect.fromLTWH(224, 202, 494, 105);
  static const statBest = Rect.fromLTWH(153, 389, 195, 96);
  static const statCurrent = Rect.fromLTWH(373, 389, 195, 96);
  static const statEntry = Rect.fromLTWH(592, 389, 195, 96);
  static const swordArt = Rect.fromLTWH(169, 563, 225, 225);
  static const info = Rect.fromLTWH(407, 565, 357, 222);
  static const slotOne = Rect.fromLTWH(158, 849, 165, 95);
  static const slotTwo = Rect.fromLTWH(389, 849, 165, 95);
  static const slotThree = Rect.fromLTWH(620, 849, 165, 95);
  static const list = Rect.fromLTWH(62, 988, 819, 485);
  static const leftButton = Rect.fromLTWH(92, 1526, 350, 84);
  static const rightButton = Rect.fromLTWH(500, 1526, 350, 84);
}
