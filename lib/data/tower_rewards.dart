class TowerRewardBracket {
  final int floorFrom;
  final int floorTo;
  final int repeatBaseGold;
  final int repeatGoldPerFloor;
  final int repeatMiniBossStone;
  final int repeatBossStone;
  final int repeatMiniBossGoldBonus;
  final int repeatBossGoldBonus;
  final int firstClearBaseGold;
  final int firstClearGoldPerFloor;
  final int firstClearMiniBossStone;
  final int firstClearBossStone;
  final int firstClearMiniBossGoldBonus;
  final int firstClearBossGoldBonus;
  final int firstClearDiamond;
  final int firstClearMiniBossDiamond;
  final int firstClearBossDiamond;

  const TowerRewardBracket({
    required this.floorFrom,
    required this.floorTo,
    required this.repeatBaseGold,
    required this.repeatGoldPerFloor,
    required this.repeatMiniBossStone,
    required this.repeatBossStone,
    required this.repeatMiniBossGoldBonus,
    required this.repeatBossGoldBonus,
    required this.firstClearBaseGold,
    required this.firstClearGoldPerFloor,
    required this.firstClearMiniBossStone,
    required this.firstClearBossStone,
    required this.firstClearMiniBossGoldBonus,
    required this.firstClearBossGoldBonus,
    required this.firstClearDiamond,
    required this.firstClearMiniBossDiamond,
    required this.firstClearBossDiamond,
  });

  bool contains(int floor) => floor >= floorFrom && floor <= floorTo;
}

class TowerRewardEntry {
  final int gold;
  final int stones;
  final int diamonds;

  const TowerRewardEntry({
    required this.gold,
    required this.stones,
    this.diamonds = 0,
  });

  bool get hasReward => gold > 0 || stones > 0 || diamonds > 0;
}

class TowerRewardResult {
  final TowerRewardEntry repeatReward;
  final TowerRewardEntry firstClearReward;

  const TowerRewardResult({
    required this.repeatReward,
    required this.firstClearReward,
  });
}

const List<TowerRewardBracket> towerRewardBrackets = [
  TowerRewardBracket(
    floorFrom: 1,
    floorTo: 10,
    repeatBaseGold: 12000,
    repeatGoldPerFloor: 3500,
    repeatMiniBossStone: 4,
    repeatBossStone: 8,
    repeatMiniBossGoldBonus: 18000,
    repeatBossGoldBonus: 36000,
    firstClearBaseGold: 18000,
    firstClearGoldPerFloor: 5000,
    firstClearMiniBossStone: 8,
    firstClearBossStone: 14,
    firstClearMiniBossGoldBonus: 26000,
    firstClearBossGoldBonus: 52000,
    firstClearDiamond: 20,
    firstClearMiniBossDiamond: 10,
    firstClearBossDiamond: 25,
  ),
  TowerRewardBracket(
    floorFrom: 11,
    floorTo: 25,
    repeatBaseGold: 33800,
    repeatGoldPerFloor: 6760,
    repeatMiniBossStone: 5,
    repeatBossStone: 10,
    repeatMiniBossGoldBonus: 33800,
    repeatBossGoldBonus: 67600,
    firstClearBaseGold: 44200,
    firstClearGoldPerFloor: 9360,
    firstClearMiniBossStone: 10,
    firstClearBossStone: 18,
    firstClearMiniBossGoldBonus: 46800,
    firstClearBossGoldBonus: 88400,
    firstClearDiamond: 30,
    firstClearMiniBossDiamond: 15,
    firstClearBossDiamond: 35,
  ),
  TowerRewardBracket(
    floorFrom: 26,
    floorTo: 50,
    repeatBaseGold: 88400,
    repeatGoldPerFloor: 14450,
    repeatMiniBossStone: 8,
    repeatBossStone: 15,
    repeatMiniBossGoldBonus: 71400,
    repeatBossGoldBonus: 136000,
    firstClearBaseGold: 119000,
    firstClearGoldPerFloor: 18700,
    firstClearMiniBossStone: 14,
    firstClearBossStone: 24,
    firstClearMiniBossGoldBonus: 95200,
    firstClearBossGoldBonus: 187000,
    firstClearDiamond: 45,
    firstClearMiniBossDiamond: 22,
    firstClearBossDiamond: 50,
  ),
  TowerRewardBracket(
    floorFrom: 51,
    floorTo: 75,
    repeatBaseGold: 90000,
    repeatGoldPerFloor: 14000,
    repeatMiniBossStone: 12,
    repeatBossStone: 22,
    repeatMiniBossGoldBonus: 70000,
    repeatBossGoldBonus: 140000,
    firstClearBaseGold: 130000,
    firstClearGoldPerFloor: 19000,
    firstClearMiniBossStone: 20,
    firstClearBossStone: 35,
    firstClearMiniBossGoldBonus: 95000,
    firstClearBossGoldBonus: 190000,
    firstClearDiamond: 70,
    firstClearMiniBossDiamond: 35,
    firstClearBossDiamond: 80,
  ),
  TowerRewardBracket(
    floorFrom: 76,
    floorTo: 100,
    repeatBaseGold: 150000,
    repeatGoldPerFloor: 19000,
    repeatMiniBossStone: 18,
    repeatBossStone: 32,
    repeatMiniBossGoldBonus: 110000,
    repeatBossGoldBonus: 220000,
    firstClearBaseGold: 220000,
    firstClearGoldPerFloor: 26000,
    firstClearMiniBossStone: 30,
    firstClearBossStone: 55,
    firstClearMiniBossGoldBonus: 150000,
    firstClearBossGoldBonus: 320000,
    firstClearDiamond: 95,
    firstClearMiniBossDiamond: 50,
    firstClearBossDiamond: 120,
  ),
];

