// lib/screens/battle_arena_screen.dart
// 🔥 배틀 아레나 - 캐릭터 + 슬래시 + 파티클 + 승패연출 풀 이펙트 버전

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../enums/sword_grade.dart';
import '../enums/element.dart';
import '../utils/battle_engine.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../services/sound_service.dart';
import '../widgets/sword_image_widget.dart';

// =====================================================
// 📦 파티클 데이터 클래스
// =====================================================

class _ImpactParticle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  _ImpactParticle({required this.angle, required this.speed, required this.size, required this.color});
}

class _ConfettiPiece {
  final double x;       // 0~1 normalized
  final double speed;   // fall speed multiplier
  final double wobble;  // horizontal oscillation
  final double size;
  final double rotation;
  final Color color;
  _ConfettiPiece({required this.x, required this.speed, required this.wobble, required this.size, required this.rotation, required this.color});
}

class _BgParticle {
  double x, y, speed, size, opacity;
  _BgParticle({required this.x, required this.y, required this.speed, required this.size, required this.opacity});
}

// =====================================================
// 🎮 배틀 아레나 위젯
// =====================================================

class BattleArenaScreen extends StatefulWidget {
  final BattleParticipant me;
  final BattleParticipant opponent;
  final BattleResult result;
  final int stoneReward;

  const BattleArenaScreen({
    super.key,
    required this.me,
    required this.opponent,
    required this.result,
    this.stoneReward = 0,
  });

  @override
  State<BattleArenaScreen> createState() => _BattleArenaScreenState();
}

