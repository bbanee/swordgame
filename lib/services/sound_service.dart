// lib/services/sound_service.dart
// 🔊 게임 사운드 서비스

import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  // 오디오 플레이어
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  
  // 설정
  bool _bgmEnabled = true;
  bool _sfxEnabled = true;
  double _bgmVolume = 0.5;
  double _sfxVolume = 0.7;
  
  // 현재 BGM
  String? _currentBgm;
  
  bool get bgmEnabled => _bgmEnabled;
  bool get sfxEnabled => _sfxEnabled;
  double get bgmVolume => _bgmVolume;
  double get sfxVolume => _sfxVolume;

  // =====================================================
  // 사운드 파일 경로
  // =====================================================
  static const String _soundPath = 'sounds/';
  
  // BGM
  static const String bgmMain = '${_soundPath}bgm_main.mp3';
  static const String bgmBattle = '${_soundPath}bgm_battle.mp3';
  static const String bgmBoss = '${_soundPath}bgm_boss.mp3';
  
  // 효과음
  static const String sfxEnhanceSuccess = '${_soundPath}enhance_success.mp3';
  static const String sfxEnhanceFail = '${_soundPath}enhance_fail.mp3';
  static const String sfxDestroy = '${_soundPath}destroy.mp3';
  static const String sfxGacha = '${_soundPath}gacha.mp3';
  static const String sfxGachaRare = '${_soundPath}gacha_rare.mp3';
  static const String sfxBattleWin = '${_soundPath}battle_win.mp3';
  static const String sfxBattleLose = '${_soundPath}battle_lose.mp3';
  static const String sfxBattleHit = '${_soundPath}battle_hit.mp3';
  static const String sfxClick = '${_soundPath}click.mp3';
  static const String sfxReward = '${_soundPath}reward.mp3';
  static const String sfxSell = '${_soundPath}sell.mp3';
  static const String sfxEquip = '${_soundPath}equip.mp3';

  // =====================================================
  // 초기화
  // =====================================================
  
  Future<void> initialize() async {
    await _loadSettings();
    
    // BGM 루프 설정 (일부 삼성 기기에서 소스 없이 설정 시 크래시 방지)
    try {
      _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      _bgmPlayer.setVolume(_bgmEnabled ? _bgmVolume : 0);
    } catch (e) {
      debugPrint('⚠️ AudioPlayer 초기 설정 실패 (무시): $e');
    }
    
    debugPrint('✅ SoundService 초기화 완료');
  }

  // =====================================================
  // 설정 관리
  // =====================================================
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _bgmEnabled = prefs.getBool('bgm_enabled') ?? true;
    _sfxEnabled = prefs.getBool('sfx_enabled') ?? true;
    _bgmVolume = prefs.getDouble('bgm_volume') ?? 0.5;
    _sfxVolume = prefs.getDouble('sfx_volume') ?? 0.7;
  }
  
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bgm_enabled', _bgmEnabled);
    await prefs.setBool('sfx_enabled', _sfxEnabled);
    await prefs.setDouble('bgm_volume', _bgmVolume);
    await prefs.setDouble('sfx_volume', _sfxVolume);
  }
  
  // BGM 설정
  Future<void> setBgmEnabled(bool enabled) async {
    _bgmEnabled = enabled;
    if (enabled) {
      _bgmPlayer.setVolume(_bgmVolume);
      // 이전에 재생 중이던 BGM 다시 재생
      if (_currentBgm != null) {
        final bgmToPlay = _currentBgm!;
        _currentBgm = null;  // playBgm 내부의 중복 체크 우회
        await playBgm(bgmToPlay);
      }
    } else {
      _bgmPlayer.setVolume(0);
      await _bgmPlayer.pause();
    }
    await _saveSettings();
  }
  
  // 효과음 설정
  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    await _saveSettings();
  }
  
  // BGM 볼륨
  Future<void> setBgmVolume(double volume) async {
    _bgmVolume = volume.clamp(0.0, 1.0);
    if (_bgmEnabled) {
      _bgmPlayer.setVolume(_bgmVolume);
    }
    await _saveSettings();
  }
  
  // 효과음 볼륨
  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume.clamp(0.0, 1.0);
    await _saveSettings();
  }

  // =====================================================
  // BGM 재생
  // =====================================================
  
  Future<void> playBgm(String assetPath) async {
    if (!_bgmEnabled) {
      _currentBgm = assetPath;  // 나중에 켜면 재생할 수 있도록 저장
      return;
    }
    
    // 이미 같은 BGM 재생 중이면 스킵
    if (_currentBgm == assetPath) return;
    
    try {
      await _bgmPlayer.stop();
      _currentBgm = assetPath;
      await _bgmPlayer.play(AssetSource(assetPath));
      debugPrint('🎵 BGM 재생: $assetPath');
    } catch (e) {
      debugPrint('❌ BGM 재생 실패: $e');
    }
  }
  
  Future<void> stopBgm() async {
    _currentBgm = null;
    await _bgmPlayer.stop();
  }
  
  Future<void> pauseBgm() async {
    await _bgmPlayer.pause();
  }
  
  Future<void> resumeBgm() async {
    if (_bgmEnabled && _currentBgm != null) {
      await _bgmPlayer.resume();
    }
  }
  
  // 🎵 메인 BGM
  Future<void> playMainBgm() async {
    await playBgm(bgmMain);
  }
  
  // 🎵 배틀 BGM
  Future<void> playBattleBgm() async {
    await playBgm(bgmBattle);
  }
  
  // 🎵 보스 BGM
  Future<void> playBossBgm() async {
    await playBgm(bgmBoss);
  }

  // =====================================================
  // 효과음 재생
  // =====================================================
  
  Future<void> playSfx(String assetPath) async {
    if (!_sfxEnabled) return;
    
    try {
      await _sfxPlayer.setVolume(_sfxVolume);
      await _sfxPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('❌ 효과음 재생 실패: $e');
    }
  }
  
  // 🔊 강화 성공
  Future<void> playEnhanceSuccess() async {
    await playSfx(sfxEnhanceSuccess);
  }
  
  // 🔊 강화 실패
  Future<void> playEnhanceFail() async {
    await playSfx(sfxEnhanceFail);
  }
  
  // 🔊 파괴
  Future<void> playDestroy() async {
    await playSfx(sfxDestroy);
  }
  
  // 🔊 뽑기
  Future<void> playGacha() async {
    await playSfx(sfxGacha);
  }
  
  // 🔊 레어 뽑기 (유니크 이상)
  Future<void> playGachaRare() async {
    await playSfx(sfxGachaRare);
  }
  
  // 🔊 배틀 승리
  Future<void> playBattleWin() async {
    await playSfx(sfxBattleWin);
  }
  
  // 🔊 배틀 패배
  Future<void> playBattleLose() async {
    await playSfx(sfxBattleLose);
  }
  
  // 🔊 배틀 타격
  Future<void> playBattleHit() async {
    await playSfx(sfxBattleHit);
  }
  
  // 🔊 버튼 클릭
  Future<void> playClick() async {
    await playSfx(sfxClick);
  }
  
  // 🔊 보상 획득
  Future<void> playReward() async {
    await playSfx(sfxReward);
  }
  
  // 🔊 판매
  Future<void> playSell() async {
    await playSfx(sfxSell);
  }
  
  // 🔊 장착
  Future<void> playEquip() async {
    await playSfx(sfxEquip);
  }

  // =====================================================
  // 리소스 정리
  // =====================================================
  
  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
  }
}
