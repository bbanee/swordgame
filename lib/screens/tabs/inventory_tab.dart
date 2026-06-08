import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../enums/sword_grade.dart';
import '../../models/owned_sword.dart';
import '../../utils/helpers.dart';
import '../../widgets/sword_image_widget.dart';

class InventoryTab extends StatefulWidget {
  static const _baseAsset =
      'assets/images/home/season1_inventory_scene_body_v2.png';
  static const _itemFrameAsset =
      'assets/images/home/season1_inventory_item_frame_v1.png';
  static const _baseWidth = 941.0;
  static const _baseHeight = 1671.0;

  final List<OwnedSword> inventory;
  final int maxInventory;
  final OwnedSword? equippedSword;
  final int gold;
  final int diamond;
  final Function(OwnedSword) onSwordTap;
  final VoidCallback onExpandInventory;
  final Function(List<OwnedSword>) onBulkSell;

  const InventoryTab({
    super.key,
    required this.inventory,
    required this.maxInventory,
    required this.equippedSword,
    required this.gold,
    required this.diamond,
    required this.onSwordTap,
    required this.onExpandInventory,
    required this.onBulkSell,
  });

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  bool _isBulkMode = false;
  final Set<String> _selectedUids = {};

  List<OwnedSword> get _selectedSwords =>
      widget.inventory.where((s) => _selectedUids.contains(s.uid)).toList();

  int get _selectedTotalPrice =>
      _selectedSwords.fold(0, (sum, sword) => sum + sword.sellPrice);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _InventoryLayout(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  InventoryTab._baseAsset,
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

  List<Widget> _buildDataOverlays(_InventoryLayout layout) {
    final isFull = widget.inventory.length >= widget.maxInventory;
    return [
      _box(
        layout,
        _InventoryRects.count,
        _fitText(
          layout,
          '${widget.inventory.length} / ${widget.maxInventory}',
          28,
          color: isFull ? Colors.redAccent : Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      if (_isBulkMode)
        _box(
          layout,
          _InventoryRects.bulkSummary,
          _fitText(
            layout,
            '선택 ${_selectedSwords.length}개  ${formatGold(_selectedTotalPrice)}G',
            24,
            color: Colors.amber,
            fontWeight: FontWeight.w900,
          ),
        ),
      _box(layout, _InventoryRects.grid, _buildGrid(layout)),
    ];
  }

  List<Widget> _buildTapOverlays(_InventoryLayout layout) {
    return [
      _tap(layout, _InventoryRects.expandButton, widget.onExpandInventory),
      _tap(layout, _InventoryRects.bulkButton, _toggleBulkMode),
      _tap(layout, _InventoryRects.allFilter, () => _selectAll()),
      for (var i = 0; i < SwordGrade.values.length; i++)
        _tap(
          layout,
          _InventoryRects.gradeFilters[i],
          () => _selectByGrade(SwordGrade.values[i]),
        ),
      if (_isBulkMode && _selectedSwords.isNotEmpty)
        _tap(layout, _InventoryRects.sellButton, _confirmBulkSell),
    ];
  }

  Widget _buildGrid(_InventoryLayout layout) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        layout.u(34),
        layout.u(22),
        layout.u(34),
        layout.u(28),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: layout.u(26),
        mainAxisSpacing: layout.u(20),
        mainAxisExtent: layout.u(254),
      ),
      itemCount: widget.inventory.length,
      itemBuilder: (_, i) => _inventoryItem(layout, widget.inventory[i]),
    );
  }

