// lib/screens/minigame/brick_breaker_game.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../enums/element.dart';
import '../../enums/sword_grade.dart';
import '../../models/owned_sword.dart';
import 'minigame_models.dart';

class BrickBreakerGame extends ChangeNotifier {
  // ─────────────────────────────────────────
  // 상수
  // ─────────────────────────────────────────
  static const int maxLives = 3;
  static const int maxShields = 3;
  static const double swordY = 0.88;
  static const double swordHalfWidth = 0.13;
  static const double dangerY = 0.96;
  static const double baseAttackInterval = 0.5; // 기본 공격 주기(초)

  // 콤보
  static const double comboResetTime = 2.5;
  static const int maxComboMult = 4;

  // 직전 막기
  static const double lastStandZone = 0.78;
  static const double lastStandDmgMult = 5.0;
  static const int lastStandMaxUses = 3; // 웨이브당 최대 사용 횟수
  static const double lastStandCooldownTime = 5.0; // 쿨다운(초)

  // 분노 게이지
  static const double rageDuration = 5.0; // 분노 지속(초)
  static const double rageDamageMult = 3.0; // 분노 시 데미지 배율

  // 필살기 (시간 정지)
  static const double ultimateDuration = 6.0; // 얼림 지속(초)

  // 크리티컬
  static const double critBaseDmgMult = 3.0;
  static const double cursedBrickTimer = 8.0;

  // 속성 체인
  static const int elementChainThreshold = 3; // 연속 N번이면 폭발

  // ─────────────────────────────────────────
  // 상태
  // ─────────────────────────────────────────
  final OwnedSword sword;

  // 발사 시 호출되는 콜백 (효과음 연결용)
  VoidCallback? onShoot;

  List<Brick> bricks = [];
  List<Projectile> projectiles = [];
  List<AttackEffect> effects = [];
  List<PowerUpItem> powerUps = [];

  int wave = 1;
  int lives = maxLives;
  int score = 0;
  int bricksDestroyed = 0;
  int playerShield = 0;
  double swordX = 0.5;
  double swordVelocity = 0.0;

  bool isRunning = false;
  bool isGameOver = false;
  bool isPaused = false;

  // 콤보
  int combo = 0;
  double comboTimer = 0;

  // 콤보 폭발 (한 번 달성하면 탭할 때까지 유지)
  bool _burstReady = false;
  bool get canBurst => _burstReady && isRunning && !isGameOver;

  // 속성 체인
  GameElement? lastDestroyedElement;
  int elementChain = 0;

  // 활성 파워업
  final Set<PowerUpType> activePowerUps = <PowerUpType>{};

  // 직전 막기 제한
  double _lastStandCooldown = 0.0;
  int _lastStandUsesThisWave = 0;
  double get lastStandCooldown => _lastStandCooldown;
  int get lastStandUsesThisWave => _lastStandUsesThisWave;
  bool get canLastStand =>
      _lastStandCooldown <= 0 && _lastStandUsesThisWave < lastStandMaxUses;

  // 분노 게이지
  double rageGauge = 0.0; // 0.0~1.0
  bool isRaging = false;
  double rageTimer = 0.0;

  // 웨이브 클리어 누적 공격력 보너스
  double waveDamageBonus = 1.0; // 클리어마다 +0.05, 최대 1.5

  // 필살기 게이지
  // 필살기 (시간 정지)
  double ultimateGauge = 0.0; // 0.0~1.0
  bool _ultimateReady = false;
  bool isTimeFrozen = false; // 벽돌 이동 정지 중
  double freezeTimer = 0.0;
  bool get canUltimate => _ultimateReady && isRunning && !isGameOver;
  WaveEventType? currentWaveEvent;
  final List<WaveRewardType> pendingRewardChoices = [];
  bool get needsRewardChoice => pendingRewardChoices.isNotEmpty;
  double rewardAttackSpeedMult = 1.0;
  double rewardDamageMult = 1.0;
  bool _miniBossSpawnedThisWave = false;

  // 실드 쿨다운
  double _shieldCooldown = 0;

  // 내부
  double _attackCooldown = 0;
  double _spawnTimer = 0;
  int _bricksLeft = 0;
  double _waveTransitionTimer = -1;

  DateTime _lastTick = DateTime.now();
  int _idCounter = 0;
  final Random _rng = Random();

  BrickBreakerGame({required this.sword});

  String _nextId() => '${_idCounter++}';

  // 현재 공격 쿨다운 (속공 파워업 적용)
  double get _currentAttackInterval {
    double interval = baseAttackInterval;
    if (activePowerUps.contains(PowerUpType.rapid)) interval *= 0.75;
    if (isTimeFrozen) interval *= 0.5; // 시간 정지 중 공격속도 2배
    if (currentWaveEvent == WaveEventType.frost) interval *= 1.15;
    interval *= rewardAttackSpeedMult;
    return interval;
  }

  // 현재 대미지 배율 (강타 파워업 + 콤보)
  double get _damageMult {
    double m = comboMultiplier;
    if (activePowerUps.contains(PowerUpType.power)) m *= 1.5;
    if (isRaging) m *= rageDamageMult;
    m *= waveDamageBonus;
    m *= rewardDamageMult;
    return m;
  }

  double get comboMultiplier {
    if (combo <= 0) return 1.0;
    if (combo < 5) return 1.0;
    if (combo < 10) return 1.5;
    if (combo < 20) return 2.0;
    if (combo < 30) return 3.0;
    return 4.0;
  }

