import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../data/npcs.dart';
import '../data/swords.dart';
import '../enums/sword_grade.dart';
import '../enums/element.dart';
import '../models/player_profile.dart';
import '../models/sword_data.dart';
import '../services/online_player_service.dart';
import '../services/friend_service.dart';
import '../utils/constants.dart';
import '../widgets/sword_image_widget.dart';

class OpponentEntry {
  final String id;
  final String name;
  final SwordData sword;
  final int swordLevel;
  final int swordBreakthroughLevel;
  final bool isNpc;
  final bool isFriend;
  final String platform; // 'google' or 'toss'

  const OpponentEntry({
    required this.id,
    required this.name,
    required this.sword,
    required this.swordLevel,
    this.swordBreakthroughLevel = 0,
    required this.isNpc,
    this.isFriend = false,
    this.platform = 'google',
  });

  int get power => sword.baseAtk + swordLevel * 10;
}

class BattleSelectScreen extends StatefulWidget {
  final OnlinePlayerService? online;
  final String myUserId;
  final List<String> friendIds;
  final GameElement? myElement;

  const BattleSelectScreen({
    super.key,
    required this.online,
    required this.myUserId,
    required this.friendIds,
    this.myElement,
  });

  @override
  State<BattleSelectScreen> createState() => _BattleSelectScreenState();
}

