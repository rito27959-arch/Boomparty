import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../design/illustration.dart';
import '../design/screen_chrome.dart';
import '../design/tokens.dart';
import '../engine/game_engine.dart';
import '../state/app_state.dart';

/// Écran 2 — Modes de jeu. Référence : reference/02_modes_de_jeu.png (214 × 536).
class ModesScreen extends StatelessWidget {
  const ModesScreen({super.key});

  static const _cards = <_ModeSpec>[
    _ModeSpec(GameMode.cultureGenerale, 'Culture générale', 'Des questions variées', 84,
        Color(0xFFFFE257), Color(0xFFFEB919), Color(0xFFF08A0A), Color(0xFF4A1A08), Color(0xFF6B2E0C), _Icon.globe,
        BombState.happy, 0, 72),
    _ModeSpec(GameMode.completementFou, 'Complètement fou', 'Des questions absurdes', 170,
        Color(0xFFFF6E95), Color(0xFFF83FA4), Color(0xFFD01E6E), Colors.white, Colors.white, _Icon.none,
        BombState.laughing, 3, 14),
    _ModeSpec(GameMode.entreAmis, 'Entre amis', 'Des questions fun\net personnelles', 256,
        Color(0xFF2ACDFD), Color(0xFF0A98F8), Color(0xFF1555B8), Colors.white, Colors.white, _Icon.hearts,
        BombState.happy, 4, 75),
    _ModeSpec(GameMode.reflexes, 'Réflexes', 'Réponds le plus vite\npossible !', 341,
        Color(0xFF74E84A), Color(0xFF05BB51), Color(0xFF07863A), Colors.white, Colors.white, _Icon.bolt,
        BombState.celebration, 2, 75),
    _ModeSpec(GameMode.extreme, 'Extrême', 'Pour les pros !', 427,
        Color(0xFFA04CFD), Color(0xFF8538F4), Color(0xFF4C1BDF), Colors.white, Colors.white, _Icon.boltPurple,
        BombState.angry, 3, 64),
  ];

  @override
  Widget build(BuildContext context) {
    return PastelScreen(
      refW: 214,
      refH: 536,
      title: 'Modes de jeu',
      titleCenterX: 112,
      builder: (context, r) => [
        for (final m in _cards)
          Positioned(
            left: r.x(8), right: r.x(6), top: r.y(m.top), height: r.y(81),
            child: CandyCard(
              top: m.c1, bottom: m.c2, edge: m.edge, radius: r.x(14), depth: r.y(3),
              onTap: () {
                AppState.instance.setMode(m.mode);
                Navigator.pushNamed(context, AppRoutes.players);
              },
              child: _ModeCardContent(spec: m, r: r),
            ),
          ),
      ],
    );
  }
}

enum _Icon { none, globe, hearts, bolt, boltPurple }

class _ModeSpec {
  const _ModeSpec(this.mode, this.title, this.subtitle, this.top, this.c1, this.c2, this.edge, this.titleColor,
      this.subColor, this.icon, this.bomb, this.frame, this.textLeft);
  final GameMode mode;
  final String title, subtitle;
  final double top;
  final Color c1, c2, edge, titleColor, subColor;
  final _Icon icon;
  final BombState bomb;
  final int frame;
  final double textLeft;
}

class _ModeCardContent extends StatelessWidget {
  const _ModeCardContent({required this.spec, required this.r});
  final _ModeSpec spec;
  final RefScale r;

  @override
  Widget build(BuildContext context) {
    final k = r.k;
    Widget? icon;
    switch (spec.icon) {
      case _Icon.globe:
        icon = SizedBox.square(dimension: 46 * k, child: const Illustration('cat_pays'));
      case _Icon.hearts:
        icon = GlossyDisc(size: 44 * k, color: const Color(0xFF2C6FE0), child: const Illustration('icon_hearts'));
      case _Icon.bolt:
        icon = GlossyDisc(size: 44 * k, color: const Color(0xFF16A63F), child: const Illustration('icon_bolt'));
      case _Icon.boltPurple:
        icon = GlossyDisc(size: 44 * k, color: const Color(0xFF7E3CF0), child: const Illustration('icon_bolt_purple'));
      case _Icon.none:
        icon = null;
    }
    final shadow = spec.titleColor == Colors.white
        ? [Shadow(color: Colors.black.withValues(alpha: 0.25), offset: Offset(0, 1.2 * k), blurRadius: 1.5 * k)]
        : null;
    return Stack(clipBehavior: Clip.none, children: [
      if (icon != null) Positioned(left: 13 * k, top: 18 * k, child: icon),
      // mascotte
      Positioned(
        right: 0 * k, top: (spec.mode == GameMode.cultureGenerale ? 4 : 2) * k, height: 76 * k,
        child: _Mascot(spec: spec),
      ),
      Positioned(
        left: spec.textLeft * k, right: 38 * k, top: 0, bottom: 0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(spec.title, maxLines: 1, style: BoomText.ui800(12.6 * k, color: spec.titleColor, height: 1.05).copyWith(shadows: shadow))),
            SizedBox(height: 1.5 * k),
            Text(spec.subtitle, style: BoomText.ui600(7.6 * k, color: spec.subColor, height: 1.2).copyWith(shadows: shadow)),
          ],
        ),
      ),
    ]);
  }
}

class _Mascot extends StatelessWidget {
  const _Mascot({required this.spec});
  final _ModeSpec spec;

  static const _art = {
    GameMode.cultureGenerale: 'mode_culture',
    GameMode.completementFou: 'mode_fou',
    GameMode.entreAmis: 'mode_amis',
    GameMode.reflexes: 'mode_reflexes',
    GameMode.extreme: 'mode_extreme',
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final h = c.maxHeight;
      return SizedBox(width: h * 0.95, child: Illustration(_art[spec.mode]!, scale: 1.15, alignment: Alignment.bottomCenter));
    });
  }
}
