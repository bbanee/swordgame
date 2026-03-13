import 'package:flutter/material.dart';

enum AchievementCategory {
  enhance,
  battle,
  boss,
  collection,
  economy,
  attendance,
  misc,
}

class AchievementData {
  final String id;
  final AchievementCategory category;
  final String name;
  final String description;

  /// statsKey에 해당하는 값이 target 이상이면 달성(언락)
  final String statsKey;
  final int target;

  /// 보상
  final int rewardGold;
  final int rewardDiamond;
  final int rewardStone;

  const AchievementData({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.statsKey,
    required this.target,
    this.rewardGold = 0,
    this.rewardDiamond = 0,
    this.rewardStone = 0,
  });

  Color get categoryColor {
    switch (category) {
      case AchievementCategory.enhance:
        return Colors.purpleAccent;
      case AchievementCategory.battle:
        return Colors.redAccent;
      case AchievementCategory.boss:
        return Colors.deepOrangeAccent;
      case AchievementCategory.collection:
        return Colors.lightBlueAccent;
      case AchievementCategory.economy:
        return Colors.amber;
      case AchievementCategory.attendance:
        return Colors.greenAccent;
      case AchievementCategory.misc:
        return Colors.white70;
    }
  }

  String get categoryName {
    switch (category) {
      case AchievementCategory.enhance:
        return '강화';
      case AchievementCategory.battle:
        return '배틀';
      case AchievementCategory.boss:
        return '보스';
      case AchievementCategory.collection:
        return '수집';
      case AchievementCategory.economy:
        return '경제';
      case AchievementCategory.attendance:
        return '출석';
      case AchievementCategory.misc:
        return '기타';
    }
  }
}
