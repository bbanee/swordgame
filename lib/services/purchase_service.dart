// lib/services/purchase_service.dart
// 💎 Google Play 인앱 결제 서비스 (프로덕션 안전 버전)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 상품 ID (Google Play Console에서 설정한 것과 동일해야 함)
class ProductIds {
  // 소모성 상품 (다이아몬드)
  static const String diamond100 = 'diamond_100';      // ₩1,100
  static const String diamond500 = 'diamond_500';      // ₩5,500
  static const String diamond1200 = 'diamond_1200';    // ₩11,000
  static const String diamond3000 = 'diamond_3000';    // ₩22,000
  static const String diamond6500 = 'diamond_6500';    // ₩44,000
  
  // ✅ 프리미엄 패스 (소모성으로 처리 → Google 계정이 아닌 Firebase 계정별 관리)
  static const String premiumPass = 'premium_pass';    // 프리미엄 패스 (₩11,000)
  
  // ✅ 소모성 상품 목록 (프리미엄 패스 포함!)
  static const List<String> consumables = [
    diamond100,
    diamond500,
    diamond1200,
    diamond3000,
    diamond6500,
    premiumPass,  // ✅ 소모성으로 전환 → 계정별 독립 관리
  ];
  
  // 비소모성 상품 목록 (현재 없음)
  static const List<String> nonConsumables = [];
  
  // 전체 상품 목록
  static List<String> get all => [...consumables, ...nonConsumables];
  
  // shop.dart의 id와 매핑
  static String? fromShopId(String shopId) {
    switch (shopId) {
      case 'dia_1': return diamond100;
      case 'dia_2': return diamond500;
      case 'dia_3': return diamond1200;
      case 'dia_4': return diamond3000;
      case 'dia_5': return diamond6500;
      case 'premium_pass': return premiumPass;
      default: return null;
    }
  }
}

/// 구매 결과
class PurchaseResult {
  final bool success;
  final String productId;
  final int diamonds;
  final int gold;
  final int stones;
  final bool isPremiumPass;
  final String? errorMessage;
  