class _BattleSelectScreenState extends State<BattleSelectScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  final _friendService = FriendService();

  bool _loadingFriends = true;
  bool _loadingRankings = true;
  List<OpponentEntry> _friends = [];
  List<OpponentEntry> _onlinePlayers = []; // ✅ 온라인 유저 분리
  List<OpponentEntry> _npcs = []; // ✅ NPC 분리

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _refreshingFriends = false; // 🔥 친구 새로고침 상태
  bool _refreshingRankings = false; // 🔥 랭킹 새로고침 상태

  Future<void> _load() async {
    setState(() {
      _loadingFriends = true;
      _loadingRankings = true;
      _npcs = _buildNpcEntries();
    });

    unawaited(_loadFriends());
    unawaited(_loadRankings());
  }

  Future<void> _loadFriends() async {
    final friendEntries = <OpponentEntry>[];
    try {
      final friendProfiles = await _friendService.getFriendProfiles();
      for (final p in friendProfiles) {
        friendEntries.add(_fromProfile(p, isFriend: true));
      }
      // ✅ v10.4: 검레벨 > 검등급 > 공격력 순 정렬
      friendEntries.sort((a, b) {
        final levelCmp = b.swordLevel.compareTo(a.swordLevel);
        if (levelCmp != 0) return levelCmp;
        final gradeCmp = b.sword.grade.index.compareTo(a.sword.grade.index);
        if (gradeCmp != 0) return gradeCmp;
        return b.power.compareTo(a.power);
      });
    } catch (e) {
      debugPrint('⚠️ 친구 목록 로드 실패: ');
    }

    if (!mounted) return;
    setState(() {
      _friends = friendEntries;
      _loadingFriends = false;
    });
  }

  Future<void> _loadRankings() async {
    final onlineEntries = <OpponentEntry>[];

    final online = widget.online;
    if (online != null) {
      try {
        final players = await online.fetchTopRankings(
          limit: 51,
          forceRefresh: true,
        );
        onlineEntries.addAll(
          players
              .where((p) => p.userId != widget.myUserId)
              .map((p) => _fromProfile(p)),
        );
        // ✅ 서버 정렬(레벨) 결과를 그대로 사용
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _onlinePlayers = onlineEntries;
      _loadingRankings = false;
    });
  }

  List<OpponentEntry> _buildNpcEntries() {
    final npcEntries = <OpponentEntry>[];
    // ✅ NPC는 별도 리스트로 (전투력 정렬)
    npcEntries.addAll(
      npcPlayers.take(20).map((n) {
        return OpponentEntry(
          id: n.id,
          name: n.name, // ✅ (AI) 제거 - 아래에서 표시
          sword: n.sword,
          swordLevel: n.swordLevel,
          swordBreakthroughLevel: 0,
          isNpc: true,
        );
      }),
    );
    // ✅ v10.4: 검레벨 > 검등급 > 공격력 순 정렬
    npcEntries.sort((a, b) {
      final levelCmp = b.swordLevel.compareTo(a.swordLevel);
      if (levelCmp != 0) return levelCmp;
      final gradeCmp = b.sword.grade.index.compareTo(a.sword.grade.index);
      if (gradeCmp != 0) return gradeCmp;
      return b.power.compareTo(a.power);
    });
    return npcEntries;
  }

  // 🔥 친구 목록만 새로고침 (강제 캐시 무효화)
  Future<void> _refreshFriends() async {
    if (_refreshingFriends) return;

    setState(() => _refreshingFriends = true);

    try {
      final friendProfiles = await _friendService.getFriendProfiles(
        forceRefresh: true,
      );
      final friendEntries = <OpponentEntry>[];

      for (final p in friendProfiles) {
        friendEntries.add(_fromProfile(p, isFriend: true));
      }

      friendEntries.sort((a, b) {
        final levelCmp = b.swordLevel.compareTo(a.swordLevel);
        if (levelCmp != 0) return levelCmp;
        final gradeCmp = b.sword.grade.index.compareTo(a.sword.grade.index);
        if (gradeCmp != 0) return gradeCmp;
        return b.power.compareTo(a.power);
      });

      setState(() => _friends = friendEntries);
    } catch (e) {
      debugPrint('⚠️ 친구 새로고침 실패: $e');
    } finally {
      setState(() => _refreshingFriends = false);
    }
  }

  // 🔥 랭킹 목록 새로고침 (강제 캐시 무효화)
  Future<void> _refreshRankings() async {
    if (_refreshingRankings || _loadingRankings) return;
    final online = widget.online;
    if (online == null) return;

    setState(() => _refreshingRankings = true);

    try {
      final players = await online.fetchTopRankings(
        limit: 51,
        forceRefresh: true,
      );
      final onlineEntries = <OpponentEntry>[];

      onlineEntries.addAll(
        players
            .where((p) => p.userId != widget.myUserId)
            .map((p) => _fromProfile(p)),
      );

      // ✅ 서버 정렬(레벨) 결과를 그대로 사용

      setState(() => _onlinePlayers = onlineEntries);
    } catch (e) {
      debugPrint('⚠️ 랭킹 새로고침 실패: $e');
    } finally {
      setState(() => _refreshingRankings = false);
    }
  }

  OpponentEntry _fromProfile(PlayerProfile p, {bool isFriend = false}) {
    return OpponentEntry(
      id: p.userId,
      name: p.nickname,
      sword: p.sword,
      swordLevel: p.swordLevel,
      swordBreakthroughLevel: p.swordBreakthroughLevel,
      isNpc: false,
      isFriend: isFriend,
      platform: p.platform,
    );
  }

  List<OpponentEntry> _filtered(List<OpponentEntry> list) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where((e) => e.name.toLowerCase().contains(q) || e.id.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('지정 배틀'),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: '친구 (${_friends.length})'),
            Tab(text: '랭킹 (${_onlinePlayers.length + _npcs.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '닉네임 검색',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: (_loadingFriends && _loadingRankings)
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _buildFriendList(),
                      _buildRankingList(), // ✅ 새로운 랭킹 리스트 빌더
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ✅ 랭킹 목록 (온라인 유저 + AI 분리 표시)
  Widget _buildRankingList() {
    if (_loadingRankings && _onlinePlayers.isEmpty && _npcs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredOnline = _filtered(_onlinePlayers);
    final filteredNpcs = _filtered(_npcs);

    if (filteredOnline.isEmpty && filteredNpcs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('검색 결과가 없습니다', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            // 🔥 새로고침 버튼
            IconButton(
              onPressed: _refreshingRankings ? null : _refreshRankings,
              icon: _refreshingRankings
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 🔥 새로고침 버튼 헤더
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '온라인 ${filteredOnline.length}명 / AI ${filteredNpcs.length}명',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              GestureDetector(
                onTap: (_refreshingRankings || _loadingRankings)
                    ? null
                    : _refreshRankings,
                child: Row(
                  children: [
                    if (_refreshingRankings)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white54,
                        ),
                      )
                    else
                      const Icon(
                        Icons.refresh,
                        size: 16,
                        color: Colors.white54,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      _refreshingRankings ? '새로고침...' : '새로고침',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 목록
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // 온라인 유저 섹션
              if (filteredOnline.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '👤 온라인 유저',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                ...filteredOnline.map((o) => _buildOpponentTile(o)),
                const SizedBox(height: 16),
              ],

              // AI 상대 섹션
              if (filteredNpcs.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '🤖 AI 상대',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                ...filteredNpcs.map((o) => _buildOpponentTile(o)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // 친구 목록 (친구 추가 안내 + 🔥 새로고침 버튼)
  Widget _buildFriendList() {
    if (_loadingFriends && _friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered(_friends);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              '친구가 없습니다',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '더보기 → 친구 메뉴에서\n친구를 추가해보세요!',
              style: TextStyle(color: Colors.white38, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // 🔥 새로고침 버튼 (친구 없어도 표시)
            IconButton(
              onPressed: _refreshingFriends ? null : _refreshFriends,
              icon: _refreshingFriends
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 🔥 새로고침 버튼 헤더
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '친구 ${filtered.length}명',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              GestureDetector(
                onTap: _refreshingFriends ? null : _refreshFriends,
                child: Row(
                  children: [
                    if (_refreshingFriends)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white54,
                        ),
                      )
                    else
                      const Icon(
                        Icons.refresh,
                        size: 16,
                        color: Colors.white54,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      _refreshingFriends ? '새로고침...' : '새로고침',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 친구 목록
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final o = filtered[i];
              return _buildOpponentTile(o);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<OpponentEntry> list, {required String emptyText}) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: const TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final o = list[i];
        return _buildOpponentTile(o);
      },
    );
  }

  Widget _buildOpponentTile(OpponentEntry o) {
    final advantageInfo = _getAdvantageInfo(o.sword.element);

    return GestureDetector(
      onTap: () => Navigator.pop(context, o),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: AppDecorations.card(
          borderColor: _getGradeColor(o.sword.grade).withOpacity(0.4),
        ),
        child: Row(
          children: [
            // ✅ SwordImageWidget으로 변경 (이모지 대신 실제 검 이미지)
            SwordImageWidget(
              grade: o.sword.grade,
              element: o.sword.element,
              swordId: o.sword.id,
              level: o.swordLevel,
              breakthroughLevel: o.swordBreakthroughLevel,
              size: 38, // ✅ 50 → 38로 줄임
              showPulse: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          o.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // ✅ AI 표시
                      if (o.isNpc) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AI',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (!o.isNpc) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (o.platform == 'toss'
                                        ? Colors.blue
                                        : Colors.green)
                                    .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            o.platform == 'toss' ? '토스' : '구글',
                            style: TextStyle(
                              color: o.platform == 'toss'
                                  ? Colors.blueAccent
                                  : Colors.greenAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (o.isFriend) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.person, size: 14, color: Colors.blue),
                      ],
                      if (advantageInfo != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: advantageInfo.$2.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: advantageInfo.$2.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            advantageInfo.$1,
                            style: TextStyle(
                              color: advantageInfo.$2,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${o.sword.name}  +${o.swordLevel}  ${_getElementEmoji(o.sword.element)}  ⚡ ${o.power}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

  (String, Color)? _getAdvantageInfo(GameElement oppElement) {
    if (widget.myElement == null) return null;

    final myEl = widget.myElement!;

    if (myEl.strongAgainst == oppElement) {
      return ('유리 ▲', Colors.green);
    } else if (myEl.weakAgainst == oppElement) {
      return ('불리 ▼', Colors.red);
    }
    return null;
  }

  Color _getGradeColor(SwordGrade grade) {
    switch (grade) {
      case SwordGrade.normal:
        return Colors.grey;
      case SwordGrade.rare:
        return Colors.blue;
      case SwordGrade.unique:
        return Colors.purple;
      case SwordGrade.legend:
        return Colors.orange;
      case SwordGrade.hidden:
        return Colors.pink;
      case SwordGrade.immortal:
        return Colors.red;
    }
  }

  String _getGradeEmoji(SwordGrade grade) {
    switch (grade) {
      case SwordGrade.normal:
        return '⚔️';
      case SwordGrade.rare:
        return '🗡️';
      case SwordGrade.unique:
        return '💎';
      case SwordGrade.legend:
        return '👑';
      case SwordGrade.hidden:
        return '🔮';
      case SwordGrade.immortal:
        return '⚡';
    }
  }

  String _getElementEmoji(GameElement element) {
    switch (element) {
      case GameElement.fire:
        return '🔥';
      case GameElement.water:
        return '💧';
      case GameElement.nature:
        return '🌿';
      case GameElement.light:
        return '✨';
      case GameElement.dark:
        return '🌑';
    }
  }
}
