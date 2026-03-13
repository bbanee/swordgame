// lib/screens/tabs/enhance_tab.dart
// 강화 탭 UI - GameScreen에서 분리

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../enums/sword_grade.dart';
import '../../models/owned_sword.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/sword_image_widget.dart';

class EnhanceTab extends StatefulWidget {
  final OwnedSword? equippedSword;
  final int gold;
  final int enhanceStone;
  final int bossCore;
  final int inventoryLength;
  final int maxInventory;
  final bool useEnhanceStone;
  final bool showEnhanceEffect;
  final int maxEnhanceLevel;
  final bool canBreakthrough;

  final VoidCallback onEnhance;
  final VoidCallback onBreakthrough;
  final Function(OwnedSword) onSellSword;
  final VoidCallback onQuickGacha;
  final Function(bool) onToggleEnhanceStone;

  const EnhanceTab({
    super.key,
    required this.equippedSword,
    required this.gold,
    required this.enhanceStone,
    required this.bossCore,
    required this.inventoryLength,
    required this.maxInventory,
    required this.useEnhanceStone,
    required this.showEnhanceEffect,
    required this.maxEnhanceLevel,
    required this.canBreakthrough,
    required this.onEnhance,
    required this.onBreakthrough,
    required this.onSellSword,
    required this.onQuickGacha,
    required this.onToggleEnhanceStone,
  });

  @override
  State<EnhanceTab> createState() => _EnhanceTabState();
}

