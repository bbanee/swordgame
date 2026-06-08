enum SkillEffect {
  // 공격 효과
  damage, // 단순 피해 증폭
  bleed, // 지속 피해 (DOT) - 매 턴 고정 피해
  pierce, // 방어/가드 무시
  critBoost, // 치명타 확률 증가
  // 흡수/회복 효과
  lifesteal, // 피해의 일부 HP 회복
  heal, // 즉시 HP 회복
  regen, // 지속 회복 (HOT)
  // 디버프 효과
  stun, // 진짜 기절 (1턴 행동 불가)
  slow, // 적중률 감소 (기존 stun의 실제 효과)
  weaken, // 상대 공격력 감소
  // 버프 효과
  shield, // 피해 감소 (방어막)
  dodge, // 회피율 증가
  attackBoost, // 자신 공격력 증가
}

extension SkillEffectExt on SkillEffect {
  String get nameKr {
    switch (this) {
      case SkillEffect.damage:
        return '강타';
      case SkillEffect.bleed:
        return '출혈';
      case SkillEffect.pierce:
        return '관통';
      case SkillEffect.critBoost:
        return '필살';
      case SkillEffect.lifesteal:
        return '흡혈';
      case SkillEffect.heal:
        return '치유';
      case SkillEffect.regen:
        return '재생';
      case SkillEffect.stun:
        return '기절';
      case SkillEffect.slow:
        return '둔화';
      case SkillEffect.weaken:
        return '약화';
      case SkillEffect.shield:
        return '방어막';
      case SkillEffect.dodge:
        return '회피';
      case SkillEffect.attackBoost:
        return '강화';
    }
  }

  String get emoji {
    switch (this) {
      case SkillEffect.damage:
        return '⚔️';
      case SkillEffect.bleed:
        return '🩸';
      case SkillEffect.pierce:
        return '📍';
      case SkillEffect.critBoost:
        return '💢';
      case SkillEffect.lifesteal:
        return '🧛';
      case SkillEffect.heal:
        return '💚';
      case SkillEffect.regen:
        return '💖';
      case SkillEffect.stun:
        return '😵';
      case SkillEffect.slow:
        return '🐌';
      case SkillEffect.weaken:
        return '📉';
      case SkillEffect.shield:
        return '🛡️';
      case SkillEffect.dodge:
        return '💨';
      case SkillEffect.attackBoost:
        return '📈';
    }
  }

  /// 효과 설명
  String get description {
    switch (this) {
      case SkillEffect.damage:
        return '피해량 증가';
      case SkillEffect.bleed:
        return '매 턴 지속 피해';
      case SkillEffect.pierce:
        return '방어/가드 무시';
      case SkillEffect.critBoost:
        return '치명타 확률 증가';
      case SkillEffect.lifesteal:
        return '피해의 일부 회복';
      case SkillEffect.heal:
        return '즉시 HP 회복';
      case SkillEffect.regen:
        return '매 턴 HP 회복';
      case SkillEffect.stun:
        return '1턴 행동 불가';
      case SkillEffect.slow:
        return '적중률 감소';
      case SkillEffect.weaken:
        return '공격력 감소';
      case SkillEffect.shield:
        return '받는 피해 감소';
      case SkillEffect.dodge:
        return '회피율 증가';
      case SkillEffect.attackBoost:
        return '공격력 증가';
    }
  }
}
