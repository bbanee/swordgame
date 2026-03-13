import 'dart:math' as math;
import '../enums/sword_grade.dart';
import '../enums/element.dart';
import '../models/sword_data.dart';
import '../models/owned_sword.dart';
import '../data/swords.dart';

// ===== 랜덤 유틸 =====
final math.Random _random = math.Random();

/// 확률 체크 (0~100 범위의 퍼센트)
bool checkProbability(double percent) {
  if (percent <= 0) return false;
  if (percent >= 100) return true;
  return _random.nextDouble() * 100 < percent;
}

/// 범위 내 랜덤 정수 (min, max 포함)
int randomInt(int min, int max) {
  // ✅ 범위 검증
  if (min > max) {
    final temp = min;
    min = max;
    max = temp;
  }
  if (min == max) return min;
  return min + _random.nextInt(max - min + 1);
}

/// 범위 내 랜덤 실수
double randomDouble(double min, double max) {
  // ✅ 범위 검증
  if (min > max) {
    final temp = min;
    min = max;
    max = temp;
  }
  return min + _random.nextDouble() * (max - min);
}

// ===== 뽑기 로직 =====
SwordData rollGacha() {
  final roll = _random.nextDouble() * 100;
  double cumulative = 0;

  for (final entry in gachaProbability.entries) {
    cumulative += entry.value;
    if (roll < cumulative) {
      final swordsOfGrade = getSwordsByGrade(entry.key);
      if (swordsOfGrade.isEmpty) continue; // ✅ 빈 리스트 방어
      return swordsOfGrade[_random.nextInt(swordsOfGrade.length)];
    }
  }

  // ✅ 기본값 (일반) - 확률 합계가 100% 미만일 때 안전망
  final normalSwords = getSwordsByGrade(SwordGrade.normal);
  return normalSwords[_random.nextInt(normalSwords.length)];
}

/// ✅ 고유 ID 생성 (충돌 방지 강화)
String generateUid() {
  final timestamp = DateTime.now().microsecondsSinceEpoch; // ✅ 마이크로초 사용
  final random1 = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
  final random2 = _random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
  return '${timestamp.toRadixString(16)}_${random1}_$random2';
}

/// 새 검 생성
OwnedSword createNewSword(SwordData data) {
  return OwnedSword(uid: generateUid(), data: data, level: 0);
}

// ===== 포맷팅 =====
String formatNumber(int number) {
  if (number < 0) return '-${formatNumber(-number)}';
  return number.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}

/// ✅ 골드 포맷 (정수면 소수점 생략)
String formatGold(int gold) {
  if (gold >= 1000000000) {
    final value = gold / 1000000000;
    return value == value.truncate()
        ? '${value.truncate()}B'
        : '${value.toStringAsFixed(1)}B';
  }
  if (gold >= 1000000) {
    final value = gold / 1000000;
    return value == value.truncate()
        ? '${value.truncate()}M'
        : '${value.toStringAsFixed(1)}M';
  }
  if (gold >= 10000) {
    final value = gold / 1000;
    return value == value.truncate()
        ? '${value.truncate()}K'
        : '${value.toStringAsFixed(1)}K';
  }
  return formatNumber(gold);
}

String formatDuration(Duration duration) {
  if (duration.inHours > 0) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String formatTimeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.isNegative) return '방금 전'; // ✅ 미래 시간 방어
  if (diff.inSeconds < 60) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  if (diff.inDays < 30) return '${diff.inDays ~/ 7}주 전';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}개월 전';
  return '${diff.inDays ~/ 365}년 전';
}

