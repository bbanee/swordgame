// lib/widgets/dialogs/synthesis_dialog.dart
// 합성 다이얼로그 - 인벤토리 그리드에서 체크박스로 선택

import 'package:flutter/material.dart';
import '../../enums/sword_grade.dart';
import '../../enums/element.dart';  // ✅ 추가
import '../../models/owned_sword.dart';
import '../../utils/helpers.dart';
import '../sword_image_widget.dart';

class SynthesisDialog extends StatefulWidget {
  final List<OwnedSword> inventory;
  final String? equippedSwordUid;  // 장착 중인 검 제외용
  final int normalToRarePity;
  final int rareToUniquePity;
  final int uniqueToLegendPity;
  // 🔥 콜백이 새 pity 값을 반환하도록 변경
  final Map<String, int> Function(List<OwnedSword> materials, {bool showResult}) onSynthesize;

  const SynthesisDialog({
    super.key,
    required this.inventory,
    this.equippedSwordUid,
    required this.normalToRarePity,
    required this.rareToUniquePity,
    required this.uniqueToLegendPity,
    required this.onSynthesize,
  });

  @override
  State<SynthesisDialog> createState() => _SynthesisDialogState();
}

class _SynthesisDialogState extends State<SynthesisDialog> {
  final Set<String> _selectedUids = {};  // 선택된 검들의 uid
  SwordGrade? _filterGrade;  // 등급 필터 (null = 전체)
  bool _autoSynthesize = false; // 자동 합성 체크
  
  // 🔥 pity 값을 state로 관리
  late int _normalToRarePity;
  late int _rareToUniquePity;
  late int _uniqueToLegendPity;

  // 합성 가능한 등급 (노말, 레어, 유니크만)
  static const _synthesizableGrades = [
    SwordGrade.normal,
    SwordGrade.rare,
    SwordGrade.unique,
  ];
  
  @override
  void initState() {
    super.initState();
    _normalToRarePity = widget.normalToRarePity;
    _rareToUniquePity = widget.rareToUniquePity;
    _uniqueToLegendPity = widget.uniqueToLegendPity;
  }

  // 선택된 검 리스트
  List<OwnedSword> get _selectedSwords {
    return widget.inventory
        .where((s) => _selectedUids.contains(s.uid))
        .toList();
  }

  // 선택된 검들이 같은 등급인지
  bool get _isSameGrade {
    if (_selectedSwords.isEmpty) return true;
    final firstGrade = _selectedSwords.first.data.grade;
    return _selectedSwords.every((s) => s.data.grade == firstGrade);
  }

  // 합성 가능 여부
  bool get _canSynthesize {
    return _selectedSwords.length == 3 && 
           _isSameGrade && 
           _synthesizableGrades.contains(_selectedSwords.first.data.grade);
  }

  bool get _canAutoSynthesize {
    final list = widget.inventory
        .where((s) => _synthesizableGrades.contains(s.data.grade))
        .where((s) => s.uid != widget.equippedSwordUid)
        .toList();
    for (final grade in _synthesizableGrades) {
      final count = list.where((s) => s.data.grade == grade).length;
      if (count >= 3) return true;
    }
    return false;
  }

