import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/swords.dart';
import '../../enums/sword_grade.dart';
import '../../models/owned_sword.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../sword_image_widget.dart';

class SynthesisDialog extends StatefulWidget {
  static const _baseAsset =
      'assets/images/home/season1_synthesis_scene_body_v1.png';
  static const _itemFrameAsset =
      'assets/images/home/season1_inventory_item_frame_v1.png';
  static const _baseWidth = 941.0;
  static const _baseHeight = 1672.0;

  final List<OwnedSword> inventory;
  final String? equippedSwordUid;
  final int normalToRarePity;
  final int rareToUniquePity;
  final int uniqueToLegendPity;
  final Map<String, int> Function(List<OwnedSword> materials, {bool showResult})
  onSynthesize;

  const SynthesisDialog({
    super.key,
    required this.inventory,
    this.equippedSwordUid,
    required this.normalToRarePity,
    required this.rareToUniquePity,
    required this.uniqueToLegendPity,
    required this.onSynthesize,
  });

  @override
  State<SynthesisDialog> createState() => _SynthesisDialogState();
}

class _SynthesisDialogState extends State<SynthesisDialog> {
  final Set<String> _selectedUids = {};
  SwordGrade _filterGrade = synthesisTable.first.$1;

  late int _normalToRarePity;
  late int _rareToUniquePity;
  late int _uniqueToLegendPity;

