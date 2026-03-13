class SeasonPassReward {
  final int level;
  // 일반 보상
  final int gold;
  final int diamond;
  final int stone;
  // 프리미엄 보상
  final int premiumGold;
  final int premiumDiamond;
  final int premiumStone;
  // 특별 보상 (10레벨 단위)
  final bool hasSpecialReward;
  final String? specialRewardType; // 'gacha_ticket', 'unique_sword', 'legend_chance'

  const SeasonPassReward({
    required this.level,
    this.gold = 0,
    this.diamond = 0,
    this.stone = 0,
    this.premiumGold = 0,
    this.premiumDiamond = 0,
    this.premiumStone = 0,
    this.hasSpecialReward = false,
    this.specialRewardType,
  });
  
  // 일반 보상 있는지
  bool get hasFreeReward => gold > 0 || diamond > 0 || stone > 0;
  
  // 프리미엄 보상 있는지
  bool get hasPremiumReward => premiumGold > 0 || premiumDiamond > 0 || premiumStone > 0;
}

/// 시즌패스 보상 생성 (v11 - 35% 이득 밸런스!)
/// 
/// ₩11,000 = 다이아 1,400개 상당
/// 프리미엄 환산 가치: ~1,890개 (약 35% 이득!)
/// 
/// - 일반: 골드 + 강화석 + 다이아
/// - 프리미엄: 대폭 상향된 보상!
List<SeasonPassReward> getSeasonPassRewards({required int maxLevel}) {
  final rewards = <SeasonPassReward>[];

  for (int lv = 1; lv <= maxLevel; lv++) {
    // ========================================
    // 일반 보상 (유지)
    // ========================================
    int gold = 1000 + (lv * 200);  // 1,200 ~ 11,000
    int stone = (lv % 2 == 0) ? 2 : 1;  // 매 레벨 1~2개
    int diamond = 0;
    if (lv % 3 == 0) diamond += 2;   // 3레벨마다 2개
    if (lv % 5 == 0) diamond += 3;   // 5레벨마다 추가 3개
    if (lv % 10 == 0) diamond += 10; // 10레벨마다 추가 10개

    // ========================================
    // 프리미엄 보상 (v11 - 35% 이득!)
    // ========================================
    int premiumGold = 4000 + (lv * 800);  // 4,800 ~ 44,000
    int premiumStone = (lv % 2 == 0) ? 8 : 5;  // 5~8개
    int premiumDiamond = 7;  // 기본 7개
    if (lv % 3 == 0) premiumDiamond += 10;  // 3레벨마다 +10개
    if (lv % 5 == 0) premiumDiamond += 18;  // 5레벨마다 +18개
    if (lv % 10 == 0) premiumDiamond += 55; // 10레벨마다 +55개
    
    // ========================================
    // 특별 보상 (10레벨 단위) - 미구현, 향후 확장용
    // ========================================
    bool hasSpecial = lv % 10 == 0;
    String? specialType;
    if (lv == 10) specialType = 'premium_gacha_5x';
    else if (lv == 20) specialType = 'unique_selector';
    else if (lv == 30) specialType = 'legend_ticket';
    else if (lv == 40) specialType = 'premium_gacha_10x';
    else if (lv == 50) specialType = 'legend_selector';

    rewards.add(SeasonPassReward(
      level: lv,
      gold: gold,
      diamond: diamond,
      stone: stone,
      premiumGold: premiumGold,
      premiumDiamond: premiumDiamond,
      premiumStone: premiumStone,
      hasSpecialReward: hasSpecial,
      specialRewardType: specialType,
    ));
  }

  return rewards;
}

/// 프리미엄 패스 가격 (다이아)
const int premiumPassPrice = 500;

/// ========================================
/// 시즌패스 총 보상 요약 (50레벨 기준, v11)
/// ========================================
/// 
/// 【일반 보상】
///   골드:    305,000G
///   다이아:  112개
///   강화석:  75개
/// 
/// 【프리미엄 보상】
///   골드:    1,220,000G
///   다이아:  965개
///   강화석:  325개
/// 
/// 【프리미엄 추가 획득 (다이아 환산)】
///   직접 다이아: +853개
///   골드 환산:   +549개 (100K G = 60💎)
///   강화석 환산: +500개 (5개 = 20💎)
///   ─────────────────────
///   합계:        ~1,902개
/// 
/// 【가치 비교】
///   ₩11,000 직접 구매: 1,400다이아
///   프리미엄 패스:      ~1,902다이아 환산
///   ✅ 약 35% 이득! 구매 필수!
/// ========================================
