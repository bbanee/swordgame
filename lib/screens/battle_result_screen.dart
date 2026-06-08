import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/battle_engine.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class BattleResultScreen extends StatelessWidget {
  final BattleParticipant me;
  final BattleParticipant opponent;
  final BattleResult result;

  const BattleResultScreen({
    super.key,
    required this.me,
    required this.opponent,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final isWin = result.isWin;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(isWin ? '승리!' : '패배...'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            tooltip: '로그 복사',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result.logs.join('\n')));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('배틀 로그를 복사했습니다')));
            },
            icon: const Icon(Icons.copy_all),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(16), child: _buildTopCard()),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.card(),
              child: ListView.builder(
                itemCount: result.logs.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      result.logs[i],
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.2,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTopCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(
        borderColor: (result.isWin ? Colors.green : Colors.red).withOpacity(
          0.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _fighterCard(me, isLeft: true)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(child: _fighterCard(opponent, isLeft: false)),
            ],
          ),
          const SizedBox(height: 12),
          if (result.isWin)
            Text(
              '전리품 +${formatGold(result.goldEarned)}',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            const Text('전리품 없음', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _fighterCard(BattleParticipant p, {required bool isLeft}) {
    return Column(
      crossAxisAlignment: isLeft
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          '${p.grade.emoji} ${p.name}',
          style: TextStyle(color: p.grade.color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          '${p.swordName}  +${p.swordLevel}  ${p.element.emoji}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          'HP ${formatNumber(isLeft ? result.myHpRemaining : result.oppHpRemaining)}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
