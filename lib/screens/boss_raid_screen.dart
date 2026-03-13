import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../models/boss_data.dart';
import '../models/owned_sword.dart';
import '../enums/element.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../enums/sword_grade.dart';
import '../services/sound_service.dart';  // 🔊 사운드 서비스
import '../widgets/sword_image_widget.dart';  // 🗡️ 검 이미지 위젯

// ============================================================
// 데미지 팝업 데이터 클래스
// ============================================================
class _DamagePopup {
  final int damage;
  final bool isCritical;
  final bool isPlayerDamage;
  final Offset position;
  final String id;
  
  _DamagePopup({
    required this.damage,
    required this.isCritical,
    required this.isPlayerDamage,
    required this.position,
  }) : id = DateTime.now().microsecondsSinceEpoch.toString();
}

// ============================================================
// 파티클 데이터 클래스
// ============================================================
class _Particle {
  double x, y;
  double vx, vy;
  double size;
  Color color;
  double life;
  final double maxLife;
  
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.maxLife,
  }) : life = maxLife;
  
  void update() {
    x += vx;
    y += vy;
    vy += 0.5; // 중력
    life -= 0.02;
  }
  
  bool get isDead => life <= 0;
  double get opacity => maxLife > 0 ? (life / maxLife).clamp(0.0, 1.0) : 0.0;
}

// ============================================================
// 스킬 이펙트 데이터 클래스
// ============================================================
class _SkillEffect {
  final String skillName;
  final Color color;
  final String id;
  
  _SkillEffect({
    required this.skillName,
    required this.color,
  }) : id = DateTime.now().microsecondsSinceEpoch.toString();
}

class BossRaidScreen extends StatefulWidget {
  final BossData boss;
  final OwnedSword playerSword;
  final int playerPower;
  final Function(bool) onComplete;

  const BossRaidScreen({
    super.key,
    required this.boss,
    required this.playerSword,
    required this.playerPower,
    required this.onComplete,
  });

  @override
  State<BossRaidScreen> createState() => _BossRaidScreenState();
}

