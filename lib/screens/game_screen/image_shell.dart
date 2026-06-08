part of '../game_screen.dart';

class _GameImageShell extends StatelessWidget {
  final int currentTab;
  final Widget body;
  final String nickname;
  final int totalPower;
  final int gold;
  final int diamond;
  final VoidCallback onHome;
  final VoidCallback onInventory;
  final VoidCallback onEnhance;
  final VoidCallback onBattle;
  final VoidCallback onShop;
  final VoidCallback onMenu;

  const _GameImageShell({
    required this.currentTab,
    required this.body,
    required this.nickname,
    required this.totalPower,
    required this.gold,
    required this.diamond,
    required this.onHome,
    required this.onInventory,
    required this.onEnhance,
    required this.onBattle,
    required this.onShop,
    required this.onMenu,
  });

  bool get _usesFullSceneBody =>
      currentTab == 0 || currentTab == 1 || currentTab == 2 || currentTab == 3;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final topHeight =
            constraints.maxWidth *
            _ImageShellTopRects.baseHeight /
            _ImageShellTopRects.baseWidth;
        final bottomHeight =
            constraints.maxWidth *
            _ImageShellBottomRects.baseHeight /
            _ImageShellBottomRects.baseWidth;

        return Stack(
          children: [
            if (_usesFullSceneBody)
              Positioned.fill(child: body)
            else
              Positioned(
                top: topHeight,
                left: 0,
                right: 0,
                bottom: bottomHeight,
                child: body,
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topHeight,
              child: _ImageTopHud(
                nickname: nickname,
                totalPower: totalPower,
                gold: gold,
                diamond: diamond,
                onMenu: onMenu,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomHeight,
              child: _ImageBottomNav(
                onHome: onHome,
                onInventory: onInventory,
                onEnhance: onEnhance,
                onBattle: onBattle,
                onShop: onShop,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ImageTopHud extends StatelessWidget {
  final String nickname;
  final int totalPower;
  final int gold;
  final int diamond;
  final VoidCallback onMenu;

  const _ImageTopHud({
    required this.nickname,
    required this.totalPower,
    required this.gold,
    required this.diamond,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _ImageShellLayout(
          constraints.maxWidth,
          constraints.maxHeight,
          _ImageShellTopRects.baseWidth,
          _ImageShellTopRects.baseHeight,
        );

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/home/season1_common_hud_frame_v1.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
              _shellBox(
                layout,
                _ImageShellTopRects.nickname,
                _shellText(layout, nickname, 24, fontWeight: FontWeight.w900),
              ),
              _shellBox(
                layout,
                _ImageShellTopRects.power,
                _shellText(
                  layout,
                  formatNumber(totalPower),
                  28,
                  color: const Color(0xFFFFC94A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              _shellBox(
                layout,
                _ImageShellTopRects.gold,
                _shellCurrencyText(layout, _formatCompactBalance(gold)),
              ),
              _shellBox(
                layout,
                _ImageShellTopRects.diamond,
                _shellCurrencyText(layout, _formatCompactBalance(diamond)),
              ),
              _shellBox(
                layout,
                _ImageShellTopRects.redDiamond,
                _shellCurrencyText(layout, '0'),
              ),
              _shellTap(layout, _ImageShellTopRects.menu, onMenu),
            ],
          ),
        );
      },
    );
  }
}

class _ImageBottomNav extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onInventory;
  final VoidCallback onEnhance;
  final VoidCallback onBattle;
  final VoidCallback onShop;

  const _ImageBottomNav({
    required this.onHome,
    required this.onInventory,
    required this.onEnhance,
    required this.onBattle,
    required this.onShop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _ImageShellLayout(
          constraints.maxWidth,
          constraints.maxHeight,
          _ImageShellBottomRects.baseWidth,
          _ImageShellBottomRects.baseHeight,
        );

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/home/season1_common_bottom_nav_frame_v2.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
              _shellTap(layout, _ImageShellBottomRects.home, onHome),
              _shellTap(layout, _ImageShellBottomRects.inventory, onInventory),
              _shellTap(layout, _ImageShellBottomRects.enhance, onEnhance),
              _shellTap(layout, _ImageShellBottomRects.battle, onBattle),
              _shellTap(layout, _ImageShellBottomRects.shop, onShop),
            ],
          ),
        );
      },
    );
  }
}

Widget _shellCurrencyText(_ImageShellLayout layout, String value) {
  return _shellText(
    layout,
    value,
    16,
    color: Colors.white,
    fontWeight: FontWeight.w900,
  );
}

Widget _shellText(
  _ImageShellLayout layout,
  String text,
  double baseSize, {
  Color color = Colors.white,
  FontWeight fontWeight = FontWeight.w700,
}) {
  final fontSize = layout.u(baseSize);
  return Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: layout.u(3)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          strutStyle: StrutStyle(
            fontSize: fontSize,
            height: 1,
            forceStrutHeight: true,
          ),
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: 1,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _shellBox(_ImageShellLayout layout, Rect rect, Widget child) {
  return Positioned.fromRect(rect: layout.r(rect), child: child);
}

Widget _shellTap(_ImageShellLayout layout, Rect rect, VoidCallback onTap) {
  return _shellBox(
    layout,
    rect,
    GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: const SizedBox.expand(),
    ),
  );
}

class _ImageShellLayout {
  final double width;
  final double height;
  final double baseWidth;
  final double baseHeight;
  late final double sx = width / baseWidth;
  late final double sy = height / baseHeight;
  late final double s = min(sx, sy);

  _ImageShellLayout(this.width, this.height, this.baseWidth, this.baseHeight);

  double u(double value) => value * s;

  Rect r(Rect rect) {
    return Rect.fromLTWH(
      rect.left * sx,
      rect.top * sy,
      rect.width * sx,
      rect.height * sy,
    );
  }
}

class _ImageShellTopRects {
  static const baseWidth = 941.0;
  static const baseHeight = 190.0;

  static const nickname = Rect.fromLTWH(169, 64, 194, 36);
  static const power = Rect.fromLTWH(216, 129, 176, 42);
  static const gold = Rect.fromLTWH(444, 83, 70, 30);
  static const diamond = Rect.fromLTWH(594, 83, 70, 30);
  static const redDiamond = Rect.fromLTWH(743, 83, 70, 30);
  static const menu = Rect.fromLTWH(864, 52, 62, 73);
}

class _ImageShellBottomRects {
  static const baseWidth = 941.0;
  static const baseHeight = 180.0;

  static const home = Rect.fromLTWH(0, 0, 188, 180);
  static const inventory = Rect.fromLTWH(188, 0, 188, 180);
  static const enhance = Rect.fromLTWH(376, 0, 188, 180);
  static const battle = Rect.fromLTWH(564, 0, 188, 180);
  static const shop = Rect.fromLTWH(752, 0, 189, 180);
}
