import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../enums/element.dart';
import '../../enums/skill_type.dart';
import '../../enums/sword_grade.dart';
import '../../models/daily_quest.dart';
import '../../models/owned_sword.dart';
import '../../models/sword_data.dart';
import '../../utils/helpers.dart';
import '../../widgets/sword_image_widget.dart';

class HomeTab extends StatelessWidget {
  static const _baseAsset = 'assets/images/home/season1_home_scene_body_v3.png';
  static const _baseWidth = 941.0;
  static const _baseHeight = 1672.0;

  final String nickname;
  final int gold;
  final int diamond;
  final int enhanceStone;
  final int totalPower;
  final OwnedSword? equippedSword;
  final List<DailyQuest> dailyQuests;
  final int titleBonus;
  final String? titleName;

  final VoidCallback onShowGachaDialog;
  final VoidCallback onShowSynthesisDialog;
  final VoidCallback onShowBossSelectDialog;
  final VoidCallback onShowRankingDialog;
  final VoidCallback onOpenMinigame;
  final VoidCallback onOpenInfiniteTower;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenInventory;
  final VoidCallback onOpenEnhance;
  final VoidCallback onOpenBattle;
  final VoidCallback onOpenShop;
  final VoidCallback onShowSwordTestDialog;
  final Function(DailyQuest) onClaimQuestReward;

