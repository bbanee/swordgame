import 'package:flutter/material.dart';
import '../data/season_pass_rewards.dart';
import '../utils/helpers.dart';

class SeasonPassScreen extends StatefulWidget {
  final int level;
  final int exp;
  final int expPerLevel;
  final int maxLevel;
  final Set<int> claimedRewards;
  final bool hasPremiumPass;
  final Set<int> claimedPremiumRewards;
  final int diamond;
  final int todaySeasonExp;  // ✅ 추가: 오늘 획득한 EXP
  final int maxDailySeasonExp;  // ✅ 추가: 하루 상한
  final void Function(int level) onClaimFreeReward;
  final void Function(int level) onClaimPremiumReward;
  final VoidCallback onBuyPremiumPass;

  const SeasonPassScreen({
    super.key,
    required this.level,
    required this.exp,
    required this.expPerLevel,
    required this.maxLevel,
    required this.claimedRewards,
    required this.hasPremiumPass,
    required this.claimedPremiumRewards,
    required this.diamond,
    this.todaySeasonExp = 0,  // ✅ 기본값
    this.maxDailySeasonExp = 300,  // ✅ 기본값
    required this.onClaimFreeReward,
    required this.onClaimPremiumReward,
    required this.onBuyPremiumPass,
  });

  @override
  State<SeasonPassScreen> createState() => _SeasonPassScreenState();
}

class _SeasonPassScreenState extends State<SeasonPassScreen> {
  late final rewards = getSeasonPassRewards(maxLevel: widget.maxLevel);
  late Set<int> _localClaimedFree;
  late Set<int> _localClaimedPremium;
  late bool _localHasPremium;

  @override
  void initState() {
    super.initState();
    _localClaimedFree = Set.from(widget.claimedRewards);
    _localClaimedPremium = Set.from(widget.claimedPremiumRewards);
    _localHasPremium = widget.hasPremiumPass;
  }
  
  // ✅ 수령 가능한 일반 보상 수
  int get _claimableFreeCount {
    return rewards.where((r) => 
      widget.level >= r.level && !_localClaimedFree.contains(r.level)
    ).length;
  }
  
  // ✅ 수령 가능한 프리미엄 보상 수
  int get _claimablePremiumCount {
    if (!_localHasPremium) return 0;
    return rewards.where((r) => 
      widget.level >= r.level && !_localClaimedPremium.contains(r.level)
    ).length;
  }
  
  // ✅ 전체 수령 가능 수
  int get _totalClaimableCount => _claimableFreeCount + _claimablePremiumCount;
  
