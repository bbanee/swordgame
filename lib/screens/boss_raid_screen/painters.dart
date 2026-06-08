part of '../boss_raid_screen.dart';

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  _ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    // size가 유효하지 않으면 그리지 않음
    if (size.width <= 0 ||
        size.height <= 0 ||
        !size.width.isFinite ||
        !size.height.isFinite) {
      return;
    }

    for (final p in particles) {
      final safeOpacity = p.opacity.clamp(0.0, 1.0);
      if (safeOpacity <= 0) continue;

      final safeSize = (p.size * safeOpacity).clamp(0.1, 100.0);
      if (safeSize <= 0 || !safeSize.isFinite) continue;

      final paint = Paint()
        ..color = p.color.withOpacity(safeOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(p.x, p.y), safeSize, paint);

      // 글로우 효과
      final glowOpacity = (safeOpacity * 0.3).clamp(0.0, 1.0);
      if (glowOpacity > 0) {
        final glowPaint = Paint()
          ..color = p.color.withOpacity(glowOpacity)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

        canvas.drawCircle(
          Offset(p.x, p.y),
          (safeSize * 1.5).clamp(0.1, 150.0),
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================
// 원소 배경 페인터 (이펙트 #7)
// ============================================================
class _ElementBackgroundPainter extends CustomPainter {
  final GameElement element;
  final double progress;

  _ElementBackgroundPainter({required this.element, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // size가 유효하지 않으면 그리지 않음
    if (size.width <= 0 ||
        size.height <= 0 ||
        !size.width.isFinite ||
        !size.height.isFinite) {
      return;
    }

    final paint = Paint()..style = PaintingStyle.fill;

    switch (element) {
      case GameElement.fire:
        _drawFireEffect(canvas, size, paint);
        break;
      case GameElement.water:
        _drawWaterEffect(canvas, size, paint);
        break;
      case GameElement.nature:
        _drawNatureEffect(canvas, size, paint);
        break;
      case GameElement.light:
        _drawLightEffect(canvas, size, paint);
        break;
      case GameElement.dark:
        _drawDarkEffect(canvas, size, paint);
        break;
    }
  }

  void _drawFireEffect(Canvas canvas, Size size, Paint paint) {
    // 불꽃 파티클
    for (int i = 0; i < 10; i++) {
      final x =
          (size.width * (0.1 + i * 0.08) + sin(progress * 2 * pi + i) * 20);
      final y =
          size.height * 0.8 - (progress + i * 0.1) % 1 * size.height * 0.3;
      final radius = (5.0 + sin(progress * 4 * pi + i) * 3).clamp(1.0, 20.0);

      paint.color = Colors.orange.withOpacity(0.3);
      canvas.drawCircle(Offset(x, y), radius * 2, paint);
      paint.color = Colors.red.withOpacity(0.5);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _drawWaterEffect(Canvas canvas, Size size, Paint paint) {
    // 물결 효과
    final path = Path();
    for (double x = 0; x <= size.width; x += 10) {
      final y = size.height * 0.85 + sin(x * 0.02 + progress * 2 * pi) * 15;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    paint.color = Colors.blue.withOpacity(0.15);
    canvas.drawPath(path, paint);
  }

  void _drawNatureEffect(Canvas canvas, Size size, Paint paint) {
    // 나뭇잎 파티클
    for (int i = 0; i < 8; i++) {
      final x =
          (size.width * (0.1 + i * 0.12) +
          sin(progress * 2 * pi + i * 0.5) * 30);
      final y = (progress * size.height + i * 50) % size.height;

      paint.color = Colors.green.withOpacity(0.4);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 2 * pi + i);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 8, height: 12),
        paint,
      );
      canvas.restore();
    }
  }

  void _drawLightEffect(Canvas canvas, Size size, Paint paint) {
    // 빛줄기
    for (int i = 0; i < 5; i++) {
      final startX = size.width * (0.2 + i * 0.15);
      final opacity = (0.1 + sin(progress * 2 * pi + i) * 0.05).clamp(0.0, 1.0);

      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.amber.withOpacity(opacity), Colors.transparent],
      ).createShader(Rect.fromLTWH(startX - 20, 0, 40, size.height * 0.6));

      canvas.drawRect(
        Rect.fromLTWH(startX - 20, 0, 40, size.height * 0.6),
        paint,
      );
    }
  }

  void _drawDarkEffect(Canvas canvas, Size size, Paint paint) {
    // 어둠 파티클
    for (int i = 0; i < 12; i++) {
      final x =
          (size.width * (i / 12) + sin(progress * 2 * pi + i) * 20) %
          size.width;
      final y =
          (size.height * (0.2 + (i % 3) * 0.2) +
          cos(progress * 2 * pi + i) * 20);
      final radius = (20.0 + sin(progress * 4 * pi + i) * 10).clamp(1.0, 50.0);

      paint.color = Colors.purple.withOpacity(0.1);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
    paint.maskFilter = null;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
