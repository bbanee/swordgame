import '../enums/element.dart';

class BossData {
  final String id;
  final String name;
  final GameElement element;
  final int hp;
  final int atk;
  final int goldReward;
  final int diamondReward;
  final double coreDropChance;
  final int coreDropMin;
  final int coreDropMax;
  final int cooldownMinutes;
  final int minLevel;
  final String? imagePath; // 보스 이미지 경로 (assets 또는 null이면 이모지 사용)

  const BossData({
    required this.id,
    required this.name,
    required this.element,
    required this.hp,
    required this.atk,
    required this.goldReward,
    required this.diamondReward,
    required this.coreDropChance,
    required this.coreDropMin,
    required this.coreDropMax,
    required this.cooldownMinutes,
    required this.minLevel,
    this.imagePath,
  });

  Duration get cooldownDuration => Duration(minutes: cooldownMinutes);

  String get difficulty {
    if (hp >= 7000) return '★★★';
    if (hp >= 5500) return '★★';
    return '★';
  }

  // 이미지가 있는지 확인
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
}