  Widget _inventoryItem(_InventoryLayout layout, OwnedSword sword) {
    final isEquipped = widget.equippedSword?.uid == sword.uid;
    final isSelected = _selectedUids.contains(sword.uid);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _isBulkMode
          ? () => _toggleSelect(sword)
          : () => widget.onSwordTap(sword),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth;
          final cellHeight = constraints.maxHeight;
          final nameHeight = layout.u(46);
          final nameBottom = 0.0;
          final swordTop = layout.u(18);
          final swordBottom = nameBottom + nameHeight + layout.u(8);
          final swordAreaHeight = cellHeight - swordTop - swordBottom;
          final swordSize = math.min(cellWidth * 0.64, swordAreaHeight * 0.96);

          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  InventoryTab._itemFrameAsset,
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
                  child: SizedBox(
                    width: swordSize,
                    height: swordSize,
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
                ),
              ),
              if (isEquipped)
                Positioned(
                  top: layout.u(11),
                  right: layout.u(12),
                  child: _badge('장착', Colors.amber),
                ),
              if (_isBulkMode && !isEquipped)
                Positioned(
                  top: layout.u(10),
                  right: layout.u(12),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.orange : Colors.white54,
                    size: layout.u(28),
                  ),
                ),
              Positioned(
                left: layout.u(16),
                right: layout.u(16),
                bottom: nameBottom,
                height: nameHeight,
                child: _fitText(
                  layout,
                  sword.data.name,
                  19,
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

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _toggleBulkMode() {
    setState(() {
      _isBulkMode = !_isBulkMode;
      _selectedUids.clear();
    });
  }

  void _toggleSelect(OwnedSword sword) {
    if (widget.equippedSword?.uid == sword.uid) return;
    setState(() {
      if (_selectedUids.contains(sword.uid)) {
        _selectedUids.remove(sword.uid);
      } else {
        _selectedUids.add(sword.uid);
      }
    });
  }

  void _selectByGrade(SwordGrade grade) {
    setState(() {
      final targets = widget.inventory
          .where(
            (s) => s.data.grade == grade && s.uid != widget.equippedSword?.uid,
          )
          .map((s) => s.uid)
          .toSet();
      final allSelected =
          targets.isNotEmpty && targets.every(_selectedUids.contains);
      if (allSelected) {
        _selectedUids.removeAll(targets);
      } else {
        _selectedUids.addAll(targets);
      }
      _isBulkMode = true;
    });
  }

  void _selectAll() {
    setState(() {
      final targets = widget.inventory
          .where((s) => s.uid != widget.equippedSword?.uid)
          .map((s) => s.uid)
          .toSet();
      final allSelected =
          targets.isNotEmpty && targets.every(_selectedUids.contains);
      if (allSelected) {
        _selectedUids.clear();
      } else {
        _selectedUids.addAll(targets);
      }
      _isBulkMode = true;
    });
  }

  void _confirmBulkSell() {
    if (_selectedSwords.isEmpty) return;
    widget.onBulkSell(_selectedSwords);
    setState(() {
      _isBulkMode = false;
      _selectedUids.clear();
    });
  }

  Widget _fitText(
    _InventoryLayout layout,
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

  Widget _box(_InventoryLayout layout, Rect rect, Widget child) {
    return Positioned.fromRect(rect: layout.r(rect), child: child);
  }

  Widget _tap(_InventoryLayout layout, Rect rect, VoidCallback onTap) {
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

class _InventoryLayout {
  final double width;
  final double height;
  late final double sx = width / InventoryTab._baseWidth;
  late final double sy = height / InventoryTab._baseHeight;
  late final double s = math.min(sx, sy);

  _InventoryLayout(this.width, this.height);

  double u(double value) => value * s;

  Rect r(Rect rect) => Rect.fromLTWH(
    rect.left * sx,
    rect.top * sy,
    rect.width * sx,
    rect.height * sy,
  );
}

class _InventoryRects {
  static const count = Rect.fromLTWH(55, 371, 407, 76);
  static const expandButton = Rect.fromLTWH(496, 391, 166, 66);
  static const bulkButton = Rect.fromLTWH(684, 391, 222, 66);
  static const bulkSummary = Rect.fromLTWH(245, 1561, 465, 58);
  static const sellButton = Rect.fromLTWH(183, 1540, 570, 90);

  static const allFilter = Rect.fromLTWH(38, 476, 126, 64);
  static const gradeFilters = [
    Rect.fromLTWH(176, 476, 126, 64),
    Rect.fromLTWH(314, 476, 126, 64),
    Rect.fromLTWH(453, 476, 126, 64),
    Rect.fromLTWH(591, 476, 126, 64),
    Rect.fromLTWH(729, 476, 126, 64),
    Rect.fromLTWH(856, 476, 70, 64),
  ];

  static const grid = Rect.fromLTWH(31, 548, 907, 968);
}