class _EnhanceTabState extends State<EnhanceTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _btnController;
  late Animation<double> _btnScale;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _btnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _btnScale = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _btnController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _btnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.equippedSword == null) {
      return const Center(
        child: Text('장착된 검이 없습니다', style: TextStyle(color: Colors.white54)),
      );
    }

    final sword = widget.equippedSword!;
    final cost = getEnhanceCost(sword.level);
    final successRate = getEnhanceSuccessRate(sword.level);
    final destroyRate = getEnhanceDestroyRate(sword.level);
    final canEnhance =
        widget.gold >= cost && sword.level < widget.maxEnhanceLevel;
    final canBreakthrough = widget.canBreakthrough;

    return LayoutBuilder(
      builder: (context, constraints) {
        final swordSize = (constraints.maxHeight * 0.30).clamp(130.0, 200.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                const SizedBox(height: 4),

                // ── 검 이미지 카드 (크게, 중앙 배치) ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  decoration: AppDecorations.glowCard(
                    sword.data.grade.color,
                    blurRadius: 30,
                  ),
                  child: Column(
                    children: [
                      // 검 이름
                      Text(
                        sword.data.name,
                        style: TextStyle(
                          color: sword.data.grade.color,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 검 이미지 크게
                      SwordImageWidget(
                        grade: sword.data.grade,
                        element: sword.data.element,
                        level: sword.level,
                        breakthroughLevel: sword.breakthroughLevel,
                        size: swordSize,
                        showPulse: true,
                        showEnhanceEffect: widget.showEnhanceEffect,
                      ),
                      const SizedBox(height: 16),

                      // 스탯 칩
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildStatChip(
                            '⚡',
                            '${sword.totalPower}',
                            Colors.amber,
                          ),
                          _buildStatChip(
                            '💰',
                            '${formatNumber(sword.sellPrice)}G',
                            Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: canBreakthrough
                              ? const Color(0xFF80DEEA).withOpacity(0.08)
                              : Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: canBreakthrough
                                ? const Color(0xFF80DEEA).withOpacity(0.45)
                                : Colors.redAccent.withOpacity(0.45),
                          ),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Text(
                              '강화 +${sword.level}/+${widget.maxEnhanceLevel}  돌파 ${sword.breakthroughLevel}/${AppConstants.maxBreakthroughLevel}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(
                              width: 112,
                              child: OutlinedButton.icon(
                                onPressed: canBreakthrough
                                    ? widget.onBreakthrough
                                    : null,
                                icon: Icon(
                                  canBreakthrough
                                      ? Icons.auto_awesome
                                      : Icons.lock,
                                  size: 16,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: canBreakthrough
                                      ? const Color(0xFF80DEEA)
                                      : Colors.redAccent,
                                  backgroundColor: canBreakthrough
                                      ? const Color(
                                          0xFF80DEEA,
                                        ).withOpacity(0.08)
                                      : Colors.red.withOpacity(0.10),
                                  side: BorderSide(
                                    color: canBreakthrough
                                        ? const Color(0xFF80DEEA)
                                        : Colors.redAccent,
                                    width: canBreakthrough ? 1.5 : 1.2,
                                  ),
                                  disabledForegroundColor: Colors.redAccent,
                                  disabledBackgroundColor: Colors.red
                                      .withOpacity(0.10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                label: Text(
                                  canBreakthrough ? '돌파' : '잠김',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── 확률 표시 ──
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildProbBox(
                          '✅ 성공',
                          formatPercent(successRate),
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildProbBox(
                          '➖ 유지',
                          formatPercent(100 - successRate - destroyRate),
                          Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildProbBox(
                          '💥 파괴',
                          formatPercent(destroyRate),
                          destroyRate > 0 ? Colors.red : Colors.grey[700]!,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── 강화석 ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: widget.useEnhanceStone,
                        onChanged: (v) =>
                            widget.onToggleEnhanceStone(v ?? false),
                        activeColor: Colors.purple,
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: Text(
                          '강화석 사용 (성공+10%, 파괴-5%, +25부터 효과↓) 보유: ${widget.enhanceStone}개',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 강화 비용 + 강화하기 버튼 ──
                Row(
                  children: [
                    // 비용 표시
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '비용 ',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${formatNumber(cost)} G',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // 강화하기 버튼 - 스케일 + 글로우 피드백
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _btnScale,
                        builder: (context, child) => Transform.scale(
                          scale: _btnScale.value,
                          child: child,
                        ),
                        child: GestureDetector(
                          onTapDown: canEnhance
                              ? (_) {
                                  setState(() => _isPressed = true);
                                  _btnController.forward();
                                  HapticFeedback.lightImpact();
                                }
                              : null,
                          onTapUp: canEnhance
                              ? (_) {
                                  setState(() => _isPressed = false);
                                  HapticFeedback.mediumImpact();
                                  _btnController.reverse().then((_) {
                                    widget.onEnhance();
                                  });
                                }
                              : null,
                          onTapCancel: () {
                            setState(() => _isPressed = false);
                            _btnController.reverse();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: canEnhance
                                  ? LinearGradient(
                                      colors: _isPressed
                                          ? [
                                              Colors.indigo.shade800,
                                              Colors.indigo.shade900,
                                            ]
                                          : [
                                              Colors.indigo.shade600,
                                              Colors.indigo.shade800,
                                            ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    )
                                  : null,
                              color: canEnhance ? null : Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: canEnhance
                                    ? (_isPressed
                                          ? Colors.indigoAccent
                                          : Colors.indigo.shade400)
                                    : Colors.grey.shade700,
                                width: _isPressed ? 2 : 1.5,
                              ),
                              boxShadow: canEnhance
                                  ? [
                                      BoxShadow(
                                        color: Colors.indigo.withOpacity(
                                          _isPressed ? 0.15 : 0.45,
                                        ),
                                        blurRadius: _isPressed ? 4 : 14,
                                        spreadRadius: _isPressed ? 0 : 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '⚔️ 강화하기',
                              style: TextStyle(
                                color: canEnhance
                                    ? Colors.white
                                    : Colors.white38,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── 판매 / 구매 (보조 버튼, 작게) ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onSellSword(sword),
                        icon: const Icon(Icons.sell, size: 14),
                        label: Text(
                          '판매 (${formatNumber(sword.sellPrice)}G)',
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: widget.inventoryLength >= widget.maxInventory
                          ? OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.block, size: 14),
                              label: const Text(
                                '가득 참',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                disabledForegroundColor: Colors.redAccent
                                    .withOpacity(0.7),
                                disabledMouseCursor:
                                    SystemMouseCursors.forbidden,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: widget.gold >= 500
                                  ? widget.onQuickGacha
                                  : null,
                              icon: const Icon(Icons.add_box, size: 14),
                              label: const Text(
                                '구매',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: const BorderSide(color: Colors.blue),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(String icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProbBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