  // ─────────────────────────────────────────
  // 공개 API
  // ─────────────────────────────────────────

  void start() {
    isRunning = true;
    isGameOver = false;
    wave = 1;
    lives = maxLives;
    score = 0;
    bricksDestroyed = 0;
    playerShield = 0;
    swordX = 0.5;
    combo = 0;
    comboTimer = 0;
    lastDestroyedElement = null;
    elementChain = 0;
    activePowerUps.clear();
    bricks.clear();
    projectiles.clear();
    effects.clear();
    powerUps.clear();
    _attackCooldown = 0;
    _shieldCooldown = 0;
    _waveTransitionTimer = -1;
    _burstReady = false;
    _lastStandCooldown = 0.0;
    rageGauge = 0.0;
    isRaging = false;
    rageTimer = 0.0;
    waveDamageBonus = 1.0;
    ultimateGauge = 0.0;
    _ultimateReady = false;
    isTimeFrozen = false;
    freezeTimer = 0.0;
    currentWaveEvent = null;
    pendingRewardChoices.clear();
    rewardAttackSpeedMult = 1.0;
    rewardDamageMult = 1.0;
    _miniBossSpawnedThisWave = false;
    _startWave();
    _lastTick = DateTime.now();
    notifyListeners();
  }

  void moveSword(double dxRatio) {
    swordVelocity = dxRatio;
    swordX = (swordX + dxRatio).clamp(0.05, 0.95);
    notifyListeners();
  }

  void tick() {
    if (!isRunning || isGameOver || isPaused) return;

    final now = DateTime.now();
    final dt = (now.difference(_lastTick).inMilliseconds / 1000.0).clamp(
      0.001,
      0.1,
    );
    _lastTick = now;

    _spawnTick(dt);
    _moveBricks(dt);
    _updateRelayLinks();
    _checkLastStandFlash();
    _moveProjectiles(dt);
    _checkProjectileCollisions();
    _checkPowerUpCollisions();
    _checkDangerZone();
    _tickHealerBricks();
    _tickCursedBricks(dt);
    _tickEffects();
    _tickAttack(dt);
    _tickTimers(dt);

    swordVelocity *= 0.75;

    // 웨이브 클리어
    if (_bricksLeft <= 0 &&
        bricks.isEmpty &&
        _waveTransitionTimer < 0 &&
        !needsRewardChoice) {
      _waveTransitionTimer = -2;
      _addEffect(0.5, 0.45, '웨이브 $wave 클리어!', Colors.amber, ttl: 90);
      if (wave % 3 == 0) {
        pendingRewardChoices
          ..clear()
          ..addAll(_rollRewardChoices());
        isPaused = true;
      } else {
        _waveTransitionTimer = 1.1;
      }
    }
    if (_waveTransitionTimer >= 0) {
      _waveTransitionTimer -= dt;
      if (_waveTransitionTimer < 0) {
        wave++;
        _startWave();
      }
    }

    notifyListeners();
  }

  void togglePause() {
    if (needsRewardChoice) return;
    isPaused = !isPaused;
    if (!isPaused) _lastTick = DateTime.now();
    notifyListeners();
  }

  void chooseWaveReward(WaveRewardType reward) {
    if (!pendingRewardChoices.contains(reward)) return;

    switch (reward) {
      case WaveRewardType.sharpen:
        rewardDamageMult = (rewardDamageMult + 0.08).clamp(1.0, 1.6);
        _addEffect(0.5, 0.40, '⚔️ 칼날 연마', Colors.orangeAccent, ttl: 70);
        break;
      case WaveRewardType.overclock:
        rewardAttackSpeedMult = (rewardAttackSpeedMult * 0.94).clamp(0.75, 1.0);
        _addEffect(0.5, 0.40, '⚡ 과속 회로', Colors.yellowAccent, ttl: 70);
        break;
      case WaveRewardType.safeguard:
        playerShield = (playerShield + 1).clamp(0, maxShields);
        _addEffect(0.5, 0.40, '🛡️ 보호막 장치', Colors.greenAccent, ttl: 70);
        break;
    }

    waveDamageBonus = (waveDamageBonus + 0.04).clamp(1.0, 1.4);
    pendingRewardChoices.clear();
    isPaused = false;
    wave++;
    _startWave();
    _lastTick = DateTime.now();
    notifyListeners();
  }

  List<WaveRewardType> _rollRewardChoices() {
    final pool = WaveRewardType.values.toList()..shuffle(_rng);
    return pool.take(3).toList();
  }

  // ─────────────────────────────────────────
  // [기믹 1] 직전 막기 — 탭 시 호출
  // ─────────────────────────────────────────

