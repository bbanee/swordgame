import 'dart:math' as math;

import '../enums/element.dart';
import '../enums/sword_grade.dart';
import '../enums/skill_type.dart';
import '../enums/skill_effect.dart';
import '../models/sword_data.dart';
import 'helpers.dart';

// ============================================================
// 🎮 밸런스 상수 (v13 - 검 강화하기 밸런스)
// ============================================================

const int underdogThreshold = 40;
const double underdogBonusPer100 = 0.10;
const double underdogMaxBonus = 0.30;

/// 등급별 레벨당 전투력 보너스 (v13)
const Map<SwordGrade, int> gradeLevelBonus = {
  SwordGrade.normal: 6,      // v12: 8 → 6
  SwordGrade.rare: 7,        // v12: 9 → 7
  SwordGrade.unique: 8,      // v12: 9 → 8
  SwordGrade.legend: 10,     // v12: 13 → 10
  SwordGrade.hidden: 13,     // v12: 15 → 13
  SwordGrade.immortal: 17,   // v12: 18 → 17
};


/// HP 계산 상수
const int baseHp = 2500;
const double hpPerPower = 1.8;

/// 데미지 계산 상수
const int baseDamage = 45;
const double damagePerPower = 0.12;

/// 상성 배율 (유리 시 +5~10% 승률 목표)
const double elementAdvantage = 1.04;       // v12: 1.025 → 1.04 (+4%)
const double elementDisadvantage = 0.96;    // v12: 0.975 → 0.96 (-4%)
const double skillAdvantageMultiplier = 1.10;
const double skillDisadvantageMultiplier = 0.90;

/// 전투 기본 수치
const double baseHitChance = 0.88;
const double baseDodgeChance = 0.06;
const double baseGuardChance = 0.12;
const double baseCritChance = 0.10;
const double critDamageMult = 1.6;
const double guardDamageReduction = 0.55;
const double counterChanceNormal = 0.06;
const double counterChanceGuarded = 0.12;
const double levelHitBonus = 0.003;
const double levelCritBonus = 0.002;

/// 등급별 회피 보너스 (v13 - 고등급 유리)
const Map<SwordGrade, double> gradeDodgeBonus = {
  SwordGrade.normal: 0.02,     // v12: 0.04 → 0.02
  SwordGrade.rare: 0.025,      // v12: 0.03 → 0.025
  SwordGrade.unique: 0.03,     // v12: 0.025 → 0.03
  SwordGrade.legend: 0.035,    // v12: 0.02 → 0.035
  SwordGrade.hidden: 0.04,     // v12: 0.025 → 0.04
  SwordGrade.immortal: 0.05,   // v12: 0.02 → 0.05
};

/// 등급별 치명타 보너스 (v13 - 고등급 유리)
const Map<SwordGrade, double> gradeCritBonus = {
  SwordGrade.normal: 0.01,     // v12: 0.02 → 0.01
  SwordGrade.rare: 0.02,       // v12: 0.04 → 0.02
  SwordGrade.unique: 0.03,     // v12: 0.03 → 0.03 (유지)
  SwordGrade.legend: 0.04,     // v12: 0.025 → 0.04
  SwordGrade.hidden: 0.05,     // v12: 0.03 → 0.05
  SwordGrade.immortal: 0.06,   // v12: 0.035 → 0.06
};

// ============================================================
// 🎮 배틀 참가자
// ============================================================

class BattleParticipant {
  final String id;
  final String name;
  final SwordGrade grade;
  final int swordLevel;
  final int baseAtk;
  final GameElement element;
  final SkillType primarySkillType;
  final List<SkillData> skills;
  final String swordName;
  final int titleBonus;  // 칭호 보너스

  BattleParticipant({
    required this.id,
    required this.name,
    required this.grade,
    required this.swordLevel,
    required this.baseAtk,
    required this.element,
    required this.primarySkillType,
    required this.skills,
    this.swordName = '검',
    this.titleBonus = 0,  // 기본값 0 (NPC/상대방은 0)
  });

