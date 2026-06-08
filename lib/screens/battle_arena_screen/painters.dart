part of '../battle_arena_screen.dart';

class _BgParticlePainter extends CustomPainter {
  final List<_BgParticle> particles;
  final double progress;
  _BgParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y + progress * p.speed) % 1.0;
      final x = p.x + sin(y * pi * 2 + p.speed) * 0.02;
      final twinkle = (0.5 + sin(progress * pi * 2 + p.x * 10) * 0.5).clamp(
        0.0,
        1.0,
      );
      canvas.drawCircle(
        Offset(x * size.width, (1 - y) * size.height),
        p.size,
        Paint()
          ..color = Colors.white.withOpacity(p.opacity * twinkle)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BgParticlePainter old) => true;
}

// ── 임팩트 파티클 ──
class _ImpactPainter extends CustomPainter {
  final List<_ImpactParticle> particles;
  final double progress;
  _ImpactPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (final p in particles) {
      final dist = p.speed * progress;
      final x = cx + cos(p.angle) * dist;
      final y = cy + sin(p.angle) * dist;
      final fade = (1.0 - progress).clamp(0.0, 1.0);
      final s = p.size * (1.0 - progress * 0.5);

      canvas.drawCircle(
        Offset(x, y),
        s.clamp(0.5, 10.0),
        Paint()
          ..color = p.color.withOpacity(fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactPainter old) => old.progress != progress;
}

// ── 컨페티 ──
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;
  _ConfettiPainter({required this.pieces, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final y = -20 + (size.height + 40) * progress * p.speed;
      final x = p.x * size.width + sin(progress * pi * 4 + p.wobble) * p.wobble;
      final rot = p.rotation + progress * pi * 6;
      final fade = progress < 0.8 ? 1.0 : (1.0 - (progress - 0.8) / 0.2);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.5,
        ),
        Paint()..color = p.color.withOpacity(fade.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}

// ── 슬래시 폴백 (이미지 없을 때) ──
class _FallbackSlashPainter extends CustomPainter {
  final double progress;
  final Color color;
  _FallbackSlashPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity((1.0 - progress).clamp(0.0, 1.0))
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    path.moveTo(size.width * 0.8, size.height * 0.1);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.5,
      size.width * 0.2,
      size.height * 0.9,
    );
    canvas.drawPath(path, paint);

    // 글로우 복제
    paint.strokeWidth = 8;
    paint.color = color.withOpacity((0.3 * (1.0 - progress)).clamp(0.0, 1.0));
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FallbackSlashPainter old) =>
      old.progress != progress;
}
