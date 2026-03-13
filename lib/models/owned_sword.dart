import 'sword_data.dart';
import '../data/swords.dart';
import '../enums/sword_grade.dart';

class OwnedSword {
  final String uid;
  final SwordData data;
  int level;
  int breakthroughLevel;

  OwnedSword({
    required this.uid,
    required this.data,
    this.level = 0,
    this.breakthroughLevel = 0,
  });

  // ✅ 등급별 레벨당 전투력 보너스 (battle_engine.dart gradeLevelBonus와 동일!)
  static const Map<SwordGrade, int> _levelBonusPerGrade = {
    SwordGrade.normal: 6,
    SwordGrade.rare: 7,
    SwordGrade.unique: 8,
    SwordGrade.legend: 10,
    SwordGrade.hidden: 13,
    SwordGrade.immortal: 17,
  };

  // ✅ 총 전투력 (등급별 차등 적용)
  int get totalPower {
    final levelBonus = _levelBonusPerGrade[data.grade] ?? 10;
    return data.baseAtk + (level * levelBonus);
  }

  // ✅ 다음 레벨 전투력 미리보기
  int get nextLevelPower {
    final levelBonus = _levelBonusPerGrade[data.grade] ?? 10;
    return data.baseAtk + ((level + 1) * levelBonus);
  }

  // ✅ 레벨당 전투력 증가량
  int get powerPerLevel => _levelBonusPerGrade[data.grade] ?? 10;

  // 판매 가격
  int get sellPrice => data.getSellPrice(level);

  // JSON 변환 (저장용)
  Map<String, dynamic> toJson() => {
    'uid': uid,
    'dataId': data.id,
    'level': level,
    'breakthroughLevel': breakthroughLevel,
  };

  // ✅ JSON에서 복원 (안전한 버전)
  factory OwnedSword.fromJson(Map<String, dynamic> json) {
    try {
      final dataId = json['dataId'] as String? ?? '';

      // ✅ 검 데이터 안전하게 찾기
      final data = allSwords.firstWhere(
        (s) => s.id == dataId,
        orElse: () => allSwords.first, // ✅ 없으면 첫 번째 검 사용
      );

      return OwnedSword(
        uid:
            json['uid'] as String? ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        data: data,
        level: (json['level'] as int?) ?? 0,
        breakthroughLevel: (json['breakthroughLevel'] as int?) ?? 0,
      );
    } catch (e) {
      // ✅ 완전히 실패하면 기본 검 반환
      return OwnedSword(
        uid: DateTime.now().millisecondsSinceEpoch.toString(),
        data: allSwords.first,
        level: 0,
        breakthroughLevel: 0,
      );
    }
  }

  // ✅ 유효성 검사
  bool get isValid => uid.isNotEmpty && data.id.isNotEmpty;

  @override
  String toString() => '${data.name} +$level (${data.grade.displayName})';
}
