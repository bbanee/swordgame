
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../services/friend_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'game_screen.dart';

class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key});

  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen>
    with TickerProviderStateMixin {
  // 애니메이션
  late AnimationController _swordController;
  late Animation<double> _swordFloat;
  late Animation<double> _swordGlow;
  late AnimationController _bgController;

  bool _showNicknameInput = false;
  final _nicknameController = TextEditingController();
  String? _errorMessage;
  String? _existingNickname;
  String? _existingUserId;
  bool _isLoading = true;
  bool _isNewGame = false;
  bool _isProcessing = false;

  // 배경 파티클
  late List<_Particle> _particles;
  final _rng = Random();

  @override
  void initState() {
    super.initState();

    _particles = List.generate(30, (_) => _Particle(
      x: _rng.nextDouble(), y: _rng.nextDouble(),
      speed: 0.1 + _rng.nextDouble() * 0.3,
      size: 1.0 + _rng.nextDouble() * 2.0,
      opacity: 0.1 + _rng.nextDouble() * 0.3,
    ));

    _bgController = AnimationController(
      duration: const Duration(seconds: 8), vsync: this,
    )..repeat();

    _swordController = AnimationController(
      duration: const Duration(milliseconds: 2500), vsync: this,
    )..repeat(reverse: true);

    _swordFloat = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _swordController, curve: Curves.easeInOut),
    );
    _swordGlow = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _swordController, curve: Curves.easeInOut),
    );

    _loadExistingData();
  }

  // =====================================================
  // 📦 데이터 로딩 (기존 로직 유지)
  // =====================================================

  Future<void> _loadExistingData() async {
    try {
      String? authUid = AuthService().uid;

      if (authUid == null || authUid.isEmpty) {
        debugPrint('⏳ Firebase Auth 복원 대기 중...');
        for (int i = 0; i < 30; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted) return;
          authUid = AuthService().uid;
          if (authUid != null && authUid.isNotEmpty) {
            debugPrint('✅ Firebase Auth 복원 완료: $authUid');
            break;
          }
        }
      }

      if (!mounted) return;

      if (authUid == null || authUid.isEmpty) {
        debugPrint('⚠️ Firebase Auth uid 없음 - 로그인 필요');
        setState(() { _existingNickname = null; _existingUserId = null; _isLoading = false; });
        return;
      }

      await StorageService().init();
      if (!mounted) return;
      
      final nickname = StorageService().nickname;

      setState(() {
        _existingNickname = (nickname != null && nickname.isNotEmpty) ? nickname : null;
        _existingUserId = authUid;
        _isLoading = false;
      });

      debugPrint('📱 기존 데이터 로드: nickname=$_existingNickname, uid=$_existingUserId');
    } catch (e) {
      debugPrint('❌ 데이터 로드 실패: $e');
      if (!mounted) return;
      setState(() { _existingNickname = null; _existingUserId = null; _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _swordController.dispose();
    _bgController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  String _getAuthUid() {
    final uid = AuthService().uid;
    if (uid == null || uid.isEmpty) {
      debugPrint('⚠️ Firebase Auth uid가 없음!');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'temp_$timestamp';
    }
    debugPrint('✅ Firebase Auth uid: $uid');
    return uid;
  }

  // =====================================================
  // 🎮 게임 로직 (기존 유지)
  // =====================================================

  void _confirmNewGame() {
    if (_existingNickname == null) {
      setState(() { _showNicknameInput = true; _isNewGame = true; });
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('새로 시작', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('정말 새로 시작하시겠습니까?',
              style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚠️ 다음 데이터가 모두 삭제됩니다:',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 8),
                  Text('• 보유 검 및 강화 상태', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('• 골드, 다이아, 강화석', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('• 업적, 칭호, 도감', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('• 시즌패스 진행도', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('• 배틀 기록 및 통계', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('이 작업은 되돌릴 수 없습니다.',
              style: TextStyle(color: Colors.orange, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _showNicknameInput = true;
                _isNewGame = true;
                _nicknameController.clear();
                _errorMessage = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('새로 시작', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _validateAndStart() async {
    if (_isProcessing) return;

    final nickname = _nicknameController.text.trim();

    if (nickname.isEmpty) { setState(() => _errorMessage = '닉네임을 입력해주세요'); return; }
    if (nickname.length < 2) { setState(() => _errorMessage = '2자 이상 입력해주세요'); return; }
    if (nickname.length > 10) { setState(() => _errorMessage = '10자 이하로 입력해주세요'); return; }

    final validPattern = RegExp(r'^[가-힣a-zA-Z0-9]+$');
    if (!validPattern.hasMatch(nickname)) {
      setState(() => _errorMessage = '한글, 영문, 숫자만 사용 가능합니다'); return;
    }

    final bannedWords = ['관리자', 'admin', 'gm', 'GM', '운영자'];
    if (bannedWords.any((word) => nickname.toLowerCase().contains(word.toLowerCase()))) {
      setState(() => _errorMessage = '사용할 수 없는 닉네임입니다'); return;
    }

    setState(() => _isProcessing = true);

    try {
      final isAvailable = await FriendService().isNicknameAvailable(nickname);
      if (!mounted) return;
      if (!isAvailable) {
        setState(() { _isProcessing = false; _errorMessage = '이미 사용 중인 닉네임입니다'; });
        return;
      }
    } catch (e) {
      debugPrint('⚠️ 닉네임 중복 체크 실패: $e');
      if (!mounted) return;
    }

    if (_isNewGame) {
      _resetAndStartNewGame(nickname);
    } else {
      _updateNicknameAndStart(nickname);
    }
  }

  Future<void> _resetAndStartNewGame(String nickname) async {
    try {
      final newUserId = _getAuthUid();
      await StorageService().deleteAllUserData(newUserId);
      await StorageService().clearAllData();
      await StorageService().init();

      StorageService().playerId = newUserId;
      StorageService().nickname = nickname;
      StorageService().gold = AppConstants.startingGold;
      StorageService().diamond = AppConstants.startingDiamond;
      StorageService().maxInventory = AppConstants.startingInventory;
      StorageService().battleCount = AppConstants.dailyBattleCount;
      StorageService().battleRefillCount = 0;
      StorageService().attendanceStreak = 0;
      StorageService().seasonPassLevel = 1;
      StorageService().seasonPassExp = 0;
      StorageService().lastBattleReset = DateTime.now();
      StorageService().inventory = [];
      StorageService().battleRecords = [];

      await StorageService().saveToCloud();
      debugPrint('✅ 새 게임 시작 완료: $nickname ($newUserId)');
      _navigateToGame(nickname, newUserId);
    } catch (e) {
      debugPrint('❌ 새 게임 시작 실패: $e');
      if (!mounted) return;
      setState(() { _isProcessing = false; _errorMessage = '초기화 중 오류가 발생했습니다. 다시 시도해주세요.'; });
    }
  }

  Future<void> _updateNicknameAndStart(String nickname) async {
    try {
      String userId = _existingUserId ?? _getAuthUid();
      if (_existingUserId == null) StorageService().playerId = userId;
      StorageService().nickname = nickname;
      await StorageService().saveToCloud();
      _navigateToGame(nickname, userId);
    } catch (e) {
      if (!mounted) return;
      setState(() { _isProcessing = false; _errorMessage = '저장 중 오류가 발생했습니다. 다시 시도해주세요.'; });
    }
  }

  void _continueGame() {
    if (_isProcessing) return;
    if (_existingNickname == null) return;
    setState(() => _isProcessing = true);
    String userId = _existingUserId ?? _getAuthUid();
    if (_existingUserId == null) StorageService().playerId = userId;
    _navigateToGame(_existingNickname!, userId);
  }

  void _navigateToGame(String nickname, String userId) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => GameScreen(nickname: nickname, userId: userId),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // =====================================================
  // 🏗️ BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      body: Stack(
        children: [
          // 배경 그라데이션
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1.5,
                colors: [Color(0xFF2a1a3e), Color(0xFF12122a), Color(0xFF0a0a1a)],
              ),
            ),
          ),

          // 파티클
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => CustomPaint(
              size: Size.infinite,
              painter: _ParticlePainter(
                particles: _particles,
                progress: _bgController.value,
                tint: Colors.amber.withOpacity(0.3),
              ),
            ),
          ),

          // 콘텐츠
          SafeArea(
            child: _isLoading
                ? _buildLoadingScreen()
                : Center(
                    child: SingleChildScrollView(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _showNicknameInput ? _buildNicknameInput() : _buildMainMenu(),
                      ),
                    ),
                  ),
          ),

          // 처리 중 오버레이
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.amber)),
            ),
        ],
      ),
    );
  }

  // =====================================================
  // ⏳ 로딩 화면
  // =====================================================
  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _swordController,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _swordFloat.value * 0.5),
              child: SizedBox(
                width: 100, height: 100,
                child: Image.asset(
                  'assets/images/swords/sword_immortal.webp',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text('⚔️', style: TextStyle(fontSize: 60)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
          const SizedBox(height: 16),
          Text('로딩 중...', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
        ],
      ),
    );
  }

  // =====================================================
  // 🎮 메인 메뉴 (계속하기 / 새로 시작)
  // =====================================================
  Widget _buildMainMenu() {
    return Padding(
      key: const ValueKey('menu'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 검 히어로
          _buildSwordHero(),
          const SizedBox(height: 24),

          // 타이틀
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.amber, Colors.orange],
            ).createShader(bounds),
            child: const Text(
              '최강 검 키우기',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 6),
          Text(AppConstants.appVersion, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 48),

          // 계속하기 버튼
          if (_existingNickname != null) ...[
            _buildMenuCard(
              icon: Icons.play_arrow_rounded,
              title: '계속하기',
              subtitle: '$_existingNickname님의 모험',
              gradientColors: [const Color(0xFF1b5e20), const Color(0xFF2e7d32)],
              glowColor: Colors.green,
              swordAsset: 'assets/images/swords/sword_immortal.webp',
              onTap: _continueGame,
            ),
            const SizedBox(height: 16),
          ],

          // 새로 시작 / 게임 시작 버튼
          _buildMenuCard(
            icon: _existingNickname != null ? Icons.refresh_rounded : Icons.star_rounded,
            title: _existingNickname != null ? '새로 시작' : '게임 시작',
            subtitle: _existingNickname != null ? '모든 데이터가 초기화됩니다' : '새로운 모험을 떠나세요',
            gradientColors: _existingNickname != null
                ? [const Color(0xFF4a1a1a), const Color(0xFF6a2020)]
                : [const Color(0xFF1a237e), const Color(0xFF283593)],
            glowColor: _existingNickname != null ? Colors.red : Colors.indigo,
            swordAsset: _existingNickname != null
                ? 'assets/images/swords/sword_normal.webp'
                : 'assets/images/swords/sword_legend.webp',
            isDestructive: _existingNickname != null,
            onTap: _confirmNewGame,
          ),

          const SizedBox(height: 48),

          // 하단
          Text('© 2026 최강 검 키우기',
            style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
        ],
      ),
    );
  }

  // ── 검 히어로 이미지 ──
  Widget _buildSwordHero() {
    return AnimatedBuilder(
      animation: _swordController,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _swordFloat.value),
        child: Container(
          width: 150, height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.12 * _swordGlow.value),
                blurRadius: 50 * _swordGlow.value,
                spreadRadius: 15 * _swordGlow.value,
              ),
              BoxShadow(
                color: Colors.orange.withOpacity(0.08 * _swordGlow.value),
                blurRadius: 80 * _swordGlow.value,
                spreadRadius: 25 * _swordGlow.value,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/swords/sword_immortal.webp',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 70, color: Colors.amber),
          ),
        ),
      ),
    );
  }

  // ── 메뉴 카드 버튼 ──
  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required Color glowColor,
    required String swordAsset,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: _isProcessing ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: glowColor.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(color: glowColor.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // 미니 검 이미지
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.3),
                border: Border.all(color: glowColor.withOpacity(0.3)),
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    swordAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(icon, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(
                    color: isDestructive ? Colors.red[200] : Colors.white70,
                    fontSize: 12)),
                ],
              ),
            ),

            // 화살표
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.6), size: 14),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ✏️ 닉네임 입력 화면
  // =====================================================
  Widget _buildNicknameInput() {
    return Padding(
      key: const ValueKey('nickname'),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 검 아이콘 (작게)
          AnimatedBuilder(
            animation: _swordController,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _swordFloat.value * 0.6),
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isNewGame ? Colors.green : Colors.indigo).withOpacity(0.15 * _swordGlow.value),
                      blurRadius: 30 * _swordGlow.value,
                      spreadRadius: 8 * _swordGlow.value,
                    ),
                  ],
                ),
                child: Image.asset(
                  _isNewGame
                      ? 'assets/images/swords/sword_legend.webp'
                      : 'assets/images/swords/sword_rare.webp',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text('⚔️', style: TextStyle(fontSize: 50)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 타이틀
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: _isNewGame
                  ? [Colors.green[300]!, Colors.tealAccent]
                  : [Colors.indigo[300]!, Colors.blue[300]!],
            ).createShader(bounds),
            child: Text(
              _isNewGame ? '새로운 모험 시작' : '닉네임 설정',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 6),
          Text('한글/영문/숫자 2~10자',
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 32),

          // 입력 카드
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a30).withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (_isNewGame ? Colors.green : Colors.indigo).withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: (_isNewGame ? Colors.green : Colors.indigo).withOpacity(0.05),
                  blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: Column(
              children: [
                // 입력 필드
                TextField(
                  controller: _nicknameController,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                  maxLength: 10,
                  enabled: !_isProcessing,
                  decoration: InputDecoration(
                    hintText: '닉네임 입력',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: (_isNewGame ? Colors.green : Colors.amber).withOpacity(0.6),
                        width: 1.5),
                    ),
                    prefixIcon: Icon(Icons.person, color: Colors.grey[600], size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) setState(() => _errorMessage = null);
                    setState(() {}); // 글자수 업데이트
                  },
                  onSubmitted: (_) => _validateAndStart(),
                ),
                const SizedBox(height: 6),

                // 글자 수
                Text('${_nicknameController.text.length}/10',
                  style: TextStyle(
                    color: _nicknameController.text.length > 10 ? Colors.red : Colors.white38,
                    fontSize: 11)),
                const SizedBox(height: 12),

                // 에러
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 버튼 Row
                Row(
                  children: [
                    // 뒤로
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : () => setState(() {
                            _showNicknameInput = false;
                            _errorMessage = null;
                            _nicknameController.clear();
                            _isNewGame = false;
                            _isProcessing = false;
                          }),
                          icon: Icon(Icons.arrow_back, size: 16, color: Colors.grey[500]),
                          label: Text('뒤로', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[800]!),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 시작
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isNewGame
                                  ? [Colors.green, Colors.teal]
                                  : [Colors.amber, Colors.orange],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: (_isNewGame ? Colors.green : Colors.amber).withOpacity(0.3),
                                blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _validateAndStart,
                            icon: _isProcessing
                                ? const SizedBox(width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.play_arrow, size: 20),
                            label: Text(
                              _isProcessing ? '처리 중...' : (_isNewGame ? '시작하기' : '확인'),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 새 게임 보상 안내
          if (_isNewGame) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.card_giftcard, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('시작 보상',
                        style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('5,000G + 100💎 + 시작 검',
                        style: TextStyle(color: Colors.green[200], fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================
// ✨ 배경 파티클
// =====================================================
class _Particle {
  double x, y, speed, size, opacity;
  _Particle({required this.x, required this.y, required this.speed, required this.size, required this.opacity});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color tint;
  _ParticlePainter({required this.particles, required this.progress, required this.tint});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y + progress * p.speed) % 1.0;
      final x = p.x + sin(y * pi * 2 + p.speed) * 0.015;
      final twinkle = (0.5 + sin(progress * pi * 2 + p.x * 8) * 0.5).clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(x * size.width, (1 - y) * size.height),
        p.size,
        Paint()
          ..color = tint.withOpacity(p.opacity * twinkle)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}
