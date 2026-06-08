import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../enums/element.dart';
import '../../enums/sword_grade.dart';
import '../../models/owned_sword.dart';
import '../../services/ad_service.dart';
import '../../services/sound_service.dart';
import '../../widgets/sword_image_widget.dart';
import 'brick_breaker_game.dart';
import 'minigame_models.dart';

class BrickBreakerScreen extends StatefulWidget {
  final List<OwnedSword> inventory;
  final int gold;
  final int diamond;
  final int enhanceStone;

  const BrickBreakerScreen({
    super.key,
    required this.inventory,
    required this.gold,
    required this.diamond,
    required this.enhanceStone,
  });

  @override
  State<BrickBreakerScreen> createState() => _BrickBreakerScreenState();
}

class _BrickBreakerScreenState extends State<BrickBreakerScreen> {
  static const SwordGrade maxAllowedGrade = SwordGrade.unique;
  static const int _freePlayLimit = 5;
  static const String _prefKeyCount = 'minigame_play_count';
  static const String _prefKeyDate = 'minigame_play_date';

  int _playsUsedToday = 0;
  bool _playsLoaded = false;
  OwnedSword? _selectedSword;
  BrickBreakerGame? _game;
  Timer? _timer;
  bool _rewardDialogOpen = false;
  int _totalGoldEarned = 0;
  int _totalStonesEarned = 0;

  int get _remainingFreePlays =>
      (_freePlayLimit - _playsUsedToday).clamp(0, _freePlayLimit);
  bool get _hasFreePlays => _remainingFreePlays > 0;

  List<OwnedSword> get _playableSwords =>
      widget.inventory
          .where((sword) => sword.data.grade.index <= maxAllowedGrade.index)
          .toList()
        ..sort((a, b) => b.totalPower.compareTo(a.totalPower));

  Map<String, int> get _exitResult => {
    'gold': widget.gold + _totalGoldEarned,
    'diamond': widget.diamond,
    'enhanceStone': widget.enhanceStone + _totalStonesEarned,
  };

  @override
  void initState() {
    super.initState();
    _loadDailyPlays();
    SoundService().playMinigameBgm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    SoundService().stopBgm();
    super.dispose();
  }

  Future<void> _loadDailyPlays() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (prefs.getString(_prefKeyDate) != today) {
      await prefs.setString(_prefKeyDate, today);
      await prefs.setInt(_prefKeyCount, 0);
      if (mounted) {
        setState(() {
          _playsUsedToday = 0;
          _playsLoaded = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _playsUsedToday = prefs.getInt(_prefKeyCount) ?? 0;
        _playsLoaded = true;
      });
    }
  }

