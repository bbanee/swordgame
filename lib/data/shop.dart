class ShopItem {
  final String id;
  final String name;
  final String description;
  final String category; // diamond_purchase, gold_purchase, enhance_stone, special
  final int price;
  final String priceType; // gold, diamond, cash
  final int amount;
  final int bonus;
  final bool isSpecial;  // 특별 상품 여부
  
  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.priceType,
    required this.amount,
    this.bonus = 0,
    this.isSpecial = false,
  });
  
  // 총 획득량
  int get totalAmount => amount + bonus;
  
  // 보너스 퍼센트
  String get bonusText => bonus > 0 ? '+$bonus' : '';
}

// =====================================================
// 상점 아이템 목록 (v10.4 밸런스)
// 기준: 1💎 = 1,000G = 강화석 1개
// =====================================================
final List<ShopItem> shopItems = [
  // ===== 다이아 결제 (실결제) =====
  const ShopItem(id: 'dia_1', name: '소량 다이아', description: '100 다이아', category: 'diamond_purchase', price: 1100, priceType: 'cash', amount: 100),
  const ShopItem(id: 'dia_2', name: '중량 다이아', description: '500+50 다이아', category: 'diamond_purchase', price: 5500, priceType: 'cash', amount: 500, bonus: 50),
  const ShopItem(id: 'dia_3', name: '대량 다이아', description: '1,200+200 다이아', category: 'diamond_purchase', price: 11000, priceType: 'cash', amount: 1200, bonus: 200),
  const ShopItem(id: 'dia_4', name: '고급 다이아', description: '3,000+600 다이아', category: 'diamond_purchase', price: 22000, priceType: 'cash', amount: 3000, bonus: 600),
  const ShopItem(id: 'dia_5', name: '최고급 다이아', description: '6,500+1,500 다이아', category: 'diamond_purchase', price: 44000, priceType: 'cash', amount: 6500, bonus: 1500),
  
  // ===== 골드 구매 (다이아) - 1💎 = 1,000G =====
  const ShopItem(id: 'gold_1', name: '소량 골드', description: '100,000 골드', category: 'gold_purchase', price: 100, priceType: 'diamond', amount: 100000),
  const ShopItem(id: 'gold_2', name: '중량 골드', description: '550,000+50,000 골드', category: 'gold_purchase', price: 500, priceType: 'diamond', amount: 550000, bonus: 50000),
  const ShopItem(id: 'gold_3', name: '대량 골드', description: '1,200,000+200,000 골드', category: 'gold_purchase', price: 1000, priceType: 'diamond', amount: 1200000, bonus: 200000),
  
  // ===== 강화석 (골드) - 1개 = 1,000G =====
  const ShopItem(id: 'stone_g1', name: '강화석 1개', description: '강화석 1개', category: 'enhance_stone', price: 1000, priceType: 'gold', amount: 1),
  const ShopItem(id: 'stone_g2', name: '강화석 5개', description: '강화석 5개 (10% 할인)', category: 'enhance_stone', price: 4500, priceType: 'gold', amount: 5),
  const ShopItem(id: 'stone_g3', name: '강화석 10개', description: '강화석 10개 (20% 할인)', category: 'enhance_stone', price: 8000, priceType: 'gold', amount: 10),
  
  // ===== 강화석 (다이아) - 1개 = 1💎 =====
  const ShopItem(id: 'stone_d1', name: '강화석 5개', description: '강화석 5개', category: 'enhance_stone', price: 5, priceType: 'diamond', amount: 5),
  const ShopItem(id: 'stone_d2', name: '강화석 20개', description: '강화석 20개 (10% 할인)', category: 'enhance_stone', price: 18, priceType: 'diamond', amount: 20),
  const ShopItem(id: 'stone_d3', name: '강화석 50개', description: '강화석 50개 (20% 할인)', category: 'enhance_stone', price: 40, priceType: 'diamond', amount: 50),
  
  // ===== 배틀 충전 =====
  const ShopItem(id: 'battle_1', name: '배틀 충전', description: '배틀 횟수 +5', category: 'battle', price: 50, priceType: 'diamond', amount: 5),
  
  // ===== 특별 상품 (실결제) =====
  const ShopItem(
    id: 'premium_pass', 
    name: '⭐ 프리미엄 패스', 
    description: '시즌 패스 프리미엄 보상 해금', 
    category: 'special', 
    price: 11000, 
    priceType: 'cash', 
    amount: 0,
    isSpecial: true,
  ),
];

// 인벤토리 확장 가격 (슬롯, 가격, 타입)
// 10→15: 골드
// 15→20: 다이아
final List<(int, int, String)> inventoryPrices = [
  (11, 10000, 'gold'),
  (12, 50000, 'gold'),
  (13, 100000, 'gold'),
  (14, 500000, 'gold'),
  (15, 1000000, 'gold'),
  (16, 80, 'diamond'),
  (17, 110, 'diamond'),
  (18, 140, 'diamond'),
  (19, 170, 'diamond'),
  (20, 200, 'diamond'),
];

// 카테고리별 상점 아이템
List<ShopItem> getShopItemsByCategory(String category) {
  return shopItems.where((i) => i.category == category).toList();
}

// 특별 상품 목록
List<ShopItem> getSpecialItems() {
  return shopItems.where((i) => i.isSpecial).toList();
}
