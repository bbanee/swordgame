import 'package:flutter/material.dart';

enum GameElement { fire, water, nature, light, dark }

extension GameElementExtension on GameElement {
  // ✅ nameKr로 변경 (Dart 내장 name과 충돌 방지)
  String get nameKr => ['불', '물', '자연', '빛', '암흑'][index];
  String get emoji => ['🔥', '💧', '🌿', '✨', '🌑'][index];
  
  Color get color => [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.amber,
    Colors.purple,
  ][index];
  
  // ✅ 올바른 상성 관계
  // 불 → 자연 (불이 풀을 태움)
  // 물 → 불 (물이 불을 끔)
  // 자연 → 물 (풀이 물을 흡수)
  // 빛 ↔ 암흑 (서로 상극)
  GameElement? get strongAgainst {
    switch (this) {
      case GameElement.fire: return GameElement.nature;
      case GameElement.water: return GameElement.fire;
      case GameElement.nature: return GameElement.water;
      case GameElement.light: return GameElement.dark;
      case GameElement.dark: return GameElement.light;
    }
  }
  
  GameElement? get weakAgainst {
    switch (this) {
      case GameElement.fire: return GameElement.water;
      case GameElement.water: return GameElement.nature;
      case GameElement.nature: return GameElement.fire;
      case GameElement.light: return GameElement.dark;
      case GameElement.dark: return GameElement.light;
    }
  }
  
  // ✅ 상성 배율 계산 (v12 밸런스 - 속성 상성 조정)
  // 유리한 속성이 +5~10% 승률 우위
  double getMultiplierAgainst(GameElement other) {
    if (strongAgainst == other) return 1.025;  // 유리: +2.5% 데미지
    if (weakAgainst == other) return 0.975;    // 불리: -2.5% 데미지
    return 1.0;  // 동등
  }
  
  // ✅ 상성 설명 텍스트
  String get advantageDescription {
    final strong = strongAgainst;
    final weak = weakAgainst;
    if (strong == weak) {
      // 빛/암흑의 경우
      return '$emoji ${strong?.emoji} 서로 상극';
    }
    return '$emoji → ${strong?.emoji} 유리 | ${weak?.emoji} → $emoji 불리';
  }
}