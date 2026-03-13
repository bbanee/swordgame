class BattleRecord {
  final String uid;
  final String opponentId;
  final String opponentName;
  final int myLevel;
  final int opponentLevel;
  final String myGrade;
  final String opponentGrade;
  final String opponentElement;  // ✅ 상대 속성 추가
  final bool opponentIsNpc;
  final bool isWin;
  final DateTime timestamp;
  final int goldEarned;
  final bool isRevengeable;
  final List<String> logs;
  final bool isAttacker;
  
  BattleRecord({
    required this.uid,
    required this.opponentId,
    required this.opponentName,
    required this.myLevel,
    required this.opponentLevel,
    required this.myGrade,
    required this.opponentGrade,
    this.opponentElement = 'fire',  // ✅ 기본값
    required this.opponentIsNpc,
    required this.isWin,
    required this.timestamp,
    required this.goldEarned,
    this.isRevengeable = false,
    this.logs = const [],
    this.isAttacker = true,
  });
  
  // 경과 시간 표시
  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
  
  Map<String, dynamic> toJson() => {
    'uid': uid,
    'opponentId': opponentId,
    'opponentName': opponentName,
    'myLevel': myLevel,
    'opponentLevel': opponentLevel,
    'myGrade': myGrade,
    'opponentGrade': opponentGrade,
    'opponentElement': opponentElement,
    'opponentIsNpc': opponentIsNpc,
    'isWin': isWin,
    'timestamp': timestamp.toIso8601String(),
    'goldEarned': goldEarned,
    'isRevengeable': isRevengeable,
    'logs': logs,
    'isAttacker': isAttacker,
  };
  
  // ✅ 안전한 fromJson
  factory BattleRecord.fromJson(Map<String, dynamic> json) {
    try {
      return BattleRecord(
        uid: (json['uid'] as String?) ?? DateTime.now().millisecondsSinceEpoch.toString(),
        opponentId: (json['opponentId'] as String?) ?? 'unknown',
        opponentName: (json['opponentName'] as String?) ?? '알 수 없음',
        myLevel: (json['myLevel'] as int?) ?? 0,
        opponentLevel: (json['opponentLevel'] as int?) ?? 0,
        myGrade: (json['myGrade'] as String?) ?? 'normal',
        opponentGrade: (json['opponentGrade'] as String?) ?? 'normal',
        opponentElement: (json['opponentElement'] as String?) ?? 'fire',
        opponentIsNpc: (json['opponentIsNpc'] as bool?) ?? false,
        isWin: (json['isWin'] as bool?) ?? false,
        timestamp: _parseTimestamp(json['timestamp']),
        goldEarned: (json['goldEarned'] as int?) ?? 0,
        isRevengeable: (json['isRevengeable'] as bool?) ?? false,
        logs: _parseLogs(json['logs']),
        isAttacker: (json['isAttacker'] as bool?) ?? true,
      );
    } catch (e) {
      // ✅ 완전히 실패하면 기본 기록 반환
      return BattleRecord(
        uid: DateTime.now().millisecondsSinceEpoch.toString(),
        opponentId: 'error',
        opponentName: '오류',
        myLevel: 0,
        opponentLevel: 0,
        myGrade: 'normal',
        opponentGrade: 'normal',
        opponentElement: 'fire',
        opponentIsNpc: true,
        isWin: false,
        timestamp: DateTime.now(),
        goldEarned: 0,
        isAttacker: true,
      );
    }
  }
  
  // ✅ 타임스탬프 안전 파싱
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
  
  // ✅ 로그 안전 파싱
  static List<String> _parseLogs(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }
  
  // ✅ 유효성 검사
  bool get isValid => uid.isNotEmpty && opponentId.isNotEmpty;
}