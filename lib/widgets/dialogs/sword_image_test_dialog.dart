import 'package:flutter/material.dart';

import '../../data/swords.dart';
import '../../enums/element.dart';
import '../../enums/sword_grade.dart';
import '../../models/sword_data.dart';
import '../sword_image_widget.dart';

class SwordImageTestDialog extends StatefulWidget {
  const SwordImageTestDialog({super.key});

  @override
  State<SwordImageTestDialog> createState() => _SwordImageTestDialogState();
}

class _SwordImageTestDialogState extends State<SwordImageTestDialog> {
  int _index = 0;

  SwordData get _sword => allSwords[_index];

  void _move(int delta) {
    setState(() {
      _index = (_index + delta) % allSwords.length;
      if (_index < 0) _index += allSwords.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sword = _sword;
    final gradeColor = sword.grade.color;

    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF05080B),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      gradeColor.withValues(alpha: 0.22),
                      const Color(0xFF05080B),
                      Colors.black,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                _header(context),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      children: [
                        const Spacer(),
                        Text(
                          '${_index + 1} / ${allSwords.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          sword.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: gradeColor,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${sword.id}  |  ${sword.grade.displayName}  |  ${sword.element.nameKr}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Expanded(
                          flex: 5,
                          child: Row(
                            children: [
                              _arrowButton(Icons.chevron_left, () => _move(-1)),
                              Expanded(
                                child: Center(
                                  child: SwordImageWidget(
                                    grade: sword.grade,
                                    element: sword.element,
                                    swordId: sword.id,
                                    level: 0,
                                    size: 300,
                                    showPulse: true,
                                  ),
                                ),
                              ),
                              _arrowButton(Icons.chevron_right, () => _move(1)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _infoPanel(sword),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              '검 이미지 테스트',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _arrowButton(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 54,
      height: 96,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 46),
      ),
    );
  }

  Widget _infoPanel(SwordData sword) {
    final skills = sword.skills.map((skill) => skill.name).join(', ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        border: Border.all(color: sword.grade.color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _infoLine('기본 공격력', '${sword.baseAtk}'),
          const SizedBox(height: 8),
          _infoLine('스킬', skills.isEmpty ? '-' : skills),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
