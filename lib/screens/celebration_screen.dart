import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app_routes.dart';
import '../character/bomb_game.dart';
import '../character/bomb_state.dart';
import '../design/avatars.dart';
import '../design/backgrounds.dart';
import '../design/candy_button.dart';
import '../design/cartoon_title.dart';
import '../design/screen_chrome.dart';
import '../design/tokens.dart';
import '../engine/game_engine.dart';
import '../state/app_state.dart';
import '../design/illustration.dart';
import 'leaderboard_screen.dart';

/// Écran 14 — Célébration finale. Référence : reference/14_celebration.png (238 × 450).
/// Les données (manches, explosions, gagnant) viennent du moteur.
class CelebrationScreen extends StatelessWidget {
  const CelebrationScreen({super.key, this.result});
  final GameFinished? result;

  @override
  Widget build(BuildContext context) {
    final res = result ?? AppState.instance.lastResult;
    final ranking = res?.ranking ?? AppState.instance.players;
    final winner = ranking.isEmpty ? null : ranking.first;
    final stats = [
      (_StatIcon.trophy, '${res?.rounds ?? 0} manches'),
      (_StatIcon.bomb, '${res?.explosions ?? 0} explosions'),
      (_StatIcon.medal, '${winner?.name ?? '—'} gagnant${_fem(winner?.name) ? 'e' : ''} !'),
    ];
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final r = RefScale(c.biggest, 238, 450);
        final k = r.k;
        // positions des joueurs autour de la bombe (gagnant en haut à gauche)
        const spots = [(10.0, 100.0, 82.0), (150.0, 92.0, 82.0), (0.0, 178.0, 70.0), (176.0, 176.0, 64.0), (96.0, 226.0, 0.0)];
        return Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: _PartyBackgroundPainter())),
          for (var i = 0; i < ranking.length && i < 4; i++)
            Positioned(
              left: r.x(spots[i].$1), top: r.y(spots[i].$2),
              child: PlayerAvatar(index: ranking[i].avatar, size: spots[i].$3 * k),
            ),
          const Positioned.fill(
            child: BombStage(
              placement: BombPlacement(feet: Offset(0.55, 0.66), bodyWidth: 0.48),
              state: BombState.celebration,
              confetti: 26,
            ),
          ),
          Positioned(
            left: r.x(16), width: r.x(200), top: r.y(14), height: r.y(84),
            child: Transform.rotate(
              angle: -0.12,
              child: FittedBox(
                child: CartoonTitle('SOIRÉE\nDE LÉGENDE !',
                    fontSize: 80, height: 0.95, fill: const [Color(0xFFFFE24A), Color(0xFFF7A112)], outline: const Color(0xFF3B1470)),
              ),
            ),
          ),
          Positioned(
            left: r.x(40), right: r.x(28), top: r.y(257), height: r.y(74),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14 * k, vertical: 6 * k),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12 * k),
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                for (final (icon, text) in stats)
                  Row(children: [
                    SizedBox(width: 16 * k, height: 16 * k, child: Illustration(_statArt[icon]!)),
                    SizedBox(width: 22 * k),
                    Text(text, style: BoomText.ui600(10.5 * k, color: const Color(0xFF1E1838))),
                  ]),
              ]),
            ),
          ),
          Positioned(
            left: r.x(20), right: r.x(18), top: r.y(342),
            child: CandyButton(
              height: r.y(40), depth: r.y(4),
              top: BoomColors.purpleTop, bottom: BoomColors.purpleBottom, edge: BoomColors.purpleEdge,
              onPressed: () => Share.share(
                'BOOM PARTY : ${res?.rounds ?? 0} manches, ${res?.explosions ?? 0} explosions… '
                'et ${winner?.name ?? 'personne'} remporte la soirée ! 💣🎉',
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.share_rounded, color: Colors.white, size: 18 * k),
                SizedBox(width: 12 * k),
                Text('Partager', style: BoomText.ui800(15.5 * k, color: Colors.white)),
              ]),
            ),
          ),
          Positioned(
            left: r.x(32), right: r.x(28), top: r.y(397), height: r.y(35),
            child: GreyPillButton(
              label: 'Rejouer', k: k,
              onTap: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.game, (route) => route.isFirst),
            ),
          ),
        ]);
      }),
    );
  }

  static bool _fem(String? n) => n != null && const {'Emma', 'Sarah', 'Inès'}.contains(n);
}

enum _StatIcon { trophy, bomb, medal }

const _statArt = {_StatIcon.trophy: 'trophy', _StatIcon.bomb: 'voice_classique', _StatIcon.medal: 'medal_1'};

class _PartyBackgroundPainter extends CustomPainter {
  const _PartyBackgroundPainter();
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final rect = Offset.zero & s;
    c.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF3FB8F8), Color(0xFF8ED8FA), Color(0xFFFFD27A), Color(0xFFF6A8C8), Color(0xFFFDE7DA)],
            stops: [0.0, 0.2, 0.42, 0.62, 0.8],
          ).createShader(rect));
    paintSpark(c, Offset(w * 0.6, h * 0.36), w * 0.1, rotation: 0.2);
    paintCloud(c, Offset(w * 0.05, h * 0.62), w * 0.45, const Color(0xFFFBC3E0), const Color(0xFFF58BC2));
    paintCloud(c, Offset(w * 0.98, h * 0.64), w * 0.42, const Color(0xFFFBC3E0), const Color(0xFFF58BC2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
