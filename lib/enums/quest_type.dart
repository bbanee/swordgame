enum QuestType {
  enhance,    // 강화
  battle,     // 배틀
  boss,       // 보스
  gacha,      // 뽑기
  sell,       // 판매
  synthesis,  // 합성
  login,      // 접속
  win,        // 승리
  collect,    // 도감 수집
}

extension QuestTypeExt on QuestType {
  String get displayName {
    switch (this) {
      case QuestType.enhance: return '강화';
      case QuestType.battle: return '배틀';
      case QuestType.boss: return '보스';
      case QuestType.gacha: return '뽑기';
      case QuestType.sell: return '판매';
      case QuestType.synthesis: return '합성';
      case QuestType.login: return '접속';
      case QuestType.win: return '승리';
      case QuestType.collect: return '수집';
    }
  }
  
  String get emoji {
    switch (this) {
      case QuestType.enhance: return '🔨';
      case QuestType.battle: return '⚔️';
      case QuestType.boss: return '👹';
      case QuestType.gacha: return '🎰';
      case QuestType.sell: return '💰';
      case QuestType.synthesis: return '🔮';
      case QuestType.login: return '📅';
      case QuestType.win: return '🏆';
      case QuestType.collect: return '📚';
    }
  }
}