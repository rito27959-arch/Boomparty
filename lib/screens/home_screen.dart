import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../character/bomb_game.dart';
import '../character/bomb_state.dart';
import '../design/backgrounds.dart';
import '../design/candy_button.dart';
import '../design/cartoon_title.dart';
import '../design/icons.dart';
import '../design/tokens.dart';

/// Écran 1 — Accueil. Coordonnées relevées sur reference/01_accueil.png
/// (224 × 544 px) puis exprimées en fractions de l'écran.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const refW = 224.0, refH = 544.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        final k = w / refW; // facteur d'échelle horizontal (ref px → dp)
        double y(double v) => v * h / refH;
        double x(double v) => v * k;
        return Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: HomeBackgroundPainter())),
          // bombe décorative derrière le logo
          Positioned(left: x(60), top: y(23), width: x(110), height: y(64), child: const CustomPaint(painter: LogoBombPainter())),
          // héros animé (Flame) + confettis
          const Positioned.fill(
            child: BombStage(
              placement: BombPlacement(feet: Offset(0.475, 0.668), bodyWidth: 146 / refW),
              state: BombState.celebration,
              confetti: 22,
            ),
          ),
          // logo BOOM / PARTY
          Positioned(
            left: x(14), width: x(196), top: y(58), height: y(60),
            child: Transform.rotate(
              angle: -0.07,
              child: FittedBox(
                child: CartoonTitle('BOOM',
                    fontSize: 80, letterSpacing: 2,
                    fill: const [BoomColors.titleYellow, BoomColors.titleOrange],
                    outline: BoomColors.titleOutline),
              ),
            ),
          ),
          Positioned(
            left: x(48), width: x(130), top: y(116), height: y(42),
            child: Transform.rotate(
              angle: -0.02,
              child: FittedBox(
                child: CartoonTitle('PARTY',
                    fontSize: 80, letterSpacing: 1,
                    fill: const [Colors.white, BoomColors.titleLavender],
                    outline: BoomColors.titleOutline),
              ),
            ),
          ),
          // accroche
          Positioned(
            left: 0, right: 0, top: y(354),
            child: Text("Le jeu qui met\nl'ambiance !",
                textAlign: TextAlign.center, style: BoomText.ui800(12.6 * k, height: 1.08)),
          ),
          // bouton Jouer
          Positioned(
            left: x(18), right: x(19), top: y(400),
            child: CandyButton(
              height: y(44), depth: y(4),
              top: BoomColors.yellowTop, bottom: BoomColors.yellowBottom, edge: BoomColors.yellowEdge,
              onPressed: () => Navigator.pushNamed(context, AppRoutes.modes),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                PlayBadge(size: x(27)),
                SizedBox(width: x(20)),
                Text('Jouer', style: BoomText.ui800(22 * k)),
                SizedBox(width: x(30)),
              ]),
            ),
          ),
          // menu secondaire
          Positioned(
            left: x(27), right: x(28), top: y(456), height: y(86),
            child: _HomeMenu(k: k, rowH: y(86) / 3, routes: const [AppRoutes.modes, AppRoutes.customize, AppRoutes.howTo]),
          ),
        ]);
      }),
    );
  }
}

class _HomeMenu extends StatelessWidget {
  const _HomeMenu({required this.k, required this.rowH, required this.routes});
  final double k, rowH;
  final List<String> routes;

  @override
  Widget build(BuildContext context) {
    const labels = ['Modes de jeu', 'Personnalisation', 'Comment jouer ?'];
    final icons = [MenuIcon.gamepad, MenuIcon.shirt, MenuIcon.help];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14 * k),
      ),
      child: Column(children: [
        for (var i = 0; i < 3; i++)
          SizedBox(
            height: rowH,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(12 * k),
                onTap: () => Navigator.pushNamed(context, routes[i]),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4 * k, vertical: 1.5 * k),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10 * k),
                  ),
                  child: Row(children: [
                    SizedBox(width: 15 * k),
                    SizedBox(width: 22 * k, height: 18 * k, child: CustomPaint(painter: MenuIconPainter(icons[i]))),
                    SizedBox(width: 15 * k),
                    Text(labels[i], style: BoomText.ui700(10.8 * k, color: const Color(0xFF1E1838))),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
