import 'dart:math';
import '../models/sword_data.dart';
import '../enums/sword_grade.dart';
import 'swords.dart';

class NPCData {
  final String id;
  final String name;
  final SwordData sword;
  final int swordLevel;
  
  NPCData({
    required this.id,
    required this.name,
    required this.sword,
    required this.swordLevel,
  });
  
  // 전투력
  int get power => sword.baseAtk + (swordLevel * 10);
}

// NPC 20명 생성
final List<NPCData> npcPlayers = _generateNPCs();

List<NPCData> _generateNPCs() {
  final random = Random(123); // 고정 시드
  
  // ✅ 레벨대별로 다양한 이름
  final names = [
    // 초보 (일반)
    '검술초보', '나무꾼', '떠돌이', '수련생', '농부', '어부', '광부',
    // 중급 (레어)
    '견습기사', '방랑자', '모험가', '탐험가', '사냥꾼',
    // 상급 (유니크)
    '정예기사', '용병대장', '검술사범',
    // 고급 (전설)
    '검호', '검성', '무림고수',
    // 최상급 (히든/불멸)
    '전설의검객', 'AI강자',
  ];
  
  final List<NPCData> npcs = [];
  
  // ✅ 등급별 NPC 수 (현실적인 분포)
  // 일반: 7명, 레어: 5명, 유니크: 4명, 전설: 2명, 히든: 1명, 불멸: 1명 = 20명
  final gradeDistribution = [
    (SwordGrade.normal, 7, 1, 8),      // 등급, 인원, 최소레벨, 최대레벨
    (SwordGrade.rare, 5, 6, 14),
    (SwordGrade.unique, 4, 12, 20),
    (SwordGrade.legend, 2, 18, 26),
    (SwordGrade.hidden, 1, 24, 28),
    (SwordGrade.immortal, 1, 28, 30),
  ];
  
  int nameIndex = 0;
  
  for (final (grade, count, minLevel, maxLevel) in gradeDistribution) {
    final swordsOfGrade = getSwordsByGrade(grade);
    
    for (int i = 0; i < count; i++) {
      final sword = swordsOfGrade[random.nextInt(swordsOfGrade.length)];
      final level = minLevel + random.nextInt(maxLevel - minLevel + 1);
      
      npcs.add(NPCData(
        id: 'npc_${npcs.length}',
        name: names[nameIndex % names.length],
        sword: sword,
        swordLevel: level,
      ));
      
      nameIndex++;
    }
  }
  
  // ✅ v10.4: 검레벨 > 검등급 > 공격력 순 정렬
  npcs.sort((a, b) {
    final levelCmp = a.swordLevel.compareTo(b.swordLevel);
    if (levelCmp != 0) return levelCmp;
    final gradeCmp = a.sword.grade.index.compareTo(b.sword.grade.index);
    if (gradeCmp != 0) return gradeCmp;
    return a.power.compareTo(b.power);
  });
  
  return npcs;
}

// ID로 NPC 찾기
NPCData? getNpcById(String id) {
  try {
    return npcPlayers.firstWhere((n) => n.id == id);
  } catch (_) {
    return null;
  }
}