  int get power => baseAtk + swordLevel * (gradeLevelBonus[grade] ?? 10) + titleBonus;
  int get hp => 2500 + (power * 1.8).round();
}

// ============================================================
// 🎮 배틀 결과
// ============================================================

class BattleResult {
  final bool iWin;
  final int rewardGold;
  final List<String> logs;
  final int myHpEnd;
  final int oppHpEnd;
  final int myMaxHp;
  final int oppMaxHp;
  final int totalTurns;

  const BattleResult({
    required this.iWin,
    required this.rewardGold,
    required this.logs,
    required this.myHpEnd,
    required this.oppHpEnd,
    required this.myMaxHp,
    required this.oppMaxHp,
    this.totalTurns = 0,
  });
  
  // 호환용 getter
  bool get isWin => iWin;
  int get goldEarned => rewardGold;
  int get myHpRemaining => myHpEnd;
  int get oppHpRemaining => oppHpEnd;
}

// ============================================================
// 🎮 내부 상태 클래스
// ============================================================

/// 버프/디버프 효과 데이터
class _StatusEffect {
  final String name;
  final int value;
  int remainingTurns;

  _StatusEffect({
    required this.name,
    required this.value,
    required this.remainingTurns,
  });
}

/// DOT/HOT 효과 데이터
class _TickEffect {
  final String name;
  final int damageOrHeal;
  int remainingTurns;

  _TickEffect({
    required this.name,
    required this.damageOrHeal,
    required this.remainingTurns,
  });
}

/// 전투 참가자의 상태
class _CombatantState {
  int hp;
  final int maxHp;
  final Map<String, _StatusEffect> buffs = {};
  final Map<String, _StatusEffect> debuffs = {};
  final List<_TickEffect> dots = [];
  final List<_TickEffect> hots = [];
  final Map<String, int> skillCooldowns = {};
  int shield = 0;

  _CombatantState({required this.hp, required this.maxHp});

  bool get isStunned => debuffs.containsKey('stun');
  bool get hasDodgeBuff => buffs.containsKey('dodge');
  bool get hasShield => shield > 0 || buffs.containsKey('shield');
  
  double get critBonus => buffs.containsKey('critBoost') ? 0.15 : 0.0;
  double get attackBonus => buffs.containsKey('attackBoost') ? 1.25 : 1.0;
  double get damageReduction => buffs.containsKey('shield') ? 0.75 : 1.0;
  double get attackPenalty => debuffs.containsKey('weaken') ? 0.75 : 1.0;
  int get accuracyPenalty => debuffs.containsKey('slow') ? 12 : 0;
}

// ============================================================
// 🎮 배틀 엔진
// ============================================================

class BattleEngine {
  
  /// 약자 보정 계산
  static double _getUnderdogBonus(int myPower, int oppPower) {
    final diff = oppPower - myPower;
    if (diff <= underdogThreshold) return 1.0;
    
    final bonus = (diff - underdogThreshold) / 100.0 * underdogBonusPer100;
    return 1.0 + math.min(bonus, underdogMaxBonus);
  }

  /// 등급별 회피 보너스
  static double _getDodgeBonus(SwordGrade grade) {
    return gradeDodgeBonus[grade] ?? 0.02;
  }

  /// 등급별 치명타 보너스
  static double _getCritBonus(SwordGrade grade) {
    return gradeCritBonus[grade] ?? 0.02;
  }