// ===== 배틀 로직 =====
/// ✅ v10.1 배틀 보상 계산 - 고레벨 대박 시스템
/// LV15+ 상대 이기면 최소 10만G!
/// 높은 레벨끼리 싸울수록 대박!
int calculateBattleReward(
  int myLevel,
  int opponentLevel,
  SwordGrade opponentGrade, [
  SwordGrade? myGrade,
]) {
  // ========================================
  // 1️⃣ 기본 보상 (상대 레벨 기반)
  // ========================================
  int baseReward;
  if (opponentLevel >= 15) {
    // LV15+: 10만G 베이스, 레벨당 +2만G
    baseReward = 100000 + (opponentLevel - 15) * 20000;
  } else if (opponentLevel >= 10) {
    // LV10~14: 3만~8만G
    baseReward = 30000 + (opponentLevel - 10) * 10000;
  } else if (opponentLevel >= 5) {
    // LV5~9: 5천~2만5천G
    baseReward = 5000 + (opponentLevel - 5) * 5000;
  } else {
    // LV1~4: 1천~4천G
    baseReward = 1000 + (opponentLevel - 1) * 1000;
  }

  // ========================================
  // 2️⃣ 레벨 차이 보정 (상대 - 나) - 역전 대박!
  // ========================================
  final levelDiff = opponentLevel - myLevel;
  double levelMultiplier;
  if (levelDiff >= 15) {
    levelMultiplier = 10.0; // +15레벨 이상: 10배 (기적!)
  } else if (levelDiff >= 10) {
    levelMultiplier = 7.0; // +10~14레벨: 7배 (대역전)
  } else if (levelDiff >= 5) {
    levelMultiplier = 4.0; // +5~9레벨: 4배 (역전)
  } else if (levelDiff >= 1) {
    levelMultiplier = 1.0 + (levelDiff * 0.4); // +1~4레벨: 1.4~2.6배
  } else if (levelDiff >= -4) {
    levelMultiplier = 1.0 + (levelDiff * 0.08); // -1~-4레벨: 0.68~0.92배 (유지)
  } else if (levelDiff >= -9) {
    levelMultiplier = 0.5; // -5~-9레벨 약적: 0.5배 (유지)
  } else {
    levelMultiplier = 0.3; // -10레벨 이상 약적: 0.3배 (유지)
  }

  // ========================================
  // 3️⃣ 등급 차이 보정 (상대 - 나) - 역전 잭팟!
  // ========================================
  double gradeMultiplier = 1.0;
  if (myGrade != null) {
    final gradeDiff = opponentGrade.index - myGrade.index;
    if (gradeDiff >= 4) {
      gradeMultiplier = 20.0; // 4등급 이상: 20배 (전설!)
    } else if (gradeDiff == 3) {
      gradeMultiplier = 12.0; // 3등급: 12배 (대역전)
    } else if (gradeDiff == 2) {
      gradeMultiplier = 5.0; // 2등급: 5배 (역전)
    } else if (gradeDiff == 1) {
      gradeMultiplier = 2.5; // 1등급: 2.5배
    } else if (gradeDiff == 0) {
      gradeMultiplier = 1.0; // 동급: 1배 (유지)
    } else if (gradeDiff == -1) {
      gradeMultiplier = 0.7; // 1등급 약적: 0.7배 (유지)
    } else if (gradeDiff == -2) {
      gradeMultiplier = 0.4; // 2등급 약적: 0.4배 (유지)
    } else {
      gradeMultiplier = 0.2; // 3등급 이상 약적: 0.2배 (유지)
    }
  }

  // ========================================
  // 4️⃣ 자연스러운 변동폭 (±15%)
  // ========================================
  // 99,112 / 103,655 / 123,111 같은 자연스러운 숫자
  final jitter = randomDouble(0.85, 1.15);

  // ========================================
  // 5️⃣ 최종 계산
  // ========================================
  final reward = (baseReward * levelMultiplier * gradeMultiplier * jitter)
      .round();

  // 최소 100G, 최대 500만G
  return math.max(100, math.min(5000000, reward));
}

/// 매칭 상대 찾기
List<T> findMatchingOpponents<T>(
  int playerPower,
  List<T> opponents,
  int Function(T) getPower,
) {
  if (opponents.isEmpty) return [];

  final minPower = (playerPower * 0.7).floor(); // ✅ 범위 확대
  final maxPower = (playerPower * 1.3).floor();

  final matched = opponents.where((o) {
    final power = getPower(o);
    return power >= minPower && power <= maxPower;
  }).toList();

  // ✅ 매칭 실패 시 가장 가까운 상대 반환
  if (matched.isEmpty && opponents.isNotEmpty) {
    opponents.sort(
      (a, b) => (getPower(a) - playerPower).abs().compareTo(
        (getPower(b) - playerPower).abs(),
      ),
    );
    return opponents.take(3).toList();
  }

  return matched;
}

