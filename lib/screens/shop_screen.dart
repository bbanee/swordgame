import 'package:flutter/material.dart';
import '../data/shop.dart';
import '../services/purchase_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class ShopScreen extends StatefulWidget {
  final int gold;
  final int diamond;
  final int enhanceStone;
  final int battleCount;
  final int battleRefillCount;
  final int maxInventory;
  final bool hasPremiumPass;

  const ShopScreen({
    super.key,
    required this.gold,
    required this.diamond,
    required this.enhanceStone,
    required this.battleCount,
    required this.battleRefillCount,
    required this.maxInventory,
    this.hasPremiumPass = false,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  late int _gold;
  late int _diamond;
  late int _stone;
  late int _battleCount;
  late int _battleRefillCount;
  late int _maxInventory;
  late bool _hasPremiumPass;
  
  bool _isPurchasing = false;

  late final TabController _tab;
  final _purchaseService = PurchaseService();

  @override
  void initState() {
    super.initState();
    _gold = widget.gold;
    _diamond = widget.diamond;
    _stone = widget.enhanceStone;
    _battleCount = widget.battleCount;
    _battleRefillCount = widget.battleRefillCount;
    _maxInventory = widget.maxInventory;
    _hasPremiumPass = widget.hasPremiumPass;

    _tab = TabController(length: 6, vsync: this);
    
    // 결제 콜백 설정
    _purchaseService.onPurchaseComplete = _onPurchaseComplete;
    _purchaseService.onPurchaseError = _onPurchaseError;
    _purchaseService.onPurchasePending = _onPurchasePending;
  }
  
  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // =====================================================
  // 결제 콜백
  // =====================================================
  
  void _onPurchaseComplete(PurchaseResult result) {
    setState(() => _isPurchasing = false);
    
    if (!result.success) {
      _toast('❌ ${result.errorMessage ?? "구매 실패"}');
      return;
    }
    
    setState(() {
      if (result.diamonds > 0) _diamond += result.diamonds;
      if (result.gold > 0) _gold += result.gold;
      if (result.stones > 0) _stone += result.stones;
      if (result.isPremiumPass) _hasPremiumPass = true;
    });
    
    String msg = '✅ 구매 완료!';
    if (result.diamonds > 0) msg += ' +${result.diamonds}💎';
    if (result.gold > 0) msg += ' +${formatNumber(result.gold)}G';
    if (result.stones > 0) msg += ' +${result.stones}🪨';
    if (result.isPremiumPass) msg = '✅ 프리미엄 패스가 활성화되었습니다!';
    
    _toast(msg);
  }
  
  void _onPurchaseError(String error) {
    setState(() => _isPurchasing = false);
    _toast('❌ $error');
  }
  
  void _onPurchasePending() {
    _toast('⏳ 결제 처리 중...');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // =====================================================
  // 구매 처리
  // =====================================================

  void _buy(ShopItem item) {
    if (item.priceType == 'cash') {
      _startPurchase(item);
      return;
    }

    if (item.priceType == 'gold') {
      if (_gold < item.price) {
        _toast('골드가 부족합니다');
        return;
      }
      setState(() {
        _gold -= item.price;
        _stone += item.totalAmount;
      });
      _toast('+${item.totalAmount} 강화석');
      return;
    }

    if (item.priceType == 'diamond') {
      if (_diamond < item.price) {
        _toast('다이아가 부족합니다');
        return;
      }

      if (item.category == 'gold_purchase') {
        setState(() {
          _diamond -= item.price;
          _gold += item.totalAmount;
        });
        _toast('+${formatNumber(item.totalAmount)}G');
        return;
      }

      if (item.category == 'enhance_stone') {
        setState(() {
          _diamond -= item.price;
          _stone += item.totalAmount;
        });
        _toast('+${item.totalAmount} 강화석');
        return;
      }

      if (item.category == 'battle') {
        if (_battleRefillCount >= AppConstants.maxBattleRefill) {
          _toast('오늘은 더 이상 충전할 수 없습니다');
          return;
        }
        setState(() {
          _diamond -= item.price;
          _battleRefillCount += 1;
          _battleCount += item.totalAmount;
        });
        _toast('배틀 +${item.totalAmount}');
        return;
      }
    }
  }
  
  void _startPurchase(ShopItem item) {
    if (_isPurchasing) {
      _toast('결제 처리 중입니다...');
      return;
    }
    
    if (item.id == 'premium_pass' && _hasPremiumPass) {
      _toast('이미 구매한 상품입니다');
      return;
    }
    
    _showPurchaseConfirmDialog(item);
  }
  
  void _showPurchaseConfirmDialog(ShopItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: const Text('구매 확인', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(item.description, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Text(
                '${formatNumber(item.price)}원',
                style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executePurchase(item);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('구매하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  void _executePurchase(ShopItem item) async {
    setState(() => _isPurchasing = true);
    
    try {
      await _purchaseService.purchaseByShopId(item.id);
    } catch (e) {
      _onPurchaseError('결제 중 오류가 발생했습니다: $e');
    }
  }
  
  void _restorePurchases() async {
    _toast('구매 복원 중...');
    try {
      await _purchaseService.restorePurchases();
      _toast('✅ 복원 완료');
    } catch (e) {
      _toast('❌ 복원 실패: $e');
    }
  }

  (int, String)? _nextInventoryPrice() {
    if (_maxInventory >= AppConstants.maxInventoryLimit) return null;
    final nextSlot = _maxInventory + 1;
    final price = inventoryPrices.firstWhere((p) => p.$1 == nextSlot, orElse: () => (0, 0, ''));
    if (price.$1 == 0) return null;
    return (price.$2, price.$3);
  }

  void _buyInventorySlot() {
    final next = _nextInventoryPrice();
    if (next == null) {
      _toast('최대치입니다');
      return;
    }
    final (price, type) = next;
    if (type == 'gold' && _gold < price) {
      _toast('골드가 부족합니다');
      return;
    }
    if (type == 'diamond' && _diamond < price) {
      _toast('다이아가 부족합니다');
      return;
    }
    setState(() {
      if (type == 'gold') _gold -= price;
      if (type == 'diamond') _diamond -= price;
      _maxInventory += 1;
    });
    _toast('인벤토리 +1 (현재 $_maxInventory칸)');
  }

  // ✅ 수정: overflow 방지
  Widget _moneyBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,  // ✅ 추가
              children: [
                const Text('💰', style: TextStyle(fontSize: 14)),  // ✅ 16 → 14
                const SizedBox(width: 4),  // ✅ 6 → 4
                Flexible(  // ✅ 추가
                  child: Text(
                    formatGold(_gold),  // ✅ formatNumber → formatGold (축약)
                    style: AppTextStyles.gold.copyWith(fontSize: 13),  // ✅ 크기 축소
                    overflow: TextOverflow.ellipsis,  // ✅ 추가
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,  // ✅ 추가
              children: [
                const Text('💎', style: TextStyle(fontSize: 14)),  // ✅ 16 → 14
                const SizedBox(width: 4),  // ✅ 6 → 4
                Flexible(  // ✅ 추가
                  child: Text(
                    '$_diamond',
                    style: AppTextStyles.diamond.copyWith(fontSize: 13),  // ✅ 크기 축소
                    overflow: TextOverflow.ellipsis,  // ✅ 추가
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,  // ✅ 추가
              children: [
                const Text('🪨', style: TextStyle(fontSize: 14)),  // ✅ 16 → 14
                const SizedBox(width: 4),  // ✅ 6 → 4
                Flexible(  // ✅ 추가
                  child: Text(
                    '$_stone',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),  // ✅ 크기 축소
                    overflow: TextOverflow.ellipsis,  // ✅ 추가
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(String category) {
    final items = getShopItemsByCategory(category);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildItemCard(items[i]),
    );
  }
  
  Widget _buildItemCard(ShopItem it) {
    final priceText = it.priceType == 'cash'
        ? '${formatNumber(it.price)}원'
        : it.priceType == 'gold' ? '${formatNumber(it.price)}G' : '${it.price}💎';
    
    bool alreadyPurchased = (it.id == 'premium_pass' && _hasPremiumPass);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: it.isSpecial ? LinearGradient(colors: [Colors.purple.withOpacity(0.2), Colors.indigo.withOpacity(0.2)]) : null,
        color: it.isSpecial ? null : const Color(0xFF2a2a4a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: it.isSpecial ? Colors.purple.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  it.name,
                  style: TextStyle(color: alreadyPurchased ? Colors.grey : Colors.white, fontWeight: FontWeight.bold, fontSize: it.isSpecial ? 16 : 14),
                  overflow: TextOverflow.ellipsis,  // ✅ 추가
                ),
                const SizedBox(height: 4),
                Text(
                  it.description,
                  style: TextStyle(color: alreadyPurchased ? Colors.grey : Colors.white60, fontSize: 12),
                  overflow: TextOverflow.ellipsis,  // ✅ 추가
                  maxLines: 2,  // ✅ 추가
                ),
                if (it.bonus > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text('보너스 +${it.bonus}', style: const TextStyle(color: Colors.amber, fontSize: 11)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(priceText, style: TextStyle(color: alreadyPurchased ? Colors.grey : Colors.white, fontWeight: FontWeight.bold, fontSize: it.priceType == 'cash' ? 16 : 14)),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: alreadyPurchased || _isPurchasing ? null : () => _buy(it),
                style: ElevatedButton.styleFrom(
                  backgroundColor: alreadyPurchased ? Colors.grey : (it.priceType == 'cash' ? Colors.green : Colors.indigo),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(alreadyPurchased ? '구매완료' : (_isPurchasing ? '...' : '구매'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _specialTab() {
    final items = getSpecialItems();
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // TODO: 구매 복원 기능 - 나중에 되살리기
        // Container(
        //   margin: const EdgeInsets.only(bottom: 16),
        //   child: OutlinedButton.icon(
        //     onPressed: _restorePurchases,
        //     icon: const Icon(Icons.restore, color: Colors.white70),
        //     label: const Text('구매 복원', style: TextStyle(color: Colors.white70)),
        //     style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(vertical: 12)),
        //   ),
        // ),
        
        if (_hasPremiumPass)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ 활성화된 혜택', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('• 프리미엄 패스', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        
        ...items.map((it) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildItemCard(it))),
        
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡 안내', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• 프리미엄 패스: 시즌 패스의 프리미엄 보상을 받을 수 있습니다.', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inventoryTab() {
    final next = _nextInventoryPrice();
    final canExpand = _maxInventory < AppConstants.maxInventoryLimit;
    String nextText = next != null ? (next.$2 == 'gold' ? '${formatNumber(next.$1)}G' : '${next.$1}💎') : '최대치';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppDecorations.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('인벤토리 확장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('현재: $_maxInventory / ${AppConstants.maxInventoryLimit}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Text('다음 확장 비용: $nextText', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: canExpand ? _buyInventorySlot : null, child: const Text('1칸 확장 구매'))),
              const SizedBox(height: 6),
              const Text('규칙: 10→15는 골드, 15→20은 다이아로만 확장됩니다.', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  void _close() {
    Navigator.pop(context, {
      'gold': _gold,
      'diamond': _diamond,
      'stone': _stone,
      'battleCount': _battleCount,
      'battleRefillCount': _battleRefillCount,
      'maxInventory': _maxInventory,
      'hasPremiumPass': _hasPremiumPass,
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('상점'),
          backgroundColor: const Color(0xFF1a1a2e),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _close),
          bottom: TabBar(
            controller: _tab,
            isScrollable: true,
            tabs: const [
              Tab(text: '⭐ 특별'),
              Tab(text: '💎 다이아'),
              Tab(text: '💰 골드'),
              Tab(text: '🪨 강화석'),
              Tab(text: '⚔️ 배틀'),
              Tab(text: '📦 인벤'),
            ],
          ),
          actions: [IconButton(onPressed: _close, icon: const Icon(Icons.check), tooltip: '적용하고 닫기')],
        ),
        body: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.backgroundDark, AppColors.background]),
            ),
            child: Column(
              children: [
                Padding(padding: const EdgeInsets.all(12), child: _moneyBar()),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _specialTab(),
                      _list('diamond_purchase'),
                      _list('gold_purchase'),
                      _list('enhance_stone'),
                      _list('battle'),
                      _inventoryTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