  const HomeTab({
    super.key,
    required this.nickname,
    required this.gold,
    required this.diamond,
    required this.enhanceStone,
    required this.totalPower,
    required this.equippedSword,
    required this.dailyQuests,
    this.titleBonus = 0,
    this.titleName,
    required this.onShowGachaDialog,
    required this.onShowSynthesisDialog,
    required this.onShowBossSelectDialog,
    required this.onShowRankingDialog,
    required this.onOpenMinigame,
    required this.onOpenInfiniteTower,
    required this.onOpenHome,
    required this.onOpenInventory,
    required this.onOpenEnhance,
    required this.onOpenBattle,
    required this.onOpenShop,
    required this.onShowSwordTestDialog,
    required this.onClaimQuestReward,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final layout = _HomeLayout(width, height);

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

  List<Widget> _buildDataOverlays(_HomeLayout layout) {
    final sword = equippedSword;

    return [
      if (sword != null)
        _box(
          layout,
          _HomeRects.sword,
          Center(
            child: SwordImageWidget(
              grade: sword.data.grade,
              element: sword.data.element,
              swordId: sword.data.id,
              level: sword.level,
              breakthroughLevel: sword.breakthroughLevel,
              size: layout.u(500),
              showPulse: true,
            ),
          ),
        ),
      _box(
        layout,
        _HomeRects.swordName,
        _fitText(
          layout,
          sword?.data.name ?? '장착된 검 없음',
          28,
          color: sword?.data.grade.color ?? Colors.white70,
          fontWeight: FontWeight.w900,
        ),
      ),
      ..._buildSwordInfo(layout, sword),
      ..._buildSkills(layout, sword?.data.skills ?? const []),
    ];
  }

  List<Widget> _buildSwordInfo(_HomeLayout layout, OwnedSword? sword) {
    final titleText = titleName == null || titleName!.isEmpty
        ? '-'
        : titleBonus > 0
        ? '$titleName +$titleBonus'
        : titleName!;

    return [
      _statValue(layout, _HomeRects.statElement, sword?.data.element.nameKr),
      _statValue(
        layout,
        _HomeRects.statPower,
        sword == null ? null : formatNumber(sword.totalPower + titleBonus),
      ),
      _statValue(
        layout,
        _HomeRects.statBaseAtk,
        sword == null ? null : formatNumber(sword.data.baseAtk),
      ),
      _statValue(
        layout,
        _HomeRects.statEnhance,
        sword == null ? null : '+${sword.level}',
        color: const Color(0xFF6EF5A1),
      ),
      _statValue(
        layout,
        _HomeRects.statTitle,
        sword == null ? null : titleText,
      ),
    ];
  }

  List<Widget> _buildSkills(_HomeLayout layout, List<SkillData> skills) {
    final widgets = <Widget>[];
    for (var i = 0; i < _HomeRects.skillIcons.length; i++) {
      final skill = i < skills.length ? skills[i] : null;
      widgets.add(
        _box(
          layout,
          _HomeRects.skillIcons[i],
          skill == null
              ? const SizedBox.shrink()
              : Center(
                  child: Icon(
                    _skillIcon(skill),
                    color: _skillColor(skill),
                    size: layout.u(46),
                  ),
                ),
        ),
      );
      widgets.add(
        _box(
          layout,
          _HomeRects.skillLabels[i],
          skill == null
              ? const SizedBox.shrink()
              : _fitText(
                  layout,
                  skill.name,
                  17,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildTapOverlays(_HomeLayout layout) {
    return [
      _tap(layout, _HomeRects.gachaButton, onShowGachaDialog),
      _tap(layout, _HomeRects.synthesisButton, onShowSynthesisDialog),
      _tap(layout, _HomeRects.bossButton, onShowBossSelectDialog),
      _tap(layout, _HomeRects.rankingButton, onShowRankingDialog),
      _tap(layout, _HomeRects.minigameButton, onOpenMinigame),
      _tap(layout, _HomeRects.towerButton, onOpenInfiniteTower),
      _box(layout, _HomeRects.testButton, _testButton(layout)),
      _tap(layout, _HomeRects.testButton, onShowSwordTestDialog),
    ];
  }

  Widget _testButton(_HomeLayout layout) {
    return Center(
      child: Container(
        width: layout.u(72),
        height: layout.u(34),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          border: Border.all(
            color: const Color(0xFFFFD86B).withValues(alpha: 0.75),
            width: layout.u(1),
          ),
          borderRadius: BorderRadius.circular(layout.u(6)),
        ),
        child: _fitText(
          layout,
          'TEST',
          14,
          color: const Color(0xFFFFD86B),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _statValue(
    _HomeLayout layout,
    Rect rect,
    String? value, {
    Color color = Colors.white,
  }) {
    return _box(
      layout,
      rect,
      _fitText(
        layout,
        value ?? '-',
        23,
        color: color,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _fitText(
    _HomeLayout layout,
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

  Widget _box(_HomeLayout layout, Rect rect, Widget child) {
    final scaled = layout.r(rect);
    return Positioned.fromRect(rect: scaled, child: child);
  }

  Widget _tap(_HomeLayout layout, Rect rect, VoidCallback onTap) {
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

  IconData _skillIcon(SkillData skill) {
    return switch (skill.type) {
      SkillType.slash => Icons.flash_on,
      SkillType.pierce => Icons.gps_fixed,
      SkillType.blast => Icons.whatshot,
      SkillType.drain => Icons.water_drop,
      SkillType.guard => Icons.shield,
    };
  }

  Color _skillColor(SkillData skill) {
    return switch (skill.type) {
      SkillType.slash => const Color(0xFFFFD166),
      SkillType.pierce => const Color(0xFF7BD3FF),
      SkillType.blast => const Color(0xFFFF6B4A),
      SkillType.drain => const Color(0xFFB277FF),
      SkillType.guard => const Color(0xFF6EF5A1),
    };
  }
}

class _HomeLayout {
  final double width;
  final double height;
  late final double sx = width / HomeTab._baseWidth;
  late final double sy = height / HomeTab._baseHeight;
  late final double s = math.min(sx, sy);

  _HomeLayout(this.width, this.height);

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

class _HomeRects {
  // Coordinates are measured against season1_home_scene_body_v3.png (941x1672).
  static const sword = Rect.fromLTWH(58, 286, 390, 625);
  static const swordName = Rect.fromLTWH(70, 922, 350, 48);

  static const statElement = Rect.fromLTWH(621, 334, 240, 34);
  static const statPower = Rect.fromLTWH(621, 406, 240, 33);
  static const statBaseAtk = Rect.fromLTWH(621, 477, 240, 33);
  static const statEnhance = Rect.fromLTWH(621, 548, 240, 34);
  static const statTitle = Rect.fromLTWH(621, 621, 240, 34);

  static const skillIcons = [
    Rect.fromLTWH(461, 750, 88, 106),
    Rect.fromLTWH(566, 750, 88, 106),
    Rect.fromLTWH(671, 750, 88, 106),
    Rect.fromLTWH(776, 750, 88, 106),
  ];
  static const skillLabels = [
    Rect.fromLTWH(461, 869, 88, 30),
    Rect.fromLTWH(566, 869, 88, 30),
    Rect.fromLTWH(671, 869, 88, 30),
    Rect.fromLTWH(776, 869, 88, 30),
  ];

  static const gachaButton = Rect.fromLTWH(51, 1032, 265, 212);
  static const synthesisButton = Rect.fromLTWH(338, 1032, 265, 212);
  static const bossButton = Rect.fromLTWH(625, 1032, 265, 212);
  static const rankingButton = Rect.fromLTWH(51, 1268, 265, 212);
  static const minigameButton = Rect.fromLTWH(338, 1268, 265, 212);
  static const towerButton = Rect.fromLTWH(625, 1268, 265, 212);
  static const testButton = Rect.fromLTWH(810, 26, 100, 58);
}
