import 'package:flutter/material.dart';
import '../../models/owned_sword.dart';
import '../../utils/constants.dart';

class SwordCard extends StatelessWidget {
  final OwnedSword sword;
  final bool isEquipped;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SwordCard({
    super.key,
    required this.sword,
    this.isEquipped = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final grade = sword.data.grade;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: grade.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEquipped ? Colors.amber : grade.color.withOpacity(0.5),
            width: isEquipped ? 2 : 1,
          ),
          boxShadow: isEquipped
              ? [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // 메인 컨텐츠
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 장착 표시
                  if (isEquipped)
                    const Align(
                      alignment: Alignment.topRight,
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.amber,
                        size: 16,
                      ),
                    ),
                  
                  // 검 이모지
                  Text(
                    grade.emoji,
                    style: const TextStyle(fontSize: 36),
                  ),
                  const SizedBox(height: 4),
                  
                  // 검 이름
                  Text(
                    sword.data.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  
                  // 강화 레벨
                  Text(
                    '+${sword.level}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // 속성 표시 (좌상단)
            Positioned(
              top: 4,
              left: 4,
              child: Text(
                sword.data.element.emoji,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 큰 사이즈 카드 (장착 화면용)
class LargeSwordCard extends StatelessWidget {
  final OwnedSword sword;
  final bool showGlow;

  const LargeSwordCard({
    super.key,
    required this.sword,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final grade = sword.data.grade;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: grade.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: grade.color, width: 2),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: grade.color.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 검 이모지
          Text(
            grade.emoji,
            style: const TextStyle(fontSize: 80),
          ),
          const SizedBox(height: 12),

          // 등급
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: grade.color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              grade.name,
              style: TextStyle(
                color: grade.color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 검 이름
          Text(
            sword.data.name,
            style: TextStyle(
              color: grade.color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          // 강화 레벨
          Text(
            '+${sword.level}',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // 속성 & 전투력
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                sword.data.element.emoji,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 4),
              Text(
                sword.data.element.name,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.flash_on, color: Colors.amber, size: 16),
              Text(
                ' ${sword.totalPower}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}