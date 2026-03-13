import '../enums/quest_type.dart';

class DailyQuest {
  final String id;
  final String name;
  final String description;
  final QuestType type;
  final int target;
  final int rewardGold;
  final int rewardDiamond;
  final int rewardStone;
  final int rewardSeasonExp;
  int progress;
  bool claimed;
  
  DailyQuest({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.target,
    this.rewardGold = 0,
    this.rewardDiamond = 0,
    this.rewardStone = 0,
    this.rewardSeasonExp = 10,
    this.progress = 0,
    this.claimed = false,
  });
  
  bool get isCompleted => progress >= target;
  
  double get progressRatio => (progress / target).clamp(0.0, 1.0);
  
  String get progressText => '$progress/$target';
  
  // ✅ 보상 요약 텍스트
  String get rewardText {
    final rewards = <String>[];
    if (rewardGold > 0) rewards.add('${rewardGold}G');
    if (rewardDiamond > 0) rewards.add('${rewardDiamond}💎');
    if (rewardStone > 0) rewards.add('${rewardStone}🔷');
    if (rewardSeasonExp > 0) rewards.add('${rewardSeasonExp}EXP');
    return rewards.join(' + ');
  }
  
  // ✅ 보상이 있는지 확인
  bool get hasReward => rewardGold > 0 || rewardDiamond > 0 || rewardStone > 0;
  
  DailyQuest copyWith({int? progress, bool? claimed}) {
    return DailyQuest(
      id: id,
      name: name,
      description: description,
      type: type,
      target: target,
      rewardGold: rewardGold,
      rewardDiamond: rewardDiamond,
      rewardStone: rewardStone,
      rewardSeasonExp: rewardSeasonExp,
      progress: progress ?? this.progress,
      claimed: claimed ?? this.claimed,
    );
  }
  
  // ✅ JSON 직렬화
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'type': type.name,
    'target': target,
    'rewardGold': rewardGold,
    'rewardDiamond': rewardDiamond,
    'rewardStone': rewardStone,
    'rewardSeasonExp': rewardSeasonExp,
    'progress': progress,
    'claimed': claimed,
  };
  
  // ✅ JSON에서 복원
  factory DailyQuest.fromJson(Map<String, dynamic> json) {
    return DailyQuest(
      id: json['id'] as String? ?? 'unknown',
      name: json['name'] as String? ?? '알 수 없음',
      description: json['description'] as String? ?? '',
      type: QuestType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => QuestType.enhance,
      ),
      target: json['target'] as int? ?? 1,
      rewardGold: json['rewardGold'] as int? ?? 0,
      rewardDiamond: json['rewardDiamond'] as int? ?? 0,
      rewardStone: json['rewardStone'] as int? ?? 0,
      rewardSeasonExp: json['rewardSeasonExp'] as int? ?? 10,
      progress: json['progress'] as int? ?? 0,
      claimed: json['claimed'] as bool? ?? false,
    );
  }
}