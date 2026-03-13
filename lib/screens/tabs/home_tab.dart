// lib/screens/tabs/home_tab.dart
// 홈 탭 UI - GameScreen에서 분리

import 'package:flutter/material.dart';
import '../../enums/sword_grade.dart';
import '../../enums/element.dart';
import '../../enums/skill_type.dart';
import '../../enums/skill_effect.dart';
import '../../models/sword_data.dart';
import '../../models/owned_sword.dart';
import '../../models/daily_quest.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/sword_image_widget.dart';

class HomeTab extends StatelessWidget {
  final OwnedSword? equippedSword;
  final int attendanceStreak;
  final bool canCheckAttendance;
  final List<DailyQuest> dailyQuests;
  final double sellEventRate;
  final String sellEventName;
  final String sellEventEmoji;
  final Color sellEventColor;
  final int titleBonus; // 칭호 보너스
  final String? titleName; // 장착 칭호 이름

  final VoidCallback onCheckAttendance;
  final VoidCallback onShowGachaDialog;
  final VoidCallback onShowSynthesisDialog;
  final VoidCallback onShowBossSelectDialog;
  final VoidCallback onShowRankingDialog;
  final Function(DailyQuest) onClaimQuestReward;

  const HomeTab({
    super.key,
    required this.equippedSword,
    required this.attendanceStreak,
    required this.canCheckAttendance,
    required this.dailyQuests,
    required this.sellEventRate,
    required this.sellEventName,
    required this.sellEventEmoji,
    required this.sellEventColor,
    this.titleBonus = 0,
    this.titleName,
    required this.onCheckAttendance,
    required this.onShowGachaDialog,
    required this.onShowSynthesisDialog,
    required this.onShowBossSelectDialog,
    required this.onShowRankingDialog,
    required this.onClaimQuestReward,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (equippedSword != null) _buildEquippedSwordCard(),
          const SizedBox(height: 16),
          _buildSellEventBanner(),
          const SizedBox(height: 16),
          if (canCheckAttendance) _buildAttendanceCard(),
          const SizedBox(height: 16),
          _buildQuickMenu(),
          const SizedBox(height: 16),
          _buildQuestPreview(),
        ],
      ),
    );
  }

  Widget _buildSellEventBanner() {
    final isGoodEvent = sellEventRate >= 1.5;
    final isBadEvent = sellEventRate < 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGoodEvent
              ? [Colors.green.withOpacity(0.3), Colors.green.withOpacity(0.1)]
              : isBadEvent
              ? [Colors.red.withOpacity(0.3), Colors.red.withOpacity(0.1)]
              : [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sellEventColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Text(sellEventEmoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '마지막 판매: $sellEventName',
                      style: TextStyle(
                        color: sellEventColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: sellEventColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${sellEventRate}배',
                        style: TextStyle(
                          color: sellEventColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '💡 판매할 때마다 랜덤 이벤트 적용!',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.casino, color: sellEventColor, size: 28),
        ],
      ),
    );
  }

  Widget _buildEquippedSwordCard() {
    final sword = equippedSword!;
    final grade = sword.data.grade;
    final element = sword.data.element;
    final skills = sword.data.skills;
    final enhanceBonus = sword.level * sword.powerPerLevel;

    return Container(
      decoration: AppDecorations.glowCard(grade.color, blurRadius: 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                SwordImageWidget(
                  grade: grade,
                  element: element,
                  level: sword.level,
                  breakthroughLevel: sword.breakthroughLevel,
                  size: 80,
                  showPulse: true,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: grade.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          grade.displayName,
                          style: TextStyle(
                            color: grade.color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sword.data.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '+${sword.level}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.2)),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    Text(element.emoji, style: const TextStyle(fontSize: 16)),
                    '속성',
                    element.nameKr,
                    Colors.cyan,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white10),
                Expanded(
                  child: _buildStatItem(
                    Image.asset(
                      'assets/images/home/fighting_power.png',
                      width: 20,
                      height: 20,
                    ),
                    '전투력',
                    '${sword.totalPower + titleBonus}',
                    Colors.amber,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white10),
                Expanded(
                  child: _buildStatItem(
                    Image.asset(
                      'assets/images/home/fighting_basic.png',
                      width: 20,
                      height: 20,
                    ),
                    '기본ATK',
                    '${sword.data.baseAtk}',
                    Colors.red,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white10),
                Expanded(
                  child: _buildStatItem(
                    Image.asset(
                      'assets/images/home/fighting_enhance.png',
                      width: 20,
                      height: 20,
                    ),
                    '강화',
                    '+$enhanceBonus',
                    Colors.purple,
                  ),
                ),
                if (titleBonus > 0) ...[
                  Container(width: 1, height: 40, color: Colors.white10),
                  Expanded(
                    child: _buildStatItem(
                      Image.asset(
                        'assets/images/home/fighting_title.png',
                        width: 20,
                        height: 20,
                      ),
                      '칭호',
                      '+$titleBonus',
                      Colors.green,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (skills.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.purple[300],
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '스킬 (${skills.length}개)',
                        style: TextStyle(
                          color: Colors.purple[300],
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...skills.map((skill) => _buildSkillRow(skill)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '💰 판매가: ${formatNumber(sword.sellPrice)}G',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(Widget icon, String label, String value, Color color) {
    return Column(
      children: [
        SizedBox(width: 20, height: 20, child: icon),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSkillRow(SkillData skill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(skill.type.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${skill.type.nameKr} · ${skill.effect.nameKr}',
                  style: TextStyle(color: Colors.purple[200], fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${skill.procRate}%',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard() {
    final expectedReward = AppConstants.getAttendanceGold(attendanceStreak + 1);
    final isWeeklyBonus = (attendanceStreak + 1) % 7 == 0;

    return GestureDetector(
      onTap: onCheckAttendance,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.gradientCard([
          Colors.green.withOpacity(0.6),
          Colors.green,
        ]),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '출석 체크',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    attendanceStreak > 0
                        ? '$attendanceStreak일 연속 출석 중!'
                        : '첫 출석 보상을 받으세요!',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '보상: ${formatNumber(expectedReward)}G${isWeeklyBonus ? " + ${AppConstants.weeklyAttendanceDiamond}💎" : ""}',
                    style: const TextStyle(color: Colors.amber, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '받기',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMenu() {
    return Row(
      children: [
        _buildQuickMenuItem('🎰', '뽑기', onShowGachaDialog),
        const SizedBox(width: 8),
        _buildQuickMenuItem('🔄', '합성', onShowSynthesisDialog),
        const SizedBox(width: 8),
        _buildQuickMenuItem('🐉', '보스', onShowBossSelectDialog),
        const SizedBox(width: 8),
        _buildQuickMenuItem('🏆', '랭킹', onShowRankingDialog),
      ],
    );
  }

  Widget _buildQuickMenuItem(String icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: AppDecorations.card(),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestPreview() {
    final incomplete = dailyQuests.where((q) => !q.claimed).take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '일일 퀘스트',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...incomplete.map(
          (quest) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: AppDecorations.card(),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        quest.progressText,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (quest.isCompleted && !quest.claimed)
                  ElevatedButton(
                    onPressed: () => onClaimQuestReward(quest),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      '수령',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
