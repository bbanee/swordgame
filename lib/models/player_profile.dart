import '../data/swords.dart';
import '../enums/element.dart';
import '../enums/sword_grade.dart';
import '../models/sword_data.dart';
import '../data/titles.dart';

class PlayerProfile {
  final String userId;
  final String nickname;
  final String swordId;
  final int swordLevel;
  final int swordBreakthroughLevel;
  final String titleId;
  final DateTime updatedAt;
  final int totalBattle;
  final int totalBattleWin;

  const PlayerProfile({
    required this.userId,
    required this.nickname,
    required this.swordId,
    required this.swordLevel,
    this.swordBreakthroughLevel = 0,
    required this.titleId,
    required this.updatedAt,
    this.totalBattle = 0,
    this.totalBattleWin = 0,
  });

  SwordData get sword => allSwords.firstWhere(
    (s) => s.id == swordId,
    orElse: () => allSwords.first,
  );

  // ✅ 등급별 레벨 보너스 (battle_engine.dart gradeLevelBonus와 동일!)
  static const Map<SwordGrade, int> _gradeLevelBonus = {
    SwordGrade.normal: 6,
    SwordGrade.rare: 7,
    SwordGrade.unique: 8,
    SwordGrade.legend: 10,
    SwordGrade.hidden: 13,
    SwordGrade.immortal: 17,
  };

  SwordGrade get grade => sword.grade;
  GameElement get element => sword.element;
  int get power => sword.baseAtk + swordLevel * (_gradeLevelBonus[grade] ?? 10);
  int get powerWithTitle => power + getTitleById(titleId).bonus;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'nickname': nickname,
    'swordId': swordId,
    'swordLevel': swordLevel,
    'swordBreakthroughLevel': swordBreakthroughLevel,
    'titleId': titleId,
    'updatedAt': updatedAt.toIso8601String(),
    'totalBattle': totalBattle,
    'totalBattleWin': totalBattleWin,
  };

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      userId: (json['userId'] ?? '') as String,
      nickname: (json['nickname'] ?? '모험가') as String,
      swordId: (json['swordId'] ?? allSwords.first.id) as String,
      swordLevel: (json['swordLevel'] ?? 0) as int,
      swordBreakthroughLevel: (json['swordBreakthroughLevel'] ?? 0) as int,
      titleId: (json['titleId'] ?? 't_01') as String,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      totalBattle: (json['totalBattle'] ?? 0) as int,
      totalBattleWin: (json['totalBattleWin'] ?? 0) as int,
    );
  }
}