  Future<void> _useFreePlay() async {
    _playsUsedToday++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyCount, _playsUsedToday);
    if (mounted) setState(() {});
  }

  void _startGame() {
    if (_selectedSword == null) return;
    if (!_hasFreePlays) {
      _showNoPlaysDialog();
      return;
    }
    _useFreePlay();
    _doStartGame();
  }

  void _doStartGame() {
    _timer?.cancel();
    final game = BrickBreakerGame(sword: _selectedSword!);
    game.onShoot = SoundService().playSwordShoot;
    game.start();
    setState(() => _game = game);

    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      _game?.tick();
      if (_game?.needsRewardChoice == true && !_rewardDialogOpen) {
        _showRewardChoiceDialog();
      }
      if (_game?.isGameOver == true) {
        _timer?.cancel();
        _showResultDialog();
      }
    });
  }

  void _watchAdForPlay() {
    if (_selectedSword == null) return;
    AdService().showRewardedAd(
      type: AdRewardType.minigamePlay,
      onRewarded: _doStartGame,
      onError: (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      },
    );
  }

  void _showNoPlaysDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'No free plays',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Watch an ad to play again.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _watchAdForPlay();
            },
            child: const Text('Watch ad'),
          ),
        ],
      ),
    );
  }

  void _showRewardChoiceDialog() {
    final game = _game;
    if (game == null || !game.needsRewardChoice || !mounted) return;
    _rewardDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Wave reward', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: game.pendingRewardChoices.map((reward) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: reward.color.withValues(alpha: 0.18),
                    foregroundColor: reward.color,
                    side: BorderSide(color: reward.color),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    game.chooseWaveReward(reward);
                  },
                  child: Text('${reward.label}  ${reward.description}'),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ).then((_) => _rewardDialogOpen = false);
  }

  void _showResultDialog() {
    final result = _game?.result;
    if (result == null) return;
    _totalGoldEarned += result.goldEarned;
    _totalStonesEarned += result.stonesEarned;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Game over', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _resultRow('Wave', '${result.wavesCleared}'),
            _resultRow('Bricks', '${result.bricksDestroyed}'),
            _resultRow('Gold', '+${result.goldEarned}'),
            if (result.stonesEarned > 0)
              _resultRow('Stones', '+${result.stonesEarned}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _game = null);
            },
            child: const Text('Select sword'),
          ),
          ElevatedButton(
            onPressed: _hasFreePlays
                ? () {
                    Navigator.pop(context);
                    _startGame();
                  }
                : null,
            child: const Text('Play again'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.amber)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _exitResult);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Brick Breaker'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _exitResult),
          ),
          actions: [
            if (_game != null && !_game!.isGameOver)
              IconButton(
                icon: Icon(_game!.isPaused ? Icons.play_arrow : Icons.pause),
                onPressed: () => setState(() => _game!.togglePause()),
              ),
          ],
        ),
        body: _game == null ? _buildSelection() : _buildGame(_game!),
      ),
    );
  }

  Widget _buildSelection() {
    final swords = _playableSwords;
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(16), child: _buildPlayCounter()),
        Expanded(
          child: swords.isEmpty
              ? const Center(
                  child: Text(
                    'No playable sword. Normal, Rare, or Unique swords only.',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: swords.length,
                  itemBuilder: (_, i) => _swordTile(swords[i]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedSword == null ? null : _startGame,
                  child: const Text('Start'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _selectedSword == null ? null : _watchAdForPlay,
                child: const Text('Ad play'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayCounter() {
    if (!_playsLoaded) {
      return const LinearProgressIndicator();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.sports_esports, color: Colors.amber),
          const SizedBox(width: 8),
          Text(
            'Free plays: $_remainingFreePlays / $_freePlayLimit',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            'Earned: ${_totalGoldEarned}G',
            style: const TextStyle(color: Colors.amber),
          ),
        ],
      ),
    );
  }

  Widget _swordTile(OwnedSword sword) {
    final selected = identical(_selectedSword, sword);
    return Card(
      color: selected ? Colors.amber.withValues(alpha: 0.16) : Colors.white10,
      child: ListTile(
        onTap: () => setState(() => _selectedSword = sword),
        leading: SwordImageWidget(
          grade: sword.data.grade,
          element: sword.data.element,
          swordId: sword.data.id,
          level: sword.level,
          breakthroughLevel: sword.breakthroughLevel,
          size: 44,
          showPulse: false,
        ),
        title: Text(
          sword.data.name,
          style: TextStyle(
            color: sword.data.grade.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Power ${sword.totalPower}  Lv.${sword.level}',
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle, color: Colors.amber)
            : const Icon(Icons.chevron_right, color: Colors.white30),
      ),
    );
  }

  Widget _buildGame(BrickBreakerGame game) {
    return Column(
      children: [
        _buildHud(game),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              final width = context.size?.width ?? 1;
              game.moveSword(details.delta.dx / width);
            },
            child: LayoutBuilder(
              builder: (_, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _GamePainter(game)),
                    ),
                    _swordWidget(
                      game,
                      constraints.maxWidth,
                      constraints.maxHeight,
                    ),
                    if (game.isPaused)
                      const Center(
                        child: Text(
                          'PAUSED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        _buildBottomControls(game),
      ],
    );
  }

  Widget _buildHud(BrickBreakerGame game) {
    return ListenableBuilder(
      listenable: game,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.black26,
        child: Row(
          children: [
            _hudText('Wave', '${game.wave}'),
            _hudText('Score', '${game.score}'),
            _hudText('Lives', '${game.lives}'),
            _hudText('Combo', 'x${game.comboMultiplier.toStringAsFixed(1)}'),
          ],
        ),
      ),
    );
  }

  Widget _hudText(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _swordWidget(BrickBreakerGame game, double w, double h) {
    const sw = 72.0;
    const sh = 96.0;
    return Positioned(
      left: game.swordX * w - sw / 2,
      top: BrickBreakerGame.swordY * h - sh * 0.75,
      width: sw,
      height: sh,
      child: IgnorePointer(
        child: SwordImageWidget(
          grade: game.sword.data.grade,
          element: game.sword.data.element,
          swordId: game.sword.data.id,
          level: game.sword.level,
          breakthroughLevel: game.sword.breakthroughLevel,
          size: 76,
          showPulse: true,
        ),
      ),
    );
  }

  Widget _buildBottomControls(BrickBreakerGame game) {
    return ListenableBuilder(
      listenable: game,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        color: Colors.black26,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: game.canLastStand ? game.tryLastStand : null,
                child: const Text('Last stand'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: game.canBurst ? game.triggerBurst : null,
                child: const Text('Burst'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: game.canUltimate ? game.triggerUltimate : null,
                child: const Text('Ultimate'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  final BrickBreakerGame game;

  _GamePainter(this.game) : super(repaint: game);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawDangerLine(canvas, size);
    for (final brick in game.bricks) {
      if (!brick.isDead) _drawBrick(canvas, size, brick);
    }
    for (final projectile in game.projectiles) {
      _drawProjectile(canvas, size, projectile);
    }
    for (final powerUp in game.powerUps) {
      _drawPowerUp(canvas, size, powerUp);
    }
    for (final effect in game.effects) {
      _drawEffect(canvas, size, effect);
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF101024), Color(0xFF070711)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _drawDangerLine(Canvas canvas, Size size) {
    final y = BrickBreakerGame.dangerY * size.height;
    final paint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.45)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  void _drawBrick(Canvas canvas, Size size, Brick brick) {
    final w = brick.type == BrickType.boss ? 86.0 : 54.0;
    final h = brick.type == BrickType.boss ? 54.0 : 34.0;
    final center = Offset(brick.x * size.width, brick.y * size.height);
    final rect = Rect.fromCenter(center: center, width: w, height: h);
    final color = brick.isFlashing ? Colors.amber : brick.type.color;

    final fill = Paint()..color = color.withValues(alpha: 0.9);
    final border = Paint()
      ..color = brick.element.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = brick.isShielded || brick.isLinkedShielded ? 3 : 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      border,
    );

    final hpRect = Rect.fromLTWH(rect.left, rect.bottom + 4, rect.width, 4);
    canvas.drawRect(hpRect, Paint()..color = Colors.black54);
    canvas.drawRect(
      Rect.fromLTWH(
        hpRect.left,
        hpRect.top,
        hpRect.width * brick.hpRatio,
        hpRect.height,
      ),
      Paint()..color = Colors.greenAccent,
    );
  }

  void _drawProjectile(Canvas canvas, Size size, Projectile p) {
    final center = Offset(p.x * size.width, p.y * size.height);
    final paint = Paint()
      ..color = p.kind.color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, p.kind == ProjectileKind.blast ? 7 : 4, paint);
  }

  void _drawPowerUp(Canvas canvas, Size size, PowerUpItem item) {
    final center = Offset(item.x * size.width, item.y * size.height);
    canvas.drawCircle(center, 12, Paint()..color = item.type.color);
  }

  void _drawEffect(Canvas canvas, Size size, AttackEffect effect) {
    final center = Offset(effect.x * size.width, effect.y * size.height);
    final alpha = (effect.ttl / 35).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = effect.color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 20 * (1.2 - alpha), paint);
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}
