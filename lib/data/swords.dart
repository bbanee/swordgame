import 'dart:math';
import '../models/sword_data.dart';
import '../enums/sword_grade.dart';
import '../enums/element.dart';
import '../enums/skill_type.dart';
import '../enums/skill_effect.dart';

// 전체 검 200개 데이터
final List<SwordData> allSwords = _generateAllSwords();

// =====================================================
// 🎰 일반 뽑기 확률 (합계 100%)
// =====================================================
const Map<SwordGrade, double> gachaProbability = {
  SwordGrade.normal: 63.6357,
  SwordGrade.rare: 35.3532,
  SwordGrade.unique: 1.0,
  SwordGrade.legend: 0.01,
  SwordGrade.hidden: 0.001,
  SwordGrade.immortal: 0.0001,
};

// =====================================================
// 💎 고급 뽑기 확률 (합계 100%) - 노말 제외!
// =====================================================
const Map<SwordGrade, double> premiumGachaProbability = {
  SwordGrade.rare: 74.889,     // 나머지 확률
  SwordGrade.unique: 25.0,     // 25%
  SwordGrade.legend: 0.1,      // 0.1%
  SwordGrade.hidden: 0.01,     // 0.01%
  SwordGrade.immortal: 0.001,  // 0.001%
};

// 고급 뽑기 비용 (다이아몬드)
const int premiumGachaCostSingle = 5;   // 1회: 5다이아
const int premiumGachaCost5x = 20;      // 5회: 20다이아 (1회당 4다이아)
const int premiumGachaCost10x = 35;     // 10회: 35다이아 (1회당 3.5다이아) + 유니크 이상 1개 확정!

// 합성 천장: 노말 10회 → 레어, 레어 50회 → 유니크, 유니크 100회 → 전설
const List<(SwordGrade, SwordGrade, double, int?)> synthesisTable = [
  (SwordGrade.normal, SwordGrade.rare, 30.0, 10),     // ✅ 노말 10회 합성 → 레어 확정
  (SwordGrade.rare, SwordGrade.unique, 5.0, 50),      // 레어 50회 합성 → 유니크 확정
  (SwordGrade.unique, SwordGrade.legend, 0.5, 100),   // 유니크 100회 합성 → 전설 확정
];

// 강화 테이블 (v13 - 파괴율 조정)
// +0→+10: 파괴 없음, 성공률 92%→65%
// +11→+14: 파괴 시작, 성공률 62%→53%, 파괴 2%→8%
// +15→+20: 파괴율 30% 고정, 성공률 50%→35%
// +21→+25: 파괴율 35% 고정, 성공률 18%→8%
// +26→+30: 파괴율 40% 고정, 성공률 6%→1%
List<(int, int, int, int)> get enhanceTable => List.generate(30, (i) {
  final level = i + 1;
  int cost, successRate, destroyRate;

  // 후반 구간 비용 테이블 (+21~+30)
  const lateCosts = [55000, 70000, 90000, 120000, 160000, 210000, 270000, 400000, 600000, 1000000];
  // 후반 구간 성공률 (+21~+30) - 극악 난이도
  const lateSuccess = [18, 15, 12, 10, 8, 6, 5, 4, 2, 1];
  // 후반 구간 파괴율 (+21~+25: 35%, +26~+30: 40%)
  const lateDestroy = [35, 35, 35, 35, 35, 40, 40, 40, 40, 40];

  if (level <= 10) {
    // 초반 구간: 파괴 없음, 성공률 92% → 65%
    cost = level * 500;  // +1: 500G ~ +10: 5,000G
    successRate = 95 - level * 3;  // +1: 92%, +10: 65%
    destroyRate = 0;
  } else if (level <= 14) {
    // 중반 초기: 파괴 시작, 성공률 62% → 53%
    cost = 5000 + (level - 10) * 3000;  // +11: 8,000G ~ +14: 17,000G
    successRate = 62 - (level - 11) * 3;  // +11: 62%, +14: 53%
    destroyRate = 2 + (level - 11) * 2;   // +11: 2%, +14: 8%
  } else if (level <= 20) {
    // 중반 후기: 파괴율 30% 고정
    cost = 5000 + (level - 10) * 3000;  // +15: 20,000G ~ +20: 35,000G
    successRate = 30 - (level - 15) * 2;  // +15: 30%, +20: 20%
    destroyRate = 30;  // 30% 고정
  } else {
    // 후반 구간: 성공률 극악
    cost = lateCosts[level - 21];
    successRate = lateSuccess[level - 21];
    destroyRate = lateDestroy[level - 21];
  }

  return (level, cost, successRate, destroyRate);
});

