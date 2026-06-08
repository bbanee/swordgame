// lib/screens/minigame/minigame_models.dart

import 'package:flutter/material.dart';
import '../../enums/element.dart';
import '../../enums/skill_type.dart';

// ─────────────────────────────────────────
// 벽돌 종류
// ─────────────────────────────────────────
enum BrickType {
  normal,
  armored,
  explosive,
  healer,
  splitter,
  core,
  relay,
  cursed,
  miniBoss,
  boss,
}

extension BrickTypeExt on BrickType {
  String get emoji {
    switch (this) {
      case BrickType.normal:
        return '🧱';
      case BrickType.armored:
        return '🛡️';
      case BrickType.explosive:
        return '💣';
      case BrickType.healer:
        return '💚';
      case BrickType.splitter:
        return '🧬';
      case BrickType.core:
        return '🎯';
      case BrickType.relay:
        return '📡';
      case BrickType.cursed:
        return '☠️';
      case BrickType.miniBoss:
        return '👹';
      case BrickType.boss:
        return '💀';
    }
  }

  Color get color {
    switch (this) {
      case BrickType.normal:
        return Colors.blueGrey;
      case BrickType.armored:
        return Colors.teal;
      case BrickType.explosive:
        return Colors.deepOrange;
      case BrickType.healer:
        return Colors.green;
      case BrickType.splitter:
        return Colors.cyanAccent;
      case BrickType.core:
        return Colors.indigoAccent;
      case BrickType.relay:
        return Colors.purpleAccent;
      case BrickType.cursed:
        return Colors.deepPurple;
      case BrickType.miniBoss:
        return Colors.deepOrangeAccent;
      case BrickType.boss:
        return Colors.red;
    }
  }

  String get nameKr {
    switch (this) {
      case BrickType.normal:
        return '일반';
      case BrickType.armored:
        return '방어막';
      case BrickType.explosive:
        return '폭발';
      case BrickType.healer:
        return '회복';
      case BrickType.splitter:
        return '분열';
      case BrickType.core:
        return '핵심';
      case BrickType.relay:
        return '중계';
      case BrickType.cursed:
        return '저주';
      case BrickType.miniBoss:
        return '미니보스';
      case BrickType.boss:
        return '보스';
    }
  }
}

enum WaveEventType { tempest, frost, jackpot }

extension WaveEventTypeExt on WaveEventType {
  String get label {
    switch (this) {
      case WaveEventType.tempest:
        return '폭풍';
      case WaveEventType.frost:
        return '한기';
      case WaveEventType.jackpot:
        return '황금비';
    }
  }

  String get emoji {
    switch (this) {
      case WaveEventType.tempest:
        return '🌪️';
      case WaveEventType.frost:
        return '❄️';
      case WaveEventType.jackpot:
        return '💰';
    }
  }

  Color get color {
    switch (this) {
      case WaveEventType.tempest:
        return Colors.lightBlueAccent;
      case WaveEventType.frost:
        return Colors.cyanAccent;
      case WaveEventType.jackpot:
        return Colors.amber;
    }
  }

  String get description {
    switch (this) {
      case WaveEventType.tempest:
        return '벽돌 이동속도 증가, 탄 퍼짐 증가';
      case WaveEventType.frost:
        return '벽돌 이동속도 감소, 공격속도 감소';
      case WaveEventType.jackpot:
        return '파워업과 점수 보너스 증가';
    }
  }
}

enum WaveRewardType { sharpen, overclock, safeguard }

extension WaveRewardTypeExt on WaveRewardType {
  String get label {
    switch (this) {
      case WaveRewardType.sharpen:
        return '칼날 연마';
      case WaveRewardType.overclock:
        return '과속 회로';
      case WaveRewardType.safeguard:
        return '보호막 장치';
    }
  }

  String get emoji {
    switch (this) {
      case WaveRewardType.sharpen:
        return '⚔️';
      case WaveRewardType.overclock:
        return '⚡';
      case WaveRewardType.safeguard:
        return '🛡️';
    }
  }

  Color get color {
    switch (this) {
      case WaveRewardType.sharpen:
        return Colors.orangeAccent;
      case WaveRewardType.overclock:
        return Colors.yellowAccent;
      case WaveRewardType.safeguard:
        return Colors.greenAccent;
    }
  }

  String get description {
    switch (this) {
      case WaveRewardType.sharpen:
        return '이번 판 공격력 +8%';
      case WaveRewardType.overclock:
        return '이번 판 공격속도 +6%';
      case WaveRewardType.safeguard:
        return '실드 +1';
    }
  }
}

// ─────────────────────────────────────────
// 벽돌
// ─────────────────────────────────────────
class Brick {
  final String id;
  final BrickType type;
  final GameElement element;
  int maxHp;
  int hp;
  double x;
  double y;
  bool isShielded;
  bool isDead;
  int moveDir;
  bool isLinkedShielded;
  double gimmickTimer;

  // 직전 막기: 위험선 근처에서 황금색으로 반짝임
  bool isFlashing = false;