  void tryLastStand() {
    // 쿨다운 / 횟수 초과 시 안내만
    if (_lastStandCooldown > 0) {
      _addEffect(
        swordX,
        swordY - 0.1,
        '쿨다운 ${_lastStandCooldown.toStringAsFixed(1)}s',
        Colors.grey,
      );
      notifyListeners();
      return;
    }
    if (_lastStandUsesThisWave >= lastStandMaxUses) {
      _addEffect(swordX, swordY - 0.1, '이번 웨이브 사용 불가', Colors.grey);
      notifyListeners();
      return;
    }

    // 검 근처의 반짝이는 벽돌만 타격 (범위: 화면 너비 30%)
    final targets = bricks
        .where(
          (b) =>
              !b.isDead &&
              b.isFlashing &&
              (b.x - swordX).abs() < swordHalfWidth + 0.30,
        )
        .toList();

    if (targets.isEmpty) return;

    int hitCount = 0;
    for (final b in targets) {
      final dmg = _dealDamage(
        b,
        (sword.totalPower * lastStandDmgMult).round(),
        hitX: swordX,
      );
      _addEffect(b.x, b.y - 0.06, '⚡직전막기! $dmg', Colors.yellowAccent, ttl: 60);
      hitCount++;
    }

    if (hitCount > 0) {
      playerShield = (playerShield + 1).clamp(0, maxShields);
      combo += hitCount;
      comboTimer = comboResetTime;
      _lastStandCooldown = lastStandCooldownTime;
      _lastStandUsesThisWave++;
    }

    bricks.removeWhere((b) => b.isDead);
    notifyListeners();
  }

  void _checkLastStandFlash() {
    for (final b in bricks) {
      b.isFlashing = !b.isDead && b.y >= lastStandZone;
    }
  }

  // ─────────────────────────────────────────
  // [기믹 2] 콤보 폭발 — 버튼 탭 시 호출
  // ─────────────────────────────────────────

  void triggerBurst() {
    if (!canBurst) return;

    final burstDmg = (sword.totalPower * comboMultiplier * 3).round();
    final snapBricks = bricks.toList();

    for (final b in snapBricks) {
      if (!b.isDead) {
        _dealDamage(b, burstDmg, hitX: 0.5);
        _addEffect(b.x, b.y, '💥$burstDmg', Colors.deepOrange, ttl: 50);
      }
    }

    _addEffect(
      0.5,
      0.4,
      '💥 콤보 폭발! x${comboMultiplier.toStringAsFixed(1)}',
      Colors.orange,
      ttl: 80,
    );

    score += combo * 5;
    combo = 0;
    comboTimer = 0;
    _burstReady = false; // 사용 시에만 리셋

    bricks.removeWhere((b) => b.isDead);
    notifyListeners();
  }

  // ─────────────────────────────────────────
  // [기믹 5] 필살기 — 버튼 탭 시 호출
  // ─────────────────────────────────────────

  // 필살기: 벽돌 이동 6초 정지, 그동안 공격 속도 2배
  void triggerUltimate() {
    if (!canUltimate) return;
    isTimeFrozen = true;
    freezeTimer = ultimateDuration;
    ultimateGauge = 0.0;
    _ultimateReady = false;
    _addEffect(
      0.5,
      0.38,
      '⏱ 시간 정지! ${ultimateDuration.toStringAsFixed(0)}초',
      Colors.cyanAccent,
      ttl: 90,
    );
    notifyListeners();
  }

  // ─────────────────────────────────────────
  // [기믹 3] 속성 체인 — _onDestroyed에서 호출
  // ─────────────────────────────────────────

  void _checkElementChain(GameElement element) {
    if (lastDestroyedElement == element) {
      elementChain++;
    } else {
      elementChain = 1;
      lastDestroyedElement = element;
    }

    if (elementChain >= elementChainThreshold) {
      _triggerElementExplosion(element);
      elementChain = 0;
      lastDestroyedElement = null;
    }
  }

  void _triggerElementExplosion(GameElement element) {
    final targets = bricks
        .where((b) => !b.isDead && b.element == element)
        .toList();
    if (targets.isEmpty) return;

    final chainDmg = (sword.totalPower * 2.5).round();
    for (final b in targets) {
      _dealDamage(b, chainDmg, hitX: b.x);
      _addEffect(b.x, b.y, '${element.emoji}체인!', element.color, ttl: 50);
    }
    _addEffect(
      0.5,
      0.35,
      '${element.emoji} ${element.nameKr} 속성 폭발!',
      element.color,
      ttl: 70,
    );

    bricks.removeWhere((b) => b.isDead);
  }

  // ─────────────────────────────────────────
  // [기믹 4] 분노 게이지
  // ─────────────────────────────────────────

  void _activateRage() {
    isRaging = true;
    rageTimer = rageDuration;
    rageGauge = 0.0;
    // 분노 발동 시 필살기 게이지도 소폭 충전
    ultimateGauge = (ultimateGauge + 0.25).clamp(0.0, 1.0);
    if (ultimateGauge >= 1.0 && !_ultimateReady) {
      _ultimateReady = true;
      _addEffect(0.5, 0.42, '⚔️ 필살기 준비!', Colors.white, ttl: 60);
    }
    _addEffect(
      0.5,
      0.45,
      '😤 분노! 공격력 x${rageDamageMult.toStringAsFixed(0)}',
      Colors.redAccent,
      ttl: 80,
    );
  }

  // ─────────────────────────────────────────
  // 타이머 틱
  // ─────────────────────────────────────────

  void _tickTimers(double dt) {
    // 콤보 리셋 타이머
    if (combo > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) {
        combo = 0;
        comboTimer = 0;
      }
    }

    // 직전 막기 쿨다운
    if (_lastStandCooldown > 0) _lastStandCooldown -= dt;

    // 시간 정지 타이머
    if (isTimeFrozen) {
      freezeTimer -= dt;
      if (freezeTimer <= 0) {
        isTimeFrozen = false;
        _addEffect(0.5, 0.45, '⏱ 시간 재개', Colors.cyanAccent);
      }
    }

