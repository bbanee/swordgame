import '../enums/sword_grade.dart';
import '../enums/element.dart';
import '../enums/skill_type.dart';
import '../enums/skill_effect.dart';

class SkillData {
  final String name;
  final double multiplier;
  final int procRate;
  final GameElement? element; // ← 변경
  final SkillType type;
  final SkillEffect effect;
  final int value;
  final int cooldownTurns;

  const SkillData({
    required this.name,
    required this.multiplier,
    required this.procRate,
    required this.type,
    this.effect = SkillEffect.damage,
    this.value = 0,
    this.cooldownTurns = 1,
    this.element,
  });
}

class SwordData {
  final String id;
  final String name;
  final SwordGrade grade;
  final GameElement element; // ← 변경
  final int baseAtk;
  final List<SkillData> skills;

  const SwordData({
    required this.id,
    required this.name,
    required this.grade,
    required this.element,
    required this.baseAtk,
    required this.skills,
  });

  SkillType get primarySkillType =>
      skills.isNotEmpty ? skills.first.type : SkillType.slash;

  // 🔥 판매 가격 (v10 - 강화 비용 상향에 맞춰 3배 상향)
  int getSellPrice(int level) {
    // 등급별 기본 배율
    final gradeMultiplier =
        {
          SwordGrade.normal: 1.5,
          SwordGrade.rare: 4.0,
          SwordGrade.unique: 10.0,
          SwordGrade.legend: 25.0,
          SwordGrade.hidden: 60.0,
          SwordGrade.immortal: 150.0,
        }[grade] ??
        1.5;

    // 레벨별 추가 가격 (3배 상향)
    // +10: 30,000G, +20: 240,000G, +30: 900,000G (노말 기준)
    int levelBonus = 0;
    if (level > 0) {
      if (level <= 10) {
        levelBonus = level * level * 300; // +10 = 30,000
      } else if (level <= 20) {
        levelBonus =
            30000 +
            (level - 10) *
                (level - 10) *
                2100; // +20 = 30,000 + 210,000 = 240,000
      } else if (level <= 30) {
        levelBonus =
            240000 +
            (level - 20) *
                (level - 20) *
                6600; // +30 = 240,000 + 660,000 = 900,000
      } else {
        levelBonus = 900000 + (level - 30) * (level - 30) * 15000;
      }
    }

    // 최종 가격 = (기본가 + 레벨 보너스) × 등급 배율
    return ((grade.baseSellPrice + levelBonus) * gradeMultiplier).round();
  }
}