class _BattleArenaScreenState extends State<BattleArenaScreen> 
    with TickerProviderStateMixin {

  // ── 공격 모션 ──
  late AnimationController _playerController;
  late Animation<double> _playerBodyX;
  late AnimationController _enemyController;
  late Animation<double> _enemyBodyX;

  // ── 피격 쉐이크 ──
  late AnimationController _hitController;

  // ── 크리티컬 화면 쉐이크 ──
  late AnimationController _screenShakeController;

  // ── 슬래시 이펙트 (임팩트 = 피격쪽, 스윙 = 공격쪽) ──
  late AnimationController _slashController;
  late Animation<double> _slashScale;
  late Animation<double> _slashOpacity;
  late AnimationController _swingSlashController;
  late Animation<double> _swingScale;
  late Animation<double> _swingOpacity;

  // ── 임팩트 파티클 ──
  late AnimationController _impactController;
  List<_ImpactParticle> _impactParticles = [];
  bool _impactOnPlayer = false;

  // ── 앰비언트 (배경 파티클 + 오라 + VS 펄스) ──
  late AnimationController _ambientController;

  // ── 화면 플래시 ──
  late AnimationController _flashController;
  late Animation<double> _flashOpacity;
  Color _flashColor = Colors.white;

  // ── 승패 연출 ──
  late AnimationController _victoryController;
  List<_ConfettiPiece> _confettiPieces = [];

  // ── 로그 ──
  int _currentLogIndex = 0;
  List<String> _displayedLogs = [];

  // ── HP ──
  late int _myMaxHp, _oppMaxHp;
  late int _myCurrentHp, _oppCurrentHp;

  // ── 상태 ──
  bool _battleFinished = false;
  Timer? _autoPlayTimer;
  String? _currentEffect;
  bool _showDamageOnPlayer = false;
  bool _showDamageOnEnemy = false;
  int _lastDamage = 0;
  bool _isCritical = false;
  String? _skillActivationText;
  bool _isPlayerTurn = true;
  bool _slashOnPlayer = false;

  // ── 배경 파티클 ──
  late List<_BgParticle> _bgParticles;

  // ── 랜덤 ──
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    SoundService().playBattleBgm();

    _myMaxHp = widget.result.myMaxHp;
    _oppMaxHp = widget.result.oppMaxHp;
    _myCurrentHp = _myMaxHp;
    _oppCurrentHp = _oppMaxHp;

    // 배경 파티클
    _bgParticles = List.generate(25, (_) => _BgParticle(
      x: _rng.nextDouble(), y: _rng.nextDouble(),
      speed: 0.15 + _rng.nextDouble() * 0.4,
      size: 1.0 + _rng.nextDouble() * 2.5,
      opacity: 0.1 + _rng.nextDouble() * 0.35,
    ));

    // ── 플레이어 공격 ──
    _playerController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _playerBodyX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 40), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 40, end: 0), weight: 60),
    ]).animate(CurvedAnimation(parent: _playerController, curve: Curves.easeOut));

    // ── 적 공격 ──
    _enemyController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _enemyBodyX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -40), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -40, end: 0), weight: 60),
    ]).animate(CurvedAnimation(parent: _enemyController, curve: Curves.easeOut));

    // ── 피격 쉐이크 ──
    _hitController = AnimationController(duration: const Duration(milliseconds: 120), vsync: this);

    // ── 크리티컬 화면 쉐이크 ──
    _screenShakeController = AnimationController(duration: const Duration(milliseconds: 350), vsync: this);

    // ── 슬래시 이펙트 (임팩트: 피격쪽 큰 슬래시) ──
    _slashController = AnimationController(duration: const Duration(milliseconds: 350), vsync: this);
    _slashScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _slashController, curve: Curves.easeOut));
    _slashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_slashController);

    // ── 스윙 슬래시 (공격쪽 작은 슬래시, 약간 빠르게) ──
    _swingSlashController = AnimationController(duration: const Duration(milliseconds: 280), vsync: this);
    _swingScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.2, end: 1.0), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 65),
    ]).animate(CurvedAnimation(parent: _swingSlashController, curve: Curves.easeOut));
    _swingOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.7), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 0.7), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 0.0), weight: 50),
    ]).animate(_swingSlashController);

    // ── 임팩트 파티클 ──
    _impactController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);

    // ── 앰비언트 (3초 루프) ──
    _ambientController = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat();

    // ── 화면 플래시 ──
    _flashController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _flashOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );

    // ── 승패 연출 ──
    _victoryController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);

    // 자동 재생
    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (_battleFinished) { t.cancel(); return; }
      _showNextLog();
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _playerController.dispose();
    _enemyController.dispose();
    _hitController.dispose();
    _screenShakeController.dispose();
    _slashController.dispose();
    _swingSlashController.dispose();
    _impactController.dispose();
    _ambientController.dispose();
    _flashController.dispose();
    _victoryController.dispose();
    super.dispose();
  }

  // =====================================================
  // 📋 로그 처리
  // =====================================================

  void _showNextLog() {
    if (_currentLogIndex >= widget.result.logs.length) {
      _finishBattle();
      return;
    }
    final log = widget.result.logs[_currentLogIndex];
    setState(() { _displayedLogs.add(log); _currentLogIndex++; });
    _parseLog(log);
  }

  void _finishBattle() {
    setState(() {
      _battleFinished = true;
      _myCurrentHp = widget.result.myHpRemaining.clamp(0, _myMaxHp);
      _oppCurrentHp = widget.result.oppHpRemaining.clamp(0, _oppMaxHp);
    });

    if (widget.result.isWin) {
      SoundService().playBattleWin();
      // 컨페티 생성
      final gradeColor = widget.me.grade.color;
      _confettiPieces = List.generate(40, (_) => _ConfettiPiece(
        x: _rng.nextDouble(),
        speed: 0.5 + _rng.nextDouble() * 0.8,
        wobble: _rng.nextDouble() * 30 - 15,
        size: 4 + _rng.nextDouble() * 6,
        rotation: _rng.nextDouble() * pi * 2,
        color: [gradeColor, Colors.amber, Colors.white, Colors.yellow, Colors.orange][_rng.nextInt(5)],
      ));
    } else {
      SoundService().playBattleLose();
    }
    _victoryController.forward(from: 0);
    Future.delayed(const Duration(seconds: 2), () => SoundService().playMainBgm());
  }

  void _parseLog(String log) {
    // HP 상태
    if (log.startsWith('📊 HP:')) {
      final m = RegExp(r'(\d+)/(\d+)').allMatches(log).toList();
      if (m.length >= 2) setState(() {
        _myCurrentHp = int.parse(m[0].group(1)!).clamp(0, _myMaxHp);
        _oppCurrentHp = int.parse(m[1].group(1)!).clamp(0, _oppMaxHp);
      });
      return;
    }

    // 사망 체크
    if ((log.contains('💀') || log.contains('패배') || log.contains('승리')) &&
        _currentLogIndex >= widget.result.logs.length - 3) {
      setState(() {
        _myCurrentHp = widget.result.myHpRemaining.clamp(0, _myMaxHp);
        _oppCurrentHp = widget.result.oppHpRemaining.clamp(0, _oppMaxHp);
      });
    }

    final isCrit = log.contains('크리티컬') || log.contains('💥');

    // 내 공격
    if (log.contains('⚔️') && log.contains(widget.me.name) && log.contains('→')) {
      setState(() => _isPlayerTurn = true);
      _playerController.forward(from: 0);
      SoundService().playBattleHit();
      final dmg = _parseDamage(log);
      if (dmg > 0) {
        _lastDamage = dmg;
        _isCritical = isCrit;
        _triggerSlash(onPlayer: false);
        _triggerImpact(onPlayer: false);
        _triggerHitEffect(false);
        if (isCrit) _triggerCritShake();
      }
    }

    // 적 공격
    if (log.contains('⚔️') && log.contains(widget.opponent.name) && log.contains('→')) {
      setState(() => _isPlayerTurn = false);
      _enemyController.forward(from: 0);
      SoundService().playBattleHit();
      final dmg = _parseDamage(log);
      if (dmg > 0) {
        _lastDamage = dmg;
        _isCritical = isCrit;
        _triggerSlash(onPlayer: true);
        _triggerImpact(onPlayer: true);
        _triggerHitEffect(true);
        if (isCrit) _triggerCritShake();
      }
    }

    // 반격
    if (log.contains('↩️')) {
      final dmg = _parseDamage(log);
      if (dmg > 0) _lastDamage = dmg;
    }

    // 스킬
    _checkSkillEffect(log);
  }

  int _parseDamage(String log) {
    final m = RegExp(r'(\d[\d,]*)\s*피해').firstMatch(log);
    return m != null ? int.parse(m.group(1)!.replaceAll(',', '')) : 0;
  }

  // =====================================================
  // ⚡ 이펙트 트리거
  // =====================================================

  void _triggerSlash({required bool onPlayer}) {
    setState(() => _slashOnPlayer = onPlayer);
    // 임팩트 슬래시 (피격쪽, 큰)
    _slashController.forward(from: 0);
    // 스윙 슬래시 (공격쪽, 작은, 약간 먼저)
    _swingSlashController.forward(from: 0);
  }

  void _triggerImpact({required bool onPlayer}) {
    final baseColors = _isCritical
        ? [Colors.yellow, Colors.amber, Colors.orange, Colors.white]
        : [Colors.red, Colors.orange, Colors.yellow, Colors.white70];
    
    _impactParticles = List.generate(_isCritical ? 16 : 10, (_) => _ImpactParticle(
      angle: _rng.nextDouble() * pi * 2,
      speed: 30 + _rng.nextDouble() * (_isCritical ? 60 : 40),
      size: 2 + _rng.nextDouble() * (_isCritical ? 4 : 3),
      color: baseColors[_rng.nextInt(baseColors.length)],
    ));
    setState(() => _impactOnPlayer = onPlayer);
    _impactController.forward(from: 0);
  }

  void _triggerHitEffect(bool isPlayer) {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      setState(() {
        if (isPlayer) _showDamageOnPlayer = true;
        else _showDamageOnEnemy = true;
      });
      _hitController.forward(from: 0);
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() { _showDamageOnPlayer = false; _showDamageOnEnemy = false; });
    });
  }

  void _triggerCritShake() {
    _screenShakeController.forward(from: 0);
    _flashColor = Colors.yellow;
    _flashController.forward(from: 0);
  }

  void _checkSkillEffect(String log) {
    if (log.contains('【')) {
      final m = RegExp(r'【(.+?)】').firstMatch(log);
      if (m != null) {
        setState(() => _skillActivationText = m.group(1));
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _skillActivationText = null);
        });
      }
    }

    String? effect;
    Color? flash;
    if (log.contains('🔥'))      { effect = '🔥'; flash = Colors.orange; }
    else if (log.contains('💧')) { effect = '💧'; flash = Colors.blue; }
    else if (log.contains('⚡')) { effect = '⚡'; flash = Colors.yellow; }
    else if (log.contains('🌿')) { effect = '🌿'; flash = Colors.green; }
    else if (log.contains('💀')) { effect = '💀'; flash = Colors.purple; }
    else if (log.contains('✨')) { effect = '✨'; flash = Colors.amber; }
    else if (log.contains('💥')) { effect = '💥'; flash = Colors.red; }

    if (effect != null) {
      setState(() => _currentEffect = effect);
      if (flash != null) { _flashColor = flash; _flashController.forward(from: 0); }
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _currentEffect = null);
      });
    }
  }

  void _skipToEnd() {
    _autoPlayTimer?.cancel();
    setState(() {
      _displayedLogs = List.from(widget.result.logs);
      _currentLogIndex = widget.result.logs.length;
    });
    _finishBattle();
  }

  // =====================================================
  // 🏗️ BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final isWin = widget.result.isWin;
    return Scaffold(
      backgroundColor: const Color(0xFF080816),
      appBar: AppBar(
        title: Text(_battleFinished ? (isWin ? '🏆 승리!' : '💀 패배...') : '⚔️ 배틀 중...'),
        backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          if (!_battleFinished)
            TextButton(onPressed: _skipToEnd, child: const Text('스킵 >>', style: TextStyle(color: Colors.white70))),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.result.logs.join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그 복사완료')));
            },
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 배틀 아레나 (크리티컬 쉐이크 래퍼)
            Expanded(
              flex: 3,
              child: AnimatedBuilder(
                animation: _screenShakeController,
                builder: (context, child) {
                  final shake = _screenShakeController.isAnimating
                      ? sin(_screenShakeController.value * pi * 10) * 8 * (1 - _screenShakeController.value)
                      : 0.0;
                  return Transform.translate(offset: Offset(shake, shake * 0.4), child: child);
                },
                child: _buildBattleArena(),
              ),
            ),
            // 배틀 로그
            Expanded(flex: 2, child: _buildBattleLog()),
            // 결과 바
            if (_battleFinished) _buildResultBar(),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // 🎮 배틀 아레나
  // =====================================================
  Widget _buildBattleArena() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _battleFinished
              ? (widget.result.isWin ? Colors.green : Colors.red).withOpacity(0.5)
              : Colors.white24,
          width: _battleFinished ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // 1) 배경 이미지 + 오버레이
            _buildBackground(),

            // 2) 앰비언트 파티클
            _buildAmbientParticles(),

            // 3) 바닥 라인
            _buildFloorLine(),

            // 4) 턴 하이라이트 (공격하는 쪽 스포트라이트)
            if (!_battleFinished) _buildTurnHighlight(),

            // 5) 캐릭터 Row
            _buildFightersRow(),

            // 6) 슬래시 이펙트 오버레이
            _buildSlashOverlay(),

            // 7) 임팩트 파티클 오버레이
            _buildImpactOverlay(),

            // 8) 스킬 이모지 (중앙)
            if (_currentEffect != null) _buildSkillEmoji(),

            // 10) VS 마크
            if (!_battleFinished) Center(child: _buildVsMarker()),

            // 11) 화면 플래시
            _buildScreenFlash(),

            // 12) 승패 오버레이
            if (_battleFinished) _buildVictoryOverlay(),

            // 13) 컨페티
            if (_battleFinished && widget.result.isWin) _buildConfetti(),
          ],
        ),
      ),
    );
  }

  // ── 배경 이미지 + 어둠 오버레이 ──
  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/battle/battle_bg.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center, radius: 1.2,
                  colors: [Color(0xFF1a1a3e), Color(0xFF0e0e24), Color(0xFF060612)],
                ),
              ),
            ),
          ),
        ),
        // 살짝 어둡게 오버레이 (UI 가독성)
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.3)),
        ),
      ],
    );
  }

  // ── 앰비언트 파티클 ──
  Widget _buildAmbientParticles() {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _BgParticlePainter(particles: _bgParticles, progress: _ambientController.value),
      ),
    );
  }

  // ── 바닥 라인 ──
  Widget _buildFloorLine() {
    return Positioned(
      bottom: 50, left: 20, right: 20,
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent, Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.12), Colors.transparent,
          ]),
        ),
      ),
    );
  }

  // ── 턴 하이라이트 (공격하는 쪽에 스포트라이트) ──
  Widget _buildTurnHighlight() {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, _) {
        final pulse = (0.03 + sin(_ambientController.value * pi * 2) * 0.02).clamp(0.0, 0.1);
        return Positioned.fill(
          child: Row(
            children: [
              Expanded(child: Container(
                color: _isPlayerTurn ? Colors.cyan.withOpacity(pulse) : Colors.transparent,
              )),
              const SizedBox(width: 40), // VS 공간
              Expanded(child: Container(
                color: !_isPlayerTurn ? Colors.red.withOpacity(pulse) : Colors.transparent,
              )),
            ],
          ),
        );
      },
    );
  }

  // ── 캐릭터 Row ──
  Widget _buildFightersRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // 플레이어
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([_playerController, _victoryController]),
              builder: (context, _) {
                double extraScale = 1.0;
                double grayscale = 0.0;
                if (_battleFinished) {
                  final v = _victoryController.value;
                  if (widget.result.isWin) {
                    extraScale = 1.0 + v * 0.15;  // 승자 확대
                  } else {
                    grayscale = v; // 패자 흑백
                    extraScale = 1.0 - v * 0.1;
                  }
                }
                return Transform.translate(
                  offset: Offset(_playerBodyX.value, 0),
                  child: Transform.scale(
                    scale: extraScale.clamp(0.5, 1.5),
                    child: ColorFiltered(
                      colorFilter: grayscale > 0
                          ? ColorFilter.matrix(_grayscaleMatrix(grayscale.clamp(0.0, 1.0)))
                          : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                      child: _buildFighter(
                        name: widget.me.name,
                        grade: widget.me.grade,
                        element: widget.me.element,
                        swordName: widget.me.swordName,
                        swordLevel: widget.me.swordLevel,
                        currentHp: _myCurrentHp,
                        maxHp: _myMaxHp,
                        isPlayer: true,
                        isHit: _showDamageOnPlayer,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 40), // VS 공간
          // 적
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([_enemyController, _victoryController]),
              builder: (context, _) {
                double extraScale = 1.0;
                double grayscale = 0.0;
                if (_battleFinished) {
                  final v = _victoryController.value;
                  if (!widget.result.isWin) {
                    extraScale = 1.0 + v * 0.15;
                  } else {
                    grayscale = v;
                    extraScale = 1.0 - v * 0.1;
                  }
                }
                return Transform.translate(
                  offset: Offset(_enemyBodyX.value, 0),
                  child: Transform.scale(
                    scale: extraScale.clamp(0.5, 1.5),
                    child: ColorFiltered(
                      colorFilter: grayscale > 0
                          ? ColorFilter.matrix(_grayscaleMatrix(grayscale.clamp(0.0, 1.0)))
                          : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                      child: _buildFighter(
                        name: widget.opponent.name,
                        grade: widget.opponent.grade,
                        element: widget.opponent.element,
                        swordName: widget.opponent.swordName,
                        swordLevel: widget.opponent.swordLevel,
                        currentHp: _oppCurrentHp,
                        maxHp: _oppMaxHp,
                        isPlayer: false,
                        isHit: _showDamageOnEnemy,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 그레이스케일 매트릭스 (0~1 강도) ──
  List<double> _grayscaleMatrix(double strength) {
    final s = 1.0 - strength;
    final r = 0.2126 * strength;
    final g = 0.7152 * strength;
    final b = 0.0722 * strength;
    return [
      r + s, g, b, 0, 0,
      r, g + s, b, 0, 0,
      r, g, b + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  // =====================================================
  // 🗡️ 전투원 (캐릭터 실루엣 + 검 에셋 + 오라)
  // =====================================================
  Widget _buildFighter({
    required String name,
    required SwordGrade grade,
    required GameElement element,
    required String swordName,
    required int swordLevel,
    required int currentHp,
    required int maxHp,
    required bool isPlayer,
    required bool isHit,
  }) {
    final hpPercent = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
    final isDead = currentHp <= 0;

    return AnimatedBuilder(
      animation: _hitController,
      builder: (context, _) {
        double shake = 0;
        if (isHit) shake = sin(_hitController.value * pi * 6) * 5;

        return Transform.translate(
          offset: Offset(shake, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 이름
              Text(name,
                style: TextStyle(
                  color: grade.color, fontWeight: FontWeight.bold, fontSize: 12,
                  shadows: [Shadow(color: grade.color.withOpacity(0.6), blurRadius: 10)],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // 캐릭터 + 검 + 오라
              SizedBox(
                width: 100,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 등급 오라 (발밑 글로우)
                    Positioned(
                      bottom: 0,
                      child: AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, _) {
                          final pulse = 0.7 + sin(_ambientController.value * pi * 2) * 0.3;
                          return Container(
                            width: 70 * pulse,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(35),
                              gradient: RadialGradient(
                                colors: [
                                  grade.color.withOpacity(isDead ? 0.05 : 0.35 * pulse),
                                  grade.color.withOpacity(isDead ? 0.0 : 0.1),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: isDead ? null : [
                                BoxShadow(color: grade.color.withOpacity(0.2 * pulse), blurRadius: 16, spreadRadius: 2),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // 캐릭터 실루엣 (등급 색 틴트)
                    Positioned(
                      bottom: 8,
                      child: Opacity(
                        opacity: isDead ? 0.25 : 1.0,
                        child: SizedBox(
                          width: 60,
                          height: 80,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              grade.color.withOpacity(0.7),
                              BlendMode.srcATop,
                            ),
                            child: Image.asset(
                              isPlayer
                                  ? 'assets/images/battle/char_player.webp'
                                  : 'assets/images/battle/char_enemy.webp',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 검 에셋 (실루엣 위에 오버레이)
                    Positioned(
                      top: 0,
                      child: Opacity(
                        opacity: isDead ? 0.25 : 1.0,
                        child: SwordImageWidget(
                          grade: grade,
                          element: element,
                          level: swordLevel,
                          size: 55,
                          showPulse: !isDead && !_battleFinished,
                        ),
                      ),
                    ),

                    // 피격 링
                    if (isHit)
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red.withOpacity(0.7), width: 2),
                          boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 20, spreadRadius: 4)],
                        ),
                      ),

                    // 사망 마크
                    if (isDead)
                      Container(
                        width: 45, height: 45,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.6)),
                        child: const Center(child: Text('💀', style: TextStyle(fontSize: 26))),
                      ),

                    // 데미지 팝업
                    if (isHit && _lastDamage > 0)
                      Positioned(
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8),
                            border: _isCritical ? Border.all(color: Colors.yellow, width: 1) : null,
                          ),
                          child: Column(
                            children: [
                              if (_isCritical)
                                const Text('CRITICAL!', style: TextStyle(color: Colors.yellow, fontSize: 9, fontWeight: FontWeight.bold)),
                              Text('-${formatNumber(_lastDamage)}',
                                style: TextStyle(
                                  color: _isCritical ? Colors.yellow : Colors.red[300],
                                  fontSize: _isCritical ? 18 : 15,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),

              // 검 이름
              Text('${element.emoji} $swordName +$swordLevel',
                style: const TextStyle(color: Colors.white60, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // HP 바
              _buildHpBar(currentHp, maxHp, hpPercent),
            ],
          ),
        );
      },
    );
  }

  // ── HP 바 ──
  Widget _buildHpBar(int hp, int maxHp, double pct) {
    final c = pct > 0.5 ? Colors.green : pct > 0.2 ? Colors.orange : Colors.red;
    return Column(
      children: [
        Container(
          width: 90, height: 10,
          decoration: BoxDecoration(
            color: Colors.grey[900], borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.white24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(children: [
              FractionallySizedBox(
                alignment: Alignment.centerLeft, widthFactor: pct,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [c.withOpacity(0.8), c]),
                    boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 4)],
                  ),
                ),
              ),
              Positioned(top: 1, left: 2, right: 2, child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.white.withOpacity(0.2), Colors.transparent]),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
            ]),
          ),
        ),
        const SizedBox(height: 2),
        Text('${formatNumber(hp)} / ${formatNumber(maxHp)}',
          style: TextStyle(color: c.withOpacity(0.9), fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // =====================================================
  // ⚔️ VS 마커
  // =====================================================
  Widget _buildVsMarker() {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, _) {
        final pulse = 0.85 + sin(_ambientController.value * pi * 4) * 0.15;
        return Transform.scale(
          scale: pulse,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Colors.red.withOpacity(0.4), Colors.transparent]),
            ),
            child: Center(
              child: Text('VS', style: TextStyle(
                color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.red.withOpacity(0.8), blurRadius: 12)],
              )),
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // 🔪 슬래시 이펙트 오버레이
  // =====================================================
  Widget _buildSlashOverlay() {
    return Stack(
      children: [
        // ── 스윙 슬래시 (공격자 쪽, 작은 크기) ──
        AnimatedBuilder(
          animation: _swingSlashController,
          builder: (context, _) {
            if (!_swingSlashController.isAnimating) return const SizedBox.shrink();
            final attackerSide = !_slashOnPlayer;
            return Positioned.fill(
              child: Align(
                alignment: attackerSide ? const Alignment(-0.4, -0.1) : const Alignment(0.4, -0.1),
                child: Transform.scale(
                  scale: (_swingScale.value * 0.7).clamp(0.1, 1.5),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..scale(attackerSide ? 1.0 : -1.0, 1.0)
                      ..rotateZ(-0.3),
                    child: Opacity(
                      opacity: _swingOpacity.value.clamp(0.0, 1.0),
                      child: SizedBox(
                        width: 90,
                        height: 90,
                        child: Image.asset(
                          'assets/images/battle/slash_effect.webp',
                          color: Colors.white.withOpacity(0.6),
                          colorBlendMode: BlendMode.modulate,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => CustomPaint(
                            painter: _FallbackSlashPainter(
                              progress: _swingSlashController.value,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // ── 스윙 슬래시 (피격자 쪽, 180도 회전) ──
        AnimatedBuilder(
          animation: _swingSlashController,
          builder: (context, _) {
            if (!_swingSlashController.isAnimating) return const SizedBox.shrink();
            final victimSide = _slashOnPlayer;
            return Positioned.fill(
              child: Align(
                alignment: victimSide ? const Alignment(-0.35, 0.05) : const Alignment(0.35, 0.05),
                child: Transform.scale(
                  scale: (_swingScale.value * 0.7).clamp(0.1, 1.5),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..scale(victimSide ? 1.0 : -1.0, 1.0)
                      ..rotateZ(pi - 0.3),
                    child: Opacity(
                      opacity: (_swingOpacity.value * 0.8).clamp(0.0, 1.0),
                      child: SizedBox(
                        width: 90,
                        height: 90,
                        child: Image.asset(
                          'assets/images/battle/slash_effect.webp',
                          color: Colors.white.withOpacity(0.5),
                          colorBlendMode: BlendMode.modulate,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => CustomPaint(
                            painter: _FallbackSlashPainter(
                              progress: _swingSlashController.value,
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // ── 임팩트 슬래시 (피격자 쪽, 큰 크기) ──
        AnimatedBuilder(
          animation: _slashController,
          builder: (context, _) {
            if (!_slashController.isAnimating) return const SizedBox.shrink();
            return Positioned.fill(
              child: Align(
                alignment: _slashOnPlayer ? const Alignment(-0.5, 0.0) : const Alignment(0.5, 0.0),
                child: Transform.scale(
                  scale: _slashScale.value.clamp(0.1, 2.0),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..scale(_slashOnPlayer ? -1.0 : 1.0, 1.0),
                    child: Opacity(
                      opacity: _slashOpacity.value.clamp(0.0, 1.0),
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: Image.asset(
                          'assets/images/battle/slash_effect.webp',
                          color: _isCritical ? Colors.yellow.withOpacity(0.8) : null,
                          colorBlendMode: BlendMode.modulate,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => CustomPaint(
                            painter: _FallbackSlashPainter(
                              progress: _slashController.value,
                              color: _isCritical ? Colors.yellow : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // =====================================================
  // 💥 임팩트 파티클 오버레이
  // =====================================================
  Widget _buildImpactOverlay() {
    return AnimatedBuilder(
      animation: _impactController,
      builder: (context, _) {
        if (!_impactController.isAnimating || _impactParticles.isEmpty) return const SizedBox.shrink();
        return Positioned.fill(
          child: Align(
            alignment: _impactOnPlayer ? const Alignment(-0.5, 0.0) : const Alignment(0.5, 0.0),
            child: SizedBox(
              width: 120, height: 120,
              child: CustomPaint(
                painter: _ImpactPainter(
                  particles: _impactParticles,
                  progress: _impactController.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 스킬 이모지 ──
  Widget _buildSkillEmoji() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.5, end: 1.5),
        duration: const Duration(milliseconds: 250),
        builder: (_, s, __) => Transform.scale(
          scale: s,
          child: Text(_currentEffect!, style: const TextStyle(fontSize: 60)),
        ),
      ),
    );
  }

  // ── 스킬 발동 배너 ──
  Widget _buildSkillBanner() {
    return Positioned(
      top: 14, left: 0, right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, Colors.amber.withOpacity(0.35), Colors.transparent]),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('⚡ $_skillActivationText',
            style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 8)]),
          ),
        ),
      ),
    );
  }

  // ── 화면 플래시 ──
  Widget _buildScreenFlash() {
    return AnimatedBuilder(
      animation: _flashController,
      builder: (context, _) {
        if (!_flashController.isAnimating) return const SizedBox.shrink();
        return Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: _flashColor.withOpacity(_flashOpacity.value.clamp(0.0, 1.0)),
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // 🏆 승패 오버레이
  // =====================================================
  Widget _buildVictoryOverlay() {
    final isWin = widget.result.isWin;
    return AnimatedBuilder(
      animation: _victoryController,
      builder: (context, _) {
        final v = _victoryController.value;
        if (v < 0.05) return const SizedBox.shrink();

        return Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 승자 쪽 빛 폭발
                Align(
                  alignment: isWin ? const Alignment(-0.5, 0.0) : const Alignment(0.5, 0.0),
                  child: Container(
                    width: 150 * v,
                    height: 150 * v,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        (isWin ? widget.me.grade.color : widget.opponent.grade.color).withOpacity((0.4 * (1 - v)).clamp(0.0, 1.0)),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 컨페티 ──
  Widget _buildConfetti() {
    return AnimatedBuilder(
      animation: _victoryController,
      builder: (context, _) {
        final v = _victoryController.value;
        if (v < 0.1 || _confettiPieces.isEmpty) return const SizedBox.shrink();
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ConfettiPainter(pieces: _confettiPieces, progress: v),
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // 📋 배틀 로그
  // =====================================================
  Widget _buildBattleLog() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.list_alt, color: Colors.white54, size: 16),
            const SizedBox(width: 6),
            const Text('배틀 로그', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
            const Spacer(),
            Text('${_currentLogIndex}/${widget.result.logs.length}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ]),
          const Divider(color: Colors.white12, height: 8),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _displayedLogs.length,
              itemBuilder: (_, i) {
                final ri = _displayedLogs.length - 1 - i;
                final log = _displayedLogs[ri];
                if (log.startsWith('📊 HP:')) return const SizedBox.shrink();
                final isRecent = ri == _displayedLogs.length - 1;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
                  margin: const EdgeInsets.only(bottom: 1),
                  decoration: isRecent ? BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)) : null,
                  child: Text(log,
                    style: TextStyle(color: _logColor(log), fontSize: 11,
                      fontWeight: isRecent ? FontWeight.bold : FontWeight.normal)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _logColor(String l) {
    if (l.contains('승리') || l.contains('쓰러졌습니다!')) return Colors.green[300]!;
    if (l.contains('패배') || l.contains('쓰러졌습니다...')) return Colors.red[300]!;
    if (l.contains(widget.me.name) && l.contains('→')) return Colors.blue[300]!;
    if (l.contains(widget.opponent.name) && l.contains('→')) return Colors.orange[300]!;
    if (l.contains('크리티컬') || l.contains('💥')) return Colors.yellow[300]!;
    if (l.contains('회피')) return Colors.grey[400]!;
    if (l.contains('스킬') || l.contains('【')) return Colors.purple[300]!;
    return Colors.white70;
  }

  // =====================================================
  // 🏆 결과 바
  // =====================================================
  Widget _buildResultBar() {
    final isWin = widget.result.isWin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isWin
            ? [Colors.green.withOpacity(0.3), Colors.green.withOpacity(0.1)]
            : [Colors.red.withOpacity(0.3), Colors.red.withOpacity(0.1)]),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isWin ? '🏆 승리!' : '💀 패배...',
              style: TextStyle(color: isWin ? Colors.green[300] : Colors.red[300], fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Row(children: [
              Text(isWin ? '전리품: +${formatGold(widget.result.goldEarned)}' : '전리품 없음',
                style: TextStyle(color: isWin ? Colors.amber : Colors.white54, fontSize: 14)),
              if (isWin && widget.stoneReward > 0) ...[
                const SizedBox(width: 8),
                Image.asset('assets/images/home/header/enhance_mythic.png', width: 16, height: 16),
                const SizedBox(width: 3),
                Text('+${widget.stoneReward}', style: const TextStyle(color: Colors.purple, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ]),
          ],
        )),
        ElevatedButton(
          onPressed: () { SoundService().playMainBgm(); Navigator.pop(context); },
          style: ElevatedButton.styleFrom(
            backgroundColor: isWin ? Colors.green : Colors.grey[700],
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('확인', style: TextStyle(color: Colors.white)),
        ),
      ]),
    );
  }
}

// =====================================================
// 🎨 커스텀 페인터들
// =====================================================

// ── 배경 파티클 ──
class _BgParticlePainter extends CustomPainter {
  final List<_BgParticle> particles;
  final double progress;
  _BgParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y + progress * p.speed) % 1.0;
      final x = p.x + sin(y * pi * 2 + p.speed) * 0.02;
      final twinkle = (0.5 + sin(progress * pi * 2 + p.x * 10) * 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x * size.width, (1 - y) * size.height),
        p.size,
        Paint()
          ..color = Colors.white.withOpacity(p.opacity * twinkle)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BgParticlePainter old) => true;
}

// ── 임팩트 파티클 ──
class _ImpactPainter extends CustomPainter {
  final List<_ImpactParticle> particles;
  final double progress;
  _ImpactPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (final p in particles) {
      final dist = p.speed * progress;
      final x = cx + cos(p.angle) * dist;
      final y = cy + sin(p.angle) * dist;
      final fade = (1.0 - progress).clamp(0.0, 1.0);
      final s = p.size * (1.0 - progress * 0.5);

      canvas.drawCircle(
        Offset(x, y), s.clamp(0.5, 10.0),
        Paint()
          ..color = p.color.withOpacity(fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactPainter old) => old.progress != progress;
}

// ── 컨페티 ──
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;
  _ConfettiPainter({required this.pieces, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final y = -20 + (size.height + 40) * progress * p.speed;
      final x = p.x * size.width + sin(progress * pi * 4 + p.wobble) * p.wobble;
      final rot = p.rotation + progress * pi * 6;
      final fade = progress < 0.8 ? 1.0 : (1.0 - (progress - 0.8) / 0.2);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
        Paint()..color = p.color.withOpacity(fade.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}

// ── 슬래시 폴백 (이미지 없을 때) ──
class _FallbackSlashPainter extends CustomPainter {
  final double progress;
  final Color color;
  _FallbackSlashPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity((1.0 - progress).clamp(0.0, 1.0))
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    path.moveTo(size.width * 0.8, size.height * 0.1);
    path.quadraticBezierTo(size.width * 0.5, size.height * 0.5, size.width * 0.2, size.height * 0.9);
    canvas.drawPath(path, paint);

    // 글로우 복제
    paint.strokeWidth = 8;
    paint.color = color.withOpacity((0.3 * (1.0 - progress)).clamp(0.0, 1.0));
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FallbackSlashPainter old) => old.progress != progress;
}