  /// 배틀 시뮬레이션
  static BattleResult simulate({
    required BattleParticipant me,
    required BattleParticipant opponent,
    int maxTurns = 100,
    math.Random? rng,
  }) {
    final random = rng ?? math.Random();
    final logs = <String>[];

    // 수정
    final myMaxHp = 2500 + (me.power * 1.8).round();
    final oppMaxHp = 2500 + (opponent.power * 1.8).round();

    // 전투 상태 초기화
    final myState = _CombatantState(hp: myMaxHp, maxHp: myMaxHp);
    final oppState = _CombatantState(hp: oppMaxHp, maxHp: oppMaxHp);

    // 전투 시작 로그
    logs.add('⚔️ 배틀 시작!');
    logs.add('');
    logs.add('👤 나: ${me.grade.emoji} ${me.name} (+${me.swordLevel})');
    logs.add('   전투력: ${formatNumber(me.power)} | 원소: ${me.element.emoji}${me.element.nameKr}');
    logs.add('   스킬상성: ${me.primarySkillType.emoji}${me.primarySkillType.nameKr}');
    logs.add('');
    logs.add('👤 상대: ${opponent.grade.emoji} ${opponent.name} (+${opponent.swordLevel})');
    logs.add('   전투력: ${formatNumber(opponent.power)} | 원소: ${opponent.element.emoji}${opponent.element.nameKr}');
    logs.add('   스킬상성: ${opponent.primarySkillType.emoji}${opponent.primarySkillType.nameKr}');
    logs.add('');
    logs.add('━━━━━━━━━━━━━━━━━━━━━━━━');

    int actualTurns = 0;

    for (int turn = 1; turn <= maxTurns; turn++) {
      actualTurns = turn;
      logs.add('');
      logs.add('【 $turn턴 】');

      // ===== 턴 시작: DOT/HOT 처리 =====
      _processTurnStartEffects(myState, me.name, logs);
      if (myState.hp <= 0) {
        logs.add('');
        logs.add('🏁 ${me.name}이(가) 쓰러졌습니다...');
        break;
      }

      _processTurnStartEffects(oppState, opponent.name, logs);
      if (oppState.hp <= 0) {
        logs.add('');
        logs.add('🏁 ${opponent.name}이(가) 쓰러졌습니다!');
        break;
      }

      // ===== 쿨다운 감소 =====
      _tickCooldowns(myState.skillCooldowns);
      _tickCooldowns(oppState.skillCooldowns);

      // ===== 선공 결정 =====
      final meFirst = _decideFirst(me, opponent, random);

      if (meFirst) {
        // 내 공격
        if (!_processAttack(
          attacker: me,
          attackerState: myState,
          defender: opponent,
          defenderState: oppState,
          rng: random,
          logs: logs,
        )) {
          logs.add('');
          logs.add('🏁 ${opponent.name}이(가) 쓰러졌습니다!');
          break;
        }

        // 상대 공격
        if (!_processAttack(
          attacker: opponent,
          attackerState: oppState,
          defender: me,
          defenderState: myState,
          rng: random,
          logs: logs,
        )) {
          logs.add('');
          logs.add('🏁 ${me.name}이(가) 쓰러졌습니다...');
          break;
        }
      } else {
        // 상대 선공
        if (!_processAttack(
          attacker: opponent,
          attackerState: oppState,
          defender: me,
          defenderState: myState,
          rng: random,
          logs: logs,
        )) {
          logs.add('');
          logs.add('🏁 ${me.name}이(가) 쓰러졌습니다...');
          break;
        }

        // 내 공격
        if (!_processAttack(
          attacker: me,
          attackerState: myState,
          defender: opponent,
          defenderState: oppState,
          rng: random,
          logs: logs,
        )) {
          logs.add('');
          logs.add('🏁 ${opponent.name}이(가) 쓰러졌습니다!');
          break;
        }
      }

      // ===== 턴 종료: 버프/디버프 지속시간 감소 =====
      _tickStatusEffects(myState);
      _tickStatusEffects(oppState);

      // HP 상태 표시
      logs.add('');
      logs.add('📊 HP: ${me.name} ${myState.hp}/${myMaxHp} | ${opponent.name} ${oppState.hp}/${oppMaxHp}');
    }

    // ===== 결과 판정 =====
    final iWin = myState.hp > 0 && (oppState.hp <= 0 || myState.hp > oppState.hp);
    final reward = iWin ? calculateBattleReward(me.swordLevel, opponent.swordLevel, opponent.grade, me.grade) : 0;

    // 패배자의 HP를 0으로 설정 (HP바 표시용)
    int finalMyHp = myState.hp;
    int finalOppHp = oppState.hp;
    if (iWin) {
      finalOppHp = 0;
    } else {
      finalMyHp = 0;
    }

    logs.add('');
    logs.add('━━━━━━━━━━━━━━━━━━━━━━━━');
    if (iWin) {
      logs.add('🎉 승리! 전리품 +${formatNumber(reward)}G');
    } else if (myState.hp == oppState.hp) {
      logs.add('⚖️ 무승부... (HP 동률)');
    } else {
      logs.add('💀 패배...');
    }

    return BattleResult(
      iWin: iWin,
      rewardGold: reward,
      logs: logs,
      myHpEnd: math.max(0, finalMyHp),
      oppHpEnd: math.max(0, finalOppHp),
      myMaxHp: myMaxHp,
      oppMaxHp: oppMaxHp,
      totalTurns: actualTurns,
    );
  }