  // 필터링된 인벤토리 (✅ 장착 검도 포함)
  List<OwnedSword> get _filteredInventory {
    var list = widget.inventory
        .where((s) => _synthesizableGrades.contains(s.data.grade))  // 합성 가능 등급만
        .toList();
    
    if (_filterGrade != null) {
      list = list.where((s) => s.data.grade == _filterGrade).toList();
    }
    
    // 등급순 정렬 (높은 등급 먼저)
    list.sort((a, b) => b.data.grade.index.compareTo(a.data.grade.index));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더 (축소)
            _buildHeader(),
            
            // 천장 정보 (축소)
            _buildPityInfo(),
            
            // 등급 필터
            _buildGradeFilter(),
            
            // 인벤토리 그리드
            Expanded(child: _buildInventoryGrid()),
            
            // 선택 현황 & 합성 버튼
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🔄', style: TextStyle(fontSize: 22)),
              SizedBox(width: 6),
              Text(
                '검 합성',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '같은 등급 검 3개를 선택하세요 (히든/불멸 불가)',
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPityInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // 천장 진행도
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: _buildPityBarCompact('노말', _normalToRarePity, 10, Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPityBarCompact('레어', _rareToUniquePity, 50, Colors.purple),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPityBarCompact('유니크', _uniqueToLegendPity, 100, Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 승급 확률 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                ...[SwordGrade.normal, SwordGrade.rare, SwordGrade.unique].map((g) {
                  final prob = getSynthesisProbability(g) ?? 0;
                  final resultGrade = getSynthesisResultGrade(g);
                  return Expanded(
                    child: Text(
                      '${g.displayName}→${resultGrade?.displayName ?? '?'} ${prob}%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: resultGrade?.color ?? Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPityBarCompact(String label, int current, int max, Color color) {
    final progress = current / max;
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
        const SizedBox(height: 2),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[800],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(height: 2),
        Text('$current/$max', style: TextStyle(color: color, fontSize: 9)),
      ],
    );
  }

  Widget _buildPityBar(String label, int current, int max, Color color, String reward) {
    final progress = current / max;
    final isClose = progress >= 0.8;
    
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Stack(
          children: [
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$current/$max',
              style: TextStyle(
                color: isClose ? color : Colors.white54,
                fontSize: 11,
                fontWeight: isClose ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(
              reward,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGradeFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 전체 버튼
            _buildFilterChip(null, '전체'),
            const SizedBox(width: 8),
            // 등급별 버튼 (✅ 장착 검도 포함)
            ..._synthesizableGrades.map((grade) {
              final count = widget.inventory
                  .where((s) => s.data.grade == grade)
                  .length;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChipWithImage(grade, count),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(SwordGrade? grade, String label) {
    final isSelected = _filterGrade == grade;
    final color = grade?.color ?? Colors.grey;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : color,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _filterGrade = grade;
          // 필터 변경 시 해당 등급 아닌 선택 해제
          if (grade != null) {
            _selectedUids.removeWhere((uid) {
              final sword = widget.inventory.firstWhere((s) => s.uid == uid);
              return sword.data.grade != grade;
            });
          }
        });
      },
      selectedColor: color.withOpacity(0.3),
      backgroundColor: const Color(0xFF2a2a4a),
      side: BorderSide(color: isSelected ? color : Colors.grey[700]!),
      showCheckmark: false,
    );
  }

  // ✅ 이미지가 포함된 필터 칩 (등급별)
  Widget _buildFilterChipWithImage(SwordGrade grade, int count) {
    final isSelected = _filterGrade == grade;
    final color = grade.color;

    return GestureDetector(
      onTap: () {
        setState(() {
          _filterGrade = grade;
          // 필터 변경 시 해당 등급 아닌 선택 해제
          _selectedUids.removeWhere((uid) {
            final sword = widget.inventory.firstWhere((s) => s.uid == uid);
            return sword.data.grade != grade;
          });
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.3) : const Color(0xFF2a2a4a),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : Colors.grey[700]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwordImageWidget(
              grade: grade,
              element: GameElement.fire,  // 기본 속성
              level: 0,
              size: 20,
              showPulse: false,
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryGrid() {
    final inventory = _filteredInventory;
    
    if (inventory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[600]),
              const SizedBox(height: 12),
              Text(
                '합성 가능한 검이 없습니다',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.75,
        ),
        itemCount: inventory.length,
        itemBuilder: (context, index) {
          final sword = inventory[index];
          return _buildSwordItem(sword);
        },
      ),
    );
  }

  Widget _buildSwordItem(OwnedSword sword) {
    final isSelected = _selectedUids.contains(sword.uid);
    final grade = sword.data.grade;
    final isEquipped = sword.uid == widget.equippedSwordUid;  // ✅ 장착 검 여부
    
    // 다른 등급 선택 시 비활성화
    final bool isDisabled = _selectedSwords.isNotEmpty && 
                            !isSelected && 
                            _selectedSwords.first.data.grade != grade;
    
    // 3개 선택 완료 시 다른 것 비활성화
    final bool isFull = _selectedSwords.length >= 3 && !isSelected;
    
    final canSelect = !isDisabled && !isFull;
    
    return GestureDetector(
      onTap: canSelect
          ? () {
              setState(() {
                if (isSelected) {
                  _selectedUids.remove(sword.uid);
                } else {
                  _selectedUids.add(sword.uid);
                }
              });
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? grade.color.withOpacity(0.3)
              : (canSelect ? grade.color.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected 
                ? Colors.amber 
                : (isEquipped 
                    ? Colors.cyan  // ✅ 장착 검은 청록색 테두리
                    : (canSelect ? grade.color.withOpacity(0.5) : Colors.grey[700]!)),
            width: isSelected || isEquipped ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // 메인 컨텐츠
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🔥 SwordImageWidget 사용
                  Opacity(
                    opacity: canSelect ? 1.0 : 0.4,
                    child: SwordImageWidget(
                      grade: grade,
                      element: sword.data.element,
                      level: sword.level,
                      size: 32,
                      showPulse: false,  // ✅ 성능을 위해 펄스 비활성화
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sword.data.name,
                    style: TextStyle(
                      color: canSelect ? Colors.white : Colors.grey,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '+${sword.level}',
                    style: TextStyle(
                      color: canSelect ? Colors.amber : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // ✅ 장착 검 표시
            if (isEquipped && !isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '장착',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            
            // 체크 표시
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.black),
                ),
              ),
            
            // 선택 번호 표시
            if (isSelected)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_selectedSwords.indexOf(sword) + 1}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final selectedGrade = _selectedSwords.isNotEmpty 
        ? _selectedSwords.first.data.grade 
        : null;
    
    // 선택된 검의 element (결과 미리보기용)
    final selectedElement = _selectedSwords.isNotEmpty 
        ? _selectedSwords.first.data.element 
        : GameElement.fire;
    
    // 결과 등급 (상위 등급)
    SwordGrade? resultGrade;
    if (selectedGrade != null) {
      final gradeIndex = SwordGrade.values.indexOf(selectedGrade);
      if (gradeIndex < SwordGrade.values.length - 1) {
        resultGrade = SwordGrade.values[gradeIndex + 1];
        // 히든은 스킵하고 불멸도 아님
        if (resultGrade == SwordGrade.hidden) {
          resultGrade = SwordGrade.legend;
        }
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 선택 현황 (축소)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(3, (i) {
                final hasSword = i < _selectedSwords.length;
                final sword = hasSword ? _selectedSwords[i] : null;
                
                return Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: hasSword 
                        ? sword!.data.grade.color.withOpacity(0.3) 
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasSword ? sword!.data.grade.color : Colors.grey[700]!,
                    ),
                  ),
                  child: Center(
                    child: hasSword
                        ? SwordImageWidget(
                            grade: sword!.data.grade,
                            element: sword.data.element,
                            level: sword.level,
                            size: 28,
                            showPulse: false,
                          )
                        : Text('${i + 1}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ),
                );
              }),
              
              // 화살표
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  color: _canSynthesize ? Colors.amber : Colors.grey[600],
                  size: 20,
                ),
              ),
              
              // ✅ 결과 미리보기 - SwordImageWidget 사용
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: resultGrade?.color.withOpacity(0.3) ?? Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: resultGrade?.color ?? Colors.grey[700]!,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: resultGrade != null
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            SwordImageWidget(
                              grade: resultGrade,
                              element: selectedElement,
                              level: 0,
                              size: 32,
                              showPulse: false,
                            ),
                            // 물음표 오버레이
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: resultGrade.color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Text('?', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 자동 합성 체크
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Checkbox(
                value: _autoSynthesize,
                onChanged: (v) => setState(() => _autoSynthesize = v ?? false),
                activeColor: Colors.cyan,
              ),
              const Text(
                '자동 합성',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // 버튼들 (Wrap으로 감싸서 overflow 방지)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              // 선택 초기화
              if (_selectedUids.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _selectedUids.clear()),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('초기화', style: TextStyle(fontSize: 12)),
                ),
              
              // 🔥 자동 선택 버튼
              TextButton(
                onPressed: _autoSelect,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.cyan,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('자동선택', style: TextStyle(fontSize: 12)),
              ),
              
              // 닫기
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('닫기', style: TextStyle(fontSize: 12)),
              ),
              
              // 🔥 합성 버튼
              ElevatedButton(
                onPressed: _autoSynthesize
                    ? (_canAutoSynthesize ? _runAutoSynthesis : null)
                    : _canSynthesize
                        ? () {
                            final swords = List<OwnedSword>.from(_selectedSwords);
                            setState(() => _selectedUids.clear());
                            // 🔥 합성 후 새 pity 값을 직접 받아서 업데이트
                            final newPity = widget.onSynthesize(swords);
                            setState(() {
                              _normalToRarePity = newPity['normalToRare'] ?? _normalToRarePity;
                              _rareToUniquePity = newPity['rareToUnique'] ?? _rareToUniquePity;
                              _uniqueToLegendPity = newPity['uniqueToLegend'] ?? _uniqueToLegendPity;
                            });
                          }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  _autoSynthesize ? '자동 합성' : (_canSynthesize ? '합성!' : '3개 선택'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _runAutoSynthesis() {
    int synthCount = 0;
    while (true) {
      final available = widget.inventory
          .where((s) => _synthesizableGrades.contains(s.data.grade))
          .where((s) => s.uid != widget.equippedSwordUid)
          .toList();

      bool didSynthesize = false;
      for (final grade in _synthesizableGrades) {
        final gradeSwords = available.where((s) => s.data.grade == grade).toList();
        if (gradeSwords.length >= 3) {
          final materials = gradeSwords.take(3).toList();
          final before = widget.inventory.length;
          final newPity = widget.onSynthesize(materials, showResult: false);
          setState(() {
            _normalToRarePity = newPity['normalToRare'] ?? _normalToRarePity;
            _rareToUniquePity = newPity['rareToUnique'] ?? _rareToUniquePity;
            _uniqueToLegendPity = newPity['uniqueToLegend'] ?? _uniqueToLegendPity;
            _selectedUids.clear();
          });
          final after = widget.inventory.length;
          if (after == before) {
            // 합성 실패(예: 골드 부족)로 판단
            return;
          }
          synthCount++;
          didSynthesize = true;
          break;
        }
      }

      if (!didSynthesize) break;
    }

    if (synthCount > 0 && mounted) {
      _showAutoSynthesisSummary(synthCount);
    }
  }

  void _showAutoSynthesisSummary(int count) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('자동 합성 완료', style: TextStyle(color: Colors.white)),
        content: Text(
          '자동 합성 ${count}회 완료되었습니다.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
  
  // 🔥 자동 선택 기능
  void _autoSelect() {
    setState(() {
      _selectedUids.clear();
      
      // 필터된 등급 우선, 없으면 가장 낮은 등급부터
      final targetGrade = _filterGrade ?? SwordGrade.normal;
      
      // 해당 등급 검 찾기
      final sameSwords = _filteredInventory
          .where((s) => s.data.grade == targetGrade)
          .toList();
      
      // 3개 선택 (레벨 낮은 것 우선)
      sameSwords.sort((a, b) => a.level.compareTo(b.level));
      
      for (var i = 0; i < sameSwords.length && _selectedUids.length < 3; i++) {
        _selectedUids.add(sameSwords[i].uid);
      }
      
      // 3개 못 채웠으면 다음 등급 시도
      if (_selectedUids.length < 3) {
        _selectedUids.clear();
        
        for (final grade in _synthesizableGrades) {
          final gradeSwords = _filteredInventory
              .where((s) => s.data.grade == grade)
              .toList();
          
          if (gradeSwords.length >= 3) {
            gradeSwords.sort((a, b) => a.level.compareTo(b.level));
            for (var i = 0; i < 3; i++) {
              _selectedUids.add(gradeSwords[i].uid);
            }
            break;
          }
        }
      }
    });
  }
}