  // ✅ 모두 수령
  void _claimAll() {
    // 일반 보상 수령
    for (final r in rewards) {
      if (widget.level >= r.level && !_localClaimedFree.contains(r.level)) {
        widget.onClaimFreeReward(r.level);
        _localClaimedFree.add(r.level);
      }
    }
    
    // 프리미엄 보상 수령
    if (_localHasPremium) {
      for (final r in rewards) {
        if (widget.level >= r.level && !_localClaimedPremium.contains(r.level)) {
          widget.onClaimPremiumReward(r.level);
          _localClaimedPremium.add(r.level);
        }
      }
    }
    
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final progress = (widget.expPerLevel <= 0)
        ? 0.0
        : (widget.exp / widget.expPerLevel).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('시즌 패스'),
        actions: [
          // ✅ 모두 수령 버튼
          if (_totalClaimableCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed: _claimAll,
                icon: const Icon(Icons.done_all, color: Colors.amber, size: 18),
                label: Text(
                  '모두 수령 ($_totalClaimableCount)',
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.amber.withOpacity(0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          if (!_localHasPremium)
            TextButton.icon(
              onPressed: _showBuyPremiumDialog,
              icon: const Icon(Icons.workspace_premium, color: Colors.amber, size: 18),
              label: const Text('₩11,000',
                  style: TextStyle(color: Colors.amber, fontSize: 12)),
            ),
        ],
      ),
      body: Column(
        children: [
          _header(progress),
          if (!_localHasPremium) _premiumBanner(),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rewards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _rewardTile(rewards[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(double progress) {
    final bool isMaxed = widget.todaySeasonExp >= widget.maxDailySeasonExp;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.confirmation_num, color: Colors.amber),
              const SizedBox(width: 8),
              Text('Lv.${widget.level}', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (_localHasPremium) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: const Text('👑 PREMIUM', 
                      style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
              const Spacer(),
              Text('EXP ${formatNumber(widget.exp)}', 
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white10,
            ),
          ),
          const SizedBox(height: 8),
          // ✅ 추가: 오늘 획득한 EXP / 상한 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isMaxed ? Colors.orange.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isMaxed ? Colors.orange.withOpacity(0.5) : Colors.blue.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isMaxed ? Icons.check_circle : Icons.today,
                  color: isMaxed ? Colors.orange : Colors.blue,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  isMaxed 
                      ? '오늘 EXP 상한 도달! (${widget.maxDailySeasonExp}/${widget.maxDailySeasonExp})'
                      : '오늘 ${widget.todaySeasonExp}/${widget.maxDailySeasonExp} EXP 획득',
                  style: TextStyle(
                    color: isMaxed ? Colors.orange : Colors.blue[300],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.withOpacity(0.3), Colors.orange.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Text('👑', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('프리미엄 패스', 
                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                Text('더 많은 보상을 받으세요!', 
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _showBuyPremiumDialog,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('₩11,000',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBuyPremiumDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: const Text('👑 프리미엄 패스 구매', style: TextStyle(color: Colors.amber)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('가격: ₩11,000',
                style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            const Text('프리미엄 혜택:', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            _benefitItem('매 레벨 추가 골드 (4배)'),
            _benefitItem('매 레벨 강화석 5~8개'),
            _benefitItem('매 레벨 다이아 7개'),
            _benefitItem('3레벨마다 다이아 +10'),
            _benefitItem('5레벨마다 다이아 +18'),
            _benefitItem('10레벨마다 다이아 +55'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);  // 다이얼로그 닫기
              Navigator.pop(context);  // 시즌패스 화면 닫기
              widget.onBuyPremiumPass();  // 인앱 결제 시작
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('구매하기', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _benefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(  // ✅ overflow 방지
            child: Text(text, style: TextStyle(color: Colors.grey[300], fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _rewardTile(SeasonPassReward r) {
    final reached = widget.level >= r.level;
    final freeClaimed = _localClaimedFree.contains(r.level);
    final premiumClaimed = _localClaimedPremium.contains(r.level);

    return Container(
      padding: const EdgeInsets.all(10),  // ✅ padding 줄임
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: reached && (!freeClaimed || (_localHasPremium && !premiumClaimed))
              ? Colors.amber.withOpacity(0.5)
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          // 레벨 표시
          Container(
            width: 40,  // ✅ 크기 줄임
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: reached ? Colors.amber.withOpacity(0.2) : Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${r.level}',  // ✅ 'Lv.' 제거
              style: TextStyle(
                color: reached ? Colors.amber : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 6),
          
          // 일반 보상
          Expanded(
            child: _rewardColumn(
              label: '일반',
              chips: _buildChips(r.gold, r.diamond, r.stone),
              claimed: freeClaimed,
              canClaim: reached && !freeClaimed,
              onClaim: () {
                widget.onClaimFreeReward(r.level);
                setState(() => _localClaimedFree.add(r.level));
              },
            ),
          ),
          
          Container(width: 1, height: 50, color: Colors.white10),
          const SizedBox(width: 6),
          
          // 프리미엄 보상
          Expanded(
            child: _rewardColumn(
              label: '👑 프리미엄',
              chips: _buildChips(r.premiumGold, r.premiumDiamond, r.premiumStone),
              claimed: premiumClaimed,
              canClaim: _localHasPremium && reached && !premiumClaimed,
              locked: !_localHasPremium,
              onClaim: () {
                widget.onClaimPremiumReward(r.level);
                setState(() => _localClaimedPremium.add(r.level));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardColumn({
    required String label,
    required List<Widget> chips,
    required bool claimed,
    required bool canClaim,
    bool locked = false,
    required VoidCallback onClaim,
  }) {
    return Column(
      children: [
        Text(label, style: TextStyle(
          color: locked ? Colors.grey : (label.contains('프리미엄') ? Colors.amber : Colors.white70),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        )),
        const SizedBox(height: 4),
        // ✅ overflow 방지: SingleChildScrollView + 제한된 높이
        SizedBox(
          height: 22,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: chips.map((chip) => Padding(
                padding: const EdgeInsets.only(right: 3),
                child: chip,
              )).toList(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 26,
          child: locked
              ? const Icon(Icons.lock, color: Colors.grey, size: 16)
              : ElevatedButton(
                  onPressed: canClaim ? onClaim : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canClaim ? Colors.amber : null,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    claimed ? '✓' : '수령',
                    style: TextStyle(
                      color: claimed ? Colors.white54 : Colors.black,
                      fontSize: 11,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> _buildChips(int gold, int diamond, int stone) {
    final chips = <Widget>[];
    if (gold > 0) chips.add(_chip('🪙', _formatShort(gold)));  // ✅ 축약 포맷
    if (diamond > 0) chips.add(_chip('💎', '$diamond'));
    if (stone > 0) chips.add(_chip('🔮', '$stone'));
    return chips;
  }

  // ✅ 추가: 숫자 축약 (1,000 → 1K)
  String _formatShort(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return '$value';
  }

  Widget _chip(String icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),  // ✅ padding 줄임
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$icon$text', style: const TextStyle(color: Colors.white70, fontSize: 9)),  // ✅ 폰트 줄임
    );
  }
}
