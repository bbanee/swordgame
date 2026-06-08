// lib/screens/friends_screen.dart
// 👥 친구 관리 화면

import 'package:flutter/material.dart';
import '../services/friend_service.dart';
import '../models/player_profile.dart';
import '../data/swords.dart';
import '../enums/sword_grade.dart';
import '../enums/element.dart';
import '../utils/constants.dart';
import '../widgets/sword_image_widget.dart';

class FriendsScreen extends StatefulWidget {
  final Function(List<String>)? onFriendListChanged;

  const FriendsScreen({super.key, this.onFriendListChanged});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _friendService = FriendService();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<PlayerProfile> _friends = [];
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    try {
      final friends = await _friendService.getFriendProfiles(
        forceRefresh: forceRefresh,
      );
      setState(() {
        _friends = friends;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _friends = [];
        _isLoading = false;
      });
    }
  }

  // 👥 친구 추가 다이얼로그
  void _showAddFriendDialog() {
    final nicknameCtrl = TextEditingController();
    bool isSearching = false;
    String? errorText;
    PlayerProfile? foundUser;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a4a),
          title: const Text('👥 친구 추가', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nicknameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '닉네임 입력',
                    hintStyle: const TextStyle(color: Colors.white38),
                    errorText: errorText,
                    filled: true,
                    fillColor: Colors.white10,
                    prefixIcon: const Icon(
                      Icons.person_search,
                      color: Colors.white54,
                    ),
                    suffixIcon: IconButton(
                      icon: isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search, color: Colors.white54),
                      onPressed: isSearching
                          ? null
                          : () async {
                              final nickname = nicknameCtrl.text.trim();
                              if (nickname.isEmpty) {
                                setDialogState(() => errorText = '닉네임을 입력하세요');
                                return;
                              }
                              if (nickname.length < 2) {
                                setDialogState(() => errorText = '2자 이상 입력하세요');
                                return;
                              }

                              setDialogState(() {
                                isSearching = true;
                                errorText = null;
                                foundUser = null;
                              });

                              // 검색
                              final results = await _friendService
                                  .searchByNickname(nickname);

                              setDialogState(() {
                                isSearching = false;
                                if (results.isEmpty) {
                                  errorText = '유저를 찾을 수 없습니다';
                                } else {
                                  foundUser = results.first;
                                }
                              });
                            },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) async {
                    // Enter 키로도 검색
                    final nickname = nicknameCtrl.text.trim();
                    if (nickname.length >= 2) {
                      setDialogState(() {
                        isSearching = true;
                        errorText = null;
                        foundUser = null;
                      });

                      final results = await _friendService.searchByNickname(
                        nickname,
                      );

                      setDialogState(() {
                        isSearching = false;
                        if (results.isEmpty) {
                          errorText = '유저를 찾을 수 없습니다';
                        } else {
                          foundUser = results.first;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '추가할 친구의 정확한 닉네임을 입력하세요',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),

                // 검색 결과
                if (foundUser != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: SwordImageWidget(
                            grade: foundUser!.sword.grade,
                            element: foundUser!.sword.element,
                            swordId: foundUser!.swordId,
                            level: foundUser!.swordLevel,
                            breakthroughLevel:
                                foundUser!.swordBreakthroughLevel,
                            size: 48,
                            showPulse: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                foundUser!.nickname,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${foundUser!.sword.name} +${foundUser!.swordLevel}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '⚡ 전투력 ${foundUser!.powerWithTitle}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle, color: Colors.green),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: foundUser == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _addFriend(foundUser!.nickname);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: foundUser != null ? Colors.green : Colors.grey,
              ),
              child: const Text('추가', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // 친구 추가 처리
  Future<void> _addFriend(String nickname) async {
    final result = await _friendService.addFriendByNickname(nickname);

    if (result.isSuccess) {
      await _loadFriends();

      // 부모에게 알림
      final newFriendIds = await _friendService.getFriendIds();
      widget.onFriendListChanged?.call(newFriendIds);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${result.profile!.nickname}님을 친구로 추가했습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 친구 삭제 확인
  void _showRemoveFriendDialog(PlayerProfile friend) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        title: const Text('친구 삭제', style: TextStyle(color: Colors.white)),
        content: Text(
          '${friend.nickname}님을 친구 목록에서 삭제하시겠습니까?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              final success = await _friendService.removeFriend(friend.userId);
              if (success) {
                // ✅ 로컬 상태에서 직접 제거 (서버 재조회 없이)
                setState(() {
                  _friends.removeWhere((f) => f.userId == friend.userId);
                });

                // 부모에게 알림
                final remainingIds = _friends.map((f) => f.userId).toList();
                widget.onFriendListChanged?.call(remainingIds);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${friend.nickname}님을 삭제했습니다'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('친구 삭제에 실패했습니다'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('👥 친구 (${_friends.length})'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadFriends(forceRefresh: true),
            tooltip: '새로고침',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFriendDialog,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.person_add),
        label: const Text('친구 추가'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
          ? _buildEmptyState()
          : _buildFriendList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 80, color: Colors.white24),
          const SizedBox(height: 24),
          const Text(
            '친구가 없습니다',
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            '아래 버튼을 눌러 친구를 추가해보세요!',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showAddFriendDialog,
            icon: const Icon(Icons.person_add),
            label: const Text('친구 추가하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return _buildFriendCard(friend);
      },
    );
  }

  Widget _buildFriendCard(PlayerProfile friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getGradeColor(friend.sword.grade).withOpacity(0.15),
            Colors.black.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getGradeColor(friend.sword.grade).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // 검 이미지
          SizedBox(
            width: 56,
            height: 56,
            child: SwordImageWidget(
              grade: friend.sword.grade,
              element: friend.sword.element,
              swordId: friend.swordId,
              level: friend.swordLevel,
              breakthroughLevel: friend.swordBreakthroughLevel,
              size: 56,
              showPulse: false,
            ),
          ),
          const SizedBox(width: 12),
          // 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 닉네임 + 친구 뱃지
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        friend.nickname,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '친구',
                        style: TextStyle(color: Colors.blue, fontSize: 9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 검 이름 + 속성
                Text(
                  '${friend.sword.name} +${friend.swordLevel}  ${_getElementEmoji(friend.sword.element)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // 전투력 (타이틀 포함)
                Text(
                  '⚡ 전투력 ${friend.powerWithTitle}',
                  style: TextStyle(color: Colors.amber[300], fontSize: 11),
                ),
              ],
            ),
          ),
          // 메뉴 버튼
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
            padding: EdgeInsets.zero,
            color: const Color(0xFF2a2a4a),
            onSelected: (value) {
              if (value == 'delete') {
                _showRemoveFriendDialog(friend);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.person_remove, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('친구 삭제', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
