import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/swords.dart';
import '../../enums/element.dart';
import '../../enums/sword_grade.dart';
import '../../models/player_profile.dart';
import '../../utils/helpers.dart';
import '../sword_image_widget.dart';

class Season1RankingDialog extends StatefulWidget {
  static const _baseAsset =
      'assets/images/home/season1_ranking_scene_body_v1.png';
  static const _rowFrameAsset =
      'assets/images/home/season1_battle_record_frame_v1.png';
  static const _baseWidth = 941.0;
  static const _baseHeight = 1671.0;

  final String userId;
  final List<Map<String, dynamic>> swordRankings;
  final List<Map<String, dynamic>> battleRankings;
  final List<Map<String, dynamic>> towerRankings;
  final List<PlayerProfile> codexRankings;

  const Season1RankingDialog({
    super.key,
    required this.userId,
    required this.swordRankings,
    required this.battleRankings,
    required this.towerRankings,
    required this.codexRankings,
  });

  @override
  State<Season1RankingDialog> createState() => _Season1RankingDialogState();
}

class _Season1RankingDialogState extends State<Season1RankingDialog> {
  int _tab = 0;

  static const _tabs = [
    '\uAC80 \uB7AD\uD0B9',
    '\uBC30\uD2C0\uC804\uC801',
    '\uBB34\uD55C\uC758\uD0D1',
    '\uB3C4\uAC10\uB7AD\uD0B9',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _RankingLayout(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            return ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      Season1RankingDialog._baseAsset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  _box(
                    layout,
                    _RankingRects.title,
                    _fitText(
                      layout,
                      '\uB7AD\uD0B9',
                      46,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  for (var i = 0; i < _tabs.length; i++)
                    _box(
                      layout,
                      _RankingRects.tabs[i],
                      _tabLabel(layout, _tabs[i], i == _tab),
                    ),
                  _box(layout, _RankingRects.list, _rankingList(layout)),
                  _tap(
                    layout,
                    _RankingRects.close,
                    () => Navigator.pop(context),
                  ),
                  for (var i = 0; i < _tabs.length; i++)
                    _tap(
                      layout,
                      _RankingRects.tabs[i],
                      () => setState(() => _tab = i),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tabLabel(_RankingLayout layout, String text, bool active) {
    return _fitText(
      layout,
      text,
      23,
      color: active ? const Color(0xFFFFD86B) : Colors.white,
      fontWeight: FontWeight.w900,
    );
  }

  Widget _rankingList(_RankingLayout layout) {
    final rows = _rows();
    if (rows.isEmpty) {
      return Center(
        child: _fitText(
          layout,
          '\uB7AD\uD0B9 \uB370\uC774\uD130\uAC00 \uC5C6\uC2B5\uB2C8\uB2E4',
          28,
          color: Colors.white70,
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        layout.u(24),
        layout.u(36),
        layout.u(24),
        layout.u(36),
      ),
      itemCount: math.min(rows.length, 100),
      itemBuilder: (_, index) => _rankingRow(layout, rows[index], index),
    );
  }

  List<_RankingRow> _rows() {
    return switch (_tab) {
      0 =>
        widget.swordRankings
            .map(
              (r) => _RankingRow(
                id: r['id'] as String? ?? '',
                name: r['name'] as String? ?? '\uBAA8\uD5D8\uAC00',
                detail:
                    '${r['swordName'] ?? '\uAC80'} +${r['swordLevel'] as int? ?? 0}',
                sub:
                    '\uC804\uD22C\uB825 ${formatNumber(r['power'] as int? ?? 0)}',
                score: formatNumber(r['power'] as int? ?? 0),
                swordId: r['swordId'] as String?,
                grade: r['swordGrade'] as SwordGrade? ?? SwordGrade.normal,
                element: r['element'] as GameElement? ?? GameElement.fire,
                level: r['swordLevel'] as int? ?? 0,
                breakthroughLevel: r['swordBreakthroughLevel'] as int? ?? 0,
                isNpc: r['isNpc'] == true,
                isOnline: r['isOnline'] == true,
              ),
            )
            .toList(),
      1 => widget.battleRankings.map((r) {
        final wins = r['totalBattleWin'] as int? ?? 0;
        final total = r['totalBattle'] as int? ?? 0;
        final losses = total - wins;
        final rate = total > 0
            ? (wins / total * 100).toStringAsFixed(1)
            : '0.0';
        return _RankingRow(
          id: r['id'] as String? ?? '',
          name: r['name'] as String? ?? '\uBAA8\uD5D8\uAC00',
          detail: '$wins\uC2B9 $losses\uD328',
          sub: '\uC2B9\uB960 $rate%',
          score: '$wins\uC2B9',
          swordId: r['swordId'] as String?,
          grade: r['swordGrade'] as SwordGrade? ?? SwordGrade.normal,
          element: r['element'] as GameElement? ?? GameElement.fire,
          level: r['swordLevel'] as int? ?? 0,
          breakthroughLevel: r['swordBreakthroughLevel'] as int? ?? 0,
          isNpc: r['isNpc'] == true,
          isOnline: r['isOnline'] == true,
        );
      }).toList(),
      2 =>
        widget.towerRankings
            .map(
              (r) => _RankingRow(
                id: r['id'] as String? ?? '',
                name: r['name'] as String? ?? '\uBAA8\uD5D8\uAC00',
                detail: '${r['floor'] as int? ?? 0}\uCE35',
                sub:
                    '${r['swordName'] ?? '\uAC80'} +${r['swordLevel'] as int? ?? 0}',
                score: '${r['floor'] as int? ?? 0}\uCE35',
                swordId: r['swordId'] as String?,
                grade: getSwordById(
                  r['swordId'] as String? ?? allSwords.first.id,
                ).grade,
                element: getSwordById(
                  r['swordId'] as String? ?? allSwords.first.id,
                ).element,
                level: r['swordLevel'] as int? ?? 0,
                breakthroughLevel: r['swordBreakthroughLevel'] as int? ?? 0,
                isOnline: r['isOnline'] == true,
              ),
            )
            .toList(),
      _ =>
        widget.codexRankings
            .map(
              (p) => _RankingRow(
                id: p.userId,
                name: p.nickname,
                detail: '${p.codexCount}/${allSwords.length}',
                sub: '${p.sword.name} +${p.swordLevel}',
                score: '${p.codexCount}',
                swordId: p.swordId,
                grade: p.grade,
                element: p.element,
                level: p.swordLevel,
                breakthroughLevel: p.swordBreakthroughLevel,
                isOnline: p.platform != 'local',
              ),
            )
            .toList(),
    };
  }

  Widget _rankingRow(_RankingLayout layout, _RankingRow row, int index) {
    final isMe = row.id == widget.userId;
    return Padding(
      padding: EdgeInsets.only(bottom: layout.u(18)),
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
                    Season1RankingDialog._rowFrameAsset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Positioned.fromRect(
                  rect: r(_RankingRowRects.rank),
                  child: _fitText(
                    layout,
                    '#${index + 1}',
                    20,
                    color: index < 3 ? const Color(0xFFFFD86B) : Colors.white70,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Positioned.fromRect(
                  rect: r(_RankingRowRects.sword),
                  child: Center(
                    child: SwordImageWidget(
                      grade: row.grade,
                      element: row.element,
                      swordId: row.swordId,
                      level: row.level,
                      breakthroughLevel: row.breakthroughLevel,
                      size: layout.u(76),
                      showPulse: false,
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: r(_RankingRowRects.name),
                  child: _fitText(
                    layout,
                    row.isNpc ? '${row.name} (AI)' : row.name,
                    22,
                    color: isMe ? const Color(0xFFFFD86B) : Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Positioned.fromRect(
                  rect: r(_RankingRowRects.detail),
                  child: _fitText(
                    layout,
                    '${row.detail}  ${row.sub}',
                    15,
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Positioned.fromRect(
                  rect: r(_RankingRowRects.score),
                  child: _fitText(
                    layout,
                    row.score,
                    22,
                    color: const Color(0xFFFFD86B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Positioned.fromRect(
                  rect: r(_RankingRowRects.action),
                  child: _fitText(
                    layout,
                    '\uB3C4\uC804\uD558\uAE30',
                    18,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _fitText(
    _RankingLayout layout,
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

  Widget _box(_RankingLayout layout, Rect rect, Widget child) {
    return Positioned.fromRect(rect: layout.r(rect), child: child);
  }

  Widget _tap(_RankingLayout layout, Rect rect, VoidCallback onTap) {
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

class _RankingRow {
  final String id;
  final String name;
  final String detail;
  final String sub;
  final String score;
  final String? swordId;
  final SwordGrade grade;
  final GameElement element;
  final int level;
  final int breakthroughLevel;
  final bool isNpc;
  final bool isOnline;

  const _RankingRow({
    required this.id,
    required this.name,
    required this.detail,
    required this.sub,
    required this.score,
    this.swordId,
    required this.grade,
    required this.element,
    required this.level,
    required this.breakthroughLevel,
    this.isNpc = false,
    this.isOnline = false,
  });
}

class _RankingLayout {
  final double width;
  final double height;
  late final double sx = width / Season1RankingDialog._baseWidth;
  late final double sy = height / Season1RankingDialog._baseHeight;
  late final double s = math.min(sx, sy);

  _RankingLayout(this.width, this.height);

  double u(double value) => value * s;

  Rect r(Rect rect) => Rect.fromLTWH(
    rect.left * sx,
    rect.top * sy,
    rect.width * sx,
    rect.height * sy,
  );
}

class _RankingRects {
  static const close = Rect.fromLTWH(28, 31, 104, 104);
  static const title = Rect.fromLTWH(223, 226, 500, 103);
  static const tabs = [
    Rect.fromLTWH(62, 421, 193, 87),
    Rect.fromLTWH(275, 421, 193, 87),
    Rect.fromLTWH(488, 421, 193, 87),
    Rect.fromLTWH(701, 421, 193, 87),
  ];
  static const list = Rect.fromLTWH(39, 544, 867, 922);
}

class _RankingRowRects {
  static const rank = Rect.fromLTWH(17, 7, 96, 24);
  static const sword = Rect.fromLTWH(22, 29, 92, 84);
  static const name = Rect.fromLTWH(143, 25, 302, 34);
  static const detail = Rect.fromLTWH(143, 64, 302, 32);
  static const score = Rect.fromLTWH(477, 37, 142, 54);
  static const action = Rect.fromLTWH(653, 37, 142, 54);
}
