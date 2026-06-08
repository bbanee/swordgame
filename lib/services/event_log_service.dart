import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class EventLogService {
  static final EventLogService _instance = EventLogService._internal();
  factory EventLogService() => _instance;
  EventLogService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-northeast3',
  );

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<void> logSnapshot({
    required int gold,
    required int diamond,
    required int seasonPassLevel,
    required int ownedSwordCount,
    required String bestSwordGrade,
    required int totalEnhanceAttempts,
    required int totalEnhanceSuccess,
    required int totalDestroy,
    required int achievementCount,
  }) async {
    final uid = AuthService().uid;
    if (uid == null || uid.isEmpty) return;

    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 30)),
    );

    final payload = {
      'event': 'snapshot',
      'state': {
        'gold': gold,
        'diamond': diamond,
        'seasonPassLevel': seasonPassLevel,
        'ownedSwordCount': ownedSwordCount,
        'bestSwordGrade': bestSwordGrade,
        'enhanceStats': {
          'totalEnhanceAttempts': totalEnhanceAttempts,
          'totalEnhanceSuccess': totalEnhanceSuccess,
          'totalDestroy': totalDestroy,
        },
        'achievementCount': achievementCount,
      },
    };

    try {
      await _functions.httpsCallable('logSnapshot').call(payload);
      return;
    } catch (e) {
      debugPrint('? logSnapshot callable failed, fallback to direct write: $e');
    }

    try {
      await _db.collection('snapshots').add({
        'userId': uid,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt,
        'gold': gold,
        'diamond': diamond,
        'seasonPassLevel': seasonPassLevel,
        'ownedSwordCount': ownedSwordCount,
        'bestSwordGrade': bestSwordGrade,
        'enhanceStats': {
          'totalEnhanceAttempts': totalEnhanceAttempts,
          'totalEnhanceSuccess': totalEnhanceSuccess,
          'totalDestroy': totalDestroy,
        },
        'achievementCount': achievementCount,
      });
    } catch (e) {
      debugPrint('? snapshot log failed: $e');
    }
  }

  Future<void> logPurchase({
    required String productId,
    required bool success,
    required bool isPremiumPass,
    required int diamonds,
    required int gold,
    required int stones,
    String? price,
    String? currency,
    String? orderId,
  }) async {
    final uid = AuthService().uid;
    if (uid == null || uid.isEmpty) return;

    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 30)),
    );

    final payload = {
      'productId': productId,
      'success': success,
      'isPremiumPass': isPremiumPass,
      'diamonds': diamonds,
      'gold': gold,
      'stones': stones,
      'price': price,
      'currency': currency,
      'orderId': orderId,
      'source': 'client_event_log_service',
    };

    try {
      await _functions.httpsCallable('logPurchase').call(payload);
      return;
    } catch (e) {
      debugPrint('? logPurchase callable failed, fallback to direct write: $e');
    }

    try {
      await _db.collection('purchase_logs').add({
        'userId': uid,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt,
        'productId': productId,
        'status': success ? 'success' : 'failed',
        'platform': _platformLabel(),
        'diamonds': diamonds,
        'gold': gold,
        'stones': stones,
        'isPremiumPass': isPremiumPass,
        'orderId': orderId,
        'price': price,
        'currency': currency,
      });
    } catch (e) {
      debugPrint('? purchase log failed: $e');
    }
  }
}
