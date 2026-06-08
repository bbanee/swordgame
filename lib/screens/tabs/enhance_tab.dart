import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../enums/sword_grade.dart';
import '../../models/owned_sword.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/sword_image_widget.dart';

class EnhanceTab extends StatelessWidget {
  static const _baseAsset =
      'assets/images/home/season1_enhance_scene_body_v2.png';
  static const _baseWidth = 941.0;
  static const _baseHeight = 1672.0;

  final String nickname;
  final int gold;
  final int diamond;
  final int totalPower;
  final int enhanceStone;
  final int bossCore;
  final int inventoryLength;
  final int maxInventory;
  final bool useEnhanceStone;
  final bool showEnhanceEffect;
  final int maxEnhanceLevel;
  final bool canBreakthrough;
  final OwnedSword? equippedSword;

  final VoidCallback onEnhance;
  final VoidCallback onBreakthrough;
  final Function(OwnedSword) onSellSword;
  final VoidCallback onQuickGacha;
  final Function(bool) onToggleEnhanceStone;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenInventory;
  final VoidCallback onOpenEnhance;
  final VoidCallback onOpenBattle;
  final VoidCallback onOpenShop;

  const EnhanceTab({
    super.key,
    required this.nickname,
    required this.gold,
    required this.diamond,
    required this.totalPower,
    required this.enhanceStone,
    required this.bossCore,
    required this.inventoryLength,
    required this.maxInventory,
    required this.useEnhanceStone,
    required this.showEnhanceEffect,
    required this.maxEnhanceLevel,
    required this.canBreakthrough,
    required this.equippedSword,
    required this.onEnhance,
    required this.onBreakthrough,
    required this.onSellSword,
    required this.onQuickGacha,
    required this.onToggleEnhanceStone,
    required this.onOpenHome,
    required this.onOpenInventory,
    required this.onOpenEnhance,
    required this.onOpenBattle,
    required this.onOpenShop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _EnhanceLayout(
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
              ..._buildDataOverlays(layout),
              ..._buildTapOverlays(layout),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildDataOverlays(_EnhanceLayout layout) {
    final sword = equippedSword;
    final cost = sword == null ? 0 : getEnhanceCost(sword.level);
    final successRate = sword == null
        ? 0.0
        : getEnhanceSuccessRate(sword.level);
    final destroyRate = sword == null
        ? 0.0
        : getEnhanceDestroyRate(sword.level);
    final keepRate = (100 - successRate - destroyRate).clamp(0.0, 100.0);
    final canEnhance =
        sword != null && gold >= cost && sword.level < maxEnhanceLevel;

    return [
      if (sword != null)
        _box(
          layout,
          _EnhanceRects.sword,
          Center(
            child: SwordImageWidget(
              grade: sword.data.grade,
              element: sword.data.element,
              swordId: sword.data.id,
              level: sword.level,
              breakthroughLevel: sword.breakthroughLevel,
              size: layout.u(520),
              showPulse: true,
              showEnhanceEffect: showEnhanceEffect,
            ),
          ),
        ),
      _box(
        layout,
        _EnhanceRects.swordName,
        _fitText(
          layout,
          sword?.data.name ?? '장착된 검 없음',
          29,
          color: sword?.data.grade.color ?? Colors.white70,
          fontWeight: FontWeight.w900,
        ),
      ),
      _box(
        layout,
        _EnhanceRects.enhanceLevel,
        _fitText(
          layout,
          sword == null ? '-' : '+${sword.level} / +$maxEnhanceLevel',
          28,
          color: const Color(0xFFFFD166),
          fontWeight: FontWeight.w900,
        ),
      ),
      _box(
        layout,
        _EnhanceRects.breakthroughLevel,
        _fitText(
          layout,
          sword == null
              ? '-'
              : '${sword.breakthroughLevel} / ${AppConstants.maxBreakthroughLevel}',
          28,
          color: const Color(0xFF7BD3FF),
          fontWeight: FontWeight.w900,
        ),
      ),
      _probability(
        layout,
        _EnhanceRects.successRate,
        successRate,
        Colors.green,
      ),
      _probability(layout, _EnhanceRects.keepRate, keepRate, Colors.white70),
      _probability(
        layout,
        _EnhanceRects.destroyRate,
        destroyRate,
        destroyRate > 0 ? Colors.redAccent : Colors.white38,
      ),
      if (useEnhanceStone)
        _box(
          layout,
          _EnhanceRects.stoneCheck,
          Icon(Icons.check, color: const Color(0xFF6EF5A1), size: layout.u(40)),
        ),
      _box(
        layout,
        _EnhanceRects.stoneBonus,
        _fitText(
          layout,
          '성공 +10%  파괴 -5%',
          20,
          color: useEnhanceStone ? const Color(0xFFC979FF) : Colors.white54,
          fontWeight: FontWeight.w800,
        ),
      ),
      _box(
        layout,
        _EnhanceRects.stoneOwned,
        _fitText(
          layout,
          formatNumber(enhanceStone),
          22,
          color: const Color(0xFFC979FF),
          fontWeight: FontWeight.w900,
        ),
      ),
      _box(
        layout,
        _EnhanceRects.cost,
        _fitText(
          layout,
          sword == null ? '-' : '${formatGold(cost)} G',
          26,
          color: canEnhance ? const Color(0xFFFFC94A) : Colors.redAccent,
          fontWeight: FontWeight.w900,
        ),
      ),
    ];
  }

  List<Widget> _buildTapOverlays(_EnhanceLayout layout) {
    final sword = equippedSword;
    final cost = sword == null ? 0 : getEnhanceCost(sword.level);
    final canEnhance =
        sword != null && gold >= cost && sword.level < maxEnhanceLevel;

    return [
      _tap(
        layout,
        _EnhanceRects.stoneToggle,
        () => onToggleEnhanceStone(!useEnhanceStone),
      ),
      if (canEnhance) _tap(layout, _EnhanceRects.enhanceButton, onEnhance),
      if (canBreakthrough)
        _tap(layout, _EnhanceRects.breakthroughButton, onBreakthrough),
      if (sword != null)
        _tap(layout, _EnhanceRects.sellButton, () => onSellSword(sword)),
      if (inventoryLength < maxInventory && gold >= 500)
        _tap(layout, _EnhanceRects.quickGachaButton, onQuickGacha),
    ];
  }

  Widget _probability(
    _EnhanceLayout layout,
    Rect rect,
    double value,
    Color color,
  ) {
    return _box(
      layout,
      rect,
      _fitText(
        layout,
        formatPercent(value),
        28,
        color: color,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _fitText(
    _EnhanceLayout layout,
    String text,
    double baseSize, {
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w700,
    Alignment align = Alignment.center,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: layout.u(3)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: align,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: color,
            fontSize: layout.u(baseSize),
            fontWeight: fontWeight,
            height: 1,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box(_EnhanceLayout layout, Rect rect, Widget child) {
    return Positioned.fromRect(rect: layout.r(rect), child: child);
  }

  Widget _tap(_EnhanceLayout layout, Rect rect, VoidCallback onTap) {
    return _box(
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

class _EnhanceLayout {
  final double width;
  final double height;
  late final double sx = width / EnhanceTab._baseWidth;
  late final double sy = height / EnhanceTab._baseHeight;
  late final double s = math.min(sx, sy);

  _EnhanceLayout(this.width, this.height);

  double u(double value) => value * s;

  Rect r(Rect rect) {
    return Rect.fromLTWH(
      rect.left * sx,
      rect.top * sy,
      rect.width * sx,
      rect.height * sy,
    );
  }
}

class _EnhanceRects {
  // Coordinates are measured against season1_enhance_scene_body_v2.png (941x1672).
  static const sword = Rect.fromLTWH(230, 136, 480, 520);
  static const swordName = Rect.fromLTWH(253, 604, 414, 78);
  static const enhanceLevel = Rect.fromLTWH(43, 612, 168, 72);
  static const breakthroughLevel = Rect.fromLTWH(725, 612, 168, 72);

  static const successRate = Rect.fromLTWH(69, 922, 230, 46);
  static const keepRate = Rect.fromLTWH(350, 922, 230, 46);
  static const destroyRate = Rect.fromLTWH(632, 922, 230, 46);
  static const stoneToggle = Rect.fromLTWH(50, 1004, 891, 76);
  static const stoneCheck = Rect.fromLTWH(253, 1014, 47, 47);
  static const stoneBonus = Rect.fromLTWH(331, 1014, 232, 48);
  static const stoneOwned = Rect.fromLTWH(770, 1014, 98, 48);
  static const cost = Rect.fromLTWH(372, 1104, 345, 48);

  static const enhanceButton = Rect.fromLTWH(225, 1175, 516, 84);
  static const breakthroughButton = Rect.fromLTWH(54, 1300, 265, 84);
  static const sellButton = Rect.fromLTWH(336, 1300, 265, 84);
  static const quickGachaButton = Rect.fromLTWH(620, 1300, 265, 84);
}
