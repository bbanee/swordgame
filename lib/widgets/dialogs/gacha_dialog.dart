import 'package:flutter/material.dart';
import '../../enums/sword_grade.dart';
import '../../enums/element.dart';
import '../../data/swords.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../sword_image_widget.dart';

class GachaDialog extends StatelessWidget {
  final int gold;
  final int inventoryCount;
  final int maxInventory;
  final Function(int count) onGacha;

  const GachaDialog({
    super.key,
    required this.gold,
    required this.inventoryCount,
    required this.maxInventory,
    required this.onGacha,
  });

  @override
  Widget build(BuildContext context) {
    final singleCost = AppConstants.singleGachaCostGold;
    final multiCount = AppConstants.multiGachaCount;
    final multiCost = (singleCost * multiCount * AppConstants.multiGachaDiscount).floor();

    return Dialog(
      backgroundColor: const Color(0xFF2a2a4a),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 타이틀
            const Text(
              '🎰 검 뽑기',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 확률표
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    '📊 확률표',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...gachaProbability.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: SwordImageWidget(
                              grade: entry.key,
                              element: GameElement.fire,
                              level: 0,
                              size: 24,
                              showPulse: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key.displayName,
                              style: TextStyle(color: entry.key.color, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${entry.value}%',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 보유 정보
            Text(
              '보유 골드: ${formatNumber(gold)}G',
              style: const TextStyle(color: Colors.amber),
            ),
            Text(
              '인벤토리: $inventoryCount/$maxInventory',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 20),

            // 뽑기 버튼
            Row(
              children: [
                // 1회 뽑기
                Expanded(
                  child: ElevatedButton(
                    onPressed: gold >= singleCost && inventoryCount < maxInventory
                        ? () {
                            Navigator.pop(context);
                            onGacha(1);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '1회 뽑기',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          '${formatNumber(singleCost)}G',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // 다연차 뽑기
                Expanded(
                  child: ElevatedButton(
                    onPressed: gold >= multiCost && inventoryCount + multiCount <= maxInventory
                        ? () {
                            Navigator.pop(context);
                            onGacha(multiCount);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$multiCount회 뽑기',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          '${formatNumber(multiCost)}G (10%↓)',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ),
            const SizedBox(height: 12),

            // 취소 버튼
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ],
        ),
      ),
    );
  }
}