  Brick({
    required this.id,
    required this.type,
    required this.element,
    required this.maxHp,
    required this.x,
    required this.y,
    this.isShielded = false,
    this.moveDir = 1,
    this.isLinkedShielded = false,
    this.gimmickTimer = 0.0,
  }) : hp = maxHp,
       isDead = false;

  double get hpRatio => (hp / maxHp).clamp(0.0, 1.0);
}

// ─────────────────────────────────────────
// 투사체 종류
// ─────────────────────────────────────────
enum ProjectileKind { slash, pierce, blast, drain, guard, fragment }

extension ProjectileKindExt on SkillType {
  ProjectileKind get projectileKind {
    switch (this) {
      case SkillType.slash:
        return ProjectileKind.slash;
      case SkillType.pierce:
        return ProjectileKind.pierce;
      case SkillType.blast:
        return ProjectileKind.blast;
      case SkillType.drain:
        return ProjectileKind.drain;
      case SkillType.guard:
        return ProjectileKind.guard;
    }
  }
}

extension ProjectileKindStyle on ProjectileKind {
  Color get color {
    switch (this) {
      case ProjectileKind.slash:
        return Colors.white;
      case ProjectileKind.pierce:
        return Colors.lightBlueAccent;
      case ProjectileKind.blast:
        return Colors.orangeAccent;
      case ProjectileKind.drain:
        return Colors.purpleAccent;
      case ProjectileKind.guard:
        return Colors.tealAccent;
      case ProjectileKind.fragment:
        return Colors.yellowAccent;
    }
  }

  double get hitW {
    switch (this) {
      case ProjectileKind.slash:
        return 0.20;
      case ProjectileKind.pierce:
        return 0.04;
      case ProjectileKind.blast:
        return 0.12;
      case ProjectileKind.drain:
        return 0.09;
      case ProjectileKind.guard:
        return 0.10;
      case ProjectileKind.fragment:
        return 0.06;
    }
  }

  double get speed {
    switch (this) {
      case ProjectileKind.slash:
        return 0.8;
      case ProjectileKind.pierce:
        return 1.4;
      case ProjectileKind.blast:
        return 0.7;
      case ProjectileKind.drain:
        return 0.9;
      case ProjectileKind.guard:
        return 0.75;
      case ProjectileKind.fragment:
        return 1.1;
    }
  }

  bool get isPiercing => this == ProjectileKind.pierce;
}

// ─────────────────────────────────────────
// 투사체
// ─────────────────────────────────────────
class Projectile {
  final String id;
  final ProjectileKind kind;
  double x;
  double y;
  final int damage;
  bool isDead;
  final double dx; // 초당 X 이동량
  final double dy; // 초당 Y 이동량 (기본 -speed, fragment는 다방향)

  Projectile({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.damage,
    this.dx = 0,
    double? dy,
  }) : isDead = false,
       dy = dy ?? -kind.speed;
}

// ─────────────────────────────────────────
// 파워업 종류
// ─────────────────────────────────────────
enum PowerUpType { rapid, power, multiShot }

extension PowerUpTypeExt on PowerUpType {
  String get emoji {
    switch (this) {
      case PowerUpType.rapid:
        return '⚡';
      case PowerUpType.power:
        return '💥';
      case PowerUpType.multiShot:
        return '🌟';
    }
  }

  String get label {
    switch (this) {
      case PowerUpType.rapid:
        return '속공';
      case PowerUpType.power:
        return '강타';
      case PowerUpType.multiShot:
        return '다발';
    }
  }

  Color get color {
    switch (this) {
      case PowerUpType.rapid:
        return Colors.yellowAccent;
      case PowerUpType.power:
        return Colors.redAccent;
      case PowerUpType.multiShot:
        return Colors.purpleAccent;
    }
  }
}

// ─────────────────────────────────────────
// 파워업 아이템 (화면에 낙하)
// ─────────────────────────────────────────
class PowerUpItem {
  final String id;
  final PowerUpType type;
  double x;
  double y;
  bool isDead;

  PowerUpItem({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
  }) : isDead = false;
}

// ─────────────────────────────────────────
// 피격 이펙트 텍스트
// ─────────────────────────────────────────
class AttackEffect {
  final String id;
  double x;
  double y;
  final String text;
  final Color color;
  int ttl;

  AttackEffect({
    required this.id,
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    this.ttl = 35,
  });
}

// ─────────────────────────────────────────
// 미니게임 결과
// ─────────────────────────────────────────
class MinigameResult {
  final int wavesCleared;
  final int bricksDestroyed;
  final int goldEarned;
  final int stonesEarned;

  const MinigameResult({
    required this.wavesCleared,
    required this.bricksDestroyed,
    required this.goldEarned,
    required this.stonesEarned,
  });
}

// 호환용
enum AttackPattern { horizontal, vertical, aoe, drain, guard }

extension AttackPatternExt on SkillType {
  AttackPattern get pattern {
    switch (this) {
      case SkillType.slash:
        return AttackPattern.horizontal;
      case SkillType.pierce:
        return AttackPattern.vertical;
      case SkillType.blast:
        return AttackPattern.aoe;
      case SkillType.drain:
        return AttackPattern.drain;
      case SkillType.guard:
        return AttackPattern.guard;
    }
  }
}
