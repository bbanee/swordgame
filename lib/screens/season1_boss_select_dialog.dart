import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/bosses.dart';
import '../models/boss_data.dart';
import '../models/owned_sword.dart';
import '../utils/helpers.dart';

class Season1BossSelectDialog extends StatelessWidget {
  static const _baseAsset = 'assets/images/home/season1_boss_scene_body_v1.png';
  static const _baseWidth = 941.0;
  static const _baseHeight = 1672.0;

  final OwnedSword? equippedSword;
  final Map<String, DateTime> bossCooldowns;
  final DateTime serverNow;
  final int bossCore;
  final void Function(BossData boss) onChallenge;
  final void Function(BossData boss) onSkipCooldown;

  const Season1BossSelectDialog({
    super.key,
    required this.equippedSword,
    required this.bossCooldowns,
    required this.serverNow,
    required this.bossCore,
    required this.onChallenge,
    required this.onSkipCooldown,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _BossLayout(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  _baseAsset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
              _box(layout, _BossRects.core, _fitText(layout, '$bossCore', 22)),
              _tap(layout, _BossRects.close, () => Navigator.pop(context)),
              _heroBoss(layout, allBosses.first),
              for (var i = 1; i < allBosses.length; i++)
                _smallBoss(layout, _BossRects.cards[i - 1], allBosses[i]),
            ],
          );
        },
      ),
    );
  }

  Widget _heroBoss(_BossLayout layout, BossData boss) {
    final status = _statusFor(boss);
    return Stack(
      children: [
        _box(layout, _BossRects.heroName, _fitText(layout, boss.name, 28)),
        _box(
          layout,
          _BossRects.heroStats,
          _fitText(
            layout,
            'HP ${formatGold(boss.hp)}  ATK ${formatGold(boss.atk)}  Lv.${boss.minLevel}+',
            19,
            color: Colors.white70,
          ),
        ),
        _box(
          layout,
          _BossRects.heroReward,
          _fitText(
            layout,
            '${formatGold(boss.goldReward)}G  ${boss.diamondReward}D',
            22,
            color: Colors.amberAccent,
          ),
        ),
        _box(
          layout,
          _BossRects.heroCooldown,
          _fitText(layout, status.text, 20, color: status.color),
        ),
        _tap(layout, _BossRects.heroPanel, () => _handleTap(boss, status)),
      ],
    );
  }

  Widget _smallBoss(_BossLayout layout, Rect rect, BossData boss) {
    final status = _statusFor(boss);
    final name = Rect.fromLTWH(rect.left + 62, rect.top + 151, 304, 38);
    final info = Rect.fromLTWH(rect.left + 62, rect.top + 197, 304, 34);
    final button = Rect.fromLTWH(rect.left + 104, rect.top + 254, 252, 58);

    return Stack(
      children: [
        _box(layout, name, _fitText(layout, boss.name, 21)),
        _box(
          layout,
          info,
          _fitText(
            layout,
            'Lv.${boss.minLevel}+  ${formatGold(boss.goldReward)}G',
            16,
            color: Colors.white70,
          ),
        ),
        _box(
          layout,
          button,
          _fitText(layout, status.text, 21, color: status.color),
        ),
        _tap(layout, rect, () => _handleTap(boss, status)),
      ],
    );
  }

  _BossStatus _statusFor(BossData boss) {
    final myLevel = equippedSword?.level ?? 0;
    if (equippedSword == null || myLevel < boss.minLevel) {
      return const _BossStatus('잠김', Colors.redAccent, false, false);
    }

    final cooldown = bossCooldowns[boss.id];
    if (cooldown != null && cooldown.isAfter(serverNow)) {
      final remaining = cooldown.difference(serverNow);
      final text = remaining.inHours > 0
          ? '${remaining.inHours}시간 ${remaining.inMinutes % 60}분'
          : '${math.max(1, remaining.inMinutes)}분';
      return _BossStatus(text, Colors.cyanAccent, true, false);
    }

    return const _BossStatus('도전', Colors.white, false, true);
  }

  void _handleTap(BossData boss, _BossStatus status) {
    if (status.onCooldown) {
      onSkipCooldown(boss);
      return;
    }
    if (status.canChallenge) onChallenge(boss);
  }

  Widget _box(_BossLayout layout, Rect rect, Widget child) {
    return Positioned.fromRect(rect: layout.r(rect), child: child);
  }

  Widget _tap(_BossLayout layout, Rect rect, VoidCallback onTap) {
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

  Widget _fitText(
    _BossLayout layout,
    String text,
    double baseSize, {
    Color color = Colors.white,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: layout.u(4)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: color,
            fontSize: layout.u(baseSize),
            fontWeight: FontWeight.w900,
            height: 1,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BossStatus {
  final String text;
  final Color color;
  final bool onCooldown;
  final bool canChallenge;

  const _BossStatus(this.text, this.color, this.onCooldown, this.canChallenge);
}

class _BossLayout {
  final double width;
  final double height;
  late final double sx = width / Season1BossSelectDialog._baseWidth;
  late final double sy = height / Season1BossSelectDialog._baseHeight;
  late final double s = math.min(sx, sy);

  _BossLayout(this.width, this.height);

  double u(double value) => value * s;

  Rect r(Rect rect) => Rect.fromLTWH(
    rect.left * sx,
    rect.top * sy,
    rect.width * sx,
    rect.height * sy,
  );
}

class _BossRects {
  static const close = Rect.fromLTWH(0, 0, 110, 110);
  static const core = Rect.fromLTWH(742, 346, 116, 42);
  static const heroPanel = Rect.fromLTWH(35, 428, 870, 424);
  static const heroName = Rect.fromLTWH(414, 468, 430, 56);
  static const heroStats = Rect.fromLTWH(420, 562, 424, 42);
  static const heroReward = Rect.fromLTWH(438, 652, 400, 78);
  static const heroCooldown = Rect.fromLTWH(552, 762, 298, 54);
  static const cards = [
    Rect.fromLTWH(31, 896, 426, 330),
    Rect.fromLTWH(489, 896, 426, 330),
    Rect.fromLTWH(31, 1246, 426, 330),
    Rect.fromLTWH(489, 1246, 426, 330),
  ];
}
