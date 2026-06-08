// lib/screens/tabs/more_tab.dart
// 더보기 탭 UI - GameScreen에서 분리

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/ad_service.dart';
import '../../utils/constants.dart';

class MoreTab extends StatelessWidget {
  // 콜백들
  final VoidCallback onShowGachaDialog;
  final VoidCallback onShowSynthesisDialog;
  final VoidCallback onShowBossSelectDialog;
  final VoidCallback onOpenShopScreen;
  final VoidCallback onOpenSeasonPassScreen;
  final VoidCallback onOpenAchievementsScreen;
  final VoidCallback onShowRankingDialog;
  final VoidCallback onOpenFriendsScreen;
  final VoidCallback onShowTitleDialog;
  final VoidCallback onShowCodexDialog;
  final VoidCallback onShowStatsDialog;
  final VoidCallback onShowHelpDialog;
  final VoidCallback onShowSettingsDialog;
  final VoidCallback onShowLogoutDialog;
  final VoidCallback onShowDeleteAccountDialog;
  final VoidCallback onWatchAdForFreeGacha;
  final VoidCallback onWatchAdForStones;
  final VoidCallback onOpenMinigame;

  const MoreTab({
    super.key,
    required this.onShowGachaDialog,
    required this.onShowSynthesisDialog,
    required this.onShowBossSelectDialog,
    required this.onOpenShopScreen,
    required this.onOpenSeasonPassScreen,
    required this.onOpenAchievementsScreen,
    required this.onShowRankingDialog,
    required this.onOpenFriendsScreen,
    required this.onShowTitleDialog,
    required this.onShowCodexDialog,
    required this.onShowStatsDialog,
    required this.onShowHelpDialog,
    required this.onShowSettingsDialog,
    required this.onShowLogoutDialog,
    required this.onShowDeleteAccountDialog,
    required this.onWatchAdForFreeGacha,
    required this.onWatchAdForStones,
    required this.onOpenMinigame,
  });

  @override
  Widget build(BuildContext context) {
    final adService = AdService();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMoreItem('🎮', '미니게임', '벽돌 깨기 - 저등급 검도 활약!', onOpenMinigame),
        _buildMoreItem('🎰', '검 뽑기', '새로운 검을 뽑아보세요', onShowGachaDialog),
        _buildMoreItem('🔄', '합성', '검 3개로 상위 등급 도전', onShowSynthesisDialog),
        _buildMoreItem('🐉', '보스 레이드', '강력한 보스에 도전', onShowBossSelectDialog),

        _buildMoreItem('🏪', '상점', '아이템 구매/인벤 확장', onOpenShopScreen),
        _buildMoreItem('🎟️', '시즌 패스', '보상 확인 및 수령', onOpenSeasonPassScreen),
        _buildMoreItem('🏅', '업적', '업적/보상 확인', onOpenAchievementsScreen),

        _buildMoreItem('🏆', '랭킹', '전체 순위 확인', onShowRankingDialog),
        _buildMoreItem('👥', '친구', '친구 추가/관리', onOpenFriendsScreen),
        _buildMoreItem('🎖️', '칭호', '획득한 칭호 관리', onShowTitleDialog),
        _buildMoreItem('📚', '도감', '수집한 검 도감', onShowCodexDialog),
        _buildMoreItem('📊', '통계', '게임 통계', onShowStatsDialog),

        const SizedBox(height: 16),
        const Divider(color: Colors.white24),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '🎬 광고 보상',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),

        _buildAdRewardItem(
          '💎',
          '무료 고급 뽑기',
          '광고 보고 다이아 뽑기 1회!',
          adService.getRemainingAdCount(AdRewardType.freeGacha),
          1,
          adService.canWatchAd(AdRewardType.freeGacha),
          onWatchAdForFreeGacha,
        ),

        _buildAdRewardItem(
          '🪨',
          '강화석 획득',
          '광고 보고 강화석 3개 획득!',
          adService.getRemainingAdCount(AdRewardType.stoneReward),
          3,
          adService.canWatchAd(AdRewardType.stoneReward),
          onWatchAdForStones,
        ),

        const SizedBox(height: 16),
        const Divider(color: Colors.white24),
        const SizedBox(height: 8),

        _buildMoreItem(
          '🌐',
          '공식 웹사이트',
          '공지사항 및 업데이트 정보',
          () => _launchUrl('https://www.opentheday.site/'),
        ),
        _buildMoreItem('❓', '도움말', '게임 가이드 및 속성 상성표', onShowHelpDialog),
        _buildMoreItem('⚙️', '설정', '사운드, 알림 설정', onShowSettingsDialog),
        _buildMoreItem('🚪', '로그아웃', '계정에서 로그아웃', onShowLogoutDialog),
        _buildMoreItem(
          '❌',
          '계정 삭제',
          '계정 및 모든 데이터 삭제',
          onShowDeleteAccountDialog,
        ),
      ],
    );
  }

  void _launchUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _buildMoreItem(
    String icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildAdRewardItem(
    String icon,
    String title,
    String sub,
    int remaining,
    int max,
    bool canWatch,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: canWatch ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: canWatch
              ? LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.2),
                    Colors.blue.withOpacity(0.2),
                  ],
                )
              : null,
          color: canWatch ? null : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canWatch
                ? Colors.green.withOpacity(0.5)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: canWatch ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      color: canWatch ? Colors.white54 : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: canWatch ? Colors.green : Colors.grey,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                canWatch ? '🎬 $remaining/$max' : '완료',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
