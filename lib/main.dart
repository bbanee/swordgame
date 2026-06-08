import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/ad_service.dart';
import 'services/sound_service.dart';
import 'services/purchase_service.dart'; // 💎 인앱 결제
import 'services/analytics_service.dart'; // 📊 분석
import 'services/remote_config_service.dart';
import 'screens/login_screen.dart';
import 'screens/opening_screen.dart';

void main() async {
  // ✅ 수정 1: WidgetsFlutterBinding을 runZonedGuarded 바깥에서 초기화!
  //    runZonedGuarded 안에서 초기화하면 자식 Zone에 바인딩이 생성되어
  //    Firebase Auth의 Platform Channel 세션 복원이 실패할 수 있음
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 (바인딩 이후, runApp 이전)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔥 Crashlytics 설정
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // ✅ PlatformDispatcher.onError로 비동기 에러 캐치 (runZonedGuarded 대체)
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // 📊 Analytics 초기화
  await AnalyticsService().initialize();

  // 📢 Remote Config 초기화
  await RemoteConfigService().initialize();

  // 🎬 AdMob 초기화
  await AdService().initialize();

  // 💎 인앱 결제 초기화
  await PurchaseService().initialize();

  // 🔊 사운드 서비스 초기화 (실패해도 앱 실행에 영향 없음)
  try {
    await SoundService().initialize();
  } catch (e) {
    debugPrint('⚠️ SoundService 초기화 실패 (무시): $e');
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SwordGame());
}

class SwordGame extends StatelessWidget {
  const SwordGame({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '최강 검 키우기',
      debugShowCheckedModeBanner: false,
      // 📊 Analytics: 화면 전환 자동 추적
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF1a1a2e),
        fontFamily: 'Pretendard',
      ),
      home: const AuthWrapper(),
    );
  }
}

// ✅ 수정 2: StatefulWidget으로 변경하여 Stream을 캐싱
//    StatelessWidget이면 build() 호출 시마다 새 Stream이 생성되어
//    StreamBuilder가 구독을 리셋 → 인증 상태 감지 불안정
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // ✅ Stream을 한 번만 생성하여 캐싱
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = AuthService().authStateChanges;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      // ✅ Firebase Auth가 이미 세션을 복원했으면 즉시 사용
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        // ✅ initialData 없고 아직 스트림 이벤트도 없을 때만 로딩
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF1a1a2e),
            body: Center(
              child: CircularProgressIndicator(color: Colors.indigo),
            ),
          );
        }

        // 로그인됨 → 게임 화면
        if (snapshot.hasData) {
          return const OpeningScreen();
        }

        // 로그인 안됨 → 로그인 화면
        return const LoginScreen();
      },
    );
  }
}
