import 'package:flutter/material.dart';

import '../design/illustration.dart';
import '../design/screen_chrome.dart';
import '../design/tokens.dart';
import '../services/audio_director.dart';
import '../services/settings_store.dart';
import 'voice_settings_sheet.dart';

/// Écran 13 — Paramètres. Référence : reference/13_parametres.png (248 × 450).
/// Chaque réglage est persisté (SharedPreferences) via [SettingsStore].
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _voiceStyle = <String, (Color, Color, Color?)>{
    'classique': (Color(0xFFFFE07A), Color(0xFFFFB627), null),
    'drole': (Color(0xFFF9C6CF), Color(0xFFE88A9C), Color(0xFFC0303E)),
    'serieuse': (Color(0xFFE4E2EC), Color(0xFFC4C0D2), Color(0xFF9A98AA)),
    'robot': (Color(0xFFDCD8EA), Color(0xFFBDB6D6), Color(0xFF6A5A9A)),
  };

  @override
  Widget build(BuildContext context) {
    final s = SettingsStore.instance;
    return PastelScreen(
      refW: 248,
      refH: 450,
      title: 'Paramètres',
      titleCenterX: 124,
      headerY: 37,
      titleSize: 13.5,
      decor: PastelDecor.pinkCloudRight,
      builder: (context, r) {
        final k = r.k;
        return [
          Positioned(
            left: r.x(8), right: r.x(8), top: r.y(64), bottom: r.y(10),
            child: ListenableBuilder(
              listenable: s,
              builder: (context, _) => Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16 * k),
                ),
                child: Stack(children: [
                  Positioned(left: 13 * k, top: r.y(84 - 64) - 7 * k, child: Text('Voix de la bombe', style: BoomText.ui700(10.5 * k))),
                  // personnalité + packs voix hors ligne
                  Positioned(
                    right: 10 * k, top: r.y(84 - 64) - 8 * k,
                    child: GestureDetector(
                      onTap: () => showVoiceSettings(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 7 * k, vertical: 2.5 * k),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(10 * k)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Personnalité & hors ligne', style: BoomText.ui600(7.6 * k, color: const Color(0xFF6B5E8A))),
                          Icon(Icons.chevron_right_rounded, size: 10 * k, color: const Color(0xFF6B5E8A)),
                        ]),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12 * k, right: 11 * k, top: r.y(101 - 64), height: r.y(72),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      for (final v in voicePacks)
                        _VoiceTile(
                          label: v.label, k: k, selected: s.voice == v.id,
                          style: _voiceStyle[v.id]!,
                          voiceArt: 'voice_${v.id}',
                          onTap: () => s.update((x) => x.voice = v.id),
                        ),
                    ]),
                  ),
                  _sliderRow(r, 199, 'Volume voix', s.voiceVolume, (v) => s.update((x) => x.voiceVolume = v)),
                  _sliderRow(r, 234, 'Volume effets', s.fxVolume, (v) => s.update((x) => x.fxVolume = v)),
                  _switchRow(r, 275, 'Vibrations', s.vibrations, (v) => s.update((x) => x.vibrations = v)),
                  _switchRow(r, 313, 'Sous-titres', s.subtitles, (v) => s.update((x) => x.subtitles = v)),
                  _switchRow(r, 352, 'Mode sombre', s.darkMode, (v) => s.update((x) => x.darkMode = v)),
                  Positioned(
                    left: 4 * k, right: 4 * k, top: r.y(375 - 64), height: r.y(40),
                    child: GestureDetector(
                      onTap: () => _language(context),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(12 * k)),
                        padding: EdgeInsets.symmetric(horizontal: 9 * k),
                        child: Row(children: [
                          Text('Langue', style: BoomText.ui600(10.5 * k)),
                          const Spacer(),
                          Text('Français', style: BoomText.ui600(10.5 * k)),
                          SizedBox(width: 10 * k),
                          Icon(Icons.chevron_right_rounded, size: 14 * k, color: const Color(0xFF6B5E8A)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ];
      },
    );
  }

  Widget _sliderRow(RefScale r, double y, String label, double value, ValueChanged<double> onChanged) {
    final k = r.k;
    return Positioned(
      left: 13 * k, right: 7 * k, top: r.y(y - 64) - 10 * k, height: 20 * k,
      child: Row(children: [
        SizedBox(width: 82 * k, child: Text(label, style: BoomText.ui600(10.5 * k))),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4 * k,
              activeTrackColor: const Color(0xFF2F8BFF),
              inactiveTrackColor: const Color(0xFFE7DDE8),
              thumbColor: const Color(0xFF2F8BFF),
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6 * k),
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ),
        SizedBox(width: 30 * k, child: Text('${(value * 100).round()}%', textAlign: TextAlign.right, style: BoomText.ui600(10.5 * k))),
      ]),
    );
  }

  Widget _switchRow(RefScale r, double y, String label, bool value, ValueChanged<bool> onChanged) {
    final k = r.k;
    return Positioned(
      left: 13 * k, right: 7 * k, top: r.y(y - 64) - 10 * k, height: 20 * k,
      child: Row(children: [
        Text(label, style: BoomText.ui600(10.5 * k)),
        const Spacer(),
        CandySwitch(value: value, onChanged: onChanged, width: 34 * k),
      ]),
    );
  }

  void _language(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: BoomColors.creamLight,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text('Français', style: BoomText.ui700(18)), trailing: const Icon(Icons.check_rounded)),
          ListTile(
            enabled: false,
            title: Text('English', style: BoomText.ui700(18)),
            subtitle: Text('Pas encore disponible : banque de mots à traduire', style: BoomText.ui600(13)),
          ),
        ]),
      ),
    );
  }
}

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({required this.label, required this.k, required this.selected, required this.style, required this.onTap, required this.voiceArt});
  final String voiceArt;
  final String label;
  final double k;
  final bool selected;
  final (Color, Color, Color?) style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (top, bottom, _) = style;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 47 * k,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(9 * k),
          boxShadow: selected ? const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))] : null,
        ),
        child: Column(children: [
          Container(
            height: 46 * k,
            margin: EdgeInsets.all(2 * k),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8 * k),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
              border: selected ? Border.all(color: const Color(0xFF4FB6FF), width: 1.5 * k) : null,
            ),
            child: Padding(
              padding: EdgeInsets.only(top: 3 * k),
              child: Illustration(voiceArt, scale: 1.2, alignment: Alignment.bottomCenter),
            ),
          ),
          SizedBox(height: 4 * k),
          Text(label, style: BoomText.ui600(8 * k)),
        ]),
      ),
    );
  }
}

/// Interrupteur bleu arrondi de la maquette.
class CandySwitch extends StatelessWidget {
  const CandySwitch({super.key, required this.value, required this.onChanged, required this.width});
  final bool value;
  final ValueChanged<bool> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 0.56;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: width, height: h,
          padding: EdgeInsets.all(h * 0.12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(h),
            color: value ? const Color(0xFF2F8BFF) : const Color(0xFFE2DAE6),
            border: value ? null : Border.all(color: const Color(0xFFCFC4D6), width: 1),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: h * 0.76, height: h * 0.76,
              decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.white,
                boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
