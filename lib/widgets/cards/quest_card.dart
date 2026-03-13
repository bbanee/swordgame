import 'package:flutter/material.dart';
import '../../models/daily_quest.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class QuestCard extends StatelessWidget {
  final DailyQuest quest;
  final VoidCallback? onClaim;

  const QuestCard({
    super.key,
    required this.quest,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = quest.isCompleted;
    final isClaimed = quest.claimed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isClaimed
            ? Colors.grey.withOpacity(0.1)
            : isCompleted
                ? Colors.green.withOpacity(0.1)
                : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isClaimed
              ? Colors.grey.withOpacity(0.2)
              : isCompleted
                  ? Colors.green.withOpacity(0.5)
                  : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          // 체크 아이콘
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isClaimed
                  ? Colors.grey.withOpacity(0.3)
                  : isCompleted
                      ? Colors.green.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
            ),
            child: Icon(
              isClaimed
                  ? Icons.check
                  : isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
              color: isClaimed
                  ? Colors.grey
                  : isCompleted
                      ? Colors.green
                      : Colors.white24,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // 퀘스트 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.name,
                  style: TextStyle(
                    color: isClaimed ? Colors.grey : Colors.white,
                    fontWeight: FontWeight.bold,
                    decoration: isClaimed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quest.description,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 4),
                
                // 프로그레스 바
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: quest.progressRatio,
                          minHeight: 6,
                          backgroundColor: Colors.grey[800],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCompleted ? Colors.green : Colors.amber,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      quest.progressText,
                      style: TextStyle(
                        color: isCompleted ? Colors.green : Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 보상 / 수령 버튼
          if (isClaimed)
            const Icon(Icons.check, color: Colors.grey)
          else if (isCompleted)
            ElevatedButton(
              onPressed: onClaim,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '수령',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    '+${formatNumber(quest.rewardGold)}G',
                    style: const TextStyle(color: Colors.amber, fontSize: 10),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${formatNumber(quest.rewardGold)}G',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}