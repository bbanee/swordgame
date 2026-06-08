// lib/widgets/sword_image_widget.dart
// 🗡️ 검 이미지 위젯 - 등급별 글로우 + 강화 레벨별 효과 + 애니메이션

import 'dart:math';
import 'package:flutter/material.dart';
import '../enums/sword_grade.dart';
import '../enums/element.dart';
part 'sword_image_widget/effects.dart';

class SwordImageWidget extends StatefulWidget {
  final SwordGrade grade;
  final GameElement element;
  final int level;
  final int breakthroughLevel;
  final double size;
  final bool showPulse; // 펄스 애니메이션 여부
  final bool showEnhanceEffect; // 강화 성공 효과
  final String? swordId; // 실제 검별 이미지 id

  const SwordImageWidget({
    super.key,
    required this.grade,
    required this.element,
    this.swordId,
    this.level = 0,
    this.breakthroughLevel = 0,
    this.size = 150,
    this.showPulse = true,
    this.showEnhanceEffect = false,
  });

  @override
  State<SwordImageWidget> createState() => _SwordImageWidgetState();
}

class _SwordImageWidgetState extends State<SwordImageWidget>
    with TickerProviderStateMixin {
  // 펄스 애니메이션 (숨쉬는 글로우)
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // 강화 성공 애니메이션
  late AnimationController _enhanceController;
  late Animation<double> _enhanceScale;
  late Animation<double> _enhanceGlow;

  // 파티클 애니메이션
  late AnimationController _particleController;
  late AnimationController _idleController;

  @override
  void initState() {
    super.initState();

    // 펄스 애니메이션 (2초 주기)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.showPulse) {
      _pulseController.repeat(reverse: true);
    }

    // 강화 성공 애니메이션
    _enhanceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _enhanceScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 70),
        ]).animate(
          CurvedAnimation(parent: _enhanceController, curve: Curves.easeOut),
        );
    _enhanceGlow =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 3.0), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 3.0, end: 1.0), weight: 70),
        ]).animate(
          CurvedAnimation(parent: _enhanceController, curve: Curves.easeOut),
        );

    // 파티클 애니메이션
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    if (widget.level >= 5) {
      _particleController.repeat();
    }

    _idleController = AnimationController(
      duration: const Duration(milliseconds: 850),
      vsync: this,
    );
    if (_usesIdleSpriteSheet) {
      _idleController.repeat();
    }

    // 강화 성공 효과 트리거
    if (widget.showEnhanceEffect) {
      _enhanceController.forward();
    }
  }

  @override
  void didUpdateWidget(SwordImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 강화 성공 효과 트리거
    if (widget.showEnhanceEffect && !oldWidget.showEnhanceEffect) {
      _enhanceController.forward(from: 0);
    }

    // 레벨 5 이상이면 파티클 시작
    if (widget.level >= 5 && !_particleController.isAnimating) {
      _particleController.repeat();
    }

    if (_usesIdleSpriteSheet && !_idleController.isAnimating) {
      _idleController.repeat();
    } else if (!_usesIdleSpriteSheet && _idleController.isAnimating) {
      _idleController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _enhanceController.dispose();
    _particleController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  bool get _usesIdleSpriteSheet =>
      widget.swordId != null &&
      widget.swordId!.isNotEmpty &&
      (widget.grade == SwordGrade.hidden ||
          widget.grade == SwordGrade.immortal);

  String? get _byIdImagePath {
    final id = widget.swordId;
    if (id == null || id.isEmpty) return null;
    if (_usesIdleSpriteSheet) {
      return 'assets/images/swords/by_id/${id}_idle.webp';
    }
    return 'assets/images/swords/by_id/$id.webp';
  }

  // 등급별 fallback 이미지 경로
  String get _fallbackImagePath {
    switch (widget.grade) {
      case SwordGrade.normal:
        return 'assets/images/swords/sword_normal.webp';
      case SwordGrade.rare:
        return 'assets/images/swords/sword_rare.webp';
      case SwordGrade.unique:
        return 'assets/images/swords/sword_unique.webp';
      case SwordGrade.legend:
        return 'assets/images/swords/sword_legend.webp';
      case SwordGrade.hidden:
        return 'assets/images/swords/sword_hidden.webp';
      case SwordGrade.immortal:
        return 'assets/images/swords/sword_immortal.webp';
    }
  }

  // 등급별 글로우 색상
  Color get _glowColor {
    switch (widget.grade) {
      case SwordGrade.normal:
        return Colors.grey;
      case SwordGrade.rare:
        return Colors.blue;
      case SwordGrade.unique:
        return Colors.purple;
      case SwordGrade.legend:
        return Colors.orange;
      case SwordGrade.hidden:
        return Colors.pink;
      case SwordGrade.immortal:
        return Colors.red;
    }
  }

  // 원소별 파티클 색상
  Color get _elementColor {
    switch (widget.element) {
      case GameElement.fire:
        return Colors.orange;
      case GameElement.water:
        return Colors.blue;
      case GameElement.nature:
        return Colors.green;
      case GameElement.light:
        return Colors.yellow;
      case GameElement.dark:
        return Colors.purple;
    }
  }

  // 강화 레벨별 글로우 강도 (0~30 → 0.0~1.0)
  double get _glowIntensity {
    if (widget.level <= 0) return 0.0;
    if (widget.level <= 4) return 0.2;
    if (widget.level <= 9) return 0.4;
    if (widget.level <= 14) return 0.6;
    if (widget.level <= 19) return 0.75;
    if (widget.level <= 24) return 0.85;
    if (widget.level <= 29) return 0.95;
    return 1.0; // +30
  }

  // 강화 레벨별 글로우 크기
  double get _glowSize {
    if (widget.level <= 0) return 0;
    if (widget.level <= 9) return 10;
    if (widget.level <= 19) return 20;
    if (widget.level <= 24) return 30;
    return 40; // +25 이상
  }

  bool get _hasBreakthrough => widget.breakthroughLevel > 0;

  int get _breakthroughVisualTier {
    if (!_hasBreakthrough) return 0;
    if (widget.level >= 41) return 3;
    if (widget.level >= 36) return 2;
    return 1;
  }

  Color get _breakthroughColor {
    switch (widget.grade) {
      case SwordGrade.normal:
        return const Color(0xFFECEFF1);
      case SwordGrade.rare:
        return const Color(0xFF6EC6FF);
      case SwordGrade.unique:
        return const Color(0xFFC77DFF);
      case SwordGrade.legend:
        return const Color(0xFFFFD166);
      case SwordGrade.hidden:
        return const Color(0xFFFF4FBF);
      case SwordGrade.immortal:
        return const Color(0xFFFF5A5A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseController,
        _enhanceController,
        _particleController,
        _idleController,
      ]),
      builder: (context, child) {
        final pulseValue = widget.showPulse ? _pulseAnimation.value : 1.0;
        final enhanceScale = _enhanceController.isAnimating
            ? _enhanceScale.value
            : 1.0;
        final enhanceGlow = _enhanceController.isAnimating
            ? _enhanceGlow.value
            : 1.0;

        // 🔥 값 범위 체크 (오류 방지)
        final safePulse = pulseValue.clamp(0.0, 2.0);
        final safeEnhanceGlow = enhanceGlow.clamp(0.0, 5.0);

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 🔥 레벨 5+ 파티클 효과
              if (widget.level >= 5) ..._buildParticles(),

              // 🌟 외곽 글로우 (레벨 20+)
              if (widget.level >= 20)
                _buildOuterGlow(safePulse, safeEnhanceGlow),

              // ✨ 메인 글로우
              if (_glowIntensity > 0)
                _buildMainGlow(safePulse, safeEnhanceGlow),

              if (_hasBreakthrough && _breakthroughVisualTier >= 2)
                _buildBreakthroughMagicCircle(),
              if (_hasBreakthrough) _buildBreakthroughRing(),
              if (_hasBreakthrough) _buildBreakthroughAura(safePulse),
              if (_hasBreakthrough) ..._buildBreakthroughSigils(),

              // 🗡️ 검 이미지
              Transform.scale(
                scale: enhanceScale.clamp(0.5, 2.0),
                child: _buildSwordImage(),
              ),

              if (_hasBreakthrough && _breakthroughVisualTier >= 3)
                _buildBreakthroughFlare(safePulse),
              if (_hasBreakthrough && _breakthroughVisualTier >= 3)
                _buildBreakthroughWave(safePulse),

              // 💫 강화 성공 빛 폭발
              if (_enhanceController.isAnimating) _buildEnhanceBurst(),

              // 🏷️ 강화 레벨 표시
              if (widget.level > 0) _buildLevelBadge(),
              if (_hasBreakthrough) _buildBreakthroughBadge(),
            ],
          ),
        );
      },
    );
  }

  // 검 이미지
  Widget _buildSwordImage() {
    return SizedBox(
      width: widget.size * 0.7,
      height: widget.size * 0.7,
      child: _usesIdleSpriteSheet
          ? _buildIdleSpriteSheet()
          : _buildStaticSwordImage(),
    );
  }

  Widget _buildStaticSwordImage() {
    return Image.asset(
      _byIdImagePath ?? _fallbackImagePath,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _buildFallbackSwordImage(),
    );
  }

  Widget _buildIdleSpriteSheet() {
    final frame = (_idleController.value * 4).floor().clamp(0, 3);
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameWidth = constraints.maxWidth;
          final frameHeight = constraints.maxHeight;
          return Transform.translate(
            offset: Offset(-frameWidth * frame, 0),
            child: SizedBox(
              width: frameWidth * 4,
              height: frameHeight,
              child: Image.asset(
                _byIdImagePath ?? _fallbackImagePath,
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) =>
                    _buildFallbackSwordImage(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackSwordImage() {
    return Image.asset(
      _fallbackImagePath,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Text(
            widget.grade.emoji,
            style: TextStyle(fontSize: widget.size * 0.4),
          ),
        );
      },
    );
  }

  Widget _buildBreakthroughAura(double pulseValue) {
    final tier = _breakthroughVisualTier;
    final auraColor = _breakthroughColor;
    final pulse = pulseValue.clamp(0.8, 1.2);
    final coreOpacity = (0.12 + tier * 0.05) * pulse;
    final ringOpacity = (0.2 + tier * 0.06) * pulse;

    return SizedBox(
      width: widget.size * (0.92 + tier * 0.06),
      height: widget.size * (0.92 + tier * 0.06),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size * (0.72 + tier * 0.04),
            height: widget.size * (0.72 + tier * 0.04),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  auraColor.withOpacity(coreOpacity.clamp(0.0, 0.45)),
                  auraColor.withOpacity((coreOpacity * 0.45).clamp(0.0, 0.25)),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Container(
            width: widget.size * (0.84 + tier * 0.05),
            height: widget.size * (0.84 + tier * 0.05),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: auraColor.withOpacity(ringOpacity.clamp(0.0, 0.5)),
                width: 1.2 + (tier * 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: auraColor.withOpacity(
                    (ringOpacity * 0.5).clamp(0.0, 0.35),
                  ),
                  blurRadius: 10 + tier * 6,
                  spreadRadius: tier.toDouble(),
                ),
              ],
            ),
          ),
          if (tier >= 2)
            Container(
              width: widget.size * 1.02,
              height: widget.size * 1.02,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: auraColor.withOpacity(
                    (ringOpacity * 0.55).clamp(0.0, 0.3),
                  ),
                  width: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBreakthroughRing() {
    final tier = _breakthroughVisualTier;
    final auraColor = _breakthroughColor;
    final rotation = _particleController.value * pi * 2;
    final ringSize = widget.size * (1.1 + tier * 0.08);
    final sideCount = switch (widget.grade) {
      SwordGrade.normal => 4,
      SwordGrade.rare => 5,
      SwordGrade.unique => 6,
      SwordGrade.legend => 8,
      SwordGrade.hidden => 7,
      SwordGrade.immortal => 10,
    };

    return Transform.rotate(
      angle: rotation * (widget.grade.index.isEven ? 1 : -1),
      child: SizedBox(
        width: ringSize,
        height: ringSize,
        child: CustomPaint(
          painter: _BreakthroughRingPainter(
            color: auraColor,
            sideCount: sideCount,
            tier: tier,
            isHidden: widget.grade == SwordGrade.hidden,
          ),
        ),
      ),
    );
  }

  Widget _buildBreakthroughMagicCircle() {
    final tier = _breakthroughVisualTier;
    final auraColor = _breakthroughColor;
    final rotation = _particleController.value * pi;
    final size = widget.size * (1.02 + tier * 0.07);

    return Transform.rotate(
      angle: rotation * 0.45,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _MagicCirclePainter(
            color: auraColor,
            tier: tier,
            grade: widget.grade,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBreakthroughSigils() {
    final tier = _breakthroughVisualTier;
    final progress = _particleController.value;
    final auraColor = _breakthroughColor;
    final count = switch (widget.grade) {
      SwordGrade.normal => 2 + tier,
      SwordGrade.rare => 3 + tier,
      SwordGrade.unique => 4 + tier,
      SwordGrade.legend => 5 + tier,
      SwordGrade.hidden => 5 + tier,
      SwordGrade.immortal => 6 + tier,
    };
    final radius = widget.size * (0.28 + tier * 0.045);
    final widgets = <Widget>[];

    for (var i = 0; i < count; i++) {
      final angle =
          (i * (360 / count) + progress * 180 * (i.isEven ? 1 : -1)) * pi / 180;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      final opacity = ((sin(progress * pi * 2 + i) + 1) / 2).clamp(0.0, 1.0);
      final size =
          switch (widget.grade) {
            SwordGrade.normal => 4.0,
            SwordGrade.rare => 4.5,
            SwordGrade.unique => 5.0,
            SwordGrade.legend => 5.5,
            SwordGrade.hidden => 5.0,
            SwordGrade.immortal => 6.0,
          } +
          (tier - 1) * 0.8;

      widgets.add(
        Positioned(
          left: widget.size / 2 + x - size / 2,
          top: widget.size / 2 + y - size / 2,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: _sigilFillColor(auraColor, opacity),
                shape: _sigilShape(),
                borderRadius: _sigilShape() == BoxShape.rectangle
                    ? BorderRadius.circular(
                        widget.grade == SwordGrade.hidden ? size / 2.5 : 1.5,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: auraColor.withOpacity(
                      (0.22 + opacity * 0.4).clamp(0.0, 0.5),
                    ),
                    blurRadius: 4 + tier * 2,
                    spreadRadius: tier >= 2 ? 0.6 : 0.2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  BoxShape _sigilShape() {
    switch (widget.grade) {
      case SwordGrade.normal:
      case SwordGrade.rare:
        return BoxShape.circle;
      case SwordGrade.unique:
      case SwordGrade.legend:
      case SwordGrade.hidden:
      case SwordGrade.immortal:
        return BoxShape.rectangle;
    }
  }

  Color _sigilFillColor(Color auraColor, double opacity) {
    switch (widget.grade) {
      case SwordGrade.normal:
        return auraColor.withOpacity((0.35 + opacity * 0.35).clamp(0.0, 0.7));
      case SwordGrade.rare:
        return auraColor.withOpacity((0.4 + opacity * 0.35).clamp(0.0, 0.75));
      case SwordGrade.unique:
        return Colors.white.withOpacity(
          (0.22 + opacity * 0.35).clamp(0.0, 0.6),
        );
      case SwordGrade.legend:
        return Colors.white.withOpacity((0.3 + opacity * 0.45).clamp(0.0, 0.8));
      case SwordGrade.hidden:
        return auraColor.withOpacity((0.28 + opacity * 0.32).clamp(0.0, 0.65));
      case SwordGrade.immortal:
        return Colors.white.withOpacity((0.34 + opacity * 0.5).clamp(0.0, 0.9));
    }
  }

  Widget _buildBreakthroughFlare(double pulseValue) {
    final auraColor = _breakthroughColor;
    final opacity = (0.18 * pulseValue).clamp(0.0, 0.3);

    return SizedBox(
      width: widget.size * 0.96,
      height: widget.size * 0.96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size * 0.16,
            height: widget.size * 0.86,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.size),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  auraColor.withOpacity(opacity),
                  Colors.white.withOpacity((opacity * 0.8).clamp(0.0, 0.2)),
                  auraColor.withOpacity(opacity),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Transform.rotate(
            angle: pi / 2,
            child: Container(
              width: widget.size * 0.16,
              height: widget.size * 0.86,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.size),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    auraColor.withOpacity(opacity),
                    Colors.white.withOpacity((opacity * 0.8).clamp(0.0, 0.2)),
                    auraColor.withOpacity(opacity),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakthroughWave(double pulseValue) {
    final auraColor = _breakthroughColor;
    final wave = ((sin(_particleController.value * pi * 2) + 1) / 2).clamp(
      0.0,
      1.0,
    );
    final size = widget.size * (0.95 + wave * 0.32);
    final opacity = (0.08 + wave * 0.14) * pulseValue.clamp(0.8, 1.1);

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: auraColor.withOpacity(opacity.clamp(0.0, 0.28)),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: auraColor.withOpacity((opacity * 0.45).clamp(0.0, 0.16)),
              blurRadius: 14,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakthroughBadge() {
    final tier = _breakthroughVisualTier;
    final badgeScale = tier == 1 ? 1.0 : (tier == 2 ? 1.08 : 1.16);
    final borderColor = tier >= 3 ? Colors.white : _breakthroughColor;
    return Positioned(
      top: widget.size * 0.08,
      left: widget.size * 0.08,
      child: Transform.scale(
        scale: badgeScale,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.size * 0.045,
            vertical: widget.size * 0.02,
          ),
          decoration: BoxDecoration(
            color: tier >= 3
                ? _breakthroughColor.withOpacity(0.22)
                : Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(widget.size),
            border: Border.all(
              color: borderColor.withOpacity(0.92),
              width: tier >= 3 ? 1.5 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _breakthroughColor.withOpacity(tier >= 3 ? 0.48 : 0.35),
                blurRadius: tier >= 3 ? 11 : 8,
                spreadRadius: tier >= 3 ? 1.5 : 1,
              ),
            ],
          ),
          child: Text(
            '◆${widget.breakthroughLevel}',
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.size * (tier >= 3 ? 0.12 : 0.11),
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  // 메인 글로우 효과
  Widget _buildMainGlow(double pulseValue, double enhanceGlow) {
    // 🔥 opacity 범위 체크 (0.0 ~ 1.0)
    final op1 = (_glowIntensity * 0.6 * pulseValue * enhanceGlow).clamp(
      0.0,
      1.0,
    );
    final op2 = (_glowIntensity * 0.3 * pulseValue).clamp(0.0, 1.0);
    final op3 = (_glowIntensity * 0.5 * pulseValue).clamp(0.0, 1.0);
    final blur = (_glowSize * pulseValue * enhanceGlow).clamp(0.0, 100.0);
    final spread = (_glowSize * 0.3 * pulseValue).clamp(0.0, 50.0);

    return Container(
      width: widget.size * 0.8,
      height: widget.size * 0.8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _glowColor.withOpacity(op1),
            _glowColor.withOpacity(op2),
            _glowColor.withOpacity(0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _glowColor.withOpacity(op3),
            blurRadius: blur,
            spreadRadius: spread,
          ),
        ],
      ),
    );
  }

  // 외곽 글로우 (레벨 20+)
  Widget _buildOuterGlow(double pulseValue, double enhanceGlow) {
    final op1 = (0.1 * pulseValue).clamp(0.0, 1.0);
    final op2 = (0.3 * pulseValue * enhanceGlow).clamp(0.0, 1.0);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.transparent,
            _glowColor.withOpacity(op1),
            _glowColor.withOpacity(op2),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 0.8, 1.0],
        ),
      ),
    );
  }

  // 강화 성공 빛 폭발
  Widget _buildEnhanceBurst() {
    final progress = _enhanceController.value;
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final scale = (1 + (progress * 0.5)).clamp(1.0, 2.0);

    return Transform.scale(
      scale: scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withOpacity((opacity * 0.8).clamp(0.0, 1.0)),
              _glowColor.withOpacity((opacity * 0.5).clamp(0.0, 1.0)),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  // 파티클 효과 (레벨 5+) - 등급별 차별화
  List<Widget> _buildParticles() {
    switch (widget.grade) {
      case SwordGrade.normal:
        return _buildNormalParticles();
      case SwordGrade.rare:
        return _buildRareParticles();
      case SwordGrade.unique:
        return _buildUniqueParticles();
      case SwordGrade.legend:
        return _buildLegendParticles();
      case SwordGrade.hidden:
        return _buildHiddenParticles();
      case SwordGrade.immortal:
        return _buildImmortalParticles();
    }
  }

  // 노말 등급: 기본 원형 파티클
  List<Widget> _buildNormalParticles() {
    final particleCount = (widget.level ~/ 5).clamp(1, 6);
    final progress = _particleController.value;

    return List.generate(particleCount, (index) {
      final angle = (index * (360 / particleCount) + progress * 360) * pi / 180;
      final radius = widget.size * 0.35;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      final particleOpacity = ((sin(progress * pi * 2 + index) + 1) / 2).clamp(
        0.0,
        1.0,
      );

      return Positioned(
        left: widget.size / 2 + x - 3,
        top: widget.size / 2 + y - 3,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _elementColor.withOpacity(
              (particleOpacity * 0.6).clamp(0.0, 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: _elementColor.withOpacity(
                  (particleOpacity * 0.3).clamp(0.0, 1.0),
                ),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
    });
  }

  // 레어 등급: 조금 더 큰 원형 파티클 + 글로우 강화
  List<Widget> _buildRareParticles() {
    final particleCount = (widget.level ~/ 5).clamp(1, 6);
    final progress = _particleController.value;

    return List.generate(particleCount, (index) {
      final angle = (index * (360 / particleCount) + progress * 360) * pi / 180;
      final radius = widget.size * 0.35;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      final particleOpacity = ((sin(progress * pi * 2 + index) + 1) / 2).clamp(
        0.0,
        1.0,
      );

      return Positioned(
        left: widget.size / 2 + x - 4,
        top: widget.size / 2 + y - 4,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _elementColor.withOpacity(
              (particleOpacity * 0.8).clamp(0.0, 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: _elementColor.withOpacity(
                  (particleOpacity * 0.5).clamp(0.0, 1.0),
                ),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      );
    });
  }

  // 유니크 등급: 다이아몬드 파티클 + 이중 레이어
  List<Widget> _buildUniqueParticles() {
    final particleCount = (widget.level ~/ 5).clamp(1, 6);
    final progress = _particleController.value;
    final List<Widget> particles = [];

    // 외곽 레이어 (다이아몬드, 시계방향)
    for (int i = 0; i < particleCount; i++) {
      final angle = (i * (360 / particleCount) + progress * 360) * pi / 180;
      final radius = widget.size * 0.38;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      final particleOpacity = ((sin(progress * pi * 2 + i) + 1) / 2).clamp(
        0.0,
        1.0,
      );

      particles.add(
        Positioned(
          left: widget.size / 2 + x - 5,
          top: widget.size / 2 + y - 5,
          child: Transform.rotate(
            angle: angle + pi / 4,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _elementColor.withOpacity(
                  (particleOpacity * 0.85).clamp(0.0, 1.0),
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: _elementColor.withOpacity(
                      (particleOpacity * 0.6).clamp(0.0, 1.0),
                    ),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 내부 레이어 (작은 원, 반시계방향)
    for (int i = 0; i < particleCount; i++) {
      final angle = (i * (360 / particleCount) - progress * 360) * pi / 180;
      final radius = widget.size * 0.25;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      final particleOpacity = ((cos(progress * pi * 2 + i) + 1) / 2).clamp(
        0.0,
        1.0,
      );

      particles.add(
        Positioned(
          left: widget.size / 2 + x - 3,
          top: widget.size / 2 + y - 3,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(
                (particleOpacity * 0.7).clamp(0.0, 1.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: _elementColor.withOpacity(
                    (particleOpacity * 0.5).clamp(0.0, 1.0),
                  ),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return particles;
  }

  // 레전드 등급: 별 모양 파티클 + 트레일 효과
  List<Widget> _buildLegendParticles() {
    final particleCount = (widget.level ~/ 5).clamp(1, 6);
    final progress = _particleController.value;
    final List<Widget> particles = [];

    // 트레일 효과 (페이딩 복사본)
    for (int trail = 2; trail >= 0; trail--) {
      final trailProgress = (progress - trail * 0.05).clamp(0.0, 1.0);
      final trailOpacity = (1.0 - trail * 0.35).clamp(0.0, 1.0);

      for (int i = 0; i < particleCount; i++) {
        final angle =
            (i * (360 / particleCount) + trailProgress * 400) * pi / 180;
        final radius = widget.size * 0.38;
        final x = cos(angle) * radius;
        final y = sin(angle) * radius;
        final particleOpacity =
            ((sin(progress * pi * 2 + i) + 1) / 2 * trailOpacity).clamp(
              0.0,
              1.0,
            );

        particles.add(
          Positioned(
            left: widget.size / 2 + x - 6,
            top: widget.size / 2 + y - 6,
            child: CustomPaint(
              size: Size(12 - trail * 2, 12 - trail * 2),
              painter: _StarPainter(
                color: _elementColor.withOpacity(
                  (particleOpacity * 0.9).clamp(0.0, 1.0),
                ),
                points: 4,
              ),
            ),
          ),
        );
      }
    }

    // 중앙 작은 반짝임
    for (int i = 0; i < particleCount; i++) {
      final angle = (i * (360 / particleCount) - progress * 200) * pi / 180;
      final radius = widget.size * 0.22;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      final particleOpacity = ((cos(progress * pi * 3 + i) + 1) / 2).clamp(
        0.0,
        1.0,
      );

      particles.add(
        Positioned(
          left: widget.size / 2 + x - 3,
          top: widget.size / 2 + y - 3,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(
                    (particleOpacity * 0.9).clamp(0.0, 1.0),
                  ),
                  _elementColor.withOpacity(
                    (particleOpacity * 0.5).clamp(0.0, 1.0),
                  ),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(
                    (particleOpacity * 0.6).clamp(0.0, 1.0),
                  ),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return particles;
  }

  // 히든 등급: 무지개빛 별 + 펄싱 효과
  List<Widget> _buildHiddenParticles() {
    final particleCount = (widget.level ~/ 5).clamp(1, 6);
    final progress = _particleController.value;
    final List<Widget> particles = [];

    // 무지개색 리스트
    final rainbowColors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.pink,
    ];

    // 외곽 레이어 (큰 별, 빠른 회전 + 색상 시프트)
    for (int i = 0; i < particleCount; i++) {
      final angle = (i * (360 / particleCount) + progress * 450) * pi / 180;
      final radius = widget.size * 0.40;
      final pulseSize = 1.0 + sin(progress * pi * 4 + i) * 0.2;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      final colorIndex = ((progress * 7 + i) % rainbowColors.length).floor();
      final particleOpacity = ((sin(progress * pi * 2 + i) + 1) / 2).clamp(
        0.0,
        1.0,
      );

      particles.add(
        Positioned(
          left: widget.size / 2 + x - 7,
          top: widget.size / 2 + y - 7,
          child: Transform.scale(
            scale: pulseSize,
            child: CustomPaint(
              size: const Size(14, 14),
              painter: _StarPainter(
                color: rainbowColors[colorIndex].withOpacity(
                  (particleOpacity * 0.9).clamp(0.0, 1.0),
                ),
                points: 5,
                innerRadius: 0.4,
              ),
            ),
          ),
        ),
      );
    }

    // 중간 레이어 (다이아몬드, 반대 방향)
    for (int i = 0; i < particleCount; i++) {
      final angle = (i * (360 / particleCount) - progress * 300) * pi / 180;
      final radius = widget.size * 0.28;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      final colorIndex = ((progress * 5 + i + 3) % rainbowColors.length)
          .floor();
      final particleOpacity = ((cos(progress * pi * 3 + i) + 1) / 2).clamp(
        0.0,
        1.0,
      );

      particles.add(
        Positioned(
          left: widget.size / 2 + x - 4,
          top: widget.size / 2 + y - 4,
          child: Transform.rotate(
            angle: progress * pi * 2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: rainbowColors[colorIndex].withOpacity(
                  (particleOpacity * 0.8).clamp(0.0, 1.0),
                ),
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(
                    color: rainbowColors[colorIndex].withOpacity(
                      (particleOpacity * 0.5).clamp(0.0, 1.0),
                    ),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 내부 글리터
    for (int i = 0; i < particleCount + 2; i++) {
      final angle =
          (i * (360 / (particleCount + 2)) + progress * 180) * pi / 180;
      final radius = widget.size * 0.15;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      final particleOpacity = ((sin(progress * pi * 6 + i * 1.5) + 1) / 2)
          .clamp(0.0, 1.0);

      particles.add(
        Positioned(
          left: widget.size / 2 + x - 2,
          top: widget.size / 2 + y - 2,
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(
                (particleOpacity * 0.9).clamp(0.0, 1.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withOpacity(
                    (particleOpacity * 0.7).clamp(0.0, 1.0),
                  ),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return particles;
  }

  // 이모탈 등급: 최고급 효과 - 다중 별 + 오라 링 + 스파클
  List<Widget> _buildImmortalParticles() {
    final particleCount = (widget.level ~/ 5).clamp(1, 6);
    final progress = _particleController.value;
    final List<Widget> particles = [];

    // 황금빛 + 붉은 그라데이션 색상
    final immortalColors = [
      Colors.red.shade400,
      Colors.orange.shade300,
      Colors.amber,
      Colors.yellow.shade200,
      Colors.white,
    ];

    // 오라 링 효과
    particles.add(
      Positioned(
        left: 0,
        top: 0,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _AuraRingPainter(
              progress: progress,
              color: Colors.red.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );

    // 외곽 대형 별 (트레일 포함)
    for (int trail = 3; trail >= 0; trail--) {
      final trailProgress = (progress - trail * 0.03).clamp(0.0, 1.0);
      final trailOpacity = (1.0 - trail * 0.25).clamp(0.0, 1.0);

      for (int i = 0; i < particleCount; i++) {
        final angle =
            (i * (360 / particleCount) + trailProgress * 500) * pi / 180;
        final radius = widget.size * 0.42;
        final x = cos(angle) * radius;
        final y = sin(angle) * radius;
        final colorIndex = ((progress * 10 + i) % immortalColors.length)
            .floor();
        final particleOpacity =
            ((sin(progress * pi * 2 + i) + 1) / 2 * trailOpacity).clamp(
              0.0,
              1.0,
            );
        final pulseSize = 1.0 + sin(progress * pi * 3 + i) * 0.15;

        particles.add(
          Positioned(
            left: widget.size / 2 + x - 8,
            top: widget.size / 2 + y - 8,
            child: Transform.scale(
              scale: pulseSize * (1.0 - trail * 0.15),
              child: CustomPaint(
                size: const Size(16, 16),
                painter: _StarPainter(
                  color: immortalColors[colorIndex].withOpacity(
                    (particleOpacity * 0.95).clamp(0.0, 1.0),
                  ),
                  points: 6,
                  innerRadius: 0.5,
                ),
              ),
            ),
          ),
        );
      }
    }

    // 중간 링 (다이아몬드, 반대 회전)
    for (int i = 0; i < particleCount + 2; i++) {
      final angle =
          (i * (360 / (particleCount + 2)) - progress * 350) * pi / 180;
      final radius = widget.size * 0.30;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      final colorIndex = ((progress * 8 + i + 2) % immortalColors.length)
          .floor();
      final particleOpacity = ((cos(progress * pi * 3 + i) + 1) / 2).clamp(
        0.0,
        1.0,
      );

      particles.add(
        Positioned(
          left: widget.size / 2 + x - 5,
          top: widget.size / 2 + y - 5,
          child: Transform.rotate(
            angle: progress * pi * 3,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: immortalColors[colorIndex].withOpacity(
                  (particleOpacity * 0.85).clamp(0.0, 1.0),
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(
                      (particleOpacity * 0.6).clamp(0.0, 1.0),
                    ),
                    blurRadius: 10,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: Colors.orange.withOpacity(
                      (particleOpacity * 0.4).clamp(0.0, 1.0),
                    ),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 내부 스파클 (반짝이는 점)
    for (int i = 0; i < particleCount * 2; i++) {
      final angle =
          (i * (360 / (particleCount * 2)) + progress * 200) * pi / 180;
      final radius = widget.size * 0.18;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      final sparkle = sin(progress * pi * 8 + i * 2);
      final particleOpacity = (sparkle > 0.5 ? 1.0 : sparkle.clamp(0.0, 1.0));

      particles.add(
        Positioned(
          left: widget.size / 2 + x - 2,
          top: widget.size / 2 + y - 2,
          child: Container(
            width: 4 + sparkle * 2,
            height: 4 + sparkle * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(
                (particleOpacity * 0.95).clamp(0.0, 1.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(
                    (particleOpacity * 0.8).clamp(0.0, 1.0),
                  ),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return particles;
  }

  // 강화 레벨 배지 (왼쪽 아래, 작게)
  Widget _buildLevelBadge() {
    // 크기에 비례하는 폰트 사이즈 (최소 8, 최대 12)
    final fontSize = (widget.size * 0.22).clamp(8.0, 12.0);
    final paddingH = (widget.size * 0.06).clamp(2.0, 6.0);
    final paddingV = (widget.size * 0.02).clamp(1.0, 3.0);
    final borderRadius = (widget.size * 0.08).clamp(4.0, 8.0);

    return Positioned(
      bottom: widget.size * 0.02,
      left: widget.size * 0.02,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: _glowColor.withOpacity(0.7), width: 1),
        ),
        child: Text(
          '+${widget.level}',
          style: TextStyle(
            color: _glowColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