TowerRewardEntry _buildRewardEntry({
  required int floor,
  required int baseGold,
  required int goldPerFloor,
  required int miniBossStone,
  required int bossStone,
  required int miniBossGoldBonus,
  required int bossGoldBonus,
  int baseDiamond = 0,
  int miniBossDiamond = 0,
  int bossDiamond = 0,
}) {
  final isMiniBossFloor = floor % 5 == 0;
  final isBossFloor = floor % 10 == 0;

  var gold = baseGold + floor * goldPerFloor;
  var stones = 0;
  var diamonds = baseDiamond;

  if (isMiniBossFloor) {
    gold += miniBossGoldBonus;
    stones += miniBossStone;
    diamonds += miniBossDiamond;
  }
  if (isBossFloor) {
    gold += bossGoldBonus;
    stones = bossStone;
    diamonds += bossDiamond;
  }

  return TowerRewardEntry(gold: gold, stones: stones, diamonds: diamonds);
}

TowerRewardResult resolveTowerReward(int floor) {
  final bracket = towerRewardBrackets.firstWhere((b) => b.contains(floor));
  return TowerRewardResult(
    repeatReward: _buildRewardEntry(
      floor: floor,
      baseGold: bracket.repeatBaseGold,
      goldPerFloor: bracket.repeatGoldPerFloor,
      miniBossStone: bracket.repeatMiniBossStone,
      bossStone: bracket.repeatBossStone,
      miniBossGoldBonus: bracket.repeatMiniBossGoldBonus,
      bossGoldBonus: bracket.repeatBossGoldBonus,
    ),
    firstClearReward: _buildRewardEntry(
      floor: floor,
      baseGold: bracket.firstClearBaseGold,
      goldPerFloor: bracket.firstClearGoldPerFloor,
      miniBossStone: bracket.firstClearMiniBossStone,
      bossStone: bracket.firstClearBossStone,
      miniBossGoldBonus: bracket.firstClearMiniBossGoldBonus,
      bossGoldBonus: bracket.firstClearBossGoldBonus,
      baseDiamond: bracket.firstClearDiamond,
      miniBossDiamond: bracket.firstClearMiniBossDiamond,
      bossDiamond: bracket.firstClearBossDiamond,
    ),
  );
}
