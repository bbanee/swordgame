import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/shop.dart';
import '../services/purchase_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class ShopScreen extends StatefulWidget {
  static const _baseAsset = 'assets/images/home/season1_shop_scene_body_v3.png';
  static const _itemFrameAsset =
      'assets/images/home/season1_shop_item_frame_v1.png';
  static const _baseWidth = 941.0;
  static const _baseHeight = 1671.0;

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

class _ShopScreenState extends State<ShopScreen> {
  late int _gold;
  late int _diamond;
  late int _stone;
  late int _battleCount;
  late int _battleRefillCount;
  late int _maxInventory;
  late bool _hasPremiumPass;
  bool _isPurchasing = false;
  int _categoryIndex = 0;

  final _purchaseService = PurchaseService();

  static const _categories = [
    ('추천', 'special'),
    ('다이아', 'diamond_purchase'),
    ('골드', 'gold_purchase'),
    ('강화석', 'enhance_stone'),
    ('배틀', 'battle'),
    ('인벤', 'inventory'),
  ];

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
    _purchaseService.onPurchaseComplete = _onPurchaseComplete;
    _purchaseService.onPurchaseError = _onPurchaseError;
    _purchaseService.onPurchasePending = () => _toast('결제 처리 중...');
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
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _ShopLayout(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            return ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      ShopScreen._baseAsset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  ..._buildOverlays(layout),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildOverlays(_ShopLayout layout) {
    return [
      _tap(layout, _ShopRects.backButton, _close),
      _box(
        layout,
        _ShopRects.diamond,
        _valueText(layout, formatGold(_diamond)),
      ),
      _box(layout, _ShopRects.gold, _valueText(layout, formatGold(_gold))),
      _box(layout, _ShopRects.stone, _valueText(layout, formatGold(_stone))),
      _box(layout, _ShopRects.battle, _valueText(layout, '$_battleCount')),
      for (var i = 0; i < _categories.length; i++) ...[
        _box(
          layout,
          _ShopRects.tabLabels[i],
          _tabText(layout, _categories[i].$1, i == _categoryIndex),
        ),
        _tap(
          layout,
          _ShopRects.tabs[i],
          () => setState(() => _categoryIndex = i),
        ),
      ],
      _box(layout, _ShopRects.list, _buildItemList(layout)),
    ];
  }

  Widget _buildItemList(_ShopLayout layout) {
    final category = _categories[_categoryIndex].$2;
    if (category == 'inventory') {
      return _inventoryExpansion(layout);
    }
    final items = category == 'special'
        ? getSpecialItems()
        : getShopItemsByCategory(category);

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        layout.u(14),
        layout.u(24),
        layout.u(14),
        layout.u(24),
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _itemRow(layout, items[i]),
    );
  }

