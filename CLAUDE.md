# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Flutter-based mobile sword enhancement/collection game (검 강화 게임) with gacha mechanics, PvP battles, boss raids, and season pass systems. The game uses Firebase for authentication and data persistence.

## Development Commands

```bash
# Run the app
flutter run

# Run on specific device
flutter run -d windows
flutter run -d chrome
flutter run -d <device_id>

# Build
flutter build apk
flutter build ios
flutter build windows

# Get dependencies
flutter pub get

# Run tests
flutter test
flutter test test/widget_test.dart

# Analyze code
flutter analyze

# Generate app icons (after modifying assets/icon/app_icon.png)
flutter pub run flutter_launcher_icons
```

## Architecture

### Core Game Systems

- **Battle Engine** (`lib/utils/battle_engine.dart`): Turn-based combat system with element/skill type rock-paper-scissors, buffs/debuffs, DOT/HOT effects, and underdog bonus mechanics
- **Gacha System** (`lib/data/swords.dart`): 200 swords across 6 grades (normal → rare → unique → legend → hidden → immortal) with weighted probability tables
- **Enhancement System** (`lib/data/swords.dart:enhanceTable`): Level +1 to +30 with escalating costs, success rates, and destruction chances

### Data Flow

1. `AuthService` (singleton) manages Firebase Auth state
2. `FirestoreService` (singleton) handles cloud save/load with user document at `users/{uid}`
3. `StorageService` handles local caching via SharedPreferences
4. Game state is centralized in `GameScreen` which contains all tabs

### Key Enums

- `SwordGrade`: normal, rare, unique, legend, hidden, immortal
- `GameElement`: fire, water, nature, light, dark (rock-paper-scissors: fire→nature→water→fire, light↔dark)
- `SkillType`: slash, pierce, blast, drain, guard (rock-paper-scissors relationships)
- `SkillEffect`: damage, bleed, pierce, lifesteal, stun, regen, heal, shield, dodge, critBoost, attackBoost, weaken, slow

### Screen Structure

- `main.dart` → `AuthWrapper` → routes to `LoginScreen` or `OpeningScreen`
- `GameScreen` contains 5 tabs: Home, Battle, Enhance, Inventory, More
- Separate screens for boss raids, arena battles, season pass, shop, achievements, friends

### Services (all singletons)

- `AuthService`: Firebase authentication
- `FirestoreService`: Cloud Firestore data persistence
- `StorageService`: Local SharedPreferences storage
- `AdService`: Google AdMob integration
- `PurchaseService`: In-app purchases
- `SoundService`: Audio playback
- `FriendService`: Social features
- `OnlinePlayerService`: Real-time player matching

## Balance Constants (v13 - 검 강화하기 밸런스)

### 기본 전투 상수 (`lib/utils/battle_engine.dart`)
- HP: `baseHp = 2500`, `hpPerPower = 1.8`
- Damage: `baseDamage = 45`, `damagePerPower = 0.12`
- Element advantage: **1.04x / 0.96x** (승률 +5~6% 효과)
- Skill type advantage: 1.10x / 0.90x
- Underdog bonus: threshold 40, +10% per 100 diff, max +30%

### 등급별 레벨 보너스 (`gradeLevelBonus`)
| 등급 | 레벨 보너스 |
|------|------------|
| 일반 | +6 |
| 레어 | +7 |
| 유니크 | +8 |
| 전설 | +10 |
| 히든 | +13 |
| 불멸 | +17 |

### 등급별 기본 스탯 (`lib/data/swords.dart _SkillBalance`)
| 등급 | 기본ATK | 스킬발동률 | 스킬배율 | 효과수치 |
|------|--------|----------|---------|---------|
| 일반 | 78 | 30% | 1.25x | 10 |
| 레어 | 96 | 34% | 1.32x | 14 |
| 유니크 | 118 | 38% | 1.40x | 18 |
| 전설 | 148 | 43% | 1.50x | 23 |
| 히든 | 188 | 48% | 1.60x | 28 |
| 불멸 | 238 | 54% | 1.72x | 34 |

### 전투력 계산
```
Power = 기본ATK + (레벨 × 레벨보너스) + 칭호보너스
HP = 2500 + (Power × 1.8)
```

### 목표 승률 (밸런스 기준)
- **같은 레벨, 1등급 차이**: 하위 등급 20~30% 승률
- **같은 레벨, 2등급 차이**: 하위 등급 ~5% 승률
- **같은 레벨, 3등급 이상 차이**: 하위 등급 ~1% 이하
- **5레벨 차이, 1등급 차이**: 하위 10~15% 승률
- **속성 유리 시**: +5~6% 승률 추가

### +10 레벨 기준 전투력
| 등급 | 전투력 | HP |
|------|--------|-----|
| 일반 | 138 | 2748 |
| 레어 | 166 | 2799 |
| 유니크 | 198 | 2856 |
| 전설 | 248 | 2946 |
| 히든 | 318 | 3072 |
| 불멸 | 408 | 3234 |

## Language

The codebase uses Korean for:
- UI strings and variable naming comments
- Sword names and skill names
- Debug log messages

Code structure and variable names use English.
