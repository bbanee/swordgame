// lib/screens/tabs/inventory_tab.dart
// 인벤토리 탭 UI - GameScreen에서 분리

import 'package:flutter/material.dart';
import '../../enums/sword_grade.dart';
import '../../models/owned_sword.dart';
import '../../utils/helpers.dart';
import '../../widgets/sword_image_widget.dart';

class InventoryTab extends StatefulWidget {
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

  void _toggleBulkMode() {
    setState(() {
      _isBulkMode = !_isBulkMode;
      _selectedUids.clear();
    });
  }

  void _toggleSelect(OwnedSword sword) {
    // 장착중인 검은 선택 불가
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
          .map((s) => s.uid);

      // 이미 전부 선택되어 있으면 해제, 아니면 전부 선택
      final allSelected = targets.every((uid) => _selectedUids.contains(uid));
      if (allSelected && targets.isNotEmpty) {
        _selectedUids.removeAll(targets);
      } else {
        _selectedUids.addAll(targets);
      }
    });
  }

  void _selectAll() {
    setState(() {
      final allNonEquipped = widget.inventory
          .where((s) => s.uid != widget.equippedSword?.uid)
          .map((s) => s.uid)
          .toSet();

      if (_selectedUids.length == allNonEquipped.length) {
        _selectedUids.clear();
      } else {
        _selectedUids.addAll(allNonEquipped);
      }
    });
  }

  List<OwnedSword> get _selectedSwords =>
      widget.inventory.where((s) => _selectedUids.contains(s.uid)).toList();

  int get _selectedTotalPrice =>
      _selectedSwords.fold(0, (sum, s) => sum + s.sellPrice);

  void _confirmBulkSell() {
    if (_selectedSwords.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('일괄 판매', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selectedSwords.length}개의 검을 판매합니다.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            // 등급별 개수 요약
            ..._buildGradeSummary(),
            const Divider(color: Colors.white24),
            Row(
              children: [
                const Text(
                  '예상 수익: ',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  '${formatNumber(_selectedTotalPrice)}G',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '※ 판매 이벤트 배율은 개별 적용됩니다',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onBulkSell(_selectedSwords);
              setState(() {
                _isBulkMode = false;
                _selectedUids.clear();
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(
              '${_selectedSwords.length}개 판매',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGradeSummary() {
    final gradeCount = <SwordGrade, int>{};
    for (final s in _selectedSwords) {
      gradeCount[s.data.grade] = (gradeCount[s.data.grade] ?? 0) + 1;
    }
    return gradeCount.entries
        .map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '  ${e.key.emoji} ${e.key.displayName} × ${e.value}',
              style: TextStyle(color: e.key.color, fontSize: 13),
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.inventory.length;
    final isFull = itemCount >= widget.maxInventory;

    return Column(
      children: [
        // 상단 바: 인벤토리 용량 + 확장 + 일괄판매
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.inventory_2,
                color: isFull ? Colors.red : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isFull
                      ? Colors.red.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFull ? Colors.red : Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  '$itemCount / ${widget.maxInventory}',
                  style: TextStyle(
                    color: isFull ? Colors.red : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 인벤토리 확장 버튼
              _buildHeaderButton(
                icon: Icons.add_circle_outline,
                label: '확장',
                color: Colors.green,
                onTap: widget.onExpandInventory,
              ),
              const Spacer(),
              // 일괄판매 토글 버튼
              _buildHeaderButton(
                icon: _isBulkMode ? Icons.close : Icons.sell,
                label: _isBulkMode ? '취소' : '일괄판매',
                color: _isBulkMode ? Colors.grey : Colors.orange,
                onTap: _toggleBulkMode,
              ),
            ],
          ),
        ),

        // 일괄판매 모드: 등급별 빠른 선택 바
        if (_isBulkMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.orange.withOpacity(0.08),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildGradeFilterChip('전체', null),
                  ...SwordGrade.values.map((g) {
                    final count = widget.inventory
                        .where(
                          (s) =>
                              s.data.grade == g &&
                              s.uid != widget.equippedSword?.uid,
                        )
                        .length;
                    if (count == 0) return const SizedBox.shrink();
                    return _buildGradeFilterChip(
                      '${g.emoji}${g.displayName}($count)',
                      g,
                    );
                  }),
                ],
              ),
            ),
          ),

        // 그리드 목록
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: widget.inventory.length,
            itemBuilder: (_, i) {
              final sword = widget.inventory[i];
              final isEquipped = widget.equippedSword?.uid == sword.uid;
              final isSelected = _selectedUids.contains(sword.uid);

              return GestureDetector(
                onTap: _isBulkMode
                    ? () => _toggleSelect(sword)
                    : () => widget.onSwordTap(sword),
                child: Container(
                  decoration: BoxDecoration(
                    color: sword.data.grade.color.withOpacity(
                      _isBulkMode && isSelected ? 0.35 : 0.2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isBulkMode && isSelected
                          ? Colors.orange
                          : isEquipped
                          ? Colors.amber
                          : sword.data.grade.color.withOpacity(0.5),
                      width: (_isBulkMode && isSelected) || isEquipped ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 일괄판매 모드에서 장착중 검은 어둡게
                      if (_isBulkMode && isEquipped)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                        ),
                      SwordImageWidget(
                        grade: sword.data.grade,
                        element: sword.data.element,
                        level: sword.level,
                        breakthroughLevel: sword.breakthroughLevel,
                        size: 60,
                        showPulse: false,
                      ),
                      // 장착 체크
                      if (isEquipped && !_isBulkMode)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 10,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      // 장착중 표시 (일괄판매 모드)
                      if (_isBulkMode && isEquipped)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '장착중',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // 선택 체크박스
                      if (_isBulkMode && !isEquipped)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.orange
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.orange
                                    : Colors.white38,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      Positioned(
                        bottom: 4,
                        child: Text(
                          sword.data.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // 일괄판매 모드: 하단 확인 바
        if (_isBulkMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '선택: ${_selectedSwords.length}개',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '💰 ${formatNumber(_selectedTotalPrice)}G',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _selectedSwords.isNotEmpty
                      ? _confirmBulkSell
                      : null,
                  icon: const Icon(Icons.sell, size: 16),
                  label: Text('${_selectedSwords.length}개 판매'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    disabledBackgroundColor: Colors.grey.shade800,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeFilterChip(String label, SwordGrade? grade) {
    // 해당 등급이 전부 선택되어 있는지 확인
    bool isActive;
    if (grade == null) {
      // 전체
      final allNonEquipped = widget.inventory
          .where((s) => s.uid != widget.equippedSword?.uid)
          .map((s) => s.uid)
          .toSet();
      isActive =
          allNonEquipped.isNotEmpty &&
          allNonEquipped.every((uid) => _selectedUids.contains(uid));
    } else {
      final targets = widget.inventory
          .where(
            (s) => s.data.grade == grade && s.uid != widget.equippedSword?.uid,
          )
          .map((s) => s.uid)
          .toSet();
      isActive =
          targets.isNotEmpty &&
          targets.every((uid) => _selectedUids.contains(uid));
    }

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => grade == null ? _selectAll() : _selectByGrade(grade),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.orange.withOpacity(0.3)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? Colors.orange : Colors.white.withOpacity(0.15),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.orange : Colors.white70,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
