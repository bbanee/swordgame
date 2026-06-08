import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/battle_record.dart';
import '../../models/owned_sword.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class BattleTab extends StatelessWidget {
  static const _baseAsset =
      'assets/images/home/season1_battle_scene_body_v2.png';
  static const _recordFrameAsset =
      'assets/images/home/season1_battle_record_frame_v1.png';
  static const _baseWidth = 941.0;
  static const _baseHeight = 1672.0;

  final int battleCount;
  final int battleWinStreak;
  final List<BattleRecord> battleRecords;
  final OwnedSword? equippedSword;

  final VoidCallback onRandomBattle;
  final VoidCallback onSelectBattle;
  final VoidCallback onRefreshRecords;
  final Function(BattleRecord) onRevengeBattle;

  const BattleTab({
    super.key,
    required this.battleCount,
    required this.battleWinStreak,
    required this.battleRecords,
    required this.equippedSword,
    required this.onRandomBattle,
    required this.onSelectBattle,
    required this.onRefreshRecords,
    required this.onRevengeBattle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _BattleLayout(
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
            _box(
              layout,
              _BattleRects.count,
              _fitText(
                layout,
                '$battleCount/${AppConstants.dailyBattleCount}',
                34,
              ),
            ),
            _box(
              layout,
              _BattleRects.streak,
              _fitText(layout, '$battleWinStreak', 34),
            ),
            _box(
              layout,
              _BattleRects.status,
              _fitText(
                layout,
                equippedSword == null ? '장착된 검이 없습니다' : '장착 검 준비 완료',
                26,
                color: equippedSword == null ? Colors.redAccent : Colors.white,
              ),
            ),
            _tap(
              layout,
              _BattleRects.randomButton,
              battleCount > 0 && equippedSword != null ? onRandomBattle : null,
            ),
            _tap(
              layout,
              _BattleRects.selectButton,
              battleCount > 0 && equippedSword != null ? onSelectBattle : null,
            ),
            _tap(layout, _BattleRects.refreshButton, onRefreshRecords),
            _box(layout, _BattleRects.records, _records(layout)),
          ],
        );
      },
    );
  }

  Widget _records(_BattleLayout layout) {
    if (battleRecords.isEmpty) {
      return Center(
        child: _fitText(layout, '배틀 기록이 없습니다', 26, color: Colors.white70),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        layout.u(24),
        layout.u(62),
        layout.u(24),
        layout.u(24),
      ),
      itemCount: battleRecords.length,
      itemBuilder: (_, index) => _recordRow(layout, battleRecords[index]),
    );
  }

  Widget _recordRow(_BattleLayout layout, BattleRecord record) {
    final result = record.isWin ? '승리' : '패배';
    final resultColor = record.isWin
        ? Colors.lightGreenAccent
        : Colors.redAccent;
    final side = record.isAttacker ? '공격' : '방어';
    final reward = record.isWin && record.goldEarned > 0
        ? '+${formatGold(record.goldEarned)}G'
        : '';

    return Padding(
      padding: EdgeInsets.only(bottom: layout.u(20)),
      child: SizedBox(
        height: layout.u(127),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sx = constraints.maxWidth / 819.0;
            final sy = constraints.maxHeight / 127.0;
            Rect r(Rect rect) => Rect.fromLTWH(
              rect.left * sx,
              rect.top * sy,
              rect.width * sx,
              rect.height * sy,
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    _recordFrameAsset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Positioned.fromRect(
                  rect: r(_BattleRecordRects.name),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _plainText(
                      layout,
                      '${record.opponentName}${record.opponentIsNpc ? ' (AI)' : ''}',
                      23,
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: r(_BattleRecordRects.meta),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _plainText(
                      layout,
                      'Lv.${record.opponentLevel}  $side  ${record.timeAgo}',
                      17,
                      color: Colors.white70,
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: r(_BattleRecordRects.result),
                  child: Center(
                    child: _fitText(layout, result, 22, color: resultColor),
                  ),
                ),
                Positioned.fromRect(
                  rect: r(_BattleRecordRects.reward),
                  child: record.isRevengeable && battleCount > 0
                      ? GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => onRevengeBattle(record),
                          child: Center(child: _fitText(layout, '복수', 22)),
                        )
                      : Center(
                          child: _fitText(
                            layout,
                            reward.isEmpty ? '-' : reward,
                            18,
                            color: Colors.amberAccent,
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _plainText(
    _BattleLayout layout,
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

  Widget _fitText(
    _BattleLayout layout,
    String text,
    double baseSize, {
    Color color = Colors.white,
  }) {
    final fontSize = layout.u(baseSize);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: layout.u(6)),
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
              fontWeight: FontWeight.w900,
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

  Widget _box(_BattleLayout layout, Rect rect, Widget child) {
    return Positioned.fromRect(rect: layout.r(rect), child: child);
  }

  Widget _tap(_BattleLayout layout, Rect rect, VoidCallback? onTap) {
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

class _BattleLayout {
  final double width;
  final double height;
  late final double sx = width / BattleTab._baseWidth;
  late final double sy = height / BattleTab._baseHeight;
  late final double s = math.min(sx, sy);

  _BattleLayout(this.width, this.height);

  double u(double value) => value * s;

  Rect r(Rect rect) => Rect.fromLTWH(
    rect.left * sx,
    rect.top * sy,
    rect.width * sx,
    rect.height * sy,
  );
}

class _BattleRects {
  static const count = Rect.fromLTWH(88, 399, 194, 74);
  static const streak = Rect.fromLTWH(652, 399, 194, 74);
  static const status = Rect.fromLTWH(196, 506, 650, 92);
  static const refreshButton = Rect.fromLTWH(812, 772, 72, 56);
  static const randomButton = Rect.fromLTWH(50, 642, 405, 92);
  static const selectButton = Rect.fromLTWH(486, 642, 405, 92);
  static const records = Rect.fromLTWH(38, 792, 866, 688);
}

class _BattleRecordRects {
  static const name = Rect.fromLTWH(174, 31, 320, 34);
  static const meta = Rect.fromLTWH(174, 69, 320, 28);
  static const result = Rect.fromLTWH(476, 44, 144, 54);
  static const reward = Rect.fromLTWH(654, 44, 140, 54);
}
