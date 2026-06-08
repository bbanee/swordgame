part of '../sword_image_widget.dart';

class _BreakthroughRingPainter extends CustomPainter {
  final Color color;
  final int sideCount;
  final int tier;
  final bool isHidden;

  const _BreakthroughRingPainter({
    required this.color,
    required this.sideCount,
    required this.tier,
    required this.isHidden,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final ringPaint = Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 + (tier * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final outerPaint = Paint()
      ..color = color.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 + (tier * 0.25);

    final path = Path();
    for (var i = 0; i < sideCount; i++) {
      final angle = (pi * 2 / sideCount) * i - pi / 2;
      final wobble = isHidden && i.isOdd ? radius * 0.08 : 0.0;
      final point = Offset(
        center.dx + cos(angle) * (radius - wobble),
        center.dy + sin(angle) * (radius - wobble),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(path, outerPaint);
    canvas.drawPath(path, ringPaint);

    if (tier >= 2) {
      final innerRadius = radius * 0.78;
      canvas.drawCircle(
        center,
        innerRadius,
        Paint()
          ..color = color.withOpacity(0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BreakthroughRingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.sideCount != sideCount ||
        oldDelegate.tier != tier ||
        oldDelegate.isHidden != isHidden;
  }
}

class _MagicCirclePainter extends CustomPainter {
  final Color color;
  final int tier;
  final SwordGrade grade;

  const _MagicCirclePainter({
    required this.color,
    required this.tier,
    required this.grade,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final paint = Paint()
      ..color = color.withOpacity(0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final strongPaint = Paint()
      ..color = color.withOpacity(0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 + tier * 0.2;

    canvas.drawCircle(center, radius * 0.82, paint);
    canvas.drawCircle(center, radius * 0.62, paint);

    final rayCount = switch (grade) {
      SwordGrade.normal => 4,
      SwordGrade.rare => 6,
      SwordGrade.unique => 6,
      SwordGrade.legend => 8,
      SwordGrade.hidden => 7,
      SwordGrade.immortal => 10,
    };

    for (var i = 0; i < rayCount; i++) {
      final angle = (pi * 2 / rayCount) * i;
      final outer = Offset(
        center.dx + cos(angle) * radius * 0.86,
        center.dy + sin(angle) * radius * 0.86,
      );
      final inner = Offset(
        center.dx + cos(angle) * radius * 0.48,
        center.dy + sin(angle) * radius * 0.48,
      );
      canvas.drawLine(inner, outer, i.isEven ? strongPaint : paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MagicCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.tier != tier ||
        oldDelegate.grade != grade;
  }
}

// 🎮 강화 성공 시 사용하는 위젯 (애니메이션 자동 재생)
class EnhanceSuccessEffect extends StatefulWidget {
  final SwordGrade grade;
  final GameElement element;
  final int level;
  final double size;
  final VoidCallback? onComplete;

  const EnhanceSuccessEffect({
    super.key,
    required this.grade,
    required this.element,
    required this.level,
    this.size = 150,
    this.onComplete,
  });

  @override
  State<EnhanceSuccessEffect> createState() => _EnhanceSuccessEffectState();
}

class _EnhanceSuccessEffectState extends State<EnhanceSuccessEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            // 검 이미지
            SwordImageWidget(
              grade: widget.grade,
              element: widget.element,
              level: widget.level,
              size: widget.size,
              showPulse: false,
              showEnhanceEffect: true,
            ),

            // 빛 줄기
            ...List.generate(8, (index) {
              final angle = index * (360 / 8) * pi / 180;
              final length = widget.size * progress * 0.5;

              return Transform.rotate(
                angle: angle,
                child: Opacity(
                  opacity: (1 - progress).clamp(0.0, 1.0),
                  child: Container(
                    width: 3,
                    height: length,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          widget.grade.color.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ⭐ 별 모양 페인터 (레전드/히든/이모탈용)
class _StarPainter extends CustomPainter {
  final Color color;
  final int points;
  final double innerRadius;

  _StarPainter({required this.color, this.points = 5, this.innerRadius = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final inner = outerRadius * innerRadius;

    final path = Path();
    final angleStep = pi / points;

    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : inner;
      final angle = i * angleStep - pi / 2;
      final point = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(path, paint);

    // 글로우 효과
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.points != points;
  }
}

// 🔥 오라 링 페인터 (이모탈용)
class _AuraRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _AuraRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;

    // 회전하는 오라 링
    final sweepAngle = pi * 1.5;
    final startAngle = progress * pi * 4;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [
          Colors.transparent,
          color.withOpacity(0.5),
          Colors.red.withOpacity(0.8),
          Colors.orange.withOpacity(0.6),
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);

    // 두 번째 링 (반대 방향)
    final paint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = SweepGradient(
        startAngle: -startAngle * 0.7,
        endAngle: -startAngle * 0.7 + sweepAngle,
        colors: [
          Colors.transparent,
          Colors.amber.withOpacity(0.3),
          Colors.yellow.withOpacity(0.5),
          Colors.white.withOpacity(0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.85));

    canvas.drawCircle(center, radius * 0.85, paint2);
  }

  @override
  bool shouldRepaint(covariant _AuraRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