  /// 턴 시작 시 DOT/HOT 및 효과 처리
  static void _processTurnStartEffects(_CombatantState state, String name, List<String> logs) {
    // DOT 처리
    final dotsToRemove = <_TickEffect>[];
    for (final dot in state.dots) {
      state.hp = math.max(0, state.hp - dot.damageOrHeal);
      logs.add('   🩸 $name ${dot.name} 피해: -${dot.damageOrHeal}');
      dot.remainingTurns--;
      if (dot.remainingTurns <= 0) {
        dotsToRemove.add(dot);
      }
    }
    state.dots.removeWhere((d) => dotsToRemove.contains(d));

    // HOT 처리
    final hotsToRemove = <_TickEffect>[];
    for (final hot in state.hots) {
      final healAmount = math.min(hot.damageOrHeal, state.maxHp - state.hp);
      if (healAmount > 0) {
        state.hp += healAmount;
        logs.add('   💚 $name ${hot.name} 회복: +$healAmount');
      }
      hot.remainingTurns--;
      if (hot.remainingTurns <= 0) {
        hotsToRemove.add(hot);
      }
    }
    state.hots.removeWhere((h) => hotsToRemove.contains(h));
  }

  /// 쿨다운 틱
  static void _tickCooldowns(Map<String, int> cooldowns) {
    final keys = cooldowns.keys.toList();
    for (final k in keys) {
      final v = cooldowns[k] ?? 0;
      if (v <= 1) {
        cooldowns.remove(k);
      } else {
        cooldowns[k] = v - 1;
      }
    }
  }

  /// 버프/디버프 지속시간 틱
  static void _tickStatusEffects(_CombatantState state) {
    // 버프 틱
    final buffsToRemove = <String>[];
    for (final entry in state.buffs.entries) {
      entry.value.remainingTurns--;
      if (entry.value.remainingTurns <= 0) {
        buffsToRemove.add(entry.key);
      }
    }
    for (final key in buffsToRemove) {
      state.buffs.remove(key);
    }

    // 디버프 틱
    final debuffsToRemove = <String>[];
    for (final entry in state.debuffs.entries) {
      entry.value.remainingTurns--;
      if (entry.value.remainingTurns <= 0) {
        debuffsToRemove.add(entry.key);
      }
    }
    for (final key in debuffsToRemove) {
      state.debuffs.remove(key);
    }

    // 쉴드 감소
    if (state.shield > 0) {
      state.shield = math.max(0, state.shield - 8);
    }
  }

  /// 선공 결정
  static bool _decideFirst(BattleParticipant a, BattleParticipant b, math.Random rng) {
    final score = (a.swordLevel - b.swordLevel) * 0.3 + ((a.power - b.power) / 300);
    final p = 0.5 + (score * 0.01);
    final clamped = p.clamp(0.42, 0.58);
    return rng.nextDouble() < clamped;
  }