// =====================================================
// 등급별 스킬 밸런스 상수 (v13 - 검 강화하기 밸런스)
// 목표: 등급 간 명확한 격차, 하위 등급도 희망 있음
// =====================================================
class _SkillBalance {
  // ✅ v13: 기본 공격력 (등급 간 명확한 격차)
  static const Map<SwordGrade, int> baseAtk = {
    SwordGrade.normal: 78,      // v12: 84 → 78
    SwordGrade.rare: 96,        // v12: 97 → 96 (+18, 23%)
    SwordGrade.unique: 118,     // v12: 101 → 118 (+22, 23%)
    SwordGrade.legend: 148,     // v12: 148 → 148 (유지, +30, 25%)
    SwordGrade.hidden: 188,     // v12: 185 → 188 (+40, 27%)
    SwordGrade.immortal: 238,   // v12: 225 → 238 (+50, 27%)
  };

  // ✅ v13: 등급별 레벨 보너스 (battle_engine.dart와 동일)
  static const Map<SwordGrade, int> levelBonus = {
    SwordGrade.normal: 6,       // v12: 8 → 6
    SwordGrade.rare: 7,         // v12: 9 → 7
    SwordGrade.unique: 8,       // v12: 10 → 8
    SwordGrade.legend: 10,      // v12: 11 → 10
    SwordGrade.hidden: 13,      // v12: 12 → 13
    SwordGrade.immortal: 17,    // v12: 14 → 17
  };

  // ✅ v13: 스킬 발동률 (등급별 차등화)
  static const Map<SwordGrade, int> baseProcRate = {
    SwordGrade.normal: 30,      // v12: 35 → 30
    SwordGrade.rare: 34,        // v12: 38 → 34
    SwordGrade.unique: 38,      // v12: 38 → 38 (유지)
    SwordGrade.legend: 43,      // v12: 42 → 43
    SwordGrade.hidden: 48,      // v12: 46 → 48
    SwordGrade.immortal: 54,    // v12: 51 → 54
  };

  // ✅ v13: 스킬 배율 (등급별 격차 확대)
  static const Map<SwordGrade, double> baseMultiplier = {
    SwordGrade.normal: 1.25,    // v12: 1.32 → 1.25
    SwordGrade.rare: 1.32,      // v12: 1.36 → 1.32
    SwordGrade.unique: 1.40,    // v12: 1.36 → 1.40
    SwordGrade.legend: 1.50,    // v12: 1.44 → 1.50
    SwordGrade.hidden: 1.60,    // v12: 1.52 → 1.60
    SwordGrade.immortal: 1.72,  // v12: 1.62 → 1.72
  };

  // ✅ v13: 스킬 효과 수치
  static const Map<SwordGrade, int> effectValue = {
    SwordGrade.normal: 10,      // v12: 12 → 10
    SwordGrade.rare: 14,        // v12: 15 → 14
    SwordGrade.unique: 18,      // v12: 18 → 18 (유지)
    SwordGrade.legend: 23,      // v12: 22 → 23
    SwordGrade.hidden: 28,      // v12: 26 → 28
    SwordGrade.immortal: 34,    // v12: 31 → 34
  };

  // ✅ v13: 회피 보너스 (등급별)
  static const Map<SwordGrade, double> dodgeBonus = {
    SwordGrade.normal: 0.01,    // +1%
    SwordGrade.rare: 0.015,     // +1.5%
    SwordGrade.unique: 0.02,    // +2%
    SwordGrade.legend: 0.025,   // +2.5%
    SwordGrade.hidden: 0.03,    // +3%
    SwordGrade.immortal: 0.035, // +3.5%
  };