double calculateElementMultiplier(GameElement attacker, GameElement defender) {
  return attacker.getMultiplierAgainst(defender);
}

int calculateDamage(int baseDamage, {double multiplier = 1.0}) {
  final variation = randomDouble(0.80, 1.20); // ✅ v10 밸런스 - 변동폭 확대
  return math.max(1, (baseDamage * multiplier * variation).floor());
}

// ===== 합성 로직 =====
bool canSynthesize(SwordGrade grade) {
  return grade != SwordGrade.immortal && grade != SwordGrade.hidden;
}

({SwordGrade to, double prob, int? ceiling})? _findSynthesisRule(
  SwordGrade from,
) {
  for (final rule in synthesisTable) {
    if (rule.$1 == from) {
      return (to: rule.$2, prob: rule.$3, ceiling: rule.$4);
    }
  }
  return null;
}

SwordGrade? getSynthesisResultGrade(SwordGrade from) {
  return _findSynthesisRule(from)?.to;
}

double? getSynthesisProbability(SwordGrade from) {
  return _findSynthesisRule(from)?.prob;
}

int? getSynthesisCeiling(SwordGrade from) {
  return _findSynthesisRule(from)?.ceiling;
}

// ===== 강화 로직 =====
/// ✅ 강화 비용 (레벨 0~29 → 레벨 1~30으로 강화)
int getEnhanceCost(int currentLevel) {
  if (currentLevel < 0) return 0;
  if (currentLevel >= 40) return 10000000;
  if (currentLevel >= 35) return 5000000;
  if (currentLevel >= 30) return 2000000;
  return enhanceTable[currentLevel].$2;
}

/// ✅ 강화 성공률 (퍼센트)
double getEnhanceSuccessRate(int currentLevel) {
  if (currentLevel < 0) return 0;
  if (currentLevel >= 40) return 0.1;
  if (currentLevel >= 35) return 0.5;
  if (currentLevel >= 30) return 1.0;
  return enhanceTable[currentLevel].$3.toDouble();
}

/// ✅ 강화 파괴율 (퍼센트)
double getEnhanceDestroyRate(int currentLevel) {
  if (currentLevel < 0) return 0;
  if (currentLevel >= 30) return 10.0;
  return enhanceTable[currentLevel].$4.toDouble();
}

/// 강화석 사용 시 보너스 (레벨별 차등 적용)
(double successRate, double destroyRate) getStoneBonus(
  double successRate,
  double destroyRate, {
  int level = 0,
}) {
  double successBonus;
  double destroyReduction;

  if (level >= 28) {
    // +28 이상: 극악 구간 - 효과 미미
    successBonus = 1.0;
    destroyReduction = 1.0;
  } else if (level >= 25) {
    // +25~+27: 후반 구간 - 효과 대폭 감소
    successBonus = 3.0;
    destroyReduction = 2.0;
  } else {
    // +24 이하: 일반 효과
    successBonus = 10.0;
    destroyReduction = 5.0;
  }

  return (
    math.min(successRate + successBonus, 100).toDouble(),
    math.max(destroyRate - destroyReduction, 0).toDouble(),
  );
}

// ===== 추가 유틸 =====
/// ✅ 퍼센트 포맷
String formatPercent(double value, {int decimals = 1}) {
  if (value == value.truncate()) {
    return '${value.truncate()}%';
  }
  return '${value.toStringAsFixed(decimals)}%';
}

/// ✅ 남은 시간 포맷
String formatRemainingTime(DateTime target) {
  final diff = target.difference(DateTime.now());
  if (diff.isNegative) return '완료';
  if (diff.inHours > 0) {
    return '${diff.inHours}시간 ${diff.inMinutes.remainder(60)}분';
  }
  if (diff.inMinutes > 0) {
    return '${diff.inMinutes}분 ${diff.inSeconds.remainder(60)}초';
  }
  return '${diff.inSeconds}초';
}
