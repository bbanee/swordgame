import 'package:flutter/material.dart';

enum SwordGrade { normal, rare, unique, legend, hidden, immortal }

extension SwordGradeExtension on SwordGrade {
  String get displayName => ['일반', '레어', '유니크', '전설', '히든', '불멸'][index];
  String get emoji => ['⚔️', '🗡️', '💎', '👑', '🔮', '⚡'][index];
  
  Color get color => [
    Colors.grey,
    Colors.blue,
    Colors.purple,
    Colors.orange,
    Colors.pink,
    Colors.red,
  ][index];
  
  Color get glowColor => [
    Colors.grey.withOpacity(0.3),
    Colors.blue.withOpacity(0.5),
    Colors.purple.withOpacity(0.6),
    Colors.orange.withOpacity(0.7),
    Colors.pink.withOpacity(0.8),
    Colors.red.withOpacity(0.9),
  ][index];
  
  int get skillCount => [2, 2, 2, 3, 3, 3][index];  // ✅ v10: 노말 1→2개
  
  // ✅ v10: 등급별 기본 스킬 발동률 (격차 축소: 30~45%)
  int get baseSkillProcRate => [30, 33, 36, 39, 42, 45][index];
  
  // ✅ v10: 등급별 스킬 배율 보너스 (격차 축소: 1.20~1.50x)
  double get skillMultiplierBonus => [1.20, 1.26, 1.32, 1.38, 1.44, 1.50][index];
  
  // 판매 기본가
  int get baseSellPrice => [100, 500, 2000, 10000, 50000, 200000][index];
  
  // 배틀 보상 배율
  double get battleBonus => [1.0, 1.2, 1.5, 2.0, 3.0, 5.0][index];
}