  /// 공격 처리 (defender HP > 0 이면 true 반환)
  static bool _processAttack({
    required BattleParticipant attacker,
    required _CombatantState attackerState,
    required BattleParticipant defender,
    required _CombatantState defenderState,
    required math.Random rng,
    required List<String> logs,
  }) {
    // 스턴 체크
    if (attackerState.isStunned) {
      logs.add('   😵 ${attacker.name}은(는) 기절 상태! 행동 불가');
      attackerState.debuffs.remove('stun');
      return defenderState.hp > 0;
    }

    // 명중률 계산
    double hitChance = baseHitChance;
    hitChance -= attackerState.accuracyPenalty / 100.0;
    hitChance += (attacker.swordLevel - defender.swordLevel) * levelHitBonus;
    hitChance = hitChance.clamp(0.70, 0.95);

    // 회피 버프 체크
    if (defenderState.hasDodgeBuff) {
      hitChance -= 0.20;
      hitChance = hitChance.clamp(0.35, 0.98);
    }

    // 명중 판정
    if (rng.nextDouble() > hitChance) {
      if (defenderState.hasDodgeBuff) {
        logs.add('   💨 ${defender.name}이(가) 회피! ${attacker.name}의 공격 빗나감');
        defenderState.buffs.remove('dodge');
      } else {
        logs.add('   💨 ${attacker.name}의 공격이 빗나갔습니다!');
      }
      return defenderState.hp > 0;
    }

    // 기본 회피 판정 (등급별 보너스 적용)
    final dodgeBonus = _getDodgeBonus(defender.grade);
    final dodgeChance = baseDodgeChance + dodgeBonus;
    if (rng.nextDouble() < dodgeChance && !defenderState.isStunned) {
      logs.add('   💨 ${defender.name} 회피 성공!');
      return defenderState.hp > 0;
    }

    // 가드 판정
    bool guarded = rng.nextDouble() < baseGuardChance;
    if (defenderState.hasShield) {
      guarded = true;
    }

    // 스킬 선택
    final skill = _selectSkill(attacker.skills, attackerState.skillCooldowns, rng);

    // 데미지 계수 초기화
    double dmgMultiplier = 1.0;
    int bonusFlat = 0;
    int healAmount = 0;
    bool pierceGuard = false;
    int lifestealPercent = 0;

    GameElement atkElement = attacker.element;
    SkillType atkSkillType = attacker.primarySkillType;

    // 공격자 버프/디버프 적용
    dmgMultiplier *= attackerState.attackBonus;
    dmgMultiplier *= attackerState.attackPenalty;

    // ✅ 약자 보정 적용 (핵심!)
    final underdogMult = _getUnderdogBonus(attacker.power, defender.power);
    dmgMultiplier *= underdogMult;

    // 스킬 처리
    if (skill != null) {
      dmgMultiplier *= skill.multiplier;
      atkSkillType = skill.type;
      if (skill.element != null) {
        atkElement = skill.element!;
      }

      // 스킬 상성
      if (skill.type.isStrongAgainst(defender.primarySkillType)) {
        dmgMultiplier *= skillAdvantageMultiplier;
        logs.add('   🔺 스킬 상성 유리! (${skill.type.nameKr} > ${defender.primarySkillType.nameKr})');
      } else if (skill.type.isWeakAgainst(defender.primarySkillType)) {
        dmgMultiplier *= skillDisadvantageMultiplier;
        logs.add('   🔻 스킬 상성 불리 (${skill.type.nameKr} < ${defender.primarySkillType.nameKr})');
      }

      // 스킬 효과 처리
      _applySkillEffect(
        skill: skill,
        attacker: attacker,
        attackerState: attackerState,
        defender: defender,
        defenderState: defenderState,
        logs: logs,
        bonusFlatRef: (v) => bonusFlat += v,
        healRef: (v) => healAmount += v,
        pierceRef: (v) => pierceGuard = v,
        lifestealRef: (v) => lifestealPercent = v,
        dmgMultiplierRef: (v) => dmgMultiplier *= v,
      );

      // 쿨다운 설정
      attackerState.skillCooldowns[skill.name] = math.max(1, skill.cooldownTurns);
      logs.add('   ${skill.type.emoji} ${attacker.name} 스킬: 【${skill.name}】');
    }

    // 원소 상성 (새 배율)
    final elemMultiplier = _calculateElementMultiplier(atkElement, defender.element);
    if (elemMultiplier > 1.0) {
      logs.add('   ${atkElement.emoji} 원소 유리! (${atkElement.nameKr} → ${defender.element.nameKr})');
    } else if (elemMultiplier < 1.0) {
      logs.add('   ${defender.element.emoji} 원소 불리 (${atkElement.nameKr} → ${defender.element.nameKr})');
    }

    // 치명타 판정 (등급별 보너스 적용)
    final critGradeBonus = _getCritBonus(attacker.grade);
    double critChance = baseCritChance + critGradeBonus + (attacker.swordLevel * levelCritBonus);
    critChance += attackerState.critBonus;
    critChance = critChance.clamp(0.05, 0.35);
    final isCrit = rng.nextDouble() < critChance;
    if (isCrit) {
      dmgMultiplier *= critDamageMult;
    }

    // 수정
    final underdogBonus = _getUnderdogBonus(attacker.power, defender.power);
    dmgMultiplier *= underdogBonus;

    final baseDamage = 50 + (attacker.power * 0.14).round();
    int damage = calculateDamage(baseDamage, multiplier: dmgMultiplier * elemMultiplier) + bonusFlat;

    // 가드 적용 (새 감소율)
    if (guarded && !pierceGuard) {
      damage = (damage * guardDamageReduction).round();
      logs.add('   🛡️ ${defender.name} 가드! 피해 ${((1 - guardDamageReduction) * 100).round()}% 감소');
    } else if (guarded && pierceGuard) {
      logs.add('   📌 관통! ${defender.name}의 가드를 무시!');
    }

    // 방어막 적용
    if (defenderState.shield > 0) {
      final absorbed = math.min(defenderState.shield, damage);
      defenderState.shield -= absorbed;
      damage -= absorbed;
      if (absorbed > 0) {
        logs.add('   🔮 방어막이 $absorbed 피해 흡수! (남은 방어막: ${defenderState.shield})');
      }
    }

    // 쉴드 버프로 인한 추가 감소
    damage = (damage * defenderState.damageReduction).round();

    // 치명타 로그
    if (isCrit) {
      logs.add('   💥 크리티컬 히트!');
    }

    // 최종 피해 적용
    damage = math.max(1, damage);
    defenderState.hp = math.max(0, defenderState.hp - damage);
    logs.add('   ⚔️ ${attacker.name} → ${defender.name}: ${formatNumber(damage)} 피해');

    // 흡혈 처리
    if (lifestealPercent > 0 && damage > 0) {
      final stolen = (damage * lifestealPercent / 100.0).round();
      final actualHeal = math.min(stolen, attackerState.maxHp - attackerState.hp);
      if (actualHeal > 0) {
        attackerState.hp += actualHeal;
        logs.add('   🩸 흡혈! ${attacker.name} HP +$actualHeal');
      }
    }

    // 즉시 회복 처리
    if (healAmount > 0) {
      final actualHeal = math.min(healAmount, attackerState.maxHp - attackerState.hp);
      if (actualHeal > 0) {
        attackerState.hp += actualHeal;
        logs.add('   💖 회복! ${attacker.name} HP +$actualHeal');
      }
    }

    // 반격 처리
    if (defenderState.hp > 0) {
      final counterChance = guarded ? counterChanceGuarded : counterChanceNormal;
      if (rng.nextDouble() < counterChance) {
        final counterDmg = math.max(8, (defender.power * 0.08).round());
        attackerState.hp = math.max(0, attackerState.hp - counterDmg);
        logs.add('   ↩️ ${defender.name} 반격! ${attacker.name}에게 $counterDmg 피해');
      }
    }

    return defenderState.hp > 0;
  }

