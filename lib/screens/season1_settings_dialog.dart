import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/sound_service.dart';

class Season1SettingsDialog extends StatefulWidget {
  static const _baseAsset =
      'assets/images/home/season1_settings_scene_body_v1.png';
  static const _baseWidth = 941.0;
  static const _baseHeight = 1671.0;

  const Season1SettingsDialog({super.key});

  @override
  State<Season1SettingsDialog> createState() => _Season1SettingsDialogState();
}

class _Season1SettingsDialogState extends State<Season1SettingsDialog> {
  final _sound = SoundService();
  bool _vibrationEnabled = true;
  bool _pushEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _SettingsLayout(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    Season1SettingsDialog._baseAsset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                _switchBox(
                  layout,
                  _SettingsRects.bgmSwitch,
                  _sound.bgmEnabled,
                  (value) {
                    _sound.setBgmEnabled(value);
                    setState(() {});
                  },
                ),
                _switchBox(
                  layout,
                  _SettingsRects.sfxSwitch,
                  _sound.sfxEnabled,
                  (value) {
                    _sound.setSfxEnabled(value);
                    setState(() {});
                  },
                ),
                _switchBox(
                  layout,
                  _SettingsRects.vibrationSwitch,
                  _vibrationEnabled,
                  (value) => setState(() => _vibrationEnabled = value),
                ),
                _switchBox(
                  layout,
                  _SettingsRects.pushSwitch,
                  _pushEnabled,
                  (value) => setState(() => _pushEnabled = value),
                ),
                _tap(layout, _SettingsRects.website, _openOfficialSite),
                _tap(layout, _SettingsRects.help, _openOfficialSite),
                _tap(
                  layout,
                  _SettingsRects.close,
                  () => Navigator.pop(context),
                ),
                _tap(
                  layout,
                  _SettingsRects.topClose,
                  () => Navigator.pop(context),
                ),
                _box(
                  layout,
                  _SettingsRects.version,
                  _fitText(layout, '1.0.0', 22),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openOfficialSite() async {
    final uri = Uri.parse('https://sites.google.com/view/sword-game-privacy');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _switchBox(
    _SettingsLayout layout,
    Rect rect,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return _box(
      layout,
      rect,
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: layout.u(6),
            vertical: layout.u(4),
          ),
          child: Center(
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: layout.u(45),
                height: layout.u(45),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value
                      ? const Color(0xFFFFD36A)
                      : const Color(0xFF252525),
                  boxShadow: [
                    BoxShadow(
                      color: value
                          ? const Color(0xFFFFD36A).withValues(alpha: 0.55)
                          : Colors.black54,
                      blurRadius: layout.u(10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fitText(_SettingsLayout layout, String text, double baseSize) {
    final fontSize = layout.u(baseSize);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: layout.u(6)),
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
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              height: 1,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _box(_SettingsLayout layout, Rect rect, Widget child) {
    return Positioned.fromRect(rect: layout.r(rect), child: child);
  }

  Widget _tap(_SettingsLayout layout, Rect rect, VoidCallback onTap) {
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

class _SettingsLayout {
  final double width;
  final double height;
  late final double sx = width / Season1SettingsDialog._baseWidth;
  late final double sy = height / Season1SettingsDialog._baseHeight;
  late final double s = math.min(sx, sy);

  _SettingsLayout(this.width, this.height);

  double u(double value) => value * s;

  Rect r(Rect rect) => Rect.fromLTWH(
    rect.left * sx,
    rect.top * sy,
    rect.width * sx,
    rect.height * sy,
  );
}

class _SettingsRects {
  static const topClose = Rect.fromLTWH(0, 0, 110, 110);
  static const bgmSwitch = Rect.fromLTWH(714, 482, 112, 62);
  static const sfxSwitch = Rect.fromLTWH(714, 566, 112, 57);
  static const vibrationSwitch = Rect.fromLTWH(714, 649, 112, 62);
  static const pushSwitch = Rect.fromLTWH(714, 808, 112, 62);
  static const website = Rect.fromLTWH(610, 963, 224, 58);
  static const help = Rect.fromLTWH(610, 1047, 224, 58);
  static const version = Rect.fromLTWH(586, 1399, 248, 60);
  static const close = Rect.fromLTWH(208, 1536, 562, 90);
}
