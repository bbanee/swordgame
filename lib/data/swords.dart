import '../enums/sword_grade.dart';
import '../models/sword_data.dart';
import 'generated/swords_generated.dart';

const Map<SwordGrade, int> activeSwordCountByGrade = {
  SwordGrade.normal: 37,
  SwordGrade.rare: 20,
  SwordGrade.unique: 10,
  SwordGrade.legend: 18,
  SwordGrade.hidden: 10,
  SwordGrade.immortal: 5,
};

const int activeSwordTotalCount = 100;

final Map<String, String> legacySwordReplacementMap = Map.unmodifiable(
  _buildLegacySwordReplacementMap(),
);

final List<SwordData> allSwords = generatedSwords;

const Map<SwordGrade, double> gachaProbability = {
  SwordGrade.normal: 63.6357,
  SwordGrade.rare: 35.3532,
  SwordGrade.unique: 1.0,
  SwordGrade.legend: 0.01,
  SwordGrade.hidden: 0.001,
  SwordGrade.immortal: 0.0001,
};

const Map<SwordGrade, double> premiumGachaProbability = {
  SwordGrade.rare: 74.889,
  SwordGrade.unique: 25.0,
  SwordGrade.legend: 0.1,
  SwordGrade.hidden: 0.01,
  SwordGrade.immortal: 0.001,
};

const int premiumGachaCostSingle = 5;
const int premiumGachaCost5x = 20;
const int premiumGachaCost10x = 35;

const List<(SwordGrade, SwordGrade, double, int?)> synthesisTable = [
  (SwordGrade.normal, SwordGrade.rare, 30.0, 10),
  (SwordGrade.rare, SwordGrade.unique, 5.0, 50),
  (SwordGrade.unique, SwordGrade.legend, 0.5, 100),
  (SwordGrade.legend, SwordGrade.hidden, 0.1, null),
  (SwordGrade.hidden, SwordGrade.immortal, 0.02, null),
];

List<(int, int, int, int)> get enhanceTable => List.generate(30, (i) {
  final level = i + 1;
  int cost, successRate, destroyRate;

  const lateCosts = [
    55000,
    70000,
    90000,
    120000,
    160000,
    210000,
    270000,
    400000,
    600000,
    1000000,
  ];
  const lateSuccess = [18, 15, 12, 10, 8, 6, 5, 4, 2, 1];
  const lateDestroy = [35, 35, 35, 35, 35, 40, 40, 40, 40, 40];

  if (level <= 10) {
    cost = level * 500;
    successRate = 95 - level * 3;
    destroyRate = 0;
  } else if (level <= 14) {
    cost = 5000 + (level - 10) * 3000;
    successRate = 62 - (level - 11) * 3;
    destroyRate = 2 + (level - 11) * 2;
  } else if (level <= 20) {
    cost = 5000 + (level - 10) * 3000;
    successRate = 30 - (level - 15) * 2;
    destroyRate = 30;
  } else {
    cost = lateCosts[level - 21];
    successRate = lateSuccess[level - 21];
    destroyRate = lateDestroy[level - 21];
  }

  return (level, cost, successRate, destroyRate);
});

Map<String, String> _buildLegacySwordReplacementMap() {
  final replacements = <String, String>{};

  void addGrade({
    required String prefix,
    required int previousCount,
    required int activeCount,
  }) {
    for (int i = activeCount; i < previousCount; i++) {
      replacements['${prefix}_$i'] = '${prefix}_${i % activeCount}';
    }
  }

  addGrade(prefix: 'normal', previousCount: 90, activeCount: 37);
  addGrade(prefix: 'rare', previousCount: 50, activeCount: 20);
  addGrade(prefix: 'unique', previousCount: 25, activeCount: 10);

  return replacements;
}

String resolveSwordDataId(String dataId) {
  return legacySwordReplacementMap[dataId] ?? dataId;
}

SwordData getSwordById(String dataId) {
  final resolvedId = resolveSwordDataId(dataId);
  return allSwords.firstWhere(
    (s) => s.id == resolvedId,
    orElse: () => allSwords.first,
  );
}

List<SwordData> getSwordsByGrade(SwordGrade grade) {
  return allSwords.where((s) => s.grade == grade).toList();
}
