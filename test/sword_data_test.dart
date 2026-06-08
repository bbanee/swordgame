import 'package:flutter_test/flutter_test.dart';
import 'package:sword_game/data/swords.dart';
import 'package:sword_game/enums/sword_grade.dart';

void main() {
  test('active sword list contains 100 swords by grade', () {
    expect(allSwords.length, activeSwordTotalCount);
    expect(getSwordsByGrade(SwordGrade.normal).length, 37);
    expect(getSwordsByGrade(SwordGrade.rare).length, 20);
    expect(getSwordsByGrade(SwordGrade.unique).length, 10);
    expect(getSwordsByGrade(SwordGrade.legend).length, 18);
    expect(getSwordsByGrade(SwordGrade.hidden).length, 10);
    expect(getSwordsByGrade(SwordGrade.immortal).length, 5);
  });

  test('legacy sword ids resolve to active replacements', () {
    expect(resolveSwordDataId('normal_37'), 'normal_0');
    expect(resolveSwordDataId('rare_20'), 'rare_0');
    expect(resolveSwordDataId('unique_10'), 'unique_0');
    expect(getSwordById('normal_89').id, 'normal_15');
    expect(getSwordById('rare_49').id, 'rare_9');
    expect(getSwordById('unique_24').id, 'unique_4');
  });
}