class _BossRaidScreenState extends State<BossRaidScreen>
    with TickerProviderStateMixin {
  
  // ============================================================
  // 애니메이션 컨트롤러들
  // ============================================================
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late AnimationController _flashController;
  late AnimationController _criticalFlashController;
  late AnimationController _bossEntranceController;
  late AnimationController _skillEffectController;
  late AnimationController _comboController;
  late AnimationController _victoryController;
  late AnimationController _defeatController;
  late AnimationController _particleController;
  late AnimationController _elementEffectController;
  
  // ✅ 보스 모션 애니메이션 컨트롤러
  late AnimationController _bossIdleController;      // 기본 숨쉬기
  late AnimationController _bossFloatController;     // 떠다니기
  late AnimationController _bossElementController;   // 원소별 특수효과
  
  late Animation<double> _shakeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _flashAnimation;
  late Animation<double> _criticalFlashAnimation;
  late Animation<double> _bossEntranceAnimation;
  late Animation<double> _bossEntranceScale;
  late Animation<double> _skillEffectAnimation;
  late Animation<double> _comboAnimation;
  late Animation<double> _victoryAnimation;
  late Animation<double> _defeatAnimation;
  
  // ✅ 보스 모션 애니메이션
  late Animation<double> _bossIdleAnimation;         // 숨쉬기 스케일
  late Animation<double> _bossFloatAnimation;        // 위아래 이동
  late Animation<double> _bossElementAnimation;      // 원소별 효과

  final _random = Random();

  // ============================================================
  // 전투 상태
  // ============================================================
  int _bossHp = 0;
  int _maxBossHp = 0;
  int _playerHp = 0;
  int _maxPlayerHp = 0;
  double _displayedBossHp = 0;  // HP바 애니메이션용
  double _displayedPlayerHp = 0;
  bool _battleStarted = false;
  bool _battleEnded = false;
  bool _isWin = false;
  bool _completionHandled = false;
  bool _isExiting = false;
  bool _allowPop = false;
  int _turn = 0;
  bool _bossEntranceComplete = false;
  
  // ============================================================
  // 이펙트 상태
  // ============================================================
  final List<_DamagePopup> _damagePopups = [];
  final List<_Particle> _particles = [];
  final List<_SkillEffect> _skillEffects = [];
  int _comboCount = 0;
  bool _showCombo = false;
  double _shakeIntensity = 1.0;
  
  // 배틀 로그
  final List<String> _battleLog = [];
  final ScrollController _logScrollController = ScrollController();

  // 타이머
  Timer? _battleTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initBattle();
    _startBossEntrance();
    
    // 🎵 보스 BGM 재생
    SoundService().playBossBgm();
  }

  // ============================================================
  // 애니메이션 초기화
  // ============================================================
  void _initAnimations() {
    // 흔들림 애니메이션
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // 펄스 애니메이션
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutBack),
    );

    // 피격 플래시 (빨강)
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _flashAnimation = Tween<double>(begin: 0, end: 1).animate(_flashController);
    
    // 크리티컬 플래시 (노랑)
    _criticalFlashController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _criticalFlashAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _criticalFlashController, curve: Curves.easeOut),
    );
    
    // 보스 등장 애니메이션
    _bossEntranceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _bossEntranceAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bossEntranceController, curve: Curves.easeOutBack),
    );
    _bossEntranceScale = Tween<double>(begin: 3.0, end: 1.0).animate(
      CurvedAnimation(parent: _bossEntranceController, curve: Curves.easeOutCubic),
    );
    
    // 스킬 이펙트 애니메이션
    _skillEffectController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _skillEffectAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _skillEffectController, curve: Curves.easeOutCubic),
    );
    
    // 콤보 애니메이션
    _comboController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _comboAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _comboController, curve: Curves.elasticOut),
    );
    
    // 승리 애니메이션
    _victoryController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _victoryAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _victoryController, curve: Curves.easeOutCubic),
    );
    
    // 패배 애니메이션
    _defeatController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _defeatAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _defeatController, curve: Curves.easeInOut),
    );
    
    // 파티클 애니메이션
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 16), // 60fps
      vsync: this,
    )..addListener(_updateParticles);
    
    // 원소 이펙트 애니메이션 (반복)
    _elementEffectController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    // ============================================================
    // ✅ 보스 모션 애니메이션 초기화
    // ============================================================
    
    // 1. 숨쉬기 애니메이션 (스케일 변화)
    _bossIdleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _bossIdleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _bossIdleController, curve: Curves.easeInOut),
    );
    
    // 2. 떠다니기 애니메이션 (위아래 움직임)
    _bossFloatController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    _bossFloatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _bossFloatController, curve: Curves.easeInOut),
    );
    
    // 3. 원소별 특수효과 애니메이션
    _bossElementController = AnimationController(
      duration: _getElementAnimationDuration(),
      vsync: this,
    )..repeat(reverse: _shouldReverseElementAnimation());
    _bossElementAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bossElementController, curve: Curves.easeInOut),
    );
  }
  
  // 원소별 애니메이션 속도
  Duration _getElementAnimationDuration() {
    switch (widget.boss.element) {
      case GameElement.fire:
        return const Duration(milliseconds: 150);  // 빠른 흔들림
      case GameElement.water:
        return const Duration(milliseconds: 2500); // 느린 물결
      case GameElement.nature:
        return const Duration(milliseconds: 4000); // 부드러운 바람
      case GameElement.light:
        return const Duration(milliseconds: 800);  // 빛 깜빡임
      case GameElement.dark:
        return const Duration(milliseconds: 3000); // 어둠 펄스
    }
  }
  
  // 원소별 reverse 여부
  bool _shouldReverseElementAnimation() {
    switch (widget.boss.element) {
      case GameElement.fire:
      case GameElement.water:
      case GameElement.nature:
      case GameElement.dark:
        return true;
      case GameElement.light:
        return false; // 빛은 계속 반복
    }
  }

  void _initBattle() {
    _maxBossHp = widget.boss.hp;
    _bossHp = _maxBossHp;
    _displayedBossHp = _maxBossHp.toDouble();
    // v9.2: PvP와 동일한 HP 공식 적용 (전투력 기반)
    _maxPlayerHp = 1000 + (widget.playerPower * 2);
    _playerHp = _maxPlayerHp;
    _displayedPlayerHp = _maxPlayerHp.toDouble();
  }
  
  // ============================================================
  // 보스 등장 연출 (이펙트 #6)
  // ============================================================
  void _startBossEntrance() {
    _bossEntranceController.forward().then((_) {
      setState(() => _bossEntranceComplete = true);
      _addLog('⚔️ ${widget.boss.name} 등장!');
      _addLog('플레이어 HP: $_playerHp | 보스 HP: $_bossHp');
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pulseController.dispose();
    _flashController.dispose();
    _criticalFlashController.dispose();
    _bossEntranceController.dispose();
    _skillEffectController.dispose();
    _comboController.dispose();
    _victoryController.dispose();
    _defeatController.dispose();
    _particleController.dispose();
    _elementEffectController.dispose();
    // ✅ 보스 모션 컨트롤러 해제
    _bossIdleController.dispose();
    _bossFloatController.dispose();
    _bossElementController.dispose();
    _logScrollController.dispose();
    _battleTimer?.cancel();
    
    // 🎵 BGM 정리 (뒤로가기 등 비정상 종료 시)
    if (!_battleEnded) {
      SoundService().playMainBgm();
    }
    
    super.dispose();
  }
  
  // 🔙 뒤로가기 처리
  Future<bool> _onWillPop() async {
    if (_battleEnded) {
      // 결과 상태에서는 수동 탈출 허용 (보상/콜백은 1회만 처리)
      _completeBattleAndExit();
      return false;
    }
    
    // 전투 중 도망 확인
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text(
          '⚠️ 전투 포기',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '전투를 포기하시겠습니까?\n패배로 처리됩니다.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 싸우기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('포기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (shouldExit == true) {
      _battleTimer?.cancel();
      SoundService().playMainBgm();
      if (!_completionHandled) {
        _completionHandled = true;
        try {
          widget.onComplete(false);  // 패배 처리 (쿨다운 적용)
        } catch (e) {
          debugPrint('⚠️ boss onComplete failed on surrender: $e');
        }
      }
      return true;
    }
    return false;
  }

  // ============================================================
  // 파티클 시스템 (이펙트 #4)
  // ============================================================
  void _updateParticles() {
    setState(() {
      for (final p in _particles) {
        p.update();
      }
      _particles.removeWhere((p) => p.isDead);
    });
    
    if (_particles.isNotEmpty) {
      _particleController.forward(from: 0);
    }
  }
  
  void _spawnParticles(Offset center, Color color, {int count = 20, bool isExplosion = true}) {
    for (int i = 0; i < count; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = isExplosion ? 3 + _random.nextDouble() * 8 : 1 + _random.nextDouble() * 3;
      
      _particles.add(_Particle(
        x: center.dx,
        y: center.dy,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - (isExplosion ? 5 : 0),
        size: 4 + _random.nextDouble() * 8,
        color: color,
        maxLife: 0.5 + _random.nextDouble() * 0.5,
      ));
    }
    
    _particleController.forward(from: 0);
  }

  // ============================================================
  // 데미지 팝업 (이펙트 #1)
  // ============================================================
  void _addDamagePopup(int damage, bool isCritical, bool isPlayerDamage) {
    final screenSize = MediaQuery.of(context).size;
    final position = isPlayerDamage 
        ? Offset(screenSize.width * 0.5, screenSize.height * 0.7)
        : Offset(screenSize.width * 0.5, screenSize.height * 0.25);
    
    setState(() {
      _damagePopups.add(_DamagePopup(
        damage: damage,
        isCritical: isCritical,
        isPlayerDamage: isPlayerDamage,
        position: position,
      ));
    });
    
    // 2초 후 제거
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _damagePopups.removeWhere((p) => p.damage == damage);
        });
      }
    });
  }
  
  // ============================================================
  // 스킬 이펙트 (이펙트 #2)
  // ============================================================
  void _showSkillEffect(String skillName, Color color) {
    setState(() {
      _skillEffects.add(_SkillEffect(skillName: skillName, color: color));
    });
    
    _skillEffectController.forward(from: 0);
    
    // 1초 후 제거
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && _skillEffects.isNotEmpty) {
        setState(() => _skillEffects.removeAt(0));
      }
    });
  }
  
  // ============================================================
  // 콤보 카운터 (이펙트 #8)
  // ============================================================
  void _incrementCombo() {
    setState(() {
      _comboCount++;
      _showCombo = true;
    });
    
    _comboController.forward(from: 0);
    
    // 2초 후 숨김
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_battleEnded) {
        setState(() => _showCombo = false);
      }
    });
  }
  
  void _resetCombo() {
    setState(() {
      _comboCount = 0;
      _showCombo = false;
    });
  }

  void _addLog(String message) {
    setState(() {
      _battleLog.add(message);
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startBattle() {
    if (!_bossEntranceComplete) return;
    
    setState(() => _battleStarted = true);
    _addLog('');
    _addLog('🔥 전투 시작!');
    _nextTurn();
  }

  void _nextTurn() {
    if (_battleEnded) return;

    _battleTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      
      _turn++;
      _playerAttack();
    });
  }

  // ============================================================
  // 플레이어 공격 (이펙트 적용)
  // ============================================================
  void _playerAttack() {
    final playerElement = widget.playerSword.data.element;
    final bossElement = widget.boss.element;
    final elementMultiplier = calculateElementMultiplier(playerElement, bossElement);

    // ✅ v7: PvP와 동일한 데미지 공식 적용
    int baseDamage = 60 + (widget.playerPower * 0.15).round();
    String skillUsed = '';
    bool isCritical = _random.nextDouble() < 0.15; // 15% 크리티컬 확률
    Color skillColor = playerElement.color;

    // 스킬 발동 체크
    for (final skill in widget.playerSword.data.skills) {
      if (_random.nextInt(100) < skill.procRate) {
        baseDamage = (baseDamage * skill.multiplier).floor();
        skillUsed = skill.name;
        skillColor = skill.element?.color ?? playerElement.color;
        
        // 스킬 이펙트 표시 (이펙트 #2)
        _showSkillEffect(skill.name, skillColor);
        break;
      }
    }

    // 크리티컬 보너스
    if (isCritical) {
      baseDamage = (baseDamage * 1.5).floor();
    }

    // 최종 데미지
    final damage = calculateDamage(baseDamage, multiplier: elementMultiplier);
    
    // 🔊 타격 사운드
    SoundService().playBattleHit();

    setState(() {
      _bossHp = max(0, _bossHp - damage);
      // 화면 흔들림 강도 (이펙트 #9)
      _shakeIntensity = (damage / 100).clamp(1.0, 5.0);
    });
    
    // HP바 애니메이션 (이펙트 #5)
    _animateHpBar();

    // 상성 텍스트
    String elementText = '';
    if (elementMultiplier > 1) {
      elementText = ' (상성 유리!)';
    } else if (elementMultiplier < 1) {
      elementText = ' (상성 불리)';
    }

    final skillText = skillUsed.isNotEmpty ? ' 💥 $skillUsed!' : '';
    final critText = isCritical ? ' ⚡크리티컬!' : '';
    _addLog('턴 $_turn: 플레이어 공격! $damage 데미지$skillText$critText$elementText');

    // 데미지 팝업 (이펙트 #1)
    _addDamagePopup(damage, isCritical, false);
    
    // 콤보 증가 (이펙트 #8)
    _incrementCombo();
    
    // 파티클 폭발 (이펙트 #4)
    final screenSize = MediaQuery.of(context).size;
    _spawnParticles(
      Offset(screenSize.width * 0.5, screenSize.height * 0.3),
      isCritical ? Colors.yellow : skillColor,
      count: isCritical ? 30 : 15,
    );

    // 애니메이션
    _pulseController.forward().then((_) => _pulseController.reverse());
    _shakeController.forward().then((_) => _shakeController.reverse());
    
    // 크리티컬 이펙트 (이펙트 #3)
    if (isCritical) {
      _criticalFlashController.forward().then((_) => _criticalFlashController.reverse());
    }

    // 보스 처치 체크
    if (_bossHp <= 0) {
      _endBattle(true);
      return;
    }

    // 보스 반격 (v7: 2배속)
    _battleTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _bossAttack();
    });
  }

  // ============================================================
  // 보스 공격
  // ============================================================
  void _bossAttack() {
    final playerElement = widget.playerSword.data.element;
    final bossElement = widget.boss.element;
    final elementMultiplier = calculateElementMultiplier(bossElement, playerElement);
    
    final damage = calculateDamage(widget.boss.atk, multiplier: elementMultiplier);
    
    // 🔊 타격 사운드
    SoundService().playBattleHit();

    setState(() {
      _playerHp = max(0, _playerHp - damage);
    });
    
    // HP바 애니메이션 (이펙트 #5)
    _animateHpBar();

    _addLog('보스 반격! $damage 데미지');
    
    // 데미지 팝업 (이펙트 #1)
    _addDamagePopup(damage, false, true);
    
    // 콤보 리셋 (피격 시)
    _resetCombo();
    
    // 파티클 (플레이어 피격)
    final screenSize = MediaQuery.of(context).size;
    _spawnParticles(
      Offset(screenSize.width * 0.5, screenSize.height * 0.75),
      Colors.red,
      count: 10,
    );

    // 플래시 애니메이션
    _flashController.forward().then((_) => _flashController.reverse());

    // 플레이어 사망 체크
    if (_playerHp <= 0) {
      _endBattle(false);
      return;
    }

    // 턴 제한 (v7: 50턴)
    if (_turn >= 50) {
      _addLog('⏰ 시간 초과!');
      _endBattle(false);
      return;
    }

    _nextTurn();
  }
  
  // HP바 부드럽게 애니메이션 (이펙트 #5)
  void _animateHpBar() {
    final bossTarget = _bossHp.toDouble();
    final playerTarget = _playerHp.toDouble();
    
    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        // 보스 HP
        if ((_displayedBossHp - bossTarget).abs() > 1) {
          _displayedBossHp += (bossTarget - _displayedBossHp) * 0.15;
        } else {
          _displayedBossHp = bossTarget;
        }
        
        // 플레이어 HP
        if ((_displayedPlayerHp - playerTarget).abs() > 1) {
          _displayedPlayerHp += (playerTarget - _displayedPlayerHp) * 0.15;
        } else {
          _displayedPlayerHp = playerTarget;
        }
      });
      
      if (_displayedBossHp == bossTarget && _displayedPlayerHp == playerTarget) {
        timer.cancel();
      }
    });
  }

  // ============================================================
  // 전투 종료 (이펙트 #10)
  // ============================================================
  void _endBattle(bool win) {
    // 중복 종료 호출 방지
    if (_battleEnded) return;

    _battleTimer?.cancel();
    
    setState(() {
      _battleEnded = true;
      _isWin = win;
    });

    if (win) {
      _addLog('');
      _addLog('🎉 승리! ${widget.boss.name} 처치!');
      _addLog('+${widget.boss.goldReward}G +${widget.boss.diamondReward}💎');
      
      // 🔊 승리 사운드
      SoundService().playBattleWin();
      
      // 승리 이펙트: 황금빛 파티클 폭발
      _victoryController.forward();
      final screenSize = MediaQuery.of(context).size;
      for (int i = 0; i < 5; i++) {
        Future.delayed(Duration(milliseconds: i * 100), () {
          if (mounted) {
            _spawnParticles(
              Offset(
                screenSize.width * (0.2 + _random.nextDouble() * 0.6),
                screenSize.height * (0.2 + _random.nextDouble() * 0.4),
              ),
              Colors.amber,
              count: 25,
              isExplosion: true,
            );
          }
        });
      }
    } else {
      _addLog('');
      _addLog('💀 패배... 다음에 다시 도전하세요');
      
      // 🔊 패배 사운드
      SoundService().playBattleLose();
      
      // 패배 이펙트: 화면 흑백
      _defeatController.forward();
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _completeBattleAndExit();
    });
  }

  void _completeBattleAndExit() {
    if (_isExiting) return;
    _isExiting = true;

    if (_completionHandled) {
      if (mounted) _safePop();
      return;
    }
    _completionHandled = true;

    // 🎵 메인 BGM으로 전환
    SoundService().playMainBgm();

    try {
      widget.onComplete(_isWin);
    } catch (e) {
      debugPrint('⚠️ boss onComplete failed: $e');
    }

    if (mounted) _safePop();
  }

  Future<void> _forceExitToHome() async {
    _battleTimer?.cancel();

    if (!_completionHandled) {
      _completionHandled = true;
      try {
        widget.onComplete(_isWin);
      } catch (e) {
        debugPrint('⚠️ boss onComplete failed on force close: $e');
      }
    }

    // 메인 BGM 복구
    SoundService().playMainBgm();

    if (!mounted) return;
    await _safePop();

    // Pop이 실패해 화면이 남아있는 경우 route를 강제 제거
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null) {
      Navigator.of(context).removeRoute(route);
    }
  }

  Future<void> _safePop([Object? result]) async {
    if (!mounted) return;

    if (!_allowPop) {
      setState(() => _allowPop = true);
      // PopScope의 canPop 반영을 한 프레임 기다림
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
    }

    final navigator = Navigator.of(context);
    final currentRoute = ModalRoute.of(context);
    final isCurrent = currentRoute?.isCurrent ?? false;

    if (isCurrent) {
      navigator.pop(result);
      return;
    }

    // 위에 남아있는 다이얼로그/오버레이를 먼저 닫고 다시 본 route pop 시도
    if (navigator.canPop()) {
      navigator.pop();
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;

      if (ModalRoute.of(context)?.isCurrent ?? false) {
        Navigator.of(context).pop(result);
      }
    }
  }

  // ============================================================
  // UI 빌드
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          _safePop();
        }
      },
      child: Scaffold(
      body: AnimatedBuilder(
        animation: _defeatAnimation,
        builder: (context, child) {
          // 패배 시 흑백 효과 (이펙트 #10)
          return ColorFiltered(
            colorFilter: ColorFilter.matrix(_getGrayscaleMatrix(_defeatAnimation.value)),
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.boss.element.color.withOpacity(0.4),
                AppColors.backgroundDark,
                AppColors.background,
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // 원소 배경 이펙트 (이펙트 #7)
                _buildElementBackground(),
                
                // 배경 파티클
                _buildBackgroundParticles(),
                
                // 피격 플래시 (빨강)
                _buildFlashOverlay(),
                
                // 크리티컬 플래시 (노랑) (이펙트 #3)
                _buildCriticalFlashOverlay(),
                
                // 승리 플래시 (이펙트 #10)
                _buildVictoryOverlay(),
                
                // 메인 컨텐츠
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    // 화면 흔들림 강화 (이펙트 #9)
                    final offset = _shakeAnimation.value * _shakeIntensity * 10;
                    return Transform.translate(
                      offset: Offset(
                        offset * (_random.nextBool() ? 1 : -1),
                        offset * 0.5 * (_random.nextBool() ? 1 : -1),
                      ),
                      child: child,
                    );
                  },
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          children: [
                            _buildHeader(),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight - 60, // header 높이 제외
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildBattleArea(),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildBattleLog(),
                                          _buildPlayerArea(),
                                          _buildActionButton(),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                
                // 파티클 레이어 (이펙트 #4)
                _buildParticleLayer(),
                
                // 데미지 팝업 레이어 (이펙트 #1)
                _buildDamagePopupLayer(),
                
                // 스킬 이펙트 레이어 (이펙트 #2)
                _buildSkillEffectLayer(),
                
                // 콤보 카운터 (이펙트 #8)
                _buildComboCounter(),
                
                // 보스 등장 연출 (이펙트 #6)
                if (!_bossEntranceComplete) _buildBossEntranceOverlay(),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
  
  // 흑백 매트릭스 (패배 효과용)
  List<double> _getGrayscaleMatrix(double amount) {
    final v = 1 - amount * 0.8;
    return [
      v, 1-v, 0, 0, 0,
      0, v, 1-v, 0, 0,
      0, 0, v, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
  
  // ============================================================
  // 원소 배경 이펙트 (이펙트 #7)
  // ============================================================
  Widget _buildElementBackground() {
    return AnimatedBuilder(
      animation: _elementEffectController,
      builder: (context, _) {
        return IgnorePointer(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final actualSize = Size(
                constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width,
                constraints.maxHeight.isFinite ? constraints.maxHeight : MediaQuery.of(context).size.height,
              );
              return CustomPaint(
                painter: _ElementBackgroundPainter(
                  element: widget.boss.element,
                  progress: _elementEffectController.value,
                ),
                size: actualSize,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBackgroundParticles() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          return Stack(
            children: List.generate(15, (i) {
              final size = 8.0 + (i % 5) * 4;
              // opacity 값을 0.0 ~ 1.0 범위로 제한
              final opacity = (0.3 + (_pulseAnimation.value - 1) * 0.5).clamp(0.0, 1.0);
              return Positioned(
                left: (i * 67.3) % MediaQuery.of(context).size.width,
                top: (i * 41.7) % (MediaQuery.of(context).size.height * 0.6),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.boss.element.color,
                      boxShadow: [
                        BoxShadow(
                          color: widget.boss.element.color,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildFlashOverlay() {
    return AnimatedBuilder(
      animation: _flashAnimation,
      builder: (context, _) {
        return IgnorePointer(
          child: Container(
            color: Colors.red.withOpacity(_flashAnimation.value * 0.4),
          ),
        );
      },
    );
  }
  
  // 크리티컬 플래시 (이펙트 #3)
  Widget _buildCriticalFlashOverlay() {
    return AnimatedBuilder(
      animation: _criticalFlashAnimation,
      builder: (context, _) {
        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.yellow.withOpacity(_criticalFlashAnimation.value * 0.6),
                  Colors.orange.withOpacity(_criticalFlashAnimation.value * 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // 승리 오버레이 (이펙트 #10)
  Widget _buildVictoryOverlay() {
    return AnimatedBuilder(
      animation: _victoryAnimation,
      builder: (context, _) {
        if (_victoryAnimation.value == 0) return const SizedBox.shrink();
        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.amber.withOpacity(_victoryAnimation.value * 0.4),
                  Colors.orange.withOpacity(_victoryAnimation.value * 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // 파티클 레이어 (이펙트 #4)
  Widget _buildParticleLayer() {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actualSize = Size(
            constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width,
            constraints.maxHeight.isFinite ? constraints.maxHeight : MediaQuery.of(context).size.height,
          );
          return CustomPaint(
            painter: _ParticlePainter(particles: _particles),
            size: actualSize,
          );
        },
      ),
    );
  }
  
  // 데미지 팝업 레이어 (이펙트 #1)
  Widget _buildDamagePopupLayer() {
    return IgnorePointer(
      child: Stack(
        children: _damagePopups.map((popup) {
          return TweenAnimationBuilder<double>(
            key: ValueKey(popup.id),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            builder: (context, value, _) {
              return Positioned(
                left: popup.position.dx - 50 + (_random.nextDouble() - 0.5) * 40,
                top: popup.position.dy - value * 80,
                child: Opacity(
                  opacity: 1 - value * 0.7,
                  child: Transform.scale(
                    scale: 1 + value * 0.3,
                    child: Text(
                      '-${popup.damage}',
                      style: TextStyle(
                        color: popup.isCritical 
                            ? Colors.yellow 
                            : (popup.isPlayerDamage ? Colors.red : Colors.white),
                        fontSize: popup.isCritical ? 36 : 28,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                            offset: const Offset(2, 2),
                          ),
                          if (popup.isCritical)
                            Shadow(
                              color: Colors.orange,
                              blurRadius: 10,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
  
  // 스킬 이펙트 레이어 (이펙트 #2)
  Widget _buildSkillEffectLayer() {
    if (_skillEffects.isEmpty) return const SizedBox.shrink();
    
    return AnimatedBuilder(
      animation: _skillEffectAnimation,
      builder: (context, _) {
        final effect = _skillEffects.isNotEmpty ? _skillEffects.first : null;
        if (effect == null) return const SizedBox.shrink();
        
        // 안전을 위해 clamp 적용
        final skillValue = _skillEffectAnimation.value.clamp(0.0, 1.0);
        return IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: (1 - skillValue).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 1 + skillValue * 0.5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: effect.color, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: effect.color.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Text(
                    '⚔️ ${effect.skillName}!',
                    style: TextStyle(
                      color: effect.color,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: effect.color, blurRadius: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  // 콤보 카운터 (이펙트 #8)
  Widget _buildComboCounter() {
    if (!_showCombo || _comboCount < 2) return const SizedBox.shrink();
    
    return Positioned(
      top: 120,
      right: 20,
      child: AnimatedBuilder(
        animation: _comboAnimation,
        builder: (context, _) {
          // elasticOut 커브는 1.0을 초과할 수 있으므로 clamp 필수
          final comboValue = _comboAnimation.value.clamp(0.0, 1.0);
          return Transform.scale(
            scale: 0.5 + comboValue * 0.5,
            child: Opacity(
              opacity: comboValue,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.red],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.5),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_comboCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'COMBO!',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  // 보스 등장 오버레이 (이펙트 #6)
  Widget _buildBossEntranceOverlay() {
    return AnimatedBuilder(
      animation: _bossEntranceAnimation,
      builder: (context, _) {
        // easeOutBack 커브는 1.0을 초과할 수 있으므로 clamp 필수
        final animValue = _bossEntranceAnimation.value.clamp(0.0, 1.0);
        return Container(
          color: Colors.black.withOpacity((1 - animValue).clamp(0.0, 1.0)),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 보스 줌인
                Transform.scale(
                  scale: _bossEntranceScale.value.clamp(0.1, 10.0),
                  child: Opacity(
                    opacity: animValue,
                    child: widget.boss.hasImage
                        ? Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.boss.element.color.withOpacity(0.8),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                widget.boss.imagePath!,
                                width: 150,
                                height: 150,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Text(
                                    widget.boss.element.emoji,
                                    style: const TextStyle(fontSize: 120),
                                  );
                                },
                              ),
                            ),
                          )
                        : Text(
                            widget.boss.element.emoji,
                            style: const TextStyle(fontSize: 120),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                // 보스 이름
                Opacity(
                  opacity: animValue,
                  child: Text(
                    widget.boss.name,
                    style: TextStyle(
                      color: widget.boss.element.color,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: widget.boss.element.color,
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // WARNING 텍스트
                Opacity(
                  opacity: (animValue * 2).clamp(0.0, 1.0),
                  child: const Text(
                    '⚠️ WARNING ⚠️',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                await _safePop();
              }
            },
          ),
          const Spacer(),
          
          Text(
            '🐉 BOSS RAID',
            style: TextStyle(
              color: widget.boss.element.color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: widget.boss.element.color,
                  blurRadius: 20,
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.home_filled, color: Colors.redAccent),
            tooltip: '강제 닫기',
            onPressed: _forceExitToHome,
          ),
        ],
      ),
    );
  }

  Widget _buildBattleArea() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 보스 HP 바 (애니메이션 적용)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      widget.boss.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_bossHp.toInt()} / $_maxBossHp',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // HP바 애니메이션 (이펙트 #5)
                Stack(
                  children: [
                    // 배경
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    // 지연 HP (빨간색)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 24,
                      width: (MediaQuery.of(context).size.width - 64) * 
                             (_displayedBossHp / _maxBossHp).clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    // 실제 HP
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 24,
                      width: (MediaQuery.of(context).size.width - 64) * 
                             (_bossHp / _maxBossHp).clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.boss.element.color,
                            widget.boss.element.color.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: widget.boss.element.color.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ✅ 보스 이미지 (모션 애니메이션 적용)
          AnimatedBuilder(
            animation: Listenable.merge([
              _bossIdleAnimation,
              _bossFloatAnimation,
              _bossElementAnimation,
            ]),
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  _getElementOffsetX(),  // 원소별 X 움직임
                  _bossFloatAnimation.value + _getElementOffsetY(),  // 떠다니기 + 원소별 Y
                ),
                child: Transform.scale(
                  scale: _bossIdleAnimation.value * _getElementScale(),  // 숨쉬기 + 원소별 스케일
                  child: Transform.rotate(
                    angle: _getElementRotation(),  // 원소별 회전
                    child: child,
                  ),
                ),
              );
            },
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.boss.element.color,
                    widget.boss.element.color.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.boss.element.color.withOpacity(0.6),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: widget.boss.hasImage
                    ? ClipOval(
                        child: Image.asset(
                          widget.boss.imagePath!,
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // 이미지 로드 실패 시 이모지 표시
                            return Text(
                              widget.boss.element.emoji,
                              style: const TextStyle(fontSize: 80),
                            );
                          },
                        ),
                      )
                    : Text(
                        widget.boss.element.emoji,
                        style: const TextStyle(fontSize: 80),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            'ATK: ${widget.boss.atk}',
            style: TextStyle(
              color: widget.boss.element.color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  // ============================================================
  // ✅ 원소별 모션 효과 계산
  // ============================================================
  
  // 원소별 X축 움직임
  double _getElementOffsetX() {
    final value = _bossElementAnimation.value;
    switch (widget.boss.element) {
      case GameElement.fire:
        // 불: 좌우 빠른 흔들림
        return (value - 0.5) * 12;
      case GameElement.water:
        // 물: 부드러운 좌우 물결
        return sin(value * 2 * pi) * 6;
      case GameElement.nature:
        // 자연: 바람에 흔들리는 듯한 움직임
        return sin(value * pi) * 4;
      case GameElement.light:
        // 빛: 미세한 떨림
        return (Random().nextDouble() - 0.5) * 2;
      case GameElement.dark:
        // 어둠: 느린 좌우 이동
        return sin(value * pi) * 8;
    }
  }
  
  // 원소별 Y축 움직임
  double _getElementOffsetY() {
    final value = _bossElementAnimation.value;
    switch (widget.boss.element) {
      case GameElement.fire:
        // 불: 위로 타오르는 느낌
        return -value * 4;
      case GameElement.water:
        // 물: 출렁이는 느낌
        return cos(value * 2 * pi) * 4;
      case GameElement.nature:
        // 자연: 부드러운 상하
        return 0;
      case GameElement.light:
        // 빛: 미세한 떨림
        return (Random().nextDouble() - 0.5) * 2;
      case GameElement.dark:
        // 어둠: 느린 상하
        return cos(value * pi) * 3;
    }
  }
  
  // 원소별 스케일 변화
  double _getElementScale() {
    final value = _bossElementAnimation.value;
    switch (widget.boss.element) {
      case GameElement.fire:
        // 불: 펄스하는 느낌
        return 1.0 + (value - 0.5).abs() * 0.1;
      case GameElement.water:
        // 물: 부드러운 스케일
        return 1.0 + sin(value * pi) * 0.03;
      case GameElement.nature:
        // 자연: 호흡하는 느낌
        return 1.0 + sin(value * pi) * 0.02;
      case GameElement.light:
        // 빛: 깜빡이는 스케일
        return 1.0 + (value > 0.5 ? 0.08 : 0);
      case GameElement.dark:
        // 어둠: 천천히 커졌다 작아지는
        return 1.0 + sin(value * pi) * 0.05;
    }
  }
  
  // 원소별 회전
  double _getElementRotation() {
    final value = _bossElementAnimation.value;
    switch (widget.boss.element) {
      case GameElement.fire:
        // 불: 미세한 회전
        return (value - 0.5) * 0.1;
      case GameElement.water:
        // 물: 흔들리는 회전
        return sin(value * 2 * pi) * 0.05;
      case GameElement.nature:
        // 자연: 바람에 흔들림
        return sin(value * pi) * 0.08;
      case GameElement.light:
        // 빛: 회전 없음
        return 0;
      case GameElement.dark:
        // 어둠: 느린 회전
        return sin(value * pi) * 0.1;
    }
  }

  Widget _buildBattleLog() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListView.builder(
        controller: _logScrollController,
        itemCount: _battleLog.length,
        itemBuilder: (context, index) {
          final log = _battleLog[index];
          Color textColor = Colors.white70;
          
          if (log.contains('승리')) textColor = Colors.green;
          if (log.contains('패배')) textColor = Colors.red;
          if (log.contains('💥')) textColor = Colors.amber;
          if (log.contains('크리티컬')) textColor = Colors.yellow;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              log,
              style: TextStyle(color: textColor, fontSize: 12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayerArea() {
    final sword = widget.playerSword;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sword.data.grade.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sword.data.grade.color),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 🗡️ 검 이미지 위젯 사용
              SwordImageWidget(
                grade: sword.data.grade,
                element: sword.data.element,
                level: sword.level,
                size: 56,
                showPulse: true,
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
                    Row(
                      children: [
                        Text(
                          sword.data.element.emoji,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '전투력: ${widget.playerPower}',
                          style: const TextStyle(color: Colors.amber),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 플레이어 HP 바 (애니메이션 적용)
          Row(
            children: [
              const Text('HP', style: TextStyle(color: Colors.white54)),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    // 지연 HP
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 16,
                      width: (MediaQuery.of(context).size.width - 150) * 
                             (_displayedPlayerHp / _maxPlayerHp).clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    // 실제 HP
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 16,
                      width: (MediaQuery.of(context).size.width - 150) * 
                             (_playerHp / _maxPlayerHp).clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _playerHp > _maxPlayerHp * 0.3 
                              ? [Colors.green, Colors.lightGreen]
                              : [Colors.red, Colors.orange],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: (_playerHp > _maxPlayerHp * 0.3 
                                ? Colors.green 
                                : Colors.red).withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_playerHp.toInt()}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: _battleEnded
            ? _buildResultDisplay()
            : _battleStarted
                ? _buildBattleStatus()
                : _buildStartButton(),
      ),
    );
  }

  Widget _buildStartButton() {
    return ElevatedButton(
      onPressed: _bossEntranceComplete ? _startBattle : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.boss.element.color,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_arrow, color: Colors.white, size: 28),
          SizedBox(width: 8),
          Text(
            '전투 시작!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.boss.element.color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '전투 중... (턴 $_turn/50)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultDisplay() {
    return AnimatedBuilder(
      animation: _isWin ? _victoryAnimation : _defeatAnimation,
      builder: (context, _) {
        final scale = _isWin 
            ? 0.5 + _victoryAnimation.value * 0.5
            : 1.0;
        
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: _isWin
                  ? Colors.green.withOpacity(0.3)
                  : Colors.red.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isWin ? Colors.green : Colors.red,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isWin ? Colors.green : Colors.red).withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  _isWin ? '🎉 승리!' : '💀 패배',
                  style: TextStyle(
                    color: _isWin ? Colors.green : Colors.red,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isWin) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+${widget.boss.goldReward}G  +${widget.boss.diamondReward}💎',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// 파티클 페인터 (이펙트 #4)
// ============================================================
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  
  _ParticlePainter({required this.particles});
  
  @override
  void paint(Canvas canvas, Size size) {
    // size가 유효하지 않으면 그리지 않음
    if (size.width <= 0 || size.height <= 0 || 
        !size.width.isFinite || !size.height.isFinite) {
      return;
    }
    
    for (final p in particles) {
      final safeOpacity = p.opacity.clamp(0.0, 1.0);
      if (safeOpacity <= 0) continue;
      
      final safeSize = (p.size * safeOpacity).clamp(0.1, 100.0);
      if (safeSize <= 0 || !safeSize.isFinite) continue;
      
      final paint = Paint()
        ..color = p.color.withOpacity(safeOpacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(p.x, p.y), safeSize, paint);
      
      // 글로우 효과
      final glowOpacity = (safeOpacity * 0.3).clamp(0.0, 1.0);
      if (glowOpacity > 0) {
        final glowPaint = Paint()
          ..color = p.color.withOpacity(glowOpacity)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        
        canvas.drawCircle(Offset(p.x, p.y), (safeSize * 1.5).clamp(0.1, 150.0), glowPaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================
// 원소 배경 페인터 (이펙트 #7)
// ============================================================
class _ElementBackgroundPainter extends CustomPainter {
  final GameElement element;
  final double progress;
  
  _ElementBackgroundPainter({required this.element, required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    // size가 유효하지 않으면 그리지 않음
    if (size.width <= 0 || size.height <= 0 || 
        !size.width.isFinite || !size.height.isFinite) {
      return;
    }
    
    final paint = Paint()
      ..style = PaintingStyle.fill;
    
    switch (element) {
      case GameElement.fire:
        _drawFireEffect(canvas, size, paint);
        break;
      case GameElement.water:
        _drawWaterEffect(canvas, size, paint);
        break;
      case GameElement.nature:
        _drawNatureEffect(canvas, size, paint);
        break;
      case GameElement.light:
        _drawLightEffect(canvas, size, paint);
        break;
      case GameElement.dark:
        _drawDarkEffect(canvas, size, paint);
        break;
    }
  }
  
  void _drawFireEffect(Canvas canvas, Size size, Paint paint) {
    // 불꽃 파티클
    for (int i = 0; i < 10; i++) {
      final x = (size.width * (0.1 + i * 0.08) + sin(progress * 2 * pi + i) * 20);
      final y = size.height * 0.8 - (progress + i * 0.1) % 1 * size.height * 0.3;
      final radius = (5.0 + sin(progress * 4 * pi + i) * 3).clamp(1.0, 20.0);
      
      paint.color = Colors.orange.withOpacity(0.3);
      canvas.drawCircle(Offset(x, y), radius * 2, paint);
      paint.color = Colors.red.withOpacity(0.5);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }
  
  void _drawWaterEffect(Canvas canvas, Size size, Paint paint) {
    // 물결 효과
    final path = Path();
    for (double x = 0; x <= size.width; x += 10) {
      final y = size.height * 0.85 + sin(x * 0.02 + progress * 2 * pi) * 15;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    paint.color = Colors.blue.withOpacity(0.15);
    canvas.drawPath(path, paint);
  }
  
  void _drawNatureEffect(Canvas canvas, Size size, Paint paint) {
    // 나뭇잎 파티클
    for (int i = 0; i < 8; i++) {
      final x = (size.width * (0.1 + i * 0.12) + sin(progress * 2 * pi + i * 0.5) * 30);
      final y = (progress * size.height + i * 50) % size.height;
      
      paint.color = Colors.green.withOpacity(0.4);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 2 * pi + i);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 8, height: 12),
        paint,
      );
      canvas.restore();
    }
  }
  
  void _drawLightEffect(Canvas canvas, Size size, Paint paint) {
    // 빛줄기
    for (int i = 0; i < 5; i++) {
      final startX = size.width * (0.2 + i * 0.15);
      final opacity = (0.1 + sin(progress * 2 * pi + i) * 0.05).clamp(0.0, 1.0);
      
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.amber.withOpacity(opacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(startX - 20, 0, 40, size.height * 0.6));
      
      canvas.drawRect(
        Rect.fromLTWH(startX - 20, 0, 40, size.height * 0.6),
        paint,
      );
    }
  }
  
  void _drawDarkEffect(Canvas canvas, Size size, Paint paint) {
    // 어둠 파티클
    for (int i = 0; i < 12; i++) {
      final x = (size.width * (i / 12) + sin(progress * 2 * pi + i) * 20) % size.width;
      final y = (size.height * (0.2 + (i % 3) * 0.2) + cos(progress * 2 * pi + i) * 20);
      final radius = (20.0 + sin(progress * 4 * pi + i) * 10).clamp(1.0, 50.0);
      
      paint.color = Colors.purple.withOpacity(0.1);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
    paint.maskFilter = null;
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