  static final List<SwordGrade> _synthesizableGrades = synthesisTable
      .map((entry) => entry.$1)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _normalToRarePity = widget.normalToRarePity;
    _rareToUniquePity = widget.rareToUniquePity;
    _uniqueToLegendPity = widget.uniqueToLegendPity;
  }

  List<OwnedSword> get _selectedSwords =>
      widget.inventory.where((s) => _selectedUids.contains(s.uid)).toList();

  List<OwnedSword> get _filteredInventory {
    final list = widget.inventory
        .where((s) => s.data.grade == _filterGrade)
        .toList();
    list.sort((a, b) {
      final level = b.level.compareTo(a.level);
      if (level != 0) return level;
      return b.data.baseAtk.compareTo(a.data.baseAtk);
    });
    return list;
  }

  bool get _isSameGrade {
    if (_selectedSwords.isEmpty) return true;
    final grade = _selectedSwords.first.data.grade;
    return _selectedSwords.every((s) => s.data.grade == grade);
  }

  bool get _canSynthesize =>
      _selectedSwords.length == AppConstants.synthesisRequiredCount &&
      _isSameGrade &&
      canSynthesize(_selectedSwords.first.data.grade);

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _SynthesisLayout(
              constraints.maxWidth,
              constraints.maxHeight,
            );

            return ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      SynthesisDialog._baseAsset,
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
        ),
      ),
    );
  }

  List<Widget> _buildDataOverlays(_SynthesisLayout layout) {
    return [
      _box(
        layout,
        _SynthesisRects.title,
        _fitText(
          layout,
          '\uAC80 \uD569\uC131',
          46,
          fontWeight: FontWeight.w900,
        ),
      ),
      for (var i = 0; i < _synthesizableGrades.length; i++)
        _box(
          layout,
          _SynthesisRects.gradeTabs[i],
          _gradeTab(layout, _synthesizableGrades[i]),
        ),
      for (var i = 0; i < _synthesizableGrades.length; i++)
        _box(
          layout,
          _SynthesisRects.rateSlots[i],
          _rateSlot(layout, _synthesizableGrades[i]),
        ),
      _box(layout, _SynthesisRects.grid, _inventoryGrid(layout)),
      for (var i = 0; i < AppConstants.synthesisRequiredCount; i++)
        _box(
          layout,
          _SynthesisRects.materialSlots[i],
          _materialSlot(layout, i),
        ),
      _box(layout, _SynthesisRects.button, _synthesisButtonLabel(layout)),
    ];
  }

  List<Widget> _buildTapOverlays(_SynthesisLayout layout) {
    return [
      _tap(layout, _SynthesisRects.close, () => Navigator.pop(context)),
      for (var i = 0; i < _synthesizableGrades.length; i++)
        _tap(
          layout,
          _SynthesisRects.gradeTabs[i],
          () => setState(() {
            _filterGrade = _synthesizableGrades[i];
            _selectedUids.clear();
          }),
        ),
      _tap(layout, _SynthesisRects.button, _canSynthesize ? _synthesize : null),
    ];
  }

  Widget _gradeTab(_SynthesisLayout layout, SwordGrade grade) {
    final count = widget.inventory.where((s) => s.data.grade == grade).length;
    final selected = grade == _filterGrade;
    return SizedBox.expand(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _fitText(
            layout,
            grade.displayName,
            21,
            color: selected ? const Color(0xFFFFD86B) : Colors.white,
            fontWeight: FontWeight.w900,
          ),
          SizedBox(height: layout.u(3)),
          _fitText(
            layout,
            '$count',
            15,
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w800,
          ),
        ],
      ),
    );
  }

  Widget _rateSlot(_SynthesisLayout layout, SwordGrade grade) {
    final resultGrade = getSynthesisResultGrade(grade);
    final probability = getSynthesisProbability(grade) ?? 0;
    final ceiling = getSynthesisCeiling(grade);
    final pity = _pityFor(grade);
    final label = resultGrade == null
        ? '-'
        : '${resultGrade.displayName}\n${_formatProbability(probability)}%';
    final progress = ceiling != null && pity != null
        ? '${math.min(pity, ceiling)}/$ceiling'
        : '\uD655\uB960';

    return SizedBox.expand(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _fitMultiline(
            layout,
            label,
            13,
            color: resultGrade?.color ?? Colors.white,
            fontWeight: FontWeight.w900,
          ),
          SizedBox(height: layout.u(3)),
          _fitText(layout, progress, 10, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _inventoryGrid(_SynthesisLayout layout) {
    final swords = _filteredInventory;
    if (swords.isEmpty) {
      return Center(
        child: _fitText(
          layout,
          '${_filterGrade.displayName} \uB4F1\uAE09 \uAC80\uC774 \uC5C6\uC2B5\uB2C8\uB2E4',
          27,
          color: Colors.white70,
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        layout.u(34),
        layout.u(36),
        layout.u(34),
        layout.u(36),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: layout.u(24),
        mainAxisSpacing: layout.u(22),
        mainAxisExtent: layout.u(220),
      ),
      itemCount: swords.length,
      itemBuilder: (_, index) => _inventoryItem(layout, swords[index]),
    );
  }

  Widget _inventoryItem(_SynthesisLayout layout, OwnedSword sword) {
    final selected = _selectedUids.contains(sword.uid);
    final equipped = sword.uid == widget.equippedSwordUid;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _toggleSword(sword),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth;
          final cellHeight = constraints.maxHeight;
          final nameHeight = layout.u(40);
          final swordTop = layout.u(15);
          final swordBottom = nameHeight + layout.u(8);
          final swordAreaHeight = cellHeight - swordTop - swordBottom;
          final swordSize = math.min(cellWidth * 0.62, swordAreaHeight * 0.94);

          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  SynthesisDialog._itemFrameAsset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: swordTop,
                height: swordAreaHeight,
                child: Center(
                  child: SwordImageWidget(
                    grade: sword.data.grade,
                    element: sword.data.element,
                    swordId: sword.data.id,
                    level: sword.level,
                    breakthroughLevel: sword.breakthroughLevel,
                    size: swordSize,
                    showPulse: false,
                  ),
                ),
              ),
              if (selected)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFFFD86B),
                        width: layout.u(3),
                      ),
                      color: const Color(0xFFFFD86B).withValues(alpha: 0.10),
                    ),
                  ),
                ),
              if (equipped)
                Positioned(
                  top: layout.u(9),
                  right: layout.u(10),
                  child: _badge(layout, '\uC7A5\uCC29', Colors.amber),
                ),
              Positioned(
                left: layout.u(12),
                right: layout.u(12),
                bottom: 0,
                height: nameHeight,
                child: _fitText(
                  layout,
                  sword.data.name,
                  17,
                  color: sword.data.grade.color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _materialSlot(_SynthesisLayout layout, int index) {
    final sword = index < _selectedSwords.length
        ? _selectedSwords[index]
        : null;
    if (sword == null) {
      return Center(
        child: _fitText(layout, '${index + 1}', 25, color: Colors.white38),
      );
    }

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: layout.u(10),
            height: layout.u(104),
            child: Center(
              child: SwordImageWidget(
                grade: sword.data.grade,
                element: sword.data.element,
                swordId: sword.data.id,
                level: sword.level,
                breakthroughLevel: sword.breakthroughLevel,
                size: layout.u(96),
                showPulse: false,
              ),
            ),
          ),
          Positioned(
            left: layout.u(8),
            right: layout.u(8),
            bottom: layout.u(4),
            height: layout.u(30),
            child: _fitText(
              layout,
              sword.data.name,
              14,
              color: sword.data.grade.color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _synthesisButtonLabel(_SynthesisLayout layout) {
    final label = _canSynthesize
        ? '\uD569\uC131  ${AppConstants.synthesisCostGold}G'
        : _selectedSwords.isEmpty
        ? '\uC7AC\uB8CC 3\uAC1C \uC120\uD0DD'
        : '${_selectedSwords.length}/3 \uC120\uD0DD\uB428';
    return _fitText(
      layout,
      label,
      32,
      color: _canSynthesize ? Colors.white : Colors.white70,
      fontWeight: FontWeight.w900,
    );
  }

  Widget _badge(_SynthesisLayout layout, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.u(5),
        vertical: layout.u(2),
      ),
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(layout.u(4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: layout.u(10),
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }

  int? _pityFor(SwordGrade grade) {
    return switch (grade) {
      SwordGrade.normal => _normalToRarePity,
      SwordGrade.rare => _rareToUniquePity,
      SwordGrade.unique => _uniqueToLegendPity,
      _ => null,
    };
  }

  void _toggleSword(OwnedSword sword) {
    setState(() {
      if (_selectedUids.contains(sword.uid)) {
        _selectedUids.remove(sword.uid);
        return;
      }

      if (_selectedSwords.isNotEmpty &&
          _selectedSwords.first.data.grade != sword.data.grade) {
        _selectedUids.clear();
      }

      if (_selectedUids.length >= AppConstants.synthesisRequiredCount) {
        _selectedUids.remove(_selectedSwords.first.uid);
      }
      _selectedUids.add(sword.uid);
    });
  }

  void _synthesize() {
    if (!_canSynthesize) return;
    final newPity = widget.onSynthesize(_selectedSwords);
    setState(() {
      _normalToRarePity = newPity['normalToRare'] ?? _normalToRarePity;
      _rareToUniquePity = newPity['rareToUnique'] ?? _rareToUniquePity;
      _uniqueToLegendPity = newPity['uniqueToLegend'] ?? _uniqueToLegendPity;
      _selectedUids.clear();
    });
  }

  String _formatProbability(double value) {
    if (value >= 1) {
      return value == value.truncate()
          ? value.truncate().toString()
          : value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(value < 0.1 ? 3 : 2);
  }

  Widget _fitText(
    _SynthesisLayout layout,
    String text,
    double baseSize, {
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    final fontSize = layout.u(baseSize);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: layout.u(4)),
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

  Widget _fitMultiline(
    _SynthesisLayout layout,
    String text,
    double baseSize, {
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: layout.u(3)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            text,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: layout.u(baseSize),
              fontWeight: fontWeight,
              height: 1.05,
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

  Widget _box(_SynthesisLayout layout, Rect rect, Widget child) {
    return Positioned.fromRect(rect: layout.r(rect), child: child);
  }

  Widget _tap(_SynthesisLayout layout, Rect rect, VoidCallback? onTap) {
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

class _SynthesisLayout {
  final double width;
  final double height;
  late final double sx = width / SynthesisDialog._baseWidth;
  late final double sy = height / SynthesisDialog._baseHeight;
  late final double s = math.min(sx, sy);

  _SynthesisLayout(this.width, this.height);

  double u(double value) => value * s;

  Rect r(Rect rect) => Rect.fromLTWH(
    rect.left * sx,
    rect.top * sy,
    rect.width * sx,
    rect.height * sy,
  );
}

class _SynthesisRects {
  static const close = Rect.fromLTWH(19, 24, 102, 102);
  static const title = Rect.fromLTWH(236, 184, 470, 110);
  static const gradeTabs = [
    Rect.fromLTWH(35, 374, 158, 70),
    Rect.fromLTWH(210, 374, 158, 70),
    Rect.fromLTWH(385, 374, 158, 70),
    Rect.fromLTWH(560, 374, 158, 70),
    Rect.fromLTWH(735, 374, 158, 70),
  ];
  static const rateSlots = [
    Rect.fromLTWH(241, 501, 74, 60),
    Rect.fromLTWH(387, 501, 74, 60),
    Rect.fromLTWH(534, 501, 74, 60),
    Rect.fromLTWH(680, 501, 74, 60),
    Rect.fromLTWH(826, 501, 74, 60),
  ];
  static const grid = Rect.fromLTWH(34, 613, 875, 635);
  static const materialSlots = [
    Rect.fromLTWH(179, 1325, 148, 148),
    Rect.fromLTWH(386, 1325, 148, 148),
    Rect.fromLTWH(607, 1325, 148, 148),
  ];
  static const button = Rect.fromLTWH(207, 1520, 562, 88);
}
