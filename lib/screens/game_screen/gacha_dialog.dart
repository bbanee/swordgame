part of '../game_screen.dart';

class _GachaDialog extends StatefulWidget {
  static const _baseAsset =
      'assets/images/home/season1_gacha_scene_body_v1.png';
  static const _baseWidth = 941.0;
  static const _baseHeight = 1672.0;

  final int gold;
  final int diamond;
  final int inventoryCount;
  final int maxInventory;
  final Function(int) onNormalGacha;
  final Function(int) onPremiumGacha;

  const _GachaDialog({
    required this.gold,
    required this.diamond,
    required this.inventoryCount,
    required this.maxInventory,
    required this.onNormalGacha,
    required this.onPremiumGacha,
  });

  @override
  State<_GachaDialog> createState() => _GachaDialogState();
}

class _GachaDialogState extends State<_GachaDialog> {
  int _tab = 0;

  bool get _inventoryFull => widget.inventoryCount >= widget.maxInventory;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _GachaLayout(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    _GachaDialog._baseAsset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                _tap(layout, _GachaRects.close, () => Navigator.pop(context)),
                _box(layout, _GachaRects.title, _text(layout, '검 뽑기', 42)),
                _box(
                  layout,
                  _GachaRects.diamond,
                  _text(layout, _formatCompactBalance(widget.diamond), 24),
                ),
                _box(
                  layout,
                  _GachaRects.gold,
                  _text(layout, _formatCompactBalance(widget.gold), 24),
                ),
                _box(
                  layout,
                  _GachaRects.inventory,
                  _text(
                    layout,
                    '${widget.inventoryCount}/${widget.maxInventory}',
                    24,
                    color: _inventoryFull ? Colors.redAccent : Colors.white,
                  ),
                ),
                _tabLabel(layout, 0, '일반 뽑기'),
                _tabLabel(layout, 1, '고급 뽑기'),
                _tap(
                  layout,
                  _GachaRects.tabs[0],
                  () => setState(() => _tab = 0),
                ),
                _tap(
                  layout,
                  _GachaRects.tabs[1],
                  () => setState(() => _tab = 1),
                ),
                ..._buildTabContent(layout),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tabLabel(_GachaLayout layout, int index, String label) {
    return _box(
      layout,
      _GachaRects.tabLabels[index],
      _text(
        layout,
        label,
        30,
        color: _tab == index ? Colors.amberAccent : Colors.white,
      ),
    );
  }

  List<Widget> _buildTabContent(_GachaLayout layout) {
    return _tab == 0 ? _normalContent(layout) : _premiumContent(layout);
  }

  List<Widget> _normalContent(_GachaLayout layout) {
    final canGacha1 = widget.gold >= 500 && !_inventoryFull;
    final canGacha5 =
        widget.gold >= 2250 && widget.inventoryCount + 5 <= widget.maxInventory;
    return [
      _box(
        layout,
        _GachaRects.description,
        _multiText(
          layout,
          '골드로 검을 뽑습니다.\n모든 등급 획득 가능',
          25,
          color: Colors.white70,
        ),
      ),
      _box(
        layout,
        _GachaRects.probabilityTitle,
        _text(layout, '획득 가능 등급', 28, color: Colors.amberAccent),
      ),
      _box(
        layout,
        _GachaRects.probabilityList,
        _gradeList(layout, gachaProbability),
      ),
      _button(
        layout,
        _GachaRects.buttons[0],
        '1회 뽑기',
        '500G',
        canGacha1,
        () => widget.onNormalGacha(1),
      ),
      _button(
        layout,
        _GachaRects.buttons[1],
        '5회 뽑기',
        '2,250G',
        canGacha5,
        () => widget.onNormalGacha(5),
      ),
      _box(
        layout,
        _GachaRects.buttons[2],
        _multiText(layout, _inventoryFull ? '인벤토리 가득참' : '고급 탭 이용', 24),
      ),
    ];
  }

  List<Widget> _premiumContent(_GachaLayout layout) {
    final canPremium1 =
        widget.diamond >= premiumGachaCostSingle && !_inventoryFull;
    final canPremium5 =
        widget.diamond >= premiumGachaCost5x &&
        widget.inventoryCount + 5 <= widget.maxInventory;
    final canPremium10 =
        widget.diamond >= premiumGachaCost10x &&
        widget.inventoryCount + 10 <= widget.maxInventory;
    return [
      _box(
        layout,
        _GachaRects.description,
        _multiText(
          layout,
          '다이아로 고급 검을 뽑습니다.\n10회 뽑기는 유니크 이상 1개 확정',
          25,
          color: Colors.white70,
        ),
      ),
      _box(
        layout,
        _GachaRects.probabilityTitle,
        _text(layout, '획득 가능 등급', 28, color: Colors.cyanAccent),
      ),
      _box(
        layout,
        _GachaRects.probabilityList,
        _gradeList(layout, premiumGachaProbability),
      ),
      _button(
        layout,
        _GachaRects.buttons[0],
        '1회 뽑기',
        '$premiumGachaCostSingle 다이아',
        canPremium1,
        () => widget.onPremiumGacha(1),
      ),
      _button(
        layout,
        _GachaRects.buttons[1],
        '5회 뽑기',
        '$premiumGachaCost5x 다이아',
        canPremium5,
        () => widget.onPremiumGacha(5),
      ),
      _button(
        layout,
        _GachaRects.buttons[2],
        '10회 뽑기',
        '$premiumGachaCost10x 다이아',
        canPremium10,
        () => widget.onPremiumGacha(10),
      ),
    ];
  }

  Widget _gradeList(_GachaLayout layout, Map<SwordGrade, double> table) {
    final entries = table.entries.toList();
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: layout.u(18),
        mainAxisSpacing: layout.u(10),
        childAspectRatio: 5.8,
      ),
      itemBuilder: (_, index) {
        final entry = entries[index];
        return Row(
          children: [
            SizedBox(
              width: layout.u(34),
              height: layout.u(34),
              child: SwordImageWidget(
                grade: entry.key,
                element: GameElement.fire,
                level: 0,
                size: layout.u(34),
                showPulse: false,
              ),
            ),
            SizedBox(width: layout.u(8)),
            Expanded(
              child: _plain(
                layout,
                '${entry.key.displayName} ${entry.value}%',
                19,
                color: entry.key.color,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _button(
    _GachaLayout layout,
    Rect rect,
    String title,
    String cost,
    bool enabled,
    VoidCallback onTap,
  ) {
    return _box(
      layout,
      rect,
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: enabled ? onTap : null,
        child: _multiText(
          layout,
          '$title\n$cost',
          25,
          color: enabled ? Colors.white : Colors.white38,
        ),
      ),
    );
  }

  Widget _text(
    _GachaLayout layout,
    String text,
    double baseSize, {
    Color color = Colors.white,
  }) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: layout.u(baseSize),
            fontWeight: FontWeight.w900,
            height: 1,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _multiText(
    _GachaLayout layout,
    String text,
    double baseSize, {
    Color color = Colors.white,
  }) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: layout.u(baseSize),
          fontWeight: FontWeight.w900,
          height: 1.22,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }

  Widget _plain(
    _GachaLayout layout,
    String text,
    double baseSize, {
    Color color = Colors.white,
  }) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: layout.u(baseSize),
        fontWeight: FontWeight.w800,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
    );
  }

  Widget _box(_GachaLayout layout, Rect rect, Widget child) {
    return Positioned.fromRect(rect: layout.r(rect), child: child);
  }

  Widget _tap(_GachaLayout layout, Rect rect, VoidCallback onTap) {
    return _box(
      layout,
      rect,
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GachaLayout {
  final double width;
  final double height;
  late final double sx = width / _GachaDialog._baseWidth;
  late final double sy = height / _GachaDialog._baseHeight;
  late final double s = min(sx, sy);

  _GachaLayout(this.width, this.height);

  double u(double value) => value * s;

  Rect r(Rect rect) => Rect.fromLTWH(
    rect.left * sx,
    rect.top * sy,
    rect.width * sx,
    rect.height * sy,
  );
}

class _GachaRects {
  static const close = Rect.fromLTWH(18, 20, 88, 88);
  static const title = Rect.fromLTWH(228, 220, 490, 130);
  static const diamond = Rect.fromLTWH(116, 430, 155, 55);
  static const gold = Rect.fromLTWH(406, 430, 155, 55);
  static const inventory = Rect.fromLTWH(700, 430, 155, 55);
  static const tabs = [
    Rect.fromLTWH(70, 522, 365, 88),
    Rect.fromLTWH(495, 522, 365, 88),
  ];
  static const tabLabels = [
    Rect.fromLTWH(92, 535, 318, 58),
    Rect.fromLTWH(520, 535, 318, 58),
  ];
  static const description = Rect.fromLTWH(62, 646, 816, 160);
  static const probabilityTitle = Rect.fromLTWH(75, 838, 780, 56);
  static const probabilityList = Rect.fromLTWH(75, 908, 780, 205);
  static const buttons = [
    Rect.fromLTWH(54, 1510, 268, 102),
    Rect.fromLTWH(344, 1510, 268, 102),
    Rect.fromLTWH(634, 1510, 268, 102),
  ];
}