  PurchaseResult({
    required this.success,
    required this.productId,
    this.diamonds = 0,
    this.gold = 0,
    this.stones = 0,
    this.isPremiumPass = false,
    this.errorMessage,
  });
}

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  
  bool _isAvailable = false;
  bool _isInitialized = false;
  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  // ✅ 중복 구매 방지를 위한 처리된 구매 ID 저장
  Set<String> _processedPurchaseIds = {};
  static const String _keyProcessedPurchases = 'processed_purchase_ids';
  
  // 구매 완료 콜백
  Function(PurchaseResult result)? onPurchaseComplete;
  Function(String error)? onPurchaseError;
  Function()? onPurchasePending;
  
  // 로컬 저장 키
  static const String _keyRemoveAds = 'purchase_remove_ads';
  static const String _keyPremiumPass = 'purchase_premium_pass';
  
  bool get isAvailable => _isAvailable;
  bool get isInitialized => _isInitialized;
  List<ProductDetails> get products => _products;

  // =====================================================
  // 초기화
  // =====================================================
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isAvailable = await _iap.isAvailable();
    
    if (!_isAvailable) {
      debugPrint('❌ 인앱 결제를 사용할 수 없습니다');
      _isInitialized = true;
      return;
    }
    
    // ✅ 처리된 구매 ID 로드 (중복 방지)
    await _loadProcessedPurchaseIds();
    
    // 구매 스트림 구독
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('❌ 구매 스트림 오류: $error');
        onPurchaseError?.call('결제 처리 중 오류가 발생했습니다');
      },
    );
    
    // ✅ 미소비 구매 처리 (앱 시작 시)
    await _consumePendingPurchases();
    
    // 상품 정보 로드
    await loadProducts();
    
    _isInitialized = true;
    debugPrint('✅ PurchaseService 초기화 완료 (${_products.length}개 상품)');
  }
  
  // =====================================================
  // ✅ 중복 구매 방지: 처리된 구매 ID 관리
  // =====================================================
  
  Future<void> _loadProcessedPurchaseIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? savedIds = prefs.getStringList(_keyProcessedPurchases);
      if (savedIds != null) {
        _processedPurchaseIds = savedIds.toSet();
        debugPrint('📋 저장된 구매 ID ${_processedPurchaseIds.length}개 로드');
      }
    } catch (e) {
      debugPrint('❌ 구매 ID 로드 오류: $e');
    }
  }
  
  Future<void> _saveProcessedPurchaseId(String purchaseId) async {
    try {
      _processedPurchaseIds.add(purchaseId);
      
      // 오래된 ID는 정리 (최근 100개만 유지)
      if (_processedPurchaseIds.length > 100) {
        final List<String> list = _processedPurchaseIds.toList();
        _processedPurchaseIds = list.sublist(list.length - 100).toSet();
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyProcessedPurchases, _processedPurchaseIds.toList());
      debugPrint('💾 구매 ID 저장: $purchaseId');
    } catch (e) {
      debugPrint('❌ 구매 ID 저장 오류: $e');
    }
  }
  
  bool _isAlreadyProcessed(String? purchaseId) {
    if (purchaseId == null || purchaseId.isEmpty) return false;
    return _processedPurchaseIds.contains(purchaseId);
  }
  
  // =====================================================
  // ✅ 미소비 구매 처리
  // =====================================================
  
  Future<void> _consumePendingPurchases() async {
    try {
      debugPrint('🔄 미소비 구매 확인 중...');
      
      // Android 전용 처리
      if (defaultTargetPlatform == TargetPlatform.android) {
        final InAppPurchaseAndroidPlatformAddition androidAddition =
            _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        
        // 미완료 구매 조회
        final QueryPurchaseDetailsResponse response = 
            await androidAddition.queryPastPurchases();
        
        if (response.error != null) {
          debugPrint('❌ 미소비 구매 조회 오류: ${response.error}');
          return;
        }
        
        debugPrint('📦 미완료 구매 ${response.pastPurchases.length}개 발견');
        
        for (final purchase in response.pastPurchases) {
          debugPrint('  - ${purchase.productID}: ${purchase.status}');
          
          // ✅ 모든 상품 소비 처리 (프리미엄 패스 포함!)
          //    → 기존 비소모성으로 구매된 premium_pass도 소비하여 Google Play에서 해제
          try {
            // 완료 처리
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
              debugPrint('✅ 미소비 구매 완료 처리: ${purchase.productID}');
            }
            
            // Android에서 소비 처리
            final consumeResult = await androidAddition.consumePurchase(purchase);
            if (consumeResult.responseCode == BillingResponse.ok) {
              debugPrint('✅ 소비 완료: ${purchase.productID}');
            } else {
              debugPrint('⚠️ 소비 실패: ${consumeResult.responseCode}');
            }
          } catch (e) {
            debugPrint('⚠️ 미소비 구매 처리 오류 (무시): $e');
          }
        }
      }
      
      debugPrint('✅ 미소비 구매 처리 완료');
    } catch (e) {
      debugPrint('❌ 미소비 구매 처리 오류: $e');
    }
  }
  
  // =====================================================
  // 상품 로드
  // =====================================================
  
  Future<void> loadProducts() async {
    if (!_isAvailable) return;
    
    try {
      final response = await _iap.queryProductDetails(ProductIds.all.toSet());
      
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ 찾을 수 없는 상품: ${response.notFoundIDs}');
      }
      
      if (response.error != null) {
        debugPrint('❌ 상품 로드 오류: ${response.error}');
      }
      
      _products = response.productDetails;
      debugPrint('📦 로드된 상품: ${_products.length}개');
      
      for (final p in _products) {
        debugPrint('  - ${p.id}: ${p.price}');
      }
    } catch (e) {
      debugPrint('❌ 상품 로드 실패: $e');
    }
  }
  
  // =====================================================
  // 구매
  // =====================================================
  
  /// 상점 아이템 ID로 구매
  Future<bool> purchaseByShopId(String shopId) async {
    final productId = ProductIds.fromShopId(shopId);
    if (productId == null) {
      onPurchaseError?.call('잘못된 상품입니다');
      return false;
    }
    return purchase(productId);
  }
  
  /// 상품 구매
  Future<bool> purchase(String productId) async {
    if (!_isAvailable) {
      onPurchaseError?.call('인앱 결제를 사용할 수 없습니다');
      return false;
    }
    
    if (_products.isEmpty) {
      await loadProducts();
    }
    
    ProductDetails? product;
    try {
      product = _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      onPurchaseError?.call('상품을 찾을 수 없습니다');
      return false;
    }
    
    final purchaseParam = PurchaseParam(productDetails: product);
    
    try {
      // ✅ 모든 상품을 소모성으로 구매 (프리미엄 패스 포함)
      //    → Google 계정이 아닌 Firebase 계정별로 관리
      return await _iap.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: true,  // ✅ 자동 소비 → 재구매 가능
      );
    } catch (e) {
      debugPrint('❌ 구매 오류: $e');
      onPurchaseError?.call('구매 처리 중 오류가 발생했습니다');
      return false;
    }
  }
  
  // =====================================================
  // 구매 상태 처리 (프로덕션 안전 버전!)
  // =====================================================
  
  void _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      debugPrint('📦 구매 상태: ${purchase.productID} - ${purchase.status}');
      debugPrint('   구매 ID: ${purchase.purchaseID}');
      
      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('⏳ 구매 대기 중: ${purchase.productID}');
          onPurchasePending?.call();
          break;
          
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // ✅ 중복 체크!
          if (_isAlreadyProcessed(purchase.purchaseID)) {
            debugPrint('⚠️ 이미 처리된 구매 (중복 무시): ${purchase.purchaseID}');
            // 완료 처리만 하고 보상은 지급하지 않음
            if (purchase.pendingCompletePurchase) {
              try {
                await _iap.completePurchase(purchase);
              } catch (e) {
                debugPrint('⚠️ completePurchase 오류 (무시): $e');
              }
            }
            break;
          }
          
          // ✅ 구매 완료 처리 (오류 발생해도 무시!)
          if (purchase.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchase);
              debugPrint('✅ completePurchase 완료: ${purchase.productID}');
            } catch (e) {
              // autoConsume: true면 이미 소비됨 → itemNotOwned 오류 발생 가능
              // 하지만 구매 자체는 성공이므로 무시하고 보상 지급!
              debugPrint('⚠️ completePurchase 오류 (무시): $e');
            }
          }
          
          // ✅ 구매 ID 저장 (중복 방지)
          if (purchase.purchaseID != null && purchase.purchaseID!.isNotEmpty) {
            await _saveProcessedPurchaseId(purchase.purchaseID!);
          }
          
          // ✅ 보상 지급! (restored면 로컬 저장 안 함)
          final isRestored = purchase.status == PurchaseStatus.restored;
          _handleSuccessfulPurchase(purchase, isRestored: isRestored);
          break;
          
        case PurchaseStatus.error:
          debugPrint('❌ 구매 오류: ${purchase.error}');
          onPurchaseError?.call(purchase.error?.message ?? '구매 중 오류가 발생했습니다');
          break;
          
        case PurchaseStatus.canceled:
          debugPrint('🚫 구매 취소: ${purchase.productID}');
          onPurchaseError?.call('구매가 취소되었습니다');
          break;
      }
    }
  }
  
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase, {bool isRestored = false}) async {
    debugPrint('✅ 구매 성공! 보상 지급: ${purchase.productID} (복원: $isRestored)');

    // 보상 결정
    final result = _getRewardForProduct(purchase.productID);

    // ✅ 신규 구매일 때만 로컬에 저장 (복원 시에는 저장 안 함 - 계정별 분리를 위해)
    // 복원된 구매는 Firestore에서 해당 계정의 hasPremiumPass를 확인해야 함
    if (result.isPremiumPass && !isRestored) {
      await _savePremiumPass(true);
    }

    // ✅ 복원된 구매는 콜백을 호출하지 않음 (계정별 분리)
    if (!isRestored) {
      onPurchaseComplete?.call(result);
    }
  }
  
  PurchaseResult _getRewardForProduct(String productId) {
    switch (productId) {
      case ProductIds.diamond100:
        return PurchaseResult(success: true, productId: productId, diamonds: 100);
        
      case ProductIds.diamond500:
        return PurchaseResult(success: true, productId: productId, diamonds: 550); // +10% 보너스
        
      case ProductIds.diamond1200:
        return PurchaseResult(success: true, productId: productId, diamonds: 1400); // +16% 보너스
        
      case ProductIds.diamond3000:
        return PurchaseResult(success: true, productId: productId, diamonds: 3600); // +20% 보너스
        
      case ProductIds.diamond6500:
        return PurchaseResult(success: true, productId: productId, diamonds: 8000); // +23% 보너스
        
      case ProductIds.premiumPass:
        return PurchaseResult(success: true, productId: productId, isPremiumPass: true);
        
      default:
        return PurchaseResult(
          success: false, 
          productId: productId, 
          errorMessage: '알 수 없는 상품',
        );
    }
  }
  
  // =====================================================
  // 복원
  // =====================================================
  
  /// 구매 복원 (비소모성 상품)
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      onPurchaseError?.call('결제 서비스를 사용할 수 없습니다');
      return;
    }
    
    try {
      await _iap.restorePurchases();
      debugPrint('✅ 구매 복원 요청 완료');
    } catch (e) {
      debugPrint('❌ 구매 복원 실패: $e');
      onPurchaseError?.call('구매 복원 중 오류가 발생했습니다');
    }
  }
  
  // =====================================================
  // 로컬 저장 (비소모성 상품 상태)
  // =====================================================
  
  Future<void> _saveRemoveAds(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRemoveAds, value);
    debugPrint('💾 광고 제거 저장: $value');
  }
  
  Future<void> _savePremiumPass(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPremiumPass, value);
    debugPrint('💾 프리미엄 패스 저장: $value');
  }
  
  Future<bool> hasRemovedAds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRemoveAds) ?? false;
  }
  
  Future<bool> hasPremiumPass() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPremiumPass) ?? false;
  }
  
  // =====================================================
  // 유틸리티
  // =====================================================
  
  /// 상품 가격 가져오기
  String? getPrice(String productId) {
    try {
      final product = _products.firstWhere((p) => p.id == productId);
      return product.price;
    } catch (e) {
      return null;
    }
  }
  
  /// 상점 ID로 가격 가져오기
  String? getPriceByShopId(String shopId) {
    final productId = ProductIds.fromShopId(shopId);
    if (productId == null) return null;
    return getPrice(productId);
  }
  
  /// 상품 정보 가져오기
  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }
  
  /// 리소스 정리
  void dispose() {
    _subscription?.cancel();
  }

  /// 로그아웃 시 로컬 구매 상태 초기화
  Future<void> resetForLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRemoveAds);
    await prefs.remove(_keyPremiumPass);
    debugPrint('🔄 로그아웃: 구매 상태 초기화 완료');
  }
}