    // 분노 타이머
    if (isRaging) {
      rageTimer -= dt;
      if (rageTimer <= 0) {
        isRaging = false;
        _addEffect(swordX, swordY - 0.08, '😤 분노 종료', Colors.red.shade300);
      }
    }

    // 실드 쿨다운
    if (_shieldCooldown > 0) _shieldCooldown -= dt;
  }

  // ─────────────────────────────────────────
  // 웨이브
  // ─────────────────────────────────────────

  void _startWave() {
    _bricksLeft = _waveBrickCount(wave);
    _spawnTimer = 0;
    _waveTransitionTimer = -1;
    _lastStandUsesThisWave = 0; // 웨이브마다 직전 막기 횟수 리셋
    _miniBossSpawnedThisWave = false;
    currentWaveEvent = wave == 1
        ? null
        : WaveEventType.values[_rng.nextInt(WaveEventType.values.length)];
    if (currentWaveEvent != null) {
      _addEffect(
        0.5,
        0.30,
        '${currentWaveEvent!.emoji} ${currentWaveEvent!.label}',
        currentWaveEvent!.color,
        ttl: 90,
      );
    }
  }

  int _waveBrickCount(int wave) => 6 + wave * 3;

  double _spawnInterval(int wave) => (1.35 - wave * 0.09).clamp(0.28, 1.35);

  void _spawnTick(double dt) {
    if (_bricksLeft <= 0) return;
    _spawnTimer -= dt;
    if (_spawnTimer > 0) return;
    _spawnTimer = _spawnInterval(wave);

    var x = 0.08 + _rng.nextDouble() * 0.84;
    final y = -0.05 - _rng.nextDouble() * 0.08;
    final bossWave = wave % 10 == 0;
    BrickType type;
    if (wave >= 5 && wave % 5 == 0 && !_miniBossSpawnedThisWave) {
      type = BrickType.miniBoss;
      x = 0.5;
      _miniBossSpawnedThisWave = true;
    } else {
      type = _pickBrickType(bossWave);
    }
    final element = GameElement.values[_rng.nextInt(GameElement.values.length)];

    bricks.add(
      Brick(
        id: _nextId(),
        type: type,
        element: element,
        maxHp: _calcBrickHp(type),
        x: x,
        y: y,
        isShielded: type == BrickType.armored,
        moveDir: _rng.nextBool() ? 1 : -1,
        gimmickTimer: type == BrickType.cursed ? cursedBrickTimer : 0.0,
      ),
    );
    _bricksLeft--;
  }

  BrickType _pickBrickType(bool bossWave) {
    if (bossWave && _rng.nextDouble() < 0.2) return BrickType.boss;
    if (wave < 3) return BrickType.normal;
    final r = _rng.nextDouble();
    if (wave >= 7 && r < 0.05) return BrickType.cursed;
    if (wave >= 6 && r < 0.11) return BrickType.relay;
    if (wave >= 5 && r < 0.18) return BrickType.core;
    if (wave >= 5 && r < 0.24) return BrickType.healer;
    if (wave >= 4 && r < 0.29) return BrickType.splitter;
    if (wave >= 4 && r < 0.38) return BrickType.explosive;
    if (wave >= 3 && r < 0.50) return BrickType.armored;
    return BrickType.normal;
  }

  int _calcBrickHp(BrickType type) {
    final base = switch (type) {
      BrickType.normal => 1000,
      BrickType.armored => 2000,
      BrickType.explosive => 800,
      BrickType.healer => 1600,
      BrickType.splitter => 1300,
      BrickType.core => 2600,
      BrickType.relay => 2200,
      BrickType.cursed => 1800,
      BrickType.miniBoss => 11000,
      BrickType.boss => 7000,
    };
    final scaled = (base * (1 + (wave - 1) * 0.55)).round();
    if (type == BrickType.miniBoss) return (scaled * 1.35).round();
    if (type == BrickType.boss) return (scaled * 1.5).round();
    return scaled;
  }

  void _updateRelayLinks() {
    for (final b in bricks) {
      b.isLinkedShielded = false;
    }
    for (final relay in bricks.where(
      (b) => !b.isDead && b.type == BrickType.relay,
    )) {
      for (final target in bricks) {
        if (target.isDead || target == relay || target.type == BrickType.relay)
          continue;
        if ((target.x - relay.x).abs() < 0.22 &&
            (target.y - relay.y).abs() < 0.13) {
          target.isLinkedShielded = true;
        }
      }
    }
  }

  // ─────────────────────────────────────────
  // 벽돌 이동
  // ─────────────────────────────────────────

  void _moveBricks(double dt) {
    if (isTimeFrozen) return; // 시간 정지 중 이동 없음
    final speed = 0.18 + (wave - 1) * 0.028;
    for (final b in bricks) {
      double eventSpeed = 1.0;
      if (currentWaveEvent == WaveEventType.tempest) eventSpeed = 1.28;
      if (currentWaveEvent == WaveEventType.frost) eventSpeed = 0.82;
      b.y += speed * dt * eventSpeed;
      if (b.type == BrickType.boss || b.type == BrickType.miniBoss) {
        b.x += b.moveDir * (b.type == BrickType.miniBoss ? 0.32 : 0.24) * dt;
        if (b.x > 0.92 || b.x < 0.08) b.moveDir *= -1;
      }
    }
  }

  // ─────────────────────────────────────────
  // 투사체 발사
  // ─────────────────────────────────────────

  void _tickAttack(double dt) {
    _attackCooldown -= dt;
    if (_attackCooldown > 0) return;
    _attackCooldown = _currentAttackInterval;
    onShoot?.call();

    final skillType = sword.data.primarySkillType;
    final kind = skillType.projectileKind;
    final firstSkill = sword.data.skills.isNotEmpty
        ? sword.data.skills.first
        : null;
    final skillProc =
        firstSkill != null && _rng.nextInt(100) < firstSkill.procRate;
    final velBonus = 1.0 + (swordVelocity.abs() * 2).clamp(0.0, 0.4);
    final baseDmg = (sword.totalPower * velBonus * _damageMult).round();
    final spreadMult = currentWaveEvent == WaveEventType.tempest ? 1.25 : 1.0;

    // 다발 파워업: 발사 수 2배
    final isMulti = activePowerUps.contains(PowerUpType.multiShot);

    switch (kind) {
      case ProjectileKind.slash:
        final offsets =
            (isMulti ? [-0.18, -0.09, 0.0, 0.09, 0.18] : [-0.12, 0.0, 0.12])
                .map((v) => v * spreadMult)
                .toList();
        final shotDamage = isMulti
            ? (skillProc ? (baseDmg * 0.85).round() : (baseDmg * 0.65).round())
            : (skillProc ? (baseDmg * 1.3).round() : baseDmg);
        for (final dx in offsets) {
          _fireProjectile(
            kind,
            swordX,
            swordY - 0.02,
            damage: shotDamage,
            dx: dx,
          );
        }
      case ProjectileKind.pierce:
        final count = isMulti ? 4 : (skillProc ? 3 : 1);
        final shotDamage = isMulti ? (baseDmg * 0.7).round() : baseDmg;
        for (int i = 0; i < count; i++) {
          final delay = i * 100;
          if (delay == 0) {
            _fireProjectile(kind, swordX, swordY - 0.02, damage: shotDamage);
          } else {
            Future.delayed(Duration(milliseconds: delay), () {
              if (isRunning)
                _fireProjectile(
                  kind,
                  swordX,
                  swordY - 0.02,
                  damage: shotDamage,
                );
            });
          }
        }
      case ProjectileKind.blast:
        final count = isMulti ? 3 : 1;
        final shotDamage = isMulti
            ? (skillProc ? (baseDmg * 1.1).round() : (baseDmg * 0.75).round())
            : (skillProc ? (baseDmg * 1.8).round() : (baseDmg * 1.3).round());
        for (int i = 0; i < count; i++) {
          _fireProjectile(
            kind,
            swordX + (i - 1) * 0.1 * spreadMult,
            swordY - 0.02,
            damage: shotDamage,
          );
        }
      case ProjectileKind.drain:
        final count = isMulti ? 3 : 1;
        final shotDamage = isMulti ? (baseDmg * 0.7).round() : baseDmg;
        for (int i = 0; i < count; i++) {
          _fireProjectile(
            kind,
            swordX + (i - 1) * 0.08,
            swordY - 0.02,
            damage: shotDamage,
          );
        }
      case ProjectileKind.guard:
        final offsets =
            (isMulti ? [-0.16, -0.08, 0.0, 0.08, 0.16] : [-0.08, 0.08])
                .map((v) => v * spreadMult)
                .toList();
        final shotDamage = isMulti ? (baseDmg * 0.65).round() : baseDmg;
        for (final dx in offsets) {
          _fireProjectile(kind, swordX + dx, swordY - 0.02, damage: shotDamage);
        }
        if (skillProc && _shieldCooldown <= 0) {
          playerShield = (playerShield + 1).clamp(0, maxShields);
          _shieldCooldown = 4.0;
          _addEffect(swordX, swordY - 0.08, '🛡️+1', Colors.cyan);
        }
      case ProjectileKind.fragment:
        break; // 파편은 직접 발사하지 않음
    }
  }

  void _fireProjectile(
    ProjectileKind kind,
    double x,
    double y, {
    required int damage,
    double dx = 0,
    double? dy,
  }) {
    projectiles.add(
      Projectile(
        id: _nextId(),
        kind: kind,
        x: x.clamp(0.0, 1.0),
        y: y,
        damage: damage,
        dx: dx,
        dy: dy,
      ),
    );
  }

  // ─────────────────────────────────────────
  // 투사체 이동
  // ─────────────────────────────────────────

  void _moveProjectiles(double dt) {
    for (final p in projectiles) {
      p.y += p.dy * dt;
      p.x += p.dx * dt;
    }
    projectiles.removeWhere(
      (p) => p.isDead || p.y < -0.1 || p.x < -0.1 || p.x > 1.1,
    );
  }

  // ─────────────────────────────────────────
  // 충돌 처리
  // ─────────────────────────────────────────

  void _checkProjectileCollisions() {
    // 스냅샷으로 순회 — 루프 도중 리스트 수정 방지
    final snapProj = projectiles.toList();
    final snapBricks = bricks.toList();

    for (final p in snapProj) {
      if (p.isDead) continue;
      for (final b in snapBricks) {
        if (b.isDead || !_overlaps(p, b)) continue;

        final dmg = _dealDamage(b, p.damage, hitX: p.x);

        if (p.kind == ProjectileKind.blast) {
          // blast 스플래시도 스냅샷으로
          for (final nb in snapBricks) {
            if (!nb.isDead &&
                nb != b &&
                (nb.x - b.x).abs() < 0.22 &&
                (nb.y - b.y).abs() < 0.12) {
              _dealDamage(nb, (p.damage * 0.6).round(), hitX: p.x);
            }
          }
        }

        // drain: 실드 생성 (쿨다운)
        if (p.kind == ProjectileKind.drain && _shieldCooldown <= 0) {
          playerShield = (playerShield + 1).clamp(0, maxShields);
          _shieldCooldown = 4.0;
          _addEffect(swordX, swordY - 0.08, '🛡️+1', Colors.cyan);
        }

        _addEffect(b.x, b.y, '$dmg', _effectColor(p.kind));

        if (!p.kind.isPiercing) {
          p.isDead = true;
          break;
        }
      }
    }
    // 루프가 끝난 뒤에 한 번만 정리
    projectiles.removeWhere((p) => p.isDead);
    bricks.removeWhere((b) => b.isDead);
  }

  bool _overlaps(Projectile p, Brick b) {
    const brickHW = 0.09;
    const brickHH = 0.04;
    final hitHW = p.kind.hitW / 2;
    const hitHH = 0.04;
    return (p.x - b.x).abs() < (hitHW + brickHW) &&
        (p.y - b.y).abs() < (hitHH + brickHH);
  }

  Color _effectColor(ProjectileKind kind) {
    switch (kind) {
      case ProjectileKind.slash:
        return Colors.white;
      case ProjectileKind.pierce:
        return Colors.lightBlueAccent;
      case ProjectileKind.blast:
        return Colors.orangeAccent;
      case ProjectileKind.drain:
        return Colors.purpleAccent;
      case ProjectileKind.guard:
        return Colors.tealAccent;
      case ProjectileKind.fragment:
        return Colors.yellowAccent;
    }
  }

  // ─────────────────────────────────────────
  // 데미지
  // ─────────────────────────────────────────

  int _dealDamage(Brick brick, int rawDmg, {double? hitX}) {
    if (brick.isDead) return 0;

    // 방어막 벽돌: 50% 데미지 감소
    // 실드는 HP가 maxHp*0.5 이하가 되면 자동 해제 (누적 피해 기반)
    if (brick.isShielded) {
      rawDmg = (rawDmg * 0.5).round().clamp(1, rawDmg);
    }
    if (brick.isLinkedShielded) {
      rawDmg = (rawDmg * 0.35).round().clamp(1, rawDmg);
      if (_rng.nextDouble() < 0.15) {
        _addEffect(
          brick.x,
          brick.y - 0.05,
          '📡 링크 보호',
          Colors.purpleAccent,
          ttl: 24,
        );
      }
    }
    if (brick.type == BrickType.core) {
      final hitDelta = hitX == null ? 1.0 : (hitX - brick.x).abs();
      final weakHit = hitDelta <= 0.035;
      rawDmg = weakHit
          ? (rawDmg * 1.8).round().clamp(1, 99999)
          : (rawDmg * 0.25).round().clamp(1, 99999);
      _addEffect(
        brick.x,
        brick.y - 0.05,
        weakHit ? '🎯 약점!' : '빗맞음',
        weakHit ? Colors.amberAccent : Colors.white54,
        ttl: weakHit ? 28 : 20,
      );
    }

    // 크리티컬 (콤보가 높을수록 확률 상승)
    final critChance =
        0.05 +
        (combo >= 25
            ? 0.15
            : combo >= 15
            ? 0.10
            : combo >= 5
            ? 0.05
            : 0.0);
    final isCrit = _rng.nextDouble() < critChance;

    final multi = sword.data.element.getMultiplierAgainst(brick.element);
    final dmg = (rawDmg * multi * (isCrit ? critBaseDmgMult : 1.0))
        .round()
        .clamp(1, 99999);
    brick.hp -= dmg;
    if (isCrit)
      _addEffect(brick.x, brick.y - 0.05, '💫 CRIT!', Colors.amber, ttl: 30);

    // 방어막 해제 조건: HP가 절반 이하로 떨어지면
    if (brick.isShielded && brick.hp <= brick.maxHp * 0.5) {
      brick.isShielded = false;
      _addEffect(
        brick.x,
        brick.y - 0.05,
        '방어막 해제!',
        Colors.tealAccent,
        ttl: 45,
      );
    }

    if (brick.hp <= 0) {
      brick.isDead = true;
      _onDestroyed(brick);
    }
    return dmg;
  }

  void _onDestroyed(Brick brick) {
    bricksDestroyed++;

    // 콤보 증가
    combo++;
    comboTimer = comboResetTime;

    // 콤보 폭발 준비 (한 번 달성 → 탭까지 유지)
    if (combo >= 10 && !_burstReady) {
      _burstReady = true;
      _addEffect(0.5, 0.5, '💥 폭발 준비!', Colors.orange, ttl: 45);
    }

    // 분노 게이지 충전
    final rageGain = brick.type == BrickType.boss
        ? 0.18
        : brick.type == BrickType.miniBoss
        ? 0.10
        : 0.06;
    rageGauge = (rageGauge + rageGain).clamp(0.0, 1.0);
    if (rageGauge >= 1.0 && !isRaging) _activateRage();

    // 필살기 게이지 충전
    final ultGain = brick.type == BrickType.boss
        ? 0.15
        : brick.type == BrickType.miniBoss
        ? 0.08
        : 0.04;
    ultimateGauge = (ultimateGauge + ultGain).clamp(0.0, 1.0);
    if (ultimateGauge >= 1.0 && !_ultimateReady) {
      _ultimateReady = true;
      _addEffect(0.5, 0.42, '⚔️ 필살기 준비!', Colors.white, ttl: 60);
    }

    final gainedScore = switch (brick.type) {
      BrickType.normal => 10 * combo.clamp(1, 10),
      BrickType.armored => 25 * combo.clamp(1, 10),
      BrickType.explosive => 30 * combo.clamp(1, 10),
      BrickType.healer => 20 * combo.clamp(1, 10),
      BrickType.splitter => 28 * combo.clamp(1, 10),
      BrickType.core => 45 * combo.clamp(1, 10),
      BrickType.relay => 40 * combo.clamp(1, 10),
      BrickType.cursed => 55 * combo.clamp(1, 10),
      BrickType.miniBoss => 140 * combo.clamp(1, 10),
      BrickType.boss => 100 * combo.clamp(1, 10),
    };
    score += gainedScore;
    if (currentWaveEvent == WaveEventType.jackpot) {
      score += (gainedScore * 0.25).round();
    }

    if (combo >= 5) {
      _addEffect(
        brick.x,
        brick.y - 0.06,
        combo >= 20
            ? '🔥 x${comboMultiplier.toStringAsFixed(0)}'
            : '콤보 $combo!',
        Colors.amber,
        ttl: 50,
      );
    }

    // 폭발 벽돌: 스플래시
    if (brick.type == BrickType.explosive) {
      _addEffect(brick.x, brick.y, '💣 폭발!', Colors.deepOrange);
      for (final b in bricks.toList()) {
        if (!b.isDead &&
            b != brick &&
            (b.x - brick.x).abs() < 0.25 &&
            (b.y - brick.y).abs() < 0.15) {
          _dealDamage(b, sword.totalPower ~/ 2, hitX: brick.x);
        }
      }
    }
    if (brick.type == BrickType.splitter) {
      _spawnSplitChildren(brick);
    }
    if (brick.type == BrickType.relay) {
      _addEffect(brick.x, brick.y, '📡 링크 붕괴!', Colors.purpleAccent, ttl: 45);
      _updateRelayLinks();
    }
    if (brick.type == BrickType.cursed) {
      playerShield = (playerShield + 1).clamp(0, maxShields);
      ultimateGauge = (ultimateGauge + 0.12).clamp(0.0, 1.0);
      _addEffect(
        brick.x,
        brick.y,
        '☠️ 해주 성공! 🛡️+1',
        Colors.deepPurpleAccent,
        ttl: 55,
      );
      if (ultimateGauge >= 1.0 && !_ultimateReady) {
        _ultimateReady = true;
        _addEffect(0.5, 0.42, '⚔️ 필살기 준비!', Colors.white, ttl: 60);
      }
    }

    // ── 속성 체인 확인
    _checkElementChain(brick.element);

    // ── 파편 미사일 발사
    _spawnFragments(brick);

    // ── 파워업 드롭 (확률)
    _tryDropPowerUp(brick);
    // ※ bricks.removeWhere는 _checkProjectileCollisions / _checkDangerZone 끝에서만 호출
  }

  void _spawnSplitChildren(Brick brick) {
    for (final dx in const [-0.06, 0.06]) {
      bricks.add(
        Brick(
          id: _nextId(),
          type: BrickType.normal,
          element: brick.element,
          maxHp: (brick.maxHp * 0.42).round(),
          x: (brick.x + dx).clamp(0.1, 0.9),
          y: brick.y - 0.015,
          moveDir: dx < 0 ? -1 : 1,
        ),
      );
    }
    _addEffect(brick.x, brick.y, '🧬 분열!', Colors.cyanAccent, ttl: 50);
  }

  // 파편 미사일: 파괴 시 3~5방향으로 날아가며 주변 벽돌 타격
  void _spawnFragments(Brick brick) {
    final count = switch (brick.type) {
      BrickType.normal => 2,
      BrickType.armored => 4,
      BrickType.explosive => 5,
      BrickType.splitter => 3,
      BrickType.core => 4,
      BrickType.relay => 3,
      BrickType.cursed => 4,
      BrickType.miniBoss => 5,
      BrickType.boss => 6,
      _ => 2,
    };
    final fragDmg = (sword.totalPower * 0.4 * _damageMult).round().clamp(
      1,
      99999,
    );

    for (int i = 0; i < count; i++) {
      // 위쪽 반원 방향으로 균등 분산
      final angle = pi + (i / (count - 1).clamp(1, 99)) * pi; // π ~ 2π (위쪽)
      final speed = ProjectileKind.fragment.speed;
      projectiles.add(
        Projectile(
          id: _nextId(),
          kind: ProjectileKind.fragment,
          x: brick.x,
          y: brick.y,
          damage: fragDmg,
          dx: cos(angle) * speed * 0.6,
          dy: sin(angle) * speed,
        ),
      );
    }
  }

  // 파워업 드롭
  void _tryDropPowerUp(Brick brick) {
    final chance = switch (brick.type) {
      BrickType.boss => 0.8,
      BrickType.miniBoss => 0.6,
      BrickType.cursed => 0.35,
      BrickType.armored => 0.25,
      _ => 0.08,
    };
    final adjustedChance = currentWaveEvent == WaveEventType.jackpot
        ? (chance + 0.12).clamp(0.0, 1.0)
        : chance;
    if (_rng.nextDouble() > adjustedChance) return;

    final types = PowerUpType.values;
    final type = types[_rng.nextInt(types.length)];
    powerUps.add(
      PowerUpItem(id: _nextId(), type: type, x: brick.x, y: brick.y),
    );
  }

  // ─────────────────────────────────────────
  // 파워업 낙하 & 수집
  // ─────────────────────────────────────────

  void _checkPowerUpCollisions() {
    for (final pu in powerUps) {
      pu.y += 0.04 * 0.016; // 천천히 낙하 (approx 60fps)
      // 검과 겹치면 수집
      if ((pu.x - swordX).abs() < 0.15 && (pu.y - swordY).abs() < 0.06) {
        pu.isDead = true;
        _activatePowerUp(pu.type);
      }
      if (pu.y > 1.05) pu.isDead = true;
    }
    powerUps.removeWhere((p) => p.isDead);
  }

  void _activatePowerUp(PowerUpType type) {
    activePowerUps.add(type);
    _addEffect(
      swordX,
      swordY - 0.1,
      '${type.emoji} ${type.label}!',
      type.color,
      ttl: 60,
    );
  }

  // ─────────────────────────────────────────
  // 회복 벽돌
  // ─────────────────────────────────────────

  void _tickHealerBricks() {
    final snap = bricks.toList();
    for (final h in snap.where(
      (b) => b.type == BrickType.healer && !b.isDead,
    )) {
      for (final b in snap.where(
        (b) =>
            !b.isDead &&
            b != h &&
            (b.x - h.x).abs() < 0.25 &&
            (b.y - h.y).abs() < 0.15,
      )) {
        b.hp = (b.hp + (b.maxHp * 0.01).round()).clamp(0, b.maxHp);
      }
    }
  }

  void _tickCursedBricks(double dt) {
    for (final b in bricks.where(
      (b) => b.type == BrickType.cursed && !b.isDead,
    )) {
      b.gimmickTimer -= dt;
      if (b.gimmickTimer > 0) continue;

      b.isDead = true;
      combo = 0;
      _loseLife(1);
      _addEffect(b.x, b.y, '☠️ 저주 폭발!', Colors.deepPurpleAccent, ttl: 60);

      for (final target in bricks) {
        if (target.isDead || target == b) continue;
        if ((target.x - b.x).abs() < 0.22 && (target.y - b.y).abs() < 0.14) {
          target.hp = (target.hp + (target.maxHp * 0.18).round()).clamp(
            0,
            target.maxHp,
          );
          _addEffect(
            target.x,
            target.y - 0.05,
            '저주 회복',
            Colors.purpleAccent,
            ttl: 24,
          );
        }
      }
    }
    bricks.removeWhere((b) => b.isDead);
  }

  // ─────────────────────────────────────────
  // 위험 구역
  // ─────────────────────────────────────────

  void _checkDangerZone() {
    final danger = bricks.where((b) => b.y >= dangerY && !b.isDead).toList();
    for (final b in danger) {
      b.isDead = true;
      combo = 0; // 콤보 리셋
      // 피격 시 분노 게이지 충전
      final rageGain = b.type == BrickType.boss ? 0.35 : 0.20;
      rageGauge = (rageGauge + rageGain).clamp(0.0, 1.0);
      if (rageGauge >= 1.0 && !isRaging) _activateRage();
      if (b.type == BrickType.boss) {
        _loseLife(3);
        _addEffect(b.x, 0.9, '💀 보스 돌파!', Colors.red);
      } else if (b.type == BrickType.miniBoss) {
        _loseLife(2);
        _addEffect(b.x, 0.9, '👹 미니보스 돌파!', Colors.deepOrangeAccent);
      } else {
        _loseLife(1);
        _addEffect(b.x, 0.9, '💔', Colors.red);
      }
    }
    bricks.removeWhere((b) => b.isDead);
  }

  void _loseLife(int n) {
    if (playerShield > 0) {
      playerShield = (playerShield - n).clamp(0, 999);
      _addEffect(0.5, swordY - 0.06, '🛡️ 막음!', Colors.cyan);
      return;
    }
    lives -= n;
    if (lives <= 0) {
      lives = 0;
      isGameOver = true;
      isRunning = false;
    }
  }

  // ─────────────────────────────────────────
  // 이펙트
  // ─────────────────────────────────────────

  void _addEffect(
    double x,
    double y,
    String text,
    Color color, {
    int ttl = 35,
  }) {
    effects.add(
      AttackEffect(
        id: _nextId(),
        x: x,
        y: y,
        text: text,
        color: color,
        ttl: ttl,
      ),
    );
  }

  void _tickEffects() {
    for (final e in effects) {
      e.ttl--;
      e.y -= 0.003;
    }
    effects.removeWhere((e) => e.ttl <= 0);
  }

  // ─────────────────────────────────────────
  // 보상
  // ─────────────────────────────────────────

  MinigameResult get result {
    final waveBonus = (wave - 1) * 8000; // 웨이브당 8000골드
    final brickBonus = bricksDestroyed * 400; // 벽돌당 400골드
    final scoreBonus = score * 3; // 점수 = 추가 골드 (3배)
    final gradeBonus = sword.data.grade.battleBonus; // 등급 배율 유지
    return MinigameResult(
      wavesCleared: wave - 1,
      bricksDestroyed: bricksDestroyed,
      goldEarned: ((waveBonus + brickBonus + scoreBonus) * gradeBonus).round(),
      stonesEarned: (wave ~/ 2).clamp(0, 20), // 강화석도 2웨이브마다 1개
    );
  }
}
