// 밸런스 시뮬레이션 테스트
// 실행: flutter test test/balance_simulation_test.dart

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sword_game/utils/battle_engine.dart';
import 'package:sword_game/enums/element.dart';
import 'package:sword_game/enums/sword_grade.dart';
import 'package:sword_game/enums/skill_type.dart';
import 'package:sword_game/enums/skill_effect.dart';
import 'package:sword_game/models/sword_data.dart';
import 'package:sword_game/data/swords.dart';

void main() {
  const int simCount = 10000; // 시뮬레이션 횟수

  // 등급별 대표 검 가져오기
  SwordData getSwordByGrade(SwordGrade grade) {
    return allSwords.firstWhere((s) => s.grade == grade);
  }

  // 시뮬레이션 실행
  double runSimulation({
    required SwordGrade grade1,
    required int level1,
    required SwordGrade grade2,
    required int level2,
    required GameElement elem1,
    required GameElement elem2,
    int count = simCount,
  }) {
    final sword1 = getSwordByGrade(grade1);
    final sword2 = getSwordByGrade(grade2);

    int wins = 0;
    final rng = Random(42); // 재현 가능한 시드

    for (int i = 0; i < count; i++) {
      final p1 = BattleParticipant(
        id: 'p1',
        name: '플레이어1',
        grade: grade1,
        swordLevel: level1,
        baseAtk: sword1.baseAtk,
        element: elem1,
        primarySkillType: sword1.primarySkillType,
        skills: sword1.skills,
        swordName: sword1.name,
      );

      final p2 = BattleParticipant(
        id: 'p2',
        name: '플레이어2',
        grade: grade2,
        swordLevel: level2,
        baseAtk: sword2.baseAtk,
        element: elem2,
        primarySkillType: sword2.primarySkillType,
        skills: sword2.skills,
        swordName: sword2.name,
      );

      final result = BattleEngine.simulate(
        me: p1,
        opponent: p2,
        rng: Random(rng.nextInt(1000000)),
      );

      if (result.iWin) wins++;
    }

    return (wins / count) * 100;
  }

  group('밸런스 시뮬레이션 테스트', () {
    test('전체 매치업 시뮬레이션', () {
      print('\n');
      print('=' * 70);
      print('  밸런스 시뮬레이션 결과 (${simCount}회 반복)');
      print('=' * 70);

      // 매치업 정의: (등급1, 레벨1, 등급2, 레벨2, 목표최소, 목표최대)
      final matchups = [
        (SwordGrade.normal, 10, SwordGrade.rare, 15, 10.0, 15.0),
        (SwordGrade.normal, 10, SwordGrade.unique, 15, 3.0, 7.0),
        (SwordGrade.normal, 10, SwordGrade.legend, 15, 0.0, 3.0),
        (SwordGrade.normal, 10, SwordGrade.rare, 10, 20.0, 30.0),
        (SwordGrade.normal, 15, SwordGrade.rare, 16, 20.0, 30.0),
        (SwordGrade.rare, 15, SwordGrade.unique, 15, 20.0, 30.0),
        (SwordGrade.unique, 20, SwordGrade.legend, 20, 20.0, 30.0),
        (SwordGrade.normal, 20, SwordGrade.legend, 20, 0.0, 5.0),
        (SwordGrade.rare, 10, SwordGrade.unique, 10, 15.0, 25.0),
      ];

      print('\n【 속성 동일 조건 】');
      print('-' * 70);

      int passCount = 0;
      for (final m in matchups) {
        final winRate = runSimulation(
          grade1: m.$1,
          level1: m.$2,
          grade2: m.$3,
          level2: m.$4,
          elem1: GameElement.fire,
          elem2: GameElement.fire,
        );

        final inRange = winRate >= m.$5 && winRate <= m.$6;
        final status = inRange ? '✓' : '✗';
        if (inRange) passCount++;

        final matchName = '${m.$1.displayName}+${m.$2} vs ${m.$3.displayName}+${m.$4}';
        print('  $matchName'.padRight(35) +
              '${winRate.toStringAsFixed(1)}%'.padLeft(8) +
              '  목표: ${m.$5.toInt()}~${m.$6.toInt()}%'.padRight(15) +
              '  $status');
      }

      print('-' * 70);
      print('  결과: $passCount/${matchups.length} 통과\n');

      // 속성 상성 테스트
      print('【 속성 상성 테스트 (유리 vs 불리) 】');
      print('-' * 70);

      // 동일 등급/레벨에서 속성 상성 효과 측정
      final elemTestCases = [
        (SwordGrade.normal, 10, SwordGrade.normal, 10),
        (SwordGrade.rare, 15, SwordGrade.rare, 15),
        (SwordGrade.unique, 15, SwordGrade.unique, 15),
        (SwordGrade.legend, 20, SwordGrade.legend, 20),
      ];

      for (final t in elemTestCases) {
        // 동일 속성
        final neutral = runSimulation(
          grade1: t.$1,
          level1: t.$2,
          grade2: t.$3,
          level2: t.$4,
          elem1: GameElement.fire,
          elem2: GameElement.fire,
        );

        // 유리 속성 (불 vs 자연)
        final advantage = runSimulation(
          grade1: t.$1,
          level1: t.$2,
          grade2: t.$3,
          level2: t.$4,
          elem1: GameElement.fire,
          elem2: GameElement.nature,
        );

        final diff = advantage - neutral;
        final inRange = diff >= 5.0 && diff <= 10.0;
        final status = inRange ? '✓' : (diff > 0 ? '△' : '✗');

        final matchName = '${t.$1.displayName}+${t.$2} vs ${t.$3.displayName}+${t.$4}';
        print('  $matchName'.padRight(30) +
              '동일: ${neutral.toStringAsFixed(1)}%'.padLeft(12) +
              '  유리: ${advantage.toStringAsFixed(1)}%'.padLeft(14) +
              '  차이: +${diff.toStringAsFixed(1)}%'.padLeft(12) +
              '  $status');
      }

      print('-' * 70);
      print('  목표: 속성 유리 시 +5~10% 승률 증가\n');
      print('=' * 70);
    });
  });
}
