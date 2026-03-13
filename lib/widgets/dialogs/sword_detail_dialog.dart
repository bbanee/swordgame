// lib/widgets/dialogs/sword_detail_dialog.dart
// 검 클릭 시 상세 정보를 보여주는 다이얼로그

import 'package:flutter/material.dart';
import '../../models/owned_sword.dart';
import '../../models/sword_data.dart';
import '../../enums/sword_grade.dart';
import '../../enums/element.dart';
import '../../enums/skill_type.dart';
import '../../enums/skill_effect.dart';
import '../sword_image_widget.dart'; // 🔥 추가

class SwordDetailDialog extends StatelessWidget {
  final OwnedSword sword;
  final bool isEquipped;
  final bool canSell; // ✅ 판매 가능 여부 (검 1개면 false)
  final VoidCallback? onEquip;
  final VoidCallback? onSell;

  const SwordDetailDialog({
    super.key,
    required this.sword,
    this.isEquipped = false,
    this.canSell = true, // ✅ 기본값 true
    this.onEquip,
    this.onSell,
  });

  @override
  Widget build(BuildContext context) {
    final grade = sword.data.grade;
    final element = sword.data.element;
    final skills = sword.data.skills;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: grade.color, width: 2),
          boxShadow: [
            BoxShadow(
              color: grade.color.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단 헤더 (검 이미지 & 기본 정보)
              _buildHeader(grade, element),

              // 스탯 정보
              _buildStats(),

              // 스킬 정보
              if (skills.isNotEmpty) _buildSkills(skills),

              // 하단 버튼
              _buildButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(SwordGrade grade, GameElement element) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [grade.color.withOpacity(0.3), grade.color.withOpacity(0.1)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        children: [
          // 장착 중 표시
          if (isEquipped)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.amber, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '장착 중',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // 검 이미지 (SwordImageWidget)
          SwordImageWidget(
            grade: grade,
            element: element,
            level: sword.level,
            breakthroughLevel: sword.breakthroughLevel,
            size: 120,
            showPulse: true,
          ),
          const SizedBox(height: 12),

          // 등급 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: grade.color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: grade.color.withOpacity(0.5)),
            ),
            child: Text(
              grade.displayName,
              style: TextStyle(
                color: grade.color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 검 이름
          Text(
            sword.data.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          // 강화 레벨
          Text(
            '+${sword.level}',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(color: Colors.amber.withOpacity(0.5), blurRadius: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    // 강화 보너스 계산
    final enhanceBonus = sword.level * sword.powerPerLevel;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 속성 & 전투력
          Row(
            children: [
              // 속성
              Expanded(
                child: _statBox(
                  icon: sword.data.element.emoji,
                  label: '속성',
                  value: sword.data.element.nameKr,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(width: 12),
              // 전투력
              Expanded(
                child: _statBox(
                  icon: '⚡',
                  label: '전투력',
                  value: '${sword.totalPower}',
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 기본 공격력 & 강화 보너스
          Row(
            children: [
              Expanded(
                child: _statBox(
                  icon: '🗡️',
                  label: '기본 공격력',
                  value: '${sword.data.baseAtk}',
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statBox(
                  icon: '✨',
                  label: '강화 보너스',
                  value: '+$enhanceBonus',
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox({
    required String icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkills(List<SkillData> skills) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.purple, size: 18),
              SizedBox(width: 6),
              Text(
                '스킬',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 스킬 리스트
          ...skills.map((skill) => _buildSkillItem(skill)),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSkillItem(SkillData skill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 스킬명 & 타입
          Row(
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
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${skill.type.nameKr} · ${skill.effect.nameKr}',
                      style: TextStyle(color: Colors.purple[200], fontSize: 11),
                    ),
                  ],
                ),
              ),
              // 발동 확률
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${skill.procRate}%',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 스킬 설명
          Text(
            _getSkillDescription(skill),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // ✅ 판매 버튼 (장착 중이어도 판매 가능, 단 1개면 불가)
          if (onSell != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canSell
                    ? () {
                        Navigator.pop(context);
                        onSell?.call();
                      }
                    : null,
                icon: const Icon(Icons.sell, size: 18),
                label: Text(
                  canSell
                      ? '판매 (${_formatGold(sword.data.getSellPrice(sword.level))}G)'
                      : '판매 불가 (1개)',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: canSell ? Colors.orange : Colors.grey,
                  side: BorderSide(
                    color: canSell ? Colors.orange : Colors.grey,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

          if (onSell != null) const SizedBox(width: 8),

          // 장착 버튼
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isEquipped
                  ? null
                  : () {
                      Navigator.pop(context);
                      onEquip?.call();
                    },
              icon: Icon(
                isEquipped ? Icons.check : Icons.add_circle_outline,
                size: 18,
              ),
              label: Text(isEquipped ? '장착 중' : '장착하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isEquipped ? Colors.grey : Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatGold(int gold) {
    if (gold >= 10000) {
      return '${(gold / 10000).toStringAsFixed(1)}만';
    } else if (gold >= 1000) {
      return '${(gold / 1000).toStringAsFixed(1)}천';
    }
    return '$gold';
  }
}
