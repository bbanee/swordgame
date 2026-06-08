import '../models/achievement_data.dart';

/// 업적 카테고리별 생성
/// 난이도 높은 업적은 보상 대폭 상향!
List<AchievementData> getAllAchievements() {
  final list = <AchievementData>[];

  // ===== 강화(25) =====
  // 시도 / 성공 / 파괴 / 연속성공 / 강화석사용
  final enhanceAttempts = [1, 10, 30, 50, 100, 200, 300, 500];
  final attemptGold = [500, 1000, 2000, 3000, 5000, 8000, 12000, 20000];
  final attemptStone = [0, 0, 1, 2, 3, 5, 7, 10];
  final attemptDiamond = [0, 0, 0, 0, 1, 2, 3, 5];
  for (int i = 0; i < enhanceAttempts.length; i++) {
    final t = enhanceAttempts[i];
    list.add(
      AchievementData(
        id: 'ach_enh_attempt_$i',
        category: AchievementCategory.enhance,
        name: '강화 시도 $t회',
        description: '강화를 총 $t회 시도하세요.',
        statsKey: 'totalEnhanceAttempts',
        target: t,
        rewardGold: attemptGold[i],
        rewardStone: attemptStone[i],
        rewardDiamond: attemptDiamond[i],
      ),
    );
  }

  final enhanceSuccess = [1, 5, 10, 25, 50, 100, 150, 250];
  final successGold = [1000, 2000, 4000, 8000, 15000, 30000, 50000, 100000];
  final successStone = [1, 2, 3, 5, 8, 12, 15, 25];
  final successDiamond = [0, 0, 1, 2, 3, 5, 8, 15];
  for (int i = 0; i < enhanceSuccess.length; i++) {
    final t = enhanceSuccess[i];
    list.add(
      AchievementData(
        id: 'ach_enh_success_$i',
        category: AchievementCategory.enhance,
        name: '강화 성공 $t회',
        description: '강화에 총 $t번 성공하세요.',
        statsKey: 'totalEnhanceSuccess',
        target: t,
        rewardGold: successGold[i],
        rewardStone: successStone[i],
        rewardDiamond: successDiamond[i],
      ),
    );
  }

  // 파괴 경험 (아픔의 대가 - 보상 상향!)
  final destroy = [1, 3, 5, 10];
  final destroyGold = [3000, 8000, 20000, 50000];
  final destroyStone = [5, 10, 20, 40];
  final destroyDiamond = [1, 3, 7, 15];
  for (int i = 0; i < destroy.length; i++) {
    final t = destroy[i];
    list.add(
      AchievementData(
        id: 'ach_enh_destroy_$i',
        category: AchievementCategory.enhance,
        name: '파괴의 기록 $t회',
        description: '강화 파괴를 $t번 경험하세요.',
        statsKey: 'totalDestroy',
        target: t,
        rewardGold: destroyGold[i],
        rewardStone: destroyStone[i],
        rewardDiamond: destroyDiamond[i],
      ),
    );
  }

  // 연속 성공 (매우 어려움 - 보상 대폭 상향!)
  final streak = [3, 5, 7, 10, 15];
  final streakGold = [3000, 8000, 20000, 50000, 150000];
  final streakStone = [3, 5, 10, 20, 50];
  final streakDiamond = [1, 3, 7, 15, 30];
  for (int i = 0; i < streak.length; i++) {
    final t = streak[i];
    list.add(
      AchievementData(
        id: 'ach_enh_streak_$i',
        category: AchievementCategory.enhance,
        name: '연속 성공 $t회',
        description: '강화 연속 성공 기록이 $t회 이상이 되세요.',
        statsKey: 'maxConsecutiveSuccess',
        target: t,
        rewardGold: streakGold[i],
        rewardStone: streakStone[i],
        rewardDiamond: streakDiamond[i],
      ),
    );
  }

  // 강화석 사용
  final stoneUsed = [1, 10, 30, 50];
  for (int i = 0; i < stoneUsed.length; i++) {
    final t = stoneUsed[i];
    list.add(
      AchievementData(
        id: 'ach_stone_used_$i',
        category: AchievementCategory.enhance,
        name: '강화석 사용 $t개',
        description: '강화석을 누적 $t개 사용하세요.',
        statsKey: 'totalStoneUsed',
        target: t,
        rewardGold: 2000 * (i + 1),
        rewardStone: 3 + i * 2,
        rewardDiamond: i >= 2 ? 2 : 0,
      ),
    );
  }

  // 강화 파트 25개 맞추기
  while (list.where((a) => a.category == AchievementCategory.enhance).length >
      25) {
    final idx = list.lastIndexWhere(
      (a) => a.category == AchievementCategory.enhance,
    );
    if (idx >= 0) list.removeAt(idx);
  }

  final breakthroughCount = [1, 3, 6];
  final breakthroughGold = [500000, 2000000, 10000000];
  final breakthroughStone = [50, 150, 500];
  final breakthroughDiamond = [20, 60, 200];
  for (int i = 0; i < breakthroughCount.length; i++) {
    final t = breakthroughCount[i];
    list.add(
      AchievementData(
        id: 'ach_breakthrough_$i',
        category: AchievementCategory.enhance,
        name: '돌파 달성 $t개',
        description: '돌파한 검을 총 $t개 보유하세요.',
        statsKey: 'breakthroughSwordCount',
        target: t,
        rewardGold: breakthroughGold[i],
        rewardStone: breakthroughStone[i],
        rewardDiamond: breakthroughDiamond[i],
      ),
    );
  }

  final transcendentLevels = [31, 35, 40, 45];
  final transcendentGold = [1000000, 5000000, 30000000, 200000000];
  final transcendentStone = [80, 200, 600, 2000];
  final transcendentDiamond = [30, 100, 300, 1000];
  for (int i = 0; i < transcendentLevels.length; i++) {
    final t = transcendentLevels[i];
    list.add(
      AchievementData(
        id: 'ach_transcend_level_$i',
        category: AchievementCategory.enhance,
        name: '$t강 초월',
        description: '검의 최고 강화 레벨을 $t강 이상 달성하세요.',
        statsKey: 'maxSwordLevel',
        target: t,
        rewardGold: transcendentGold[i],
        rewardStone: transcendentStone[i],
        rewardDiamond: transcendentDiamond[i],
      ),
    );
  }

  // ===== 배틀(25) =====
  // 총 배틀 / 승리 / 연승 / 복수승리
  final totalBattle = [1, 10, 30, 50, 100, 200, 300, 500];
  final battleGold = [1000, 2000, 4000, 7000, 12000, 20000, 35000, 60000];
  final battleDiamond = [0, 0, 1, 1, 2, 3, 5, 8];
  for (int i = 0; i < totalBattle.length; i++) {
    final t = totalBattle[i];
    list.add(
      AchievementData(
        id: 'ach_battle_total_$i',
        category: AchievementCategory.battle,
        name: '배틀 참여 $t회',
        description: '배틀을 총 $t회 진행하세요.',
        statsKey: 'totalBattle',
        target: t,
        rewardGold: battleGold[i],
        rewardDiamond: battleDiamond[i],
      ),
    );
  }

  final battleWin = [1, 5, 10, 30, 50, 100, 150, 250];
  final winGold = [1500, 3000, 6000, 12000, 25000, 50000, 80000, 150000];
  final winStone = [1, 2, 3, 5, 8, 12, 18, 30];
  final winDiamond = [0, 0, 1, 2, 4, 7, 12, 20];
  for (int i = 0; i < battleWin.length; i++) {
    final t = battleWin[i];
    list.add(
      AchievementData(
        id: 'ach_battle_win_$i',
        category: AchievementCategory.battle,
        name: '배틀 승리 $t회',
        description: '배틀에서 총 $t회 승리하세요.',
        statsKey: 'totalBattleWin',
        target: t,
        rewardGold: winGold[i],
        rewardStone: winStone[i],
        rewardDiamond: winDiamond[i],
      ),
    );
  }

  // 연승 (매우 어려움!)
  final maxWinStreak = [3, 5, 10, 15, 20];
  final streakWinGold = [5000, 15000, 50000, 120000, 300000];
  final streakWinStone = [5, 10, 25, 50, 100];
  final streakWinDiamond = [2, 5, 15, 35, 80];
  for (int i = 0; i < maxWinStreak.length; i++) {
    final t = maxWinStreak[i];
    list.add(
      AchievementData(
        id: 'ach_battle_streak_$i',
        category: AchievementCategory.battle,
        name: '최대 연승 $t',
        description: '최대 연승 기록이 $t 이상이 되세요.',
        statsKey: 'maxWinStreak',
        target: t,
        rewardGold: streakWinGold[i],
        rewardStone: streakWinStone[i],
        rewardDiamond: streakWinDiamond[i],
      ),
    );
  }

  final revengeWins = [1, 3, 5, 10];
  final revengeGold = [5000, 15000, 35000, 80000];
  final revengeStone = [3, 8, 18, 40];
  final revengeDiamond = [2, 5, 12, 30];
  for (int i = 0; i < revengeWins.length; i++) {
    final t = revengeWins[i];
    list.add(
      AchievementData(
        id: 'ach_revenge_$i',
        category: AchievementCategory.battle,
        name: '복수 성공 $t회',
        description: '복수전에서 $t번 승리하세요.',
        statsKey: 'totalRevengeWins',
        target: t,
        rewardGold: revengeGold[i],
        rewardStone: revengeStone[i],
        rewardDiamond: revengeDiamond[i],
      ),
    );
  }

  // battle 업적 수 25 맞추기
  while (list.where((a) => a.category == AchievementCategory.battle).length >
      25) {
    final idx = list.lastIndexWhere(
      (a) => a.category == AchievementCategory.battle,
    );
    if (idx >= 0) list.removeAt(idx);
  }

  // ===== 보스(15) =====
  // 최대 목표를 500회로 조정 (현실적인 달성 가능 범위)
  final bossKills = [
    1,
    3,
    5,
    10,
    20,
    30,
    50,
    80,
    120,
    170,
    230,
    300,
    380,
    450,
    500,
  ];
  final bossGold = [
    3000,
    6000,
    12000,
    25000,
    50000,
    80000,
    130000,
    200000,
    300000,
    450000,
    650000,
    900000,
    1200000,
    1800000,
    3000000,
  ];
  final bossStone = [
    2,
    3,
    5,
    8,
    12,
    18,
    25,
    35,
    50,
    70,
    95,
    125,
    160,
    220,
    350,
  ];
  final bossDiamond = [
    1,
    2,
    4,
    7,
    12,
    18,
    28,
    40,
    60,
    85,
    115,
    150,
    200,
    300,
    500,
  ];
  for (int i = 0; i < bossKills.length; i++) {
    final t = bossKills[i];
    list.add(
      AchievementData(
        id: 'ach_boss_kill_$i',
        category: AchievementCategory.boss,
        name: '보스 처치 $t회',
        description: '보스를 총 $t회 처치하세요.',
        statsKey: 'bossKills',
        target: t,
        rewardGold: bossGold[i],
        rewardStone: bossStone[i],
        rewardDiamond: bossDiamond[i],
      ),
    );
  }

  // ===== 수집(15) =====
  // 도감(코덱스) 수집 - 컬렉션 완성은 최고 보상!
  final codex = [
    1,
    5,
    10,
    20,
    30,
    50,
    70,
    100,
    120,
    140,
    160,
    180,
    190,
    195,
    200,
  ];
  final codexGold = [
    2000,
    5000,
    12000,
    25000,
    45000,
    80000,
    120000,
    180000,
    250000,
    350000,
    500000,
    700000,
    1000000,
    1500000,
    3000000,
  ];
  final codexStone = [
    1,
    3,
    5,
    10,
    15,
    25,
    40,
    60,
    80,
    100,
    130,
    170,
    220,
    300,
    500,
  ];
  final codexDiamond = [
    0,
    1,
    2,
    5,
    8,
    15,
    25,
    40,
    60,
    90,
    130,
    180,
    250,
    400,
    1000,
  ];
  for (int i = 0; i < codex.length; i++) {
    final t = codex[i];
    list.add(
      AchievementData(
        id: 'ach_codex_$i',
        category: AchievementCategory.collection,
        name: '도감 $t개',
        description: '검 도감을 $t개 등록하세요.',
        statsKey: 'codexCount',
        target: t,
        rewardGold: codexGold[i],
        rewardStone: codexStone[i],
        rewardDiamond: codexDiamond[i],
      ),
    );
  }

  // ===== 경제(10) =====
  // 판매 보상 상향
  final sell = [1, 10, 30, 50, 100];
  final sellGold = [3000, 10000, 30000, 60000, 120000];
  final sellStone = [1, 3, 6, 12, 25];
  final sellDiamond = [0, 2, 5, 10, 20];
  for (int i = 0; i < sell.length; i++) {
    final t = sell[i];
    list.add(
      AchievementData(
        id: 'ach_sell_$i',
        category: AchievementCategory.economy,
        name: '검 판매 $t회',
        description: '검을 $t회 판매하세요.',
        statsKey: 'totalSell',
        target: t,
        rewardGold: sellGold[i],
        rewardStone: sellStone[i],
        rewardDiamond: sellDiamond[i],
      ),
    );
  }

  // 뽑기 보상 상향 (다이아 추가)
  final gacha = [1, 10, 30, 50, 100];
  final gachaGold = [2000, 6000, 15000, 30000, 60000];
  final gachaStone = [1, 3, 6, 10, 18];
  final gachaDiamond = [0, 1, 3, 6, 12];
  for (int i = 0; i < gacha.length; i++) {
    final t = gacha[i];
    list.add(
      AchievementData(
        id: 'ach_gacha_$i',
        category: AchievementCategory.economy,
        name: '뽑기 $t회',
        description: '검 뽑기를 총 $t회 진행하세요.',
        statsKey: 'totalGacha',
        target: t,
        rewardGold: gachaGold[i],
        rewardStone: gachaStone[i],
        rewardDiamond: gachaDiamond[i],
      ),
    );
  }

  // ===== 출석(10) =====
  // 출석은 시간이 오래 걸리므로 보상 대폭 상향!
  final att = [1, 3, 7, 14, 21, 30, 50, 70, 100, 150];
  final attGold = [
    1000,
    3000,
    8000,
    18000,
    30000,
    50000,
    100000,
    180000,
    300000,
    500000,
  ];
  final attStone = [1, 2, 4, 7, 12, 20, 35, 55, 80, 120];
  final attDiamond = [0, 1, 2, 4, 7, 12, 22, 40, 70, 120];
  for (int i = 0; i < att.length; i++) {
    final t = att[i];
    list.add(
      AchievementData(
        id: 'ach_att_$i',
        category: AchievementCategory.attendance,
        name: '출석 $t일',
        description: '연속 출석을 $t일 달성하세요.',
        statsKey: 'attendanceStreak',
        target: t,
        rewardGold: attGold[i],
        rewardStone: attStone[i],
        rewardDiamond: attDiamond[i],
      ),
    );
  }

  // ===== 기타(misc) =====
  // 합성 횟수
  final miscSynth = [1, 5, 10, 25, 50, 100];
  final synthGold = [2000, 6000, 15000, 40000, 80000, 180000];
  final synthStone = [2, 4, 8, 15, 30, 60];
  final synthDiamond = [0, 1, 3, 8, 18, 40];
  for (int i = 0; i < miscSynth.length; i++) {
    final t = miscSynth[i];
    list.add(
      AchievementData(
        id: 'ach_misc_synth_$i',
        category: AchievementCategory.misc,
        name: '합성 마스터 $t회',
        description: '검 합성을 총 $t회 하세요.',
        statsKey: 'totalSynthesis',
        target: t,
        rewardGold: synthGold[i],
        rewardStone: synthStone[i],
        rewardDiamond: synthDiamond[i],
      ),
    );
  }

  // 퀘스트 완료 (시간 오래 걸림!)
  final miscQuest = [1, 10, 30, 50, 100];
  final questGold = [3000, 12000, 35000, 70000, 200000];
  final questStone = [2, 6, 15, 30, 70];
  final questDiamond = [1, 4, 12, 28, 70];
  for (int i = 0; i < miscQuest.length; i++) {
    final t = miscQuest[i];
    list.add(
      AchievementData(
        id: 'ach_misc_quest_$i',
        category: AchievementCategory.misc,
        name: '퀘스트 헌터 $t회',
        description: '일일 퀘스트를 총 $t개 완료하세요.',
        statsKey: 'totalQuestsCompleted',
        target: t,
        rewardGold: questGold[i],
        rewardStone: questStone[i],
        rewardDiamond: questDiamond[i],
      ),
    );
  }

  final towerFloors = [20, 40, 60, 80, 100];
  final towerGold = [150000, 450000, 1200000, 2800000, 7000000];
  final towerStone = [25, 70, 160, 320, 700];
  final towerDiamond = [12, 30, 65, 120, 250];
  for (int i = 0; i < towerFloors.length; i++) {
    final t = towerFloors[i];
    list.add(
      AchievementData(
        id: 'ach_tower_floor_$i',
        category: AchievementCategory.misc,
        name: '무한의 탑 $t층 돌파',
        description: '무한의 탑 최고 기록을 $t층 이상 달성하세요.',
        statsKey: 'infiniteTowerBestFloor',
        target: t,
        rewardGold: towerGold[i],
        rewardStone: towerStone[i],
        rewardDiamond: towerDiamond[i],
      ),
    );
  }

  // 총 100개 검증(혹시라도 변경되면 여기서 확인 가능)
  // assert(list.length == 100);

  return list;
}