  /// 원소 상성 배율 계산 (새 배율)
  static double _calculateElementMultiplier(GameElement attacker, GameElement defender) {
    // 불 > 자연 > 물 > 불, 빛 <-> 암흑
    const strongAgainst = {
      GameElement.fire: GameElement.nature,
      GameElement.water: GameElement.fire,
      GameElement.nature: GameElement.water,
      GameElement.light: GameElement.dark,
      GameElement.dark: GameElement.light,
    };
    
    if (strongAgainst[attacker] == defender) {
      return elementAdvantage;
    }
    if (strongAgainst[defender] == attacker) {
      return elementDisadvantage;
    }
    return 1.0;
  }

  /// 스킬 선택 (쿨다운 고려)
  static SkillData? _selectSkill(
    List<SkillData> skills,
    Map<String, int> cooldowns,
    math.Random rng,
  ) {
    final candidates = skills.where((s) {
      final cd = cooldowns[s.name];
      return cd == null || cd <= 0;
    }).toList();

    for (final skill in candidates) {
      if (rng.nextInt(100) < skill.procRate) {
        return skill;
      }
    }
    return null;
  }

  /// 스킬 효과 적용
  static void _applySkillEffect({
    required SkillData skill,
    required BattleParticipant attacker,
    required _CombatantState attackerState,
    required BattleParticipant defender,
    required _CombatantState defenderState,
    required List<String> logs,
    required void Function(int) bonusFlatRef,
    required void Function(int) healRef,
    required void Function(bool) pierceRef,
    required void Function(int) lifestealRef,
    required void Function(double) dmgMultiplierRef,
  }) {
    switch (skill.effect) {
      case SkillEffect.damage:
        break;

      case SkillEffect.bleed:
        final dotDamage = math.max(8, skill.value);
        defenderState.dots.add(_TickEffect(
          name: '출혈',
          damageOrHeal: dotDamage,
          remainingTurns: 3,
        ));
        logs.add('   🩸 출혈 부여! ($dotDamage 피해 × 3턴)');
        break;

      case SkillEffect.pierce:
        pierceRef(true);
        break;

      case SkillEffect.lifesteal:
        lifestealRef(skill.value);
        break;

      case SkillEffect.stun:
        defenderState.debuffs['stun'] = _StatusEffect(
          name: '기절',
          value: 1,
          remainingTurns: 1,
        );
        logs.add('   😵 ${defender.name} 기절! (1턴 행동 불가)');
        break;

      case SkillEffect.regen:
        final hotAmount = math.max(12, skill.value);
        attackerState.hots.add(_TickEffect(
          name: '재생',
          damageOrHeal: hotAmount,
          remainingTurns: 3,
        ));
        logs.add('   💚 재생 버프! ($hotAmount 회복 × 3턴)');
        break;

      case SkillEffect.heal:
        healRef(skill.value);
        break;

      case SkillEffect.shield:
        attackerState.shield += skill.value;
        attackerState.buffs['shield'] = _StatusEffect(
          name: '방어막',
          value: skill.value,
          remainingTurns: 2,
        );
        logs.add('   🔮 방어막 +${skill.value}! (2턴 지속)');
        break;

      case SkillEffect.dodge:
        attackerState.buffs['dodge'] = _StatusEffect(
          name: '회피',
          value: 1,
          remainingTurns: 1,
        );
        logs.add('   💨 회피 태세! (1턴 지속)');
        break;

      case SkillEffect.critBoost:
        attackerState.buffs['critBoost'] = _StatusEffect(
          name: '집중',
          value: 15,
          remainingTurns: 2,
        );
        logs.add('   🎯 집중! 치명타 확률 +15% (2턴)');
        break;

      case SkillEffect.attackBoost:
        attackerState.buffs['attackBoost'] = _StatusEffect(
          name: '공격 강화',
          value: 25,
          remainingTurns: 2,
        );
        logs.add('   💪 공격 강화! 공격력 +25% (2턴)');
        break;

      case SkillEffect.weaken:
        defenderState.debuffs['weaken'] = _StatusEffect(
          name: '약화',
          value: 25,
          remainingTurns: 2,
        );
        logs.add('   📉 ${defender.name} 약화! 공격력 -25% (2턴)');
        break;

      case SkillEffect.slow:
        defenderState.debuffs['slow'] = _StatusEffect(
          name: '둔화',
          value: 12,
          remainingTurns: 2,
        );
        logs.add('   🐌 ${defender.name} 둔화! 적중률 -12% (2턴)');
        break;

      default:
        break;
    }
  }
}