  // ✅ v13: 기절 스킬 발동률 (전설부터)
  static const Map<SwordGrade, int> stunProcRate = {
    SwordGrade.legend: 7,       // v12: 8 → 7
    SwordGrade.hidden: 10,      // v12: 12 → 10
    SwordGrade.immortal: 14,    // v12: 16 → 14
  };

  // ✅ v13: 기절 스킬 쿨다운 (유지)
  static const Map<SwordGrade, int> stunCooldown = {
    SwordGrade.legend: 5,
    SwordGrade.hidden: 4,
    SwordGrade.immortal: 4,
  };
}

// =====================================================
// 검 200개 생성 함수
// =====================================================
List<SwordData> _generateAllSwords() {
  final List<SwordData> swords = [];
  final random = Random(42);
  
  // ===== 일반 90개 (스킬 1개) =====
  final normalNames = [
    '낡은 검', '철검', '청동검', '강철검', '연습용 검', '나무검', '돌검', '구리검',
    '주석검', '녹슨 검', '훈련검', '초보자의 검', '병사의 검', '수련검', '단검',
    '장검', '활검', '곡검', '직검', '양날검', '외날검', '무딘 검', '날카로운 검',
    '가벼운 검', '무거운 검', '균형잡힌 검', '견습생의 검', '모험가의 검', '탐험가의 검',
    '사냥꾼의 검', '전사의 검', '기사의 검', '용병의 검', '경비병의 검', '순찰자의 검',
    '수호자의 검', '파수꾼의 검', '척후병의 검', '정찰병의 검', '궁병의 검', '창병의 검',
    '방패병의 검', '보병의 검', '기병의 검', '해병의 검', '산악병의 검', '숲의 검',
    '평원의 검', '사막의 검', '설원의 검', '화산의 검', '늪지의 검', '동굴의 검',
    '폐허의 검', '고성의 검', '마을의 검', '도시의 검', '왕국의 검', '제국의 검',
    '동방의 검', '서방의 검', '남방의 검', '북방의 검', '중앙의 검', '변방의 검',
    '대륙의 검', '섬의 검', '해안의 검', '산맥의 검', '강변의 검', '호수의 검',
    '새벽의 검', '황혼의 검', '정오의 검', '자정의 검', '봄의 검', '여름의 검',
    '가을의 검', '겨울의 검', '비의 검', '눈의 검', '바람의 검', '안개의 검',
    '번개의 검', '천둥의 검', '서리의 검', '이슬의 검', '달빛의 검', '별빛의 검',
    '햇빛의 검',
  ];
  
  final normalSkillNames = ['베기', '찌르기', '휘두르기', '내려치기', '올려베기'];
  final normalSkillTypes = [SkillType.slash, SkillType.pierce, SkillType.slash, SkillType.blast, SkillType.slash];
  
  for (int i = 0; i < normalNames.length; i++) {
    final elem = GameElement.values[i % 5];
    final skillIdx = i % normalSkillNames.length;
    final procRate = _SkillBalance.baseProcRate[SwordGrade.normal]! + random.nextInt(5);
    final effectVal = _SkillBalance.effectValue[SwordGrade.normal]!;
    final baseAtk = _SkillBalance.baseAtk[SwordGrade.normal]! + random.nextInt(10) - 5;  // ✅ v3: 80~90
    
    swords.add(SwordData(
      id: 'normal_$i',
      name: normalNames[i],
      grade: SwordGrade.normal,
      element: elem,
      baseAtk: baseAtk,
      skills: [
        // ✅ v3: 메인 스킬
        SkillData(
          name: normalSkillNames[skillIdx],
          multiplier: _SkillBalance.baseMultiplier[SwordGrade.normal]! + random.nextDouble() * 0.1,
          procRate: procRate,
          type: normalSkillTypes[skillIdx],
          effect: SkillEffect.damage,
          cooldownTurns: 1,
          element: elem,
        ),
        // ✅ v10: 서브 스킬 (출혈) 추가
        SkillData(
          name: '찌르기',
          multiplier: _SkillBalance.baseMultiplier[SwordGrade.normal]! * 0.9,
          procRate: procRate - 5,
          type: SkillType.pierce,
          effect: SkillEffect.bleed,
          value: effectVal,
          cooldownTurns: 2,
          element: elem,
        ),
      ],
    ));
  }
  
  // ===== 레어 50개 (스킬 2개) =====
  final rareNames = [
    '미스릴 검', '오리할콘 검', '아다만트 검', '마법검', '정령검', '축복받은 검',
    '저주받은 검', '불꽃검', '얼음검', '번개검', '독검', '치유검', '흡혈검',
    '파괴검', '수호검', '심판검', '복수검', '구원검', '정의검', '자비검',
    '용기의 검', '지혜의 검', '힘의 검', '속도의 검', '인내의 검', '행운의 검',
    '기적의 검', '운명의 검', '예언의 검', '환상의 검', '몽환의 검', '각성의 검',
    '초월의 검', '진화의 검', '변이의 검', '융합의 검', '분열의 검', '증폭의 검',
    '흡수의 검', '반사의 검', '관통의 검', '폭발의 검', '연쇄의 검', '확산의 검',
    '집중의 검', '분산의 검', '회전의 검', '직선의 검', '곡선의 검', '나선의 검',
  ];
  
  // ✅ v3: 레어 스킬 조합 (메인 + 서브)
  final rareSkillConfigs = [
    [('강타', SkillType.slash, SkillEffect.damage), ('연속 베기', SkillType.slash, SkillEffect.bleed)],
    [('관통 찌르기', SkillType.pierce, SkillEffect.pierce), ('급소 공격', SkillType.pierce, SkillEffect.critBoost)],
    [('화염 베기', SkillType.blast, SkillEffect.bleed), ('폭발 일격', SkillType.blast, SkillEffect.damage)],
    [('흡혈 일격', SkillType.drain, SkillEffect.lifesteal), ('생명 흡수', SkillType.drain, SkillEffect.heal)],
    [('수호의 일격', SkillType.guard, SkillEffect.damage), ('방어 태세', SkillType.guard, SkillEffect.shield)],
  ];
  
  for (int i = 0; i < rareNames.length; i++) {
    final elem = GameElement.values[i % 5];
    final skillSet = rareSkillConfigs[i % rareSkillConfigs.length];
    final baseProcRate = _SkillBalance.baseProcRate[SwordGrade.rare]!;
    final baseMulti = _SkillBalance.baseMultiplier[SwordGrade.rare]!;
    final effectVal = _SkillBalance.effectValue[SwordGrade.rare]!;
    final baseAtk = _SkillBalance.baseAtk[SwordGrade.rare]! + random.nextInt(10) - 5;  // ✅ v3: 92~102
    
    swords.add(SwordData(
      id: 'rare_$i',
      name: rareNames[i],
      grade: SwordGrade.rare,
      element: elem,
      baseAtk: baseAtk,
      skills: [
        // ✅ v3: 메인 스킬
        SkillData(
          name: skillSet[0].$1,
          multiplier: baseMulti + random.nextDouble() * 0.08,
          procRate: baseProcRate + random.nextInt(5),
          type: skillSet[0].$2,
          effect: skillSet[0].$3,
          value: skillSet[0].$3 != SkillEffect.damage ? effectVal : 0,
          cooldownTurns: 2,
          element: elem,
        ),
        // ✅ v3: 서브 스킬 (추가)
        SkillData(
          name: skillSet[1].$1,
          multiplier: baseMulti * 0.95 + random.nextDouble() * 0.05,
          procRate: baseProcRate - 3 + random.nextInt(4),
          type: skillSet[1].$2,
          effect: skillSet[1].$3,
          value: skillSet[1].$3 != SkillEffect.damage ? (effectVal * 0.85).round() : 0,
          cooldownTurns: 2,
          element: elem,
        ),
      ],
    ));
  }
  
  // ===== 유니크 25개 (스킬 2개) =====
  final uniqueNames = [
    '용의 검', '불사조의 검', '유니콘의 검', '그리폰의 검', '키메라의 검',
    '히드라의 검', '세르베로스의 검', '페가수스의 검', '미노타우로스의 검', '메두사의 검',
    '타이탄의 검', '올림푸스의 검', '발할라의 검', '아스가르드의 검', '니플헤임의 검',
    '무스펠헤임의 검', '미드가르드의 검', '요툰헤임의 검', '알프헤임의 검', '스바르탈프헤임의 검',
    '헬헤임의 검', '천상의 검', '지옥의 검', '연옥의 검', '심연의 검',
  ];
  
  // 유니크 스킬 조합 (메인 + 서브)
  final uniqueSkillSets = [
    [('용의 일격', SkillType.blast, SkillEffect.damage), ('불의 숨결', SkillType.blast, SkillEffect.bleed)],
    [('불사의 베기', SkillType.slash, SkillEffect.lifesteal), ('재생의 불꽃', SkillType.guard, SkillEffect.damage)],
    [('신성한 돌진', SkillType.pierce, SkillEffect.pierce), ('정화의 빛', SkillType.guard, SkillEffect.damage)],
    [('맹수의 발톱', SkillType.slash, SkillEffect.bleed), ('사나운 포효', SkillType.blast, SkillEffect.stun)],
    [('혼돈의 일격', SkillType.blast, SkillEffect.damage), ('변이의 독', SkillType.drain, SkillEffect.bleed)],
  ];
  
  for (int i = 0; i < uniqueNames.length; i++) {
    final elem = GameElement.values[i % 5];
    final skillSet = uniqueSkillSets[i % uniqueSkillSets.length];
    final baseProcRate = _SkillBalance.baseProcRate[SwordGrade.unique]!;
    final baseMulti = _SkillBalance.baseMultiplier[SwordGrade.unique]!;
    final effectVal = _SkillBalance.effectValue[SwordGrade.unique]!;
    final baseAtk = _SkillBalance.baseAtk[SwordGrade.unique]! + random.nextInt(10) - 5;  // ✅ v3: 105~115
    
    swords.add(SwordData(
      id: 'unique_$i',
      name: uniqueNames[i],
      grade: SwordGrade.unique,
      element: elem,
      baseAtk: baseAtk,
      skills: [
        // 메인 스킬 (더 강함)
        SkillData(
          name: skillSet[0].$1,
          multiplier: baseMulti + 0.08 + random.nextDouble() * 0.08,
          procRate: baseProcRate + random.nextInt(5),
          type: skillSet[0].$2,
          effect: skillSet[0].$3,
          value: skillSet[0].$3 != SkillEffect.damage ? effectVal : 0,
          cooldownTurns: 2,
          element: elem,
        ),
        // 서브 스킬
        SkillData(
          name: skillSet[1].$1,
          multiplier: baseMulti + random.nextDouble() * 0.08,
          procRate: baseProcRate - 3 + random.nextInt(5),
          type: skillSet[1].$2,
          effect: skillSet[1].$3,
          value: skillSet[1].$3 != SkillEffect.damage ? (effectVal * 0.8).round() : 0,
          cooldownTurns: 2,
          element: elem,
        ),
      ],
    ));
  }
  
  // ===== 전설 20개 (스킬 3개) =====
  final legendNames = [
    '엑스칼리버', '듀란달', '그람', '발뭉', '커틀라스',
    '무라마사', '마사무네', '쿠사나기', '아메노무라쿠모', '토츠카',
    '천총운검', '용천검', '간장막야', '태아', '의천검',
    '칠성검', '삼척검', '비수', '청홍검', '사인검',
  ];
  
  final legendSkillSets = [
    [('왕의 일격', SkillType.slash, SkillEffect.damage), ('성스러운 빛', SkillType.guard, SkillEffect.lifesteal), ('천벌', SkillType.blast, SkillEffect.stun)],
    [('영웅의 베기', SkillType.slash, SkillEffect.pierce), ('불굴의 의지', SkillType.guard, SkillEffect.damage), ('최후의 일격', SkillType.blast, SkillEffect.bleed)],
    [('마검 각성', SkillType.drain, SkillEffect.lifesteal), ('저주의 파동', SkillType.blast, SkillEffect.bleed), ('암흑 관통', SkillType.pierce, SkillEffect.pierce)],
    [('용의 분노', SkillType.blast, SkillEffect.damage), ('비늘 방패', SkillType.guard, SkillEffect.damage), ('화염 폭풍', SkillType.blast, SkillEffect.bleed)],
    [('천지개벽', SkillType.slash, SkillEffect.damage), ('만물귀일', SkillType.drain, SkillEffect.lifesteal), ('음양조화', SkillType.guard, SkillEffect.stun)],
  ];
  
  for (int i = 0; i < legendNames.length; i++) {
    final elem = GameElement.values[i % 5];
    final skillSet = legendSkillSets[i % legendSkillSets.length];
    final baseProcRate = _SkillBalance.baseProcRate[SwordGrade.legend]!;
    final baseMulti = _SkillBalance.baseMultiplier[SwordGrade.legend]!;
    final effectVal = _SkillBalance.effectValue[SwordGrade.legend]!;
    // ✅ v3: 기절 스킬 발동률/쿨다운
    final stunProcRate = _SkillBalance.stunProcRate[SwordGrade.legend]!;
    final stunCooldown = _SkillBalance.stunCooldown[SwordGrade.legend]!;
    final baseAtk = _SkillBalance.baseAtk[SwordGrade.legend]! + random.nextInt(10) - 5;  // ✅ v3: 120~130
    
    swords.add(SwordData(
      id: 'legend_$i',
      name: legendNames[i],
      grade: SwordGrade.legend,
      element: elem,
      baseAtk: baseAtk,
      skills: [
        // 메인 스킬 (가장 강함)
        SkillData(
          name: skillSet[0].$1,
          multiplier: baseMulti + 0.12 + random.nextDouble() * 0.08,
          procRate: baseProcRate + 2 + random.nextInt(5),
          type: skillSet[0].$2,
          effect: skillSet[0].$3,
          value: skillSet[0].$3 != SkillEffect.damage ? effectVal : 0,
          cooldownTurns: 2,
          element: elem,
        ),
        // 서브 스킬 1
        SkillData(
          name: skillSet[1].$1,
          multiplier: baseMulti + 0.05 + random.nextDouble() * 0.08,
          procRate: baseProcRate + random.nextInt(5),
          type: skillSet[1].$2,
          effect: skillSet[1].$3,
          value: skillSet[1].$3 != SkillEffect.damage ? (effectVal * 0.8).round() : 0,
          cooldownTurns: 2,
          element: elem,
        ),
        // 서브 스킬 2 (✅ v3: 기절이면 너프된 발동률/쿨다운 적용)
        SkillData(
          name: skillSet[2].$1,
          multiplier: baseMulti + random.nextDouble() * 0.08,
          procRate: skillSet[2].$3 == SkillEffect.stun 
              ? stunProcRate + random.nextInt(3)  // ✅ v3: 기절 14%
              : baseProcRate - 2 + random.nextInt(5),
          type: skillSet[2].$2,
          effect: skillSet[2].$3,
          value: skillSet[2].$3 != SkillEffect.damage ? (effectVal * 0.7).round() : 0,
          cooldownTurns: skillSet[2].$3 == SkillEffect.stun 
              ? stunCooldown  // ✅ v3: 기절 5턴
              : 3,
          element: elem,
        ),
      ],
    ));
  }
  
  // ===== 히든 10개 (스킬 3개) =====
  final hiddenNames = [
    '세계수의 검', '차원의 검', '시간의 검', '공간의 검', '인과의 검',
    '운명의 톱니', '존재의 검', '허무의 검', '혼돈의 검', '질서의 검',
  ];
  
  final hiddenSkillSets = [
    [('세계수의 가호', SkillType.guard, SkillEffect.lifesteal), ('생명의 축복', SkillType.drain, SkillEffect.lifesteal), ('자연의 분노', SkillType.blast, SkillEffect.bleed)],
    [('차원 절단', SkillType.pierce, SkillEffect.pierce), ('공간 왜곡', SkillType.blast, SkillEffect.stun), ('차원 흡수', SkillType.drain, SkillEffect.lifesteal)],
    [('시간 정지', SkillType.guard, SkillEffect.stun), ('시간 역행', SkillType.drain, SkillEffect.lifesteal), ('시간 가속', SkillType.slash, SkillEffect.damage)],
    [('공간 압축', SkillType.blast, SkillEffect.damage), ('텔레포트 슬래시', SkillType.slash, SkillEffect.pierce), ('차원 감옥', SkillType.guard, SkillEffect.stun)],
    [('인과율 조작', SkillType.drain, SkillEffect.pierce), ('운명 변경', SkillType.guard, SkillEffect.lifesteal), ('필연의 일격', SkillType.slash, SkillEffect.damage)],
  ];
  
  for (int i = 0; i < hiddenNames.length; i++) {
    final elem = GameElement.values[i % 5];
    final skillSet = hiddenSkillSets[i % hiddenSkillSets.length];
    final baseProcRate = _SkillBalance.baseProcRate[SwordGrade.hidden]!;
    final baseMulti = _SkillBalance.baseMultiplier[SwordGrade.hidden]!;
    final effectVal = _SkillBalance.effectValue[SwordGrade.hidden]!;
    // ✅ v3: 기절 스킬 발동률/쿨다운
    final stunProcRate = _SkillBalance.stunProcRate[SwordGrade.hidden]!;
    final stunCooldown = _SkillBalance.stunCooldown[SwordGrade.hidden]!;
    final baseAtk = _SkillBalance.baseAtk[SwordGrade.hidden]! + random.nextInt(10) - 5;  // ✅ v3: 137~147
    
    swords.add(SwordData(
      id: 'hidden_$i',
      name: hiddenNames[i],
      grade: SwordGrade.hidden,
      element: elem,
      baseAtk: baseAtk,
      skills: [
        // 메인 스킬 (✅ v3: 기절이면 너프된 발동률/쿨다운 적용)
        SkillData(
          name: skillSet[0].$1,
          multiplier: baseMulti + 0.12 + random.nextDouble() * 0.08,
          procRate: skillSet[0].$3 == SkillEffect.stun 
              ? stunProcRate + random.nextInt(3)
              : baseProcRate + 2 + random.nextInt(5),
          type: skillSet[0].$2,
          effect: skillSet[0].$3,
          value: skillSet[0].$3 != SkillEffect.damage ? effectVal : 0,
          cooldownTurns: skillSet[0].$3 == SkillEffect.stun ? stunCooldown : 2,
          element: elem,
        ),
        // 서브 스킬 1 (✅ v3: 기절이면 너프된 발동률/쿨다운 적용)
        SkillData(
          name: skillSet[1].$1,
          multiplier: baseMulti + 0.06 + random.nextDouble() * 0.08,
          procRate: skillSet[1].$3 == SkillEffect.stun 
              ? stunProcRate + random.nextInt(3)
              : baseProcRate + random.nextInt(5),
          type: skillSet[1].$2,
          effect: skillSet[1].$3,
          value: skillSet[1].$3 != SkillEffect.damage ? (effectVal * 0.85).round() : 0,
          cooldownTurns: skillSet[1].$3 == SkillEffect.stun ? stunCooldown : 2,
          element: elem,
        ),
        // 서브 스킬 2 (✅ v3: 기절이면 너프된 발동률/쿨다운 적용)
        SkillData(
          name: skillSet[2].$1,
          multiplier: baseMulti + random.nextDouble() * 0.08,
          procRate: skillSet[2].$3 == SkillEffect.stun 
              ? stunProcRate + random.nextInt(3)
              : baseProcRate - 2 + random.nextInt(5),
          type: skillSet[2].$2,
          effect: skillSet[2].$3,
          value: skillSet[2].$3 != SkillEffect.damage ? (effectVal * 0.75).round() : 0,
          cooldownTurns: skillSet[2].$3 == SkillEffect.stun ? stunCooldown : 3,
          element: elem,
        ),
      ],
    ));
  }
  
  // ===== 불멸 5개 (스킬 3개) - 최강 =====
  final immortalNames = [
    '태초의 검 - 창세',
    '종말의 검 - 멸세',
    '영원의 검 - 무한',
    '절대의 검 - 초월',
    '유일의 검 - 근원',
  ];
  
  final immortalSkillSets = [
    [('창세의 빛', SkillType.blast, SkillEffect.damage), ('만물 창조', SkillType.guard, SkillEffect.lifesteal), ('태초의 불꽃', SkillType.blast, SkillEffect.bleed)],
    [('멸세의 일격', SkillType.slash, SkillEffect.pierce), ('종말의 파동', SkillType.blast, SkillEffect.stun), ('소멸의 어둠', SkillType.drain, SkillEffect.lifesteal)],
    [('무한의 베기', SkillType.slash, SkillEffect.damage), ('영원의 순환', SkillType.drain, SkillEffect.lifesteal), ('불멸의 의지', SkillType.guard, SkillEffect.damage)],
    [('초월의 경지', SkillType.pierce, SkillEffect.pierce), ('차원 붕괴', SkillType.blast, SkillEffect.bleed), ('절대 방어', SkillType.guard, SkillEffect.lifesteal)],
    [('근원의 힘', SkillType.blast, SkillEffect.damage), ('원초의 베기', SkillType.slash, SkillEffect.pierce), ('시작과 끝', SkillType.drain, SkillEffect.stun)],
  ];
  
  for (int i = 0; i < immortalNames.length; i++) {
    final elem = GameElement.values[i];
    final skillSet = immortalSkillSets[i];
    final baseProcRate = _SkillBalance.baseProcRate[SwordGrade.immortal]!;
    final baseMulti = _SkillBalance.baseMultiplier[SwordGrade.immortal]!;
    final effectVal = _SkillBalance.effectValue[SwordGrade.immortal]!;
    // ✅ v3: 기절 스킬 발동률/쿨다운
    final stunProcRate = _SkillBalance.stunProcRate[SwordGrade.immortal]!;
    final stunCooldown = _SkillBalance.stunCooldown[SwordGrade.immortal]!;
    final baseAtk = _SkillBalance.baseAtk[SwordGrade.immortal]! + random.nextInt(10) - 5;  // ✅ v3: 157~167
    
    swords.add(SwordData(
      id: 'immortal_$i',
      name: immortalNames[i],
      grade: SwordGrade.immortal,
      element: elem,
      baseAtk: baseAtk,
      skills: [
        // 메인 스킬 (최강) - ✅ v3: 기절이면 너프
        SkillData(
          name: skillSet[0].$1,
          multiplier: baseMulti + 0.15 + random.nextDouble() * 0.08,
          procRate: skillSet[0].$3 == SkillEffect.stun 
              ? stunProcRate + random.nextInt(3)
              : baseProcRate + 3 + random.nextInt(5),
          type: skillSet[0].$2,
          effect: skillSet[0].$3,
          value: skillSet[0].$3 != SkillEffect.damage ? effectVal : 0,
          cooldownTurns: skillSet[0].$3 == SkillEffect.stun ? stunCooldown : 2,
          element: elem,
        ),
        // 서브 스킬 1 - ✅ v3: 기절이면 너프
        SkillData(
          name: skillSet[1].$1,
          multiplier: baseMulti + 0.08 + random.nextDouble() * 0.08,
          procRate: skillSet[1].$3 == SkillEffect.stun 
              ? stunProcRate + random.nextInt(3)
              : baseProcRate + random.nextInt(5),
          type: skillSet[1].$2,
          effect: skillSet[1].$3,
          value: skillSet[1].$3 != SkillEffect.damage ? (effectVal * 0.9).round() : 0,
          cooldownTurns: skillSet[1].$3 == SkillEffect.stun ? stunCooldown : 2,
          element: elem,
        ),
        // 서브 스킬 2 - ✅ v3: 기절이면 너프
        SkillData(
          name: skillSet[2].$1,
          multiplier: baseMulti + 0.03 + random.nextDouble() * 0.08,
          procRate: skillSet[2].$3 == SkillEffect.stun 
              ? stunProcRate + random.nextInt(3)
              : baseProcRate - 2 + random.nextInt(5),
          type: skillSet[2].$2,
          effect: skillSet[2].$3,
          value: skillSet[2].$3 != SkillEffect.damage ? (effectVal * 0.8).round() : 0,
          cooldownTurns: skillSet[2].$3 == SkillEffect.stun ? stunCooldown : 3,
          element: elem,
        ),
      ],
    ));
  }
  
  return swords;
}

// 등급별 검 가져오기
List<SwordData> getSwordsByGrade(SwordGrade grade) {
  return allSwords.where((s) => s.grade == grade).toList();
}
