import 'package:flutter/material.dart';

import '../data/achievements.dart';
import '../models/achievement_data.dart';
import '../utils/helpers.dart';

class AchievementsScreen extends StatefulWidget {
  final Map<String, int> stats;
  final Set<String> unlocked;
  final Set<String> claimed;
  final void Function(AchievementData ach) onClaim;

  const AchievementsScreen({
    super.key,
    required this.stats,
    required this.unlocked,
    required this.claimed,
    required this.onClaim,
  });

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final List<AchievementData> _all = getAllAchievements();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: AchievementCategory.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  int _stat(String key) => widget.stats[key] ?? 0;
  
  // ✅ 수령 가능한 업적 목록
  List<AchievementData> get _claimableAchievements {
    return _all.where((a) => 
      widget.unlocked.contains(a.id) && !widget.claimed.contains(a.id)
    ).toList();
  }
  
  // ✅ 모두 수령
  void _claimAll() {
    final claimable = _claimableAchievements;
    if (claimable.isEmpty) return;
    
    for (final ach in claimable) {
      widget.onClaim(ach);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final claimableCount = _claimableAchievements.length;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('업적'),
        actions: [
          // ✅ 모두 수령 버튼
          if (claimableCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _claimAll,
                icon: const Icon(Icons.done_all, color: Colors.amber),
                label: Text(
                  '모두 수령 ($claimableCount)',
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.amber.withOpacity(0.15),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: AchievementCategory.values
              .map((c) => Tab(text: _catName(c)))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: AchievementCategory.values.map((c) {
          final items = _all.where((a) => a.category == c).toList();
          return _buildList(items);
        }).toList(),
      ),
    );
  }

  String _catName(AchievementCategory c) {
    switch (c) {
      case AchievementCategory.enhance:
        return '강화';
      case AchievementCategory.battle:
        return '배틀';
      case AchievementCategory.boss:
        return '보스';
      case AchievementCategory.collection:
        return '수집';
      case AchievementCategory.economy:
        return '경제';
      case AchievementCategory.attendance:
        return '출석';
      case AchievementCategory.misc:
        return '기타';
    }
  }

  Widget _buildList(List<AchievementData> items) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = items[i];
        final unlocked = widget.unlocked.contains(a.id);
        final claimed = widget.claimed.contains(a.id);

        final v = _stat(a.statsKey);
        final progress = a.target <= 0 ? 0.0 : (v / a.target).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: a.categoryColor.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: a.categoryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      a.categoryName,
                      style: TextStyle(
                        color: a.categoryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      a.name,
                      style: TextStyle(
                        color: unlocked ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (claimed)
                    const Icon(Icons.check_circle, color: Colors.greenAccent)
                  else if (unlocked)
                    const Icon(Icons.emoji_events, color: Colors.amber)
                  else
                    const Icon(Icons.lock, color: Colors.white30),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                a.description,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white10,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${formatNumber(v)} / ${formatNumber(a.target)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const Spacer(),
                  _rewardChips(a),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (!unlocked || claimed)
                      ? null
                      : () {
                          widget.onClaim(a);
                          setState(() {});
                        },
                  child: Text(
                    claimed ? '수령 완료' : (unlocked ? '보상 수령' : '미달성'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rewardChips(AchievementData a) {
    final chips = <Widget>[];
    if (a.rewardGold > 0) chips.add(_chip('🪙', formatNumber(a.rewardGold)));
    if (a.rewardDiamond > 0) chips.add(_chip('💎', formatNumber(a.rewardDiamond)));
    if (a.rewardStone > 0) chips.add(_chip('🔮', formatNumber(a.rewardStone)));
    return Wrap(spacing: 6, children: chips);
  }

  Widget _chip(String icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$icon $text',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
