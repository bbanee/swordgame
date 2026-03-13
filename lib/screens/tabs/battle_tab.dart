// lib/screens/tabs/battle_tab.dart
// 배틀 탭 UI - GameScreen에서 분리

import 'package:flutter/material.dart';
import '../../models/battle_record.dart';
import '../../models/owned_sword.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class BattleTab extends StatelessWidget {
  final int battleCount;
  final int battleWinStreak;
  final List<BattleRecord> battleRecords;
  final OwnedSword? equippedSword;
  
  final VoidCallback onRandomBattle;
  final VoidCallback onSelectBattle;
  final VoidCallback onRefreshRecords;
  final Function(BattleRecord) onRevengeBattle;
  
  const BattleTab({
    super.key,
    required this.battleCount,
    required this.battleWinStreak,
    required this.battleRecords,
    required this.equippedSword,
    required this.onRandomBattle,
    required this.onSelectBattle,
    required this.onRefreshRecords,
    required this.onRevengeBattle,
  });
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 남은 배틀 횟수
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.card(borderColor: Colors.red.withOpacity(0.5)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sports_mma, color: Colors.red),
                const SizedBox(width: 8),
                Text('남은 배틀: $battleCount/${AppConstants.dailyBattleCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          if (battleWinStreak > 0) ...[
            const SizedBox(height: 12),
            Text('🔥 $battleWinStreak연승 중!', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ],
          
          const SizedBox(height: 24),
          
          // 배틀 버튼들
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: battleCount > 0 && equippedSword != null ? onRandomBattle : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 20)),
                child: const Column(children: [
                  Icon(Icons.casino, size: 28, color: Colors.white),
                  SizedBox(height: 4),
                  Text('랜덤 배틀', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: battleCount > 0 && equippedSword != null ? onSelectBattle : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 20)),
                child: const Column(children: [
                  Icon(Icons.person_search, size: 28, color: Colors.white),
                  SizedBox(height: 4),
                  Text('지정 배틀', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ]),
          
          const SizedBox(height: 24),
          
          // 배틀 기록 섹션
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('최근 배틀 기록', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Row(children: [
                Text('${battleRecords.length}건', style: const TextStyle(color: Colors.white54)),
                const SizedBox(width: 8),
                GestureDetector(onTap: onRefreshRecords, child: const Icon(Icons.refresh, color: Colors.white54, size: 20)),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          
          // 배틀 기록 목록
          if (battleRecords.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Text('배틀 기록이 없습니다', style: TextStyle(color: Colors.white54)))
          else
            ...battleRecords.take(10).map((record) => _buildBattleRecordItem(record)),
        ],
      ),
    );
  }
  
  Widget _buildBattleRecordItem(BattleRecord record) {
    String resultText;
    if (record.isAttacker) {
      resultText = record.isWin ? '승리' : '패배';
    } else {
      resultText = record.isWin ? '방어 성공' : '방어 실패';
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(borderColor: record.isWin ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
      child: Row(children: [
        // 승패 아이콘
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: record.isWin ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(record.isWin ? '승' : '패', style: TextStyle(color: record.isWin ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(record.isAttacker ? '공격' : '방어', style: TextStyle(color: record.isAttacker ? Colors.orange : Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        
        // 상대 정보
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${record.opponentName} ${record.opponentIsNpc ? "(AI)" : ""}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('Lv.${record.opponentLevel} • ${record.timeAgo}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 2),
            Text(resultText, style: TextStyle(color: record.isWin ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
        
        // 보상 또는 복수전 버튼
        if (record.isWin && record.goldEarned > 0)
          Text('+${formatNumber(record.goldEarned)}G', style: const TextStyle(color: Colors.amber))
        else if (record.isWin && !record.isAttacker)
          const Text('🛡️', style: TextStyle(fontSize: 20))
        else if (record.isRevengeable)
          ElevatedButton(
            onPressed: battleCount > 0 ? () => onRevengeBattle(record) : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
            child: const Text('복수전', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
      ]),
    );
  }
}
