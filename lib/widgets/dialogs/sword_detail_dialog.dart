import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../enums/element.dart';
import '../../enums/skill_effect.dart';
import '../../enums/skill_type.dart';
import '../../enums/sword_grade.dart';
import '../../models/owned_sword.dart';
import '../../models/sword_data.dart';
import '../../utils/helpers.dart';
import '../sword_image_widget.dart';

class SwordDetailDialog extends StatelessWidget {
  static const _baseAsset =
      'assets/images/home/season1_sword_detail_scene_body_v1.png';
  static const _baseWidth = 941.0;
  static const _baseHeight = 1671.0;

  final OwnedSword sword;
  final bool isEquipped;
  final bool canSell;
  final VoidCallback? onEquip;
  final VoidCallback? onSell;

  const SwordDetailDialog({
    super.key,
    required this.sword,
    this.isEquipped = false,
    this.canSell = true,
    this.onEquip,
    this.onSell,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _SwordDetailLayout(
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
                  ..._buildOverlays(context, layout),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildOverlays(BuildContext context, _SwordDetailLayout layout) {
    return [
      _box(
        layout,
        _SwordDetailRects.title,
        _fitText(layout, '검 상세', 44, fontWeight: FontWeight.w900),
      ),
      _tap(layout, _SwordDetailRects.close, () => Navigator.pop(context)),
      _box(layout, _SwordDetailRects.sword, _swordArt(layout)),
      _box(
        layout,
        _SwordDetailRects.name,
        _fitText(
          layout,
          '${sword.data.name} +${sword.level}',
          30,
          color: sword.data.grade.color,
          fontWeight: FontWeight.w900,
        ),
      ),
      for (var i = 0; i < _statRows.length; i++)
        _box(
          layout,
          _SwordDetailRects.stats[i],
          _statText(layout, _statRows[i]),
        ),
      for (var i = 0; i < _skillRows.length; i++)
        _box(layout, _SwordDetailRects.skills[i], _skillText(layout, i)),
      _box(
        layout,
        _SwordDetailRects.sellButton,
        _buttonText(layout, _sellLabel),
      ),
      _box(
        layout,
        _SwordDetailRects.equipButton,
        _buttonText(layout, isEquipped ? '장착 중' : '장착하기'),
      ),
      _box(layout, _SwordDetailRects.closeButton, _buttonText(layout, '닫기')),
      _tap(
        layout,
        _SwordDetailRects.sellButton,
        onSell == null || !canSell
            ? null
            : () {
                Navigator.pop(context);
                onSell?.call();
              },
      ),
      _tap(
        layout,
        _SwordDetailRects.equipButton,
        isEquipped || onEquip == null
            ? null
            : () {
                Navigator.pop(context);
                onEquip?.call();
              },
      ),
      _tap(layout, _SwordDetailRects.closeButton, () => Navigator.pop(context)),
    ];
  }

  List<(String, String, Color)> get _statRows {
    final enhanceBonus = sword.level * sword.powerPerLevel;
    return [
      ('등급', sword.data.grade.displayName, sword.data.grade.color),
      ('속성', sword.data.element.nameKr, sword.data.element.color),
      ('전투력', formatNumber(sword.totalPower), const Color(0xFFFFD86B)),
      ('기본공격력', formatNumber(sword.data.baseAtk), Colors.white),
      ('강화수치', '+${sword.level} / 보너스 +$enhanceBonus', Colors.white),
      ('돌파', '+${sword.breakthroughLevel}', Colors.white),
    ];
  }

  List<SkillData> get _skillRows => sword.data.skills.take(5).toList();

  String get _sellLabel =>
      canSell ? '판매 ${formatGold(sword.sellPrice)}G' : '판매 불가';

  Widget _swordArt(_SwordDetailLayout layout) {
    return Center(
      child: SwordImageWidget(
        grade: sword.data.grade,
        element: sword.data.element,
        swordId: sword.data.id,
        level: sword.level,
        breakthroughLevel: sword.breakthroughLevel,
        size: layout.u(360),
        showPulse: true,
      ),
    );
  }

  Widget _statText(_SwordDetailLayout layout, (String, String, Color) row) {
    return Padding(
      padding: EdgeInsets.only(left: layout.u(98), right: layout.u(16)),
      child: Row(
        children: [
          SizedBox(
            width: layout.u(112),
            child: _plainText(layout, row.$1, 17, color: Colors.white70),
          ),
          Expanded(
            child: _plainText(
              layout,
              row.$2,
              20,
              color: row.$3,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillText(_SwordDetailLayout layout, int index) {
    if (index >= _skillRows.length) {
      return Center(
        child: _fitText(layout, '스킬 없음', 18, color: Colors.white38),
      );
    }
    final skill = _skillRows[index];
    return Padding(
      padding: EdgeInsets.only(left: layout.u(100), right: layout.u(20)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _plainText(
            layout,
            '${skill.name}  ${skill.procRate}%',
            17,
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
          SizedBox(height: layout.u(4)),
          _plainText(
            layout,
            _getSkillDescription(skill),
            13,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _buttonText(_SwordDetailLayout layout, String text) {
    return _fitText(layout, text, 25, fontWeight: FontWeight.w900);
  }

  String _getSkillDescription(SkillData skill) {
    final dmgText = '${(skill.multiplier * 100).toInt()}% 피해';

    switch (skill.effect) {
      case SkillEffect.damage:
        return '$dmgText를 입힙니다. ${skill.type.description}';
      case SkillEffect.bleed:
        return '$dmgText + ${skill.value}턴간 지속 피해를 입힙니다.';
      case SkillEffect.pierce:
        return '$dmgText를 입히고 방어력을 무시합니다.';
      case SkillEffect.critBoost:
        return '$dmgText + 치명타 확률이 ${skill.value}% 증가합니다.';
      case SkillEffect.lifesteal:
        return '$dmgText를 입히고 ${skill.value}%를 회복합니다.';
      case SkillEffect.heal:
        return 'HP를 ${skill.value}% 회복합니다.';
      case SkillEffect.regen:
        return '${skill.value}턴간 매 턴 HP를 회복합니다.';
      case SkillEffect.stun:
        return '$dmgText + ${skill.value}% 확률로 기절시킵니다.';
      case SkillEffect.slow:
        return '$dmgText + 적의 적중률을 ${skill.value}% 감소시킵니다.';
      case SkillEffect.weaken:
        return '$dmgText + 적의 공격력을 ${skill.value}% 감소시킵니다.';
      case SkillEffect.shield:
        return '피해의 ${skill.value}%만큼 보호막을 생성합니다.';
      case SkillEffect.dodge:
        return '회피율이 ${skill.value}% 증가합니다.';
      case SkillEffect.attackBoost:
        return '공격력이 ${skill.value}% 증가합니다.';
    }
  }

  Widget _plainText(
    _SwordDetailLayout layout,
    String text,
    double baseSize, {
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w800,
  }) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: layout.u(baseSize),
        fontWeight: fontWeight,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
  }

  Widget _fitText(
    _SwordDetailLayout layout,
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

  Widget _box(_SwordDetailLayout layout, Rect rect, Widget child) {
    return Positioned.fromRect(rect: layout.r(rect), child: child);
  }

  Widget _tap(_SwordDetailLayout layout, Rect rect, VoidCallback? onTap) {
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

class _SwordDetailLayout {
  final double width;
  final double height;
  late final double sx = width / SwordDetailDialog._baseWidth;
  late final double sy = height / SwordDetailDialog._baseHeight;
  late final double s = math.min(sx, sy);

  _SwordDetailLayout(this.width, this.height);

  double u(double value) => value * s;

  Rect r(Rect rect) => Rect.fromLTWH(
    rect.left * sx,
    rect.top * sy,
    rect.width * sx,
    rect.height * sy,
  );
}

class _SwordDetailRects {
  static const close = Rect.fromLTWH(23, 27, 100, 100);
  static const title = Rect.fromLTWH(205, 67, 535, 120);
  static const sword = Rect.fromLTWH(193, 233, 552, 500);
  static const name = Rect.fromLTWH(160, 779, 620, 69);
  static const stats = [
    Rect.fromLTWH(34, 916, 380, 60),
    Rect.fromLTWH(34, 1002, 380, 60),
    Rect.fromLTWH(34, 1092, 380, 60),
    Rect.fromLTWH(34, 1182, 380, 60),
    Rect.fromLTWH(34, 1272, 380, 60),
    Rect.fromLTWH(34, 1360, 380, 60),
  ];
  static const skills = [
    Rect.fromLTWH(446, 937, 448, 72),
    Rect.fromLTWH(446, 1046, 448, 72),
    Rect.fromLTWH(446, 1154, 448, 72),
    Rect.fromLTWH(446, 1262, 448, 72),
    Rect.fromLTWH(446, 1370, 448, 72),
  ];
  static const sellButton = Rect.fromLTWH(45, 1504, 260, 86);
  static const equipButton = Rect.fromLTWH(326, 1504, 290, 86);
  static const closeButton = Rect.fromLTWH(637, 1504, 260, 86);
}
