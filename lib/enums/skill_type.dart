enum SkillType {
  slash,   // 참격 - 밸런스형
  pierce,  // 관통 - 방어 무시
  blast,   // 폭발 - 고대미지
  drain,   // 흡수 - 회복형
  guard,   // 수호 - 방어형
}

// ✅ 상성 배율 상수 (v10 밸런스)
const double skillAdvantageMultiplier = 1.012;     // +1.2%
const double skillDisadvantageMultiplier = 0.988;  // -1.2%

extension SkillTypeExt on SkillType {
  String get nameKr {
    switch (this) {
      case SkillType.slash: return '참격';
      case SkillType.pierce: return '관통';
      case SkillType.blast: return '폭발';
      case SkillType.drain: return '흡수';
      case SkillType.guard: return '수호';
    }
  }

  String get emoji {
    switch (this) {
      case SkillType.slash: return '🗡️';
      case SkillType.pierce: return '📍';
      case SkillType.blast: return '💥';
      case SkillType.drain: return '🩸';
      case SkillType.guard: return '🛡️';
    }
  }
  
  // ✅ 스킬 타입 설명
  String get description {
    switch (this) {
      case SkillType.slash: return '균형 잡힌 공격';
      case SkillType.pierce: return '방어 관통';
      case SkillType.blast: return '폭발적 피해';
      case SkillType.drain: return '피해량 일부 회복';
      case SkillType.guard: return '피해 감소';
    }
  }

  /// ✅ 직관적인 상성 관계
  /// pierce(관통) > guard(수호) - 관통이 방어 무시
  /// guard(수호) > blast(폭발) - 방어가 폭발 흡수
  /// blast(폭발) > slash(참격) - 범위 공격이 근접 압도
  /// slash(참격) > drain(흡수) - 빠른 공격이 흡수 방해
  /// drain(흡수) > pierce(관통) - 흡수가 관통 피해 회복
  bool isStrongAgainst(SkillType other) {
    return switch (this) {
      SkillType.pierce => other == SkillType.guard,  // 관통 > 수호
      SkillType.guard => other == SkillType.blast,   // 수호 > 폭발
      SkillType.blast => other == SkillType.slash,   // 폭발 > 참격
      SkillType.slash => other == SkillType.drain,   // 참격 > 흡수
      SkillType.drain => other == SkillType.pierce,  // 흡수 > 관통
    };
  }

  bool isWeakAgainst(SkillType other) {
    return other.isStrongAgainst(this);
  }
  
  double getMultiplierAgainst(SkillType other) {
    if (isStrongAgainst(other)) return skillAdvantageMultiplier;
    if (isWeakAgainst(other)) return skillDisadvantageMultiplier;
    return 1.0;
  }
  
  // ✅ 상성 아이콘
  SkillType get strongAgainst {
    return switch (this) {
      SkillType.pierce => SkillType.guard,
      SkillType.guard => SkillType.blast,
      SkillType.blast => SkillType.slash,
      SkillType.slash => SkillType.drain,
      SkillType.drain => SkillType.pierce,
    };
  }
  
  SkillType get weakAgainst {
    return switch (this) {
      SkillType.pierce => SkillType.drain,
      SkillType.guard => SkillType.pierce,
      SkillType.blast => SkillType.guard,
      SkillType.slash => SkillType.blast,
      SkillType.drain => SkillType.slash,
    };
  }
  
  // ✅ 상성 설명 텍스트
  String get advantageText => 
      '$emoji$nameKr → ${strongAgainst.emoji} 유리 | ${weakAgainst.emoji} → 불리';
}