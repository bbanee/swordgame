import 'package:flutter/material.dart';

enum TitleGrade { normal, rare, legend, hidden }

extension TitleGradeExtension on TitleGrade {
  Color get color => [
    Colors.grey,
    Colors.blue,
    Colors.orange,
    Colors.pink,
  ][index];
}

class TitleData {
  final String id;
  final String name;
  final String description;
  final TitleGrade grade;
  final int bonus; // 공격력 보너스
  final String condition; // 획득 조건 키
  final bool isHidden;
  
  const TitleData({
    required this.id,
    required this.name,
    required this.description,
    required this.grade,
    required this.bonus,
    required this.condition,
    this.isHidden = false,
  });
  
  // 표시용 이름 (히든은 ??? 처리)
  String getDisplayName(bool isUnlocked) {
    if (isHidden && !isUnlocked) return '???';
    return name;
  }
  
  // 표시용 설명
  String getDisplayDescription(bool isUnlocked) {
    if (isHidden && !isUnlocked) return '???';
    return description;
  }
}