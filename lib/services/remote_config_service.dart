import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? const Duration(minutes: 1)
            : const Duration(hours: 1),
      ),
    );

    await _remoteConfig.setDefaults(const {
      'notice_active': false,
      'notice_id': '',
      'notice_title': '업데이트 안내',
      'notice_body': '',
      'notice_remind_hours': 12,
    });

    await refresh();
    _initialized = true;
  }

  Future<void> refresh() async {
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('⚠️ Remote Config fetch 실패(기본값 사용): $e');
    }
  }

  bool get noticeActive => _remoteConfig.getBool('notice_active');
  String get noticeId => _remoteConfig.getString('notice_id');
  String get noticeTitle => _remoteConfig.getString('notice_title');
  String get noticeBody => _remoteConfig.getString('notice_body');
  int get noticeRemindHours {
    final value = _remoteConfig.getInt('notice_remind_hours');
    return value <= 0 ? 12 : value;
  }
}
