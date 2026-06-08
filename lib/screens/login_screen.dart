import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import 'opening_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isLoginMode = true;
  String? _errorMessage;
  bool _obscurePassword = true;

  // 애니메이션
  late AnimationController _bgController;
  late AnimationController _swordController;
  late Animation<double> _swordFloat;
  late Animation<double> _swordGlow;

  // 배경 파티클
  late List<_Particle> _particles;
  final _rng = Random();

  @override
  void initState() {
    super.initState();

    // 배경 파티클
    _particles = List.generate(
      30,
      (_) => _Particle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        speed: 0.1 + _rng.nextDouble() * 0.3,
        size: 1.0 + _rng.nextDouble() * 2.0,
        opacity: 0.1 + _rng.nextDouble() * 0.3,
      ),
    );

    // 배경 루프
    _bgController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    // 검 플로팅
    _swordController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _swordFloat = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _swordController, curve: Curves.easeInOut),
    );
    _swordGlow = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _swordController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _bgController.dispose();
    _swordController.dispose();
    super.dispose();
  }

  // ── 로직 ──

  Future<void> _submitForm() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = '이메일과 비밀번호를 입력하세요');
      return;
    }

    // ✅ 이메일 형식 검증 (회원가입 시)
    if (!_isLoginMode) {
      final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
      if (!emailRegex.hasMatch(email)) {
        setState(() => _errorMessage = '유효한 이메일 주소를 입력하세요');
        return;
      }
      if (password.length < 6) {
        setState(() => _errorMessage = '비밀번호는 6자 이상이어야 합니다');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = _isLoginMode
        ? await _authService.signInWithEmail(email: email, password: password)
        : await _authService.signUpWithEmail(email: email, password: password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      final uid = _authService.currentUser?.uid ?? '';
      AnalyticsService().setUser(uid, loginMethod: 'email');
      _goToGame();
    } else {
      setState(() => _errorMessage = result.errorMessage);
    }
  }

  Future<void> _signInAsGuest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.signInAnonymously();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      final uid = _authService.currentUser?.uid ?? '';
      AnalyticsService().setUser(uid, loginMethod: 'anonymous');
      _goToGame();
    } else {
      setState(() => _errorMessage = result.errorMessage);
    }
  }

  void _goToGame() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const OpeningScreen()));
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _errorMessage = null;
    });
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252542),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('비밀번호 재설정', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '가입한 이메일 주소를 입력하세요.\n비밀번호 재설정 링크를 보내드립니다.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '이메일',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.email, color: Colors.grey[400]),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                filled: true,
                fillColor: const Color(0xFF1a1a2e),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('이메일을 입력하세요')));
                return;
              }
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final result = await _authService.sendPasswordResetEmail(email);
              if (!mounted) return;
              setState(() => _isLoading = false);
              if (result.isSuccess) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('📧 $email로 재설정 이메일을 보냈습니다'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.errorMessage ?? '이메일 전송 실패'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('전송', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── 테마 색상 ──
  Color get _accentColor => _isLoginMode ? Colors.amber : Colors.cyanAccent;
  Color get _accentDark => _isLoginMode ? Colors.orange : Colors.cyan;
  Color get _bgTint =>
      _isLoginMode ? const Color(0xFF1a1a2e) : const Color(0xFF141430);
  String get _swordAsset => _isLoginMode
      ? 'assets/images/swords/sword_immortal.webp'
      : 'assets/images/swords/sword_legend.webp';

  // ── BUILD ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTint,
      body: Stack(
        children: [
          // 1) 배경 그라데이션
          _buildBackground(),

          // 2) 떠다니는 파티클
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => CustomPaint(
              size: Size.infinite,
              painter: _ParticlePainter(
                particles: _particles,
                progress: _bgController.value,
                tint: _accentColor.withOpacity(0.3),
              ),
            ),
          ),

          // 3) 메인 콘텐츠
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _isLoginMode
                      ? _buildLoginContent()
                      : _buildSignupContent(),
                ),
              ),
            ),
          ),

          // 4) 로딩 오버레이
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  // =====================================================
  // 🔐 로그인 화면
  // =====================================================
  Widget _buildLoginContent() {
    return Column(
      key: const ValueKey('login'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 검 이미지 히어로
        _buildSwordHero(),
        const SizedBox(height: 20),

        // 타이틀
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.amber, Colors.orange[300]!],
          ).createShader(bounds),
          child: const Text(
            '최강 검 키우기',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '전설의 검사가 되어라',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 36),

        // 입력 폼
        _buildInputField(_emailController, '이메일', Icons.email, false),
        const SizedBox(height: 14),
        _buildInputField(_passwordController, '비밀번호', Icons.lock, true),
        const SizedBox(height: 6),

        // 비밀번호 찾기
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _showForgotPasswordDialog,
            child: Text(
              '비밀번호를 잊으셨나요?',
              style: TextStyle(color: Colors.blue[300], fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // 에러
        if (_errorMessage != null) _buildErrorBox(),
        if (_errorMessage != null) const SizedBox(height: 12),

        // 로그인 버튼
        _buildPrimaryButton('로그인', Colors.amber, Colors.orange),
        const SizedBox(height: 14),

        // 전환
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '계정이 없으신가요?',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            TextButton(
              onPressed: _toggleMode,
              child: Text(
                '회원가입',
                style: TextStyle(
                  color: _accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 구분선
        _buildDivider(),
        const SizedBox(height: 16),

        // 게스트 버튼
        _buildGuestButton(),
        const SizedBox(height: 10),
        Text(
          '⚠️ 게스트 계정은 앱 삭제 시 데이터가 사라집니다',
          style: TextStyle(fontSize: 11, color: Colors.orange[300]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildPrivacyPolicyLink(),
      ],
    );
  }

  // =====================================================
  // 📝 회원가입 화면
  // =====================================================
  Widget _buildSignupContent() {
    return Column(
      key: const ValueKey('signup'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 검 이미지 (작게)
        _buildSwordHero(small: true),
        const SizedBox(height: 16),

        // 타이틀
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.cyanAccent, Colors.blue[300]!],
          ).createShader(bounds),
          child: const Text(
            '최강 검 키우기',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '새로운 모험의 시작',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 28),

        // 회원가입 카드
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1e1e3a).withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyan.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(0.05),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1,
                      color: Colors.cyanAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '회원가입',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildInputField(_emailController, '이메일', Icons.email, false),
              const SizedBox(height: 14),
              _buildInputField(
                _passwordController,
                '비밀번호 (6자 이상)',
                Icons.lock,
                true,
              ),
              const SizedBox(height: 16),

              // 에러
              if (_errorMessage != null) _buildErrorBox(),
              if (_errorMessage != null) const SizedBox(height: 12),

              // 가입 버튼
              _buildPrimaryButton('계정 만들기', Colors.cyan, Colors.blue),
              const SizedBox(height: 8),

              Text(
                '가입 시 데이터가 안전하게 저장됩니다',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 전환
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '이미 계정이 있으신가요?',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            TextButton(
              onPressed: _toggleMode,
              child: Text(
                '로그인',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 구분선
        _buildDivider(),
        const SizedBox(height: 12),

        // 게스트 버튼
        _buildGuestButton(),
        const SizedBox(height: 10),
        Text(
          '⚠️ 게스트 계정은 앱 삭제 시 데이터가 사라집니다',
          style: TextStyle(fontSize: 11, color: Colors.orange[300]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildPrivacyPolicyLink(),
      ],
    );
  }

  // =====================================================
  // 🗡️ 검 이미지 히어로
  // =====================================================
  Widget _buildSwordHero({bool small = false}) {
    final size = small ? 100.0 : 140.0;

    return AnimatedBuilder(
      animation: _swordController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _swordFloat.value),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withOpacity(0.15 * _swordGlow.value),
                  blurRadius: 40 * _swordGlow.value,
                  spreadRadius: 10 * _swordGlow.value,
                ),
                BoxShadow(
                  color: _accentDark.withOpacity(0.1 * _swordGlow.value),
                  blurRadius: 60 * _swordGlow.value,
                  spreadRadius: 20 * _swordGlow.value,
                ),
              ],
            ),
            child: Image.asset(
              _swordAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.shield, size: size * 0.5, color: _accentColor),
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // 🎨 공통 위젯들
  // =====================================================

  Widget _buildInputField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isPassword,
  ) {
    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      keyboardType: isPassword ? null : TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[600],
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: _accentColor.withOpacity(0.6),
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFF1a1a30),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String text, Color color1, Color color2) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color1, color2]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color1.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _signInAsGuest,
        icon: Icon(Icons.person_outline, color: Colors.grey[400], size: 20),
        label: Text(
          '게스트로 시작하기',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey[700]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[800])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '또는',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[800])),
      ],
    );
  }

  Widget _buildPrivacyPolicyLink() {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(
          'https://sites.google.com/view/sword-game-privacy',
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        '개인정보처리방침',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          decoration: TextDecoration.underline,
          decorationColor: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.5,
          colors: [
            _isLoginMode ? const Color(0xFF2a1a3e) : const Color(0xFF1a2a3e),
            _bgTint,
            const Color(0xFF0a0a1a),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// ✨ 배경 파티클
// =====================================================

class _Particle {
  double x, y, speed, size, opacity;
  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color tint;
  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.tint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y + progress * p.speed) % 1.0;
      final x = p.x + sin(y * pi * 2 + p.speed) * 0.015;
      final twinkle = (0.5 + sin(progress * pi * 2 + p.x * 8) * 0.5).clamp(
        0.0,
        1.0,
      );

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
