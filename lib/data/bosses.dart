import '../models/boss_data.dart';
import '../enums/element.dart';

// v8 보스 밸런스
// Lv1~3: 쿨타임 1시간
// Lv4~5: 쿨타임 4시간
final List<BossData> allBosses = [
  // ⭐ Lv1: 초보자용
  const BossData(
    id: 'boss_fire',
    name: '🔥 화염의 군주',
    element: GameElement.fire,
    hp: 2800,
    atk: 55,
    goldReward: 30000,
    diamondReward: 10,
    coreDropChance: 0.15,
    coreDropMin: 1,
    coreDropMax: 1,
    cooldownMinutes: 60, // 1시간
    minLevel: 5,
    imagePath: 'assets/images/bosses/boss_fire.png',
  ),
  // ⭐ Lv2
  const BossData(
    id: 'boss_water',
    name: '💧 심해의 지배자',
    element: GameElement.water,
    hp: 4200,
    atk: 70,
    goldReward: 60000,
    diamondReward: 20,
    coreDropChance: 0.25,
    coreDropMin: 1,
    coreDropMax: 2,
    cooldownMinutes: 60, // 1시간
    minLevel: 10,
    imagePath: 'assets/images/bosses/boss_water.png',
  ),
  // ⭐ Lv3
  const BossData(
    id: 'boss_nature',
    name: '🌿 숲의 수호자',
    element: GameElement.nature,
    hp: 6500,
    atk: 100,
    goldReward: 150000,
    diamondReward: 45,
    coreDropChance: 0.4,
    coreDropMin: 1,
    coreDropMax: 2,
    cooldownMinutes: 60, // 1시간
    minLevel: 15,
    imagePath: 'assets/images/bosses/boss_nature.png',
  ),
  // ⭐ Lv4: 전설급 권장
  const BossData(
    id: 'boss_light',
    name: '✨ 천상의 심판자',
    element: GameElement.light,
    hp: 7200,
    atk: 110,
    goldReward: 500000,
    diamondReward: 100,
    coreDropChance: 0.6,
    coreDropMin: 2,
    coreDropMax: 3,
    cooldownMinutes: 240, // 4시간
    minLevel: 20,
    imagePath: 'assets/images/bosses/boss_light.png',
  ),
  // ⭐ Lv5: 최종보스 - 히든급 필수
  const BossData(
    id: 'boss_dark',
    name: '🌑 암흑의 지배자',
    element: GameElement.dark,
    hp: 8000,
    atk: 125,
    goldReward: 1500000,
    diamondReward: 300,
    coreDropChance: 0.8,
    coreDropMin: 3,
    coreDropMax: 5,
    cooldownMinutes: 240, // 4시간
    minLevel: 25,
    imagePath: 'assets/images/bosses/boss_dark.png',
  ),
];