  Widget _itemRow(_ShopLayout layout, ShopItem item) {
    final alreadyPurchased = item.id == 'premium_pass' && _hasPremiumPass;
    return Padding(
      padding: EdgeInsets.only(bottom: layout.u(16)),
      child: SizedBox(
        height: layout.u(184),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sx = constraints.maxWidth / 850.0;
            final sy = constraints.maxHeight / 184.0;
            Rect r(Rect rect) => Rect.fromLTWH(
              rect.left * sx,
              rect.top * sy,
              rect.width * sx,
              rect.height * sy,
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    ShopScreen._itemFrameAsset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Positioned.fromRect(
                  rect: r(_ShopItemRects.icon),
                  child: Center(
                    child: Icon(
                      _itemIcon(item),
                      color: item.isSpecial
                          ? Colors.purpleAccent
                          : Colors.amber,
                      size: layout.u(58),
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: r(_ShopItemRects.name),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _plainText(
                      layout,
                      item.name,
                      25,
                      color: alreadyPurchased ? Colors.grey : Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: r(_ShopItemRects.description),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _plainText(
                      layout,
                      item.description,
                      17,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: r(_ShopItemRects.price),
                  child: _fitText(layout, _priceText(item), 20),
                ),
                Positioned.fromRect(
                  rect: r(_ShopItemRects.buyButton),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: alreadyPurchased || _isPurchasing
                        ? null
                        : () => _buy(item),
                    child: _fitText(
                      layout,
                      alreadyPurchased
                          ? '구매 완료'
                          : (_isPurchasing ? '처리 중' : '구매'),
                      24,
                      color: alreadyPurchased ? Colors.grey : Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _inventoryExpansion(_ShopLayout layout) {
    final next = _nextInventoryPrice();
    final canExpand = next != null;
    final priceText = next == null
        ? '최대치'
        : next.$2 == 'gold'
        ? '${formatGold(next.$1)}G'
        : '${next.$1} 다이아';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.u(48),
        layout.u(70),
        layout.u(48),
        layout.u(0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _plainText(layout, '인벤토리 확장', 32, fontWeight: FontWeight.w900),
          SizedBox(height: layout.u(18)),
          _plainText(
            layout,
            '현재 $_maxInventory / ${AppConstants.maxInventoryLimit}칸',
            24,
            color: Colors.white70,
          ),
          SizedBox(height: layout.u(12)),
          _plainText(layout, '다음 확장 비용: $priceText', 24, color: Colors.amber),
          SizedBox(height: layout.u(36)),
          GestureDetector(
            onTap: canExpand ? _buyInventorySlot : null,
            child: SizedBox(
              width: double.infinity,
              height: layout.u(84),
              child: Center(
                child: _fitText(
                  layout,
                  canExpand ? '구매' : '최대치',
                  28,
                  color: canExpand ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      _toast('강화석 +${item.totalAmount}');
      return;
    }

    if (_diamond < item.price) {
      _toast('다이아가 부족합니다');
      return;
    }

    if (item.category == 'gold_purchase') {
      setState(() {
        _diamond -= item.price;
        _gold += item.totalAmount;
      });
      _toast('골드 +${formatGold(item.totalAmount)}');
    } else if (item.category == 'enhance_stone') {
      setState(() {
        _diamond -= item.price;
        _stone += item.totalAmount;
      });
      _toast('강화석 +${item.totalAmount}');
    } else if (item.category == 'battle') {
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
    }
  }

  void _startPurchase(ShopItem item) {
    if (_isPurchasing) {
      _toast('결제 처리 중입니다');
      return;
    }
    if (item.id == 'premium_pass' && _hasPremiumPass) {
      _toast('이미 구매한 상품입니다');
      return;
    }
    setState(() => _isPurchasing = true);
    _purchaseService.purchaseByShopId(item.id);
  }

  void _onPurchaseComplete(PurchaseResult result) {
    setState(() => _isPurchasing = false);
    if (!result.success) {
      _toast(result.errorMessage ?? '구매 실패');
      return;
    }
    setState(() {
      if (result.diamonds > 0) _diamond += result.diamonds;
      if (result.gold > 0) _gold += result.gold;
      if (result.stones > 0) _stone += result.stones;
      if (result.isPremiumPass) _hasPremiumPass = true;
    });
    _toast('구매 완료');
  }

  void _onPurchaseError(String error) {
    setState(() => _isPurchasing = false);
    _toast(error);
  }

  (int, String)? _nextInventoryPrice() {
    if (_maxInventory >= AppConstants.maxInventoryLimit) return null;
    final nextSlot = _maxInventory + 1;
    final price = inventoryPrices.firstWhere(
      (p) => p.$1 == nextSlot,
      orElse: () => (0, 0, ''),
    );
    if (price.$1 == 0) return null;
    return (price.$2, price.$3);
  }

  void _buyInventorySlot() {
    final next = _nextInventoryPrice();
    if (next == null) {
      _toast('최대치입니다');
      return;
    }
    if (next.$2 == 'gold' && _gold < next.$1) {
      _toast('골드가 부족합니다');
      return;
    }
    if (next.$2 == 'diamond' && _diamond < next.$1) {
      _toast('다이아가 부족합니다');
      return;
    }
    setState(() {
      if (next.$2 == 'gold') _gold -= next.$1;
      if (next.$2 == 'diamond') _diamond -= next.$1;
      _maxInventory += 1;
    });
    _toast('인벤토리 +1');
  }

  String _priceText(ShopItem item) {
    if (item.priceType == 'cash') return '${formatNumber(item.price)}원';
    if (item.priceType == 'gold') return '${formatGold(item.price)}G';
    return '${item.price} 다이아';
  }

  IconData _itemIcon(ShopItem item) {
    if (item.category == 'diamond_purchase') return Icons.diamond;
    if (item.category == 'gold_purchase') return Icons.monetization_on;
    if (item.category == 'enhance_stone') return Icons.auto_awesome;
    if (item.category == 'battle') return Icons.sports_mma;
    return Icons.workspace_premium;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _valueText(_ShopLayout layout, String text) {
    return _fitText(layout, text, 22, fontWeight: FontWeight.w900);
  }

  Widget _tabText(_ShopLayout layout, String text, bool active) {
    return _fitText(
      layout,
      text,
      24,
      color: active ? Colors.amber : Colors.white,
      fontWeight: FontWeight.w900,
    );
  }

  Widget _plainText(
    _ShopLayout layout,
    String text,
    double baseSize, {
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: layout.u(baseSize),
        fontWeight: fontWeight,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
  }

  Widget _fitText(
    _ShopLayout layout,
    String text,
    double baseSize, {
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    final fontSize = layout.u(baseSize);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: layout.u(4)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            strutStyle: StrutStyle(
              fontSize: fontSize,
              height: 1,
              forceStrutHeight: true,
            ),
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: fontWeight,
              height: 1,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _box(_ShopLayout layout, Rect rect, Widget child) {
    return Positioned.fromRect(rect: layout.r(rect), child: child);
  }

  Widget _tap(_ShopLayout layout, Rect rect, VoidCallback onTap) {
    return _box(
      layout,
      rect,
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ShopLayout {
  final double width;
  final double height;
  late final double sx = width / ShopScreen._baseWidth;
  late final double sy = height / ShopScreen._baseHeight;
  late final double s = math.min(sx, sy);

  _ShopLayout(this.width, this.height);

  double u(double value) => value * s;

  Rect r(Rect rect) => Rect.fromLTWH(
    rect.left * sx,
    rect.top * sy,
    rect.width * sx,
    rect.height * sy,
  );
}

class _ShopRects {
  static const backButton = Rect.fromLTWH(18, 24, 84, 84);
  static const diamond = Rect.fromLTWH(100, 453, 150, 48);
  static const gold = Rect.fromLTWH(318, 453, 150, 48);
  static const stone = Rect.fromLTWH(548, 453, 138, 48);
  static const battle = Rect.fromLTWH(724, 453, 150, 48);
  static const tabs = [
    Rect.fromLTWH(29, 536, 137, 70),
    Rect.fromLTWH(177, 536, 137, 70),
    Rect.fromLTWH(321, 536, 137, 70),
    Rect.fromLTWH(469, 536, 137, 70),
    Rect.fromLTWH(617, 536, 137, 70),
    Rect.fromLTWH(763, 536, 140, 70),
  ];
  static const tabLabels = [
    Rect.fromLTWH(39, 548, 117, 46),
    Rect.fromLTWH(187, 548, 117, 46),
    Rect.fromLTWH(331, 548, 117, 46),
    Rect.fromLTWH(479, 548, 117, 46),
    Rect.fromLTWH(627, 548, 117, 46),
    Rect.fromLTWH(773, 548, 120, 46),
  ];
  static const list = Rect.fromLTWH(32, 594, 876, 970);
}

class _ShopItemRects {
  static const icon = Rect.fromLTWH(26, 20, 130, 136);
  static const name = Rect.fromLTWH(202, 42, 395, 38);
  static const description = Rect.fromLTWH(202, 83, 395, 44);
  static const price = Rect.fromLTWH(660, 28, 168, 45);
  static const buyButton = Rect.fromLTWH(612, 107, 224, 55);
}
