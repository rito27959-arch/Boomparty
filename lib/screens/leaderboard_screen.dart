import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../services/ads_service.dart';
import '../design/avatars.dart';
import '../design/backgrounds.dart';
import '../design/candy_button.dart';
import '../design/illustration.dart';
import '../design/screen_chrome.dart';
import '../design/tokens.dart';
import '../engine/game_engine.dart';
import '../state/app_state.dart';

/// Écran 11 — Classement. Référence : reference/11_classement.png (222 × 450).
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key, this.ranking});

  /// Classement à afficher ; par défaut celui de la dernière partie.
  final List<Player>? ranking;

  @override
  Widget build(BuildContext context) {
    final rank = ranking ?? AppState.instance.lastResult?.ranking ?? const <Player>[];
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final r = RefScale(c.biggest, 222, 450);
        final k = r.k;
        return Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: PastelBackgroundPainter(PastelDecor.none))),
          Positioned(left: 0, right: 0, top: 0, height: r.y(98), child: const CustomPaint(painter: _SkyHeaderPainter())),
          Positioned(left: r.x(31), top: r.y(30), width: r.x(42), height: r.y(52), child: const Illustration('trophy', scale: 1.35)),
          Positioned(
            left: r.x(83), top: r.y(30),
            child: Text('Classement\nde la partie', style: BoomText.ui800(15.5 * k, color: const Color(0xFF1A1A4A), height: 1.02)),
          ),
          Positioned(
            left: r.x(7), right: r.x(11), top: r.y(98), height: r.y(214),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14 * k),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: rank.length,
                itemExtent: r.y(41.5),
                itemBuilder: (_, i) => _Row(rank: i + 1, p: rank[i], k: k, highlight: i == 0),
              ),
            ),
          ),
          Positioned(
            left: r.x(15), right: r.x(16), top: r.y(328),
            child: CandyButton(
              height: r.y(40), depth: r.y(4),
              top: BoomColors.yellowTop, bottom: BoomColors.yellowBottom, edge: BoomColors.yellowEdge,
              onPressed: () => AdsService.beforeNextGame(() => Navigator.pushReplacementNamed(context, AppRoutes.game)),
              child: Text('Rejouer', style: BoomText.ui800(15.5 * k)),
            ),
          ),
          Positioned(
            left: r.x(15), right: r.x(16), top: r.y(384), height: r.y(38),
            child: _GreyPill(
              label: 'Retour au menu', k: k,
              onTap: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false),
            ),
          ),
          if (AppState.instance.lastResult != null)
            Positioned(
              right: r.x(12), top: r.y(84),
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.celebration),
                child: Text('Voir la fête ›', style: BoomText.ui700(8 * k, color: const Color(0xFF6B4FA0))),
              ),
            ),
        ]);
      }),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.p, required this.k, required this.highlight});
  final int rank;
  final Player p;
  final double k;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 2 * k, vertical: 1 * k),
      decoration: BoxDecoration(
        color: highlight ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10 * k),
        border: highlight ? null : const Border(top: BorderSide(color: Color(0x146B4FA0))),
      ),
      child: Row(children: [
        SizedBox(width: 9 * k),
        SizedBox(width: 26 * k, height: 26 * k, child: rank <= 3 ? Illustration('medal_$rank', scale: 2.1) : Center(child: Text('$rank', style: BoomText.ui800(12.5 * k)))),
        SizedBox(width: 8 * k),
        PlayerAvatar(index: p.avatar, size: 30 * k),
        SizedBox(width: 9 * k),
        Expanded(child: Text(p.name, style: BoomText.ui700(11.5 * k))),
        Text('${p.score}', style: BoomText.ui800(11.5 * k)),
        SizedBox(width: 11 * k),
      ]),
    );
  }
}

class _GreyPill extends StatelessWidget {
  const _GreyPill({required this.label, required this.k, required this.onTap});
  final String label;
  final double k;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEFE7EE),
            borderRadius: BorderRadius.circular(100),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 3))],
          ),
          alignment: Alignment.center,
          child: Text(label, style: BoomText.ui700(10.5 * k, color: const Color(0xFF1E1838))),
        ),
      );
}

/// Bouton gris secondaire réutilisé (Classement, Célébration).
class GreyPillButton extends StatelessWidget {
  const GreyPillButton({super.key, required this.label, required this.k, required this.onTap});
  final String label;
  final double k;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _GreyPill(label: label, k: k, onTap: onTap);
}

class _SkyHeaderPainter extends CustomPainter {
  const _SkyHeaderPainter();
  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    c.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFBFE6FA), Color(0xFFF6DCEA), Color(0x00FDE7DA)]).createShader(rect));
    paintCloud(c, Offset(s.width * 0.88, s.height * 0.12), s.width * 0.5, const Color(0xFFF9C9DF), const Color(0x00F9C9DF));
    paintCloud(c, Offset(s.width * 0.08, s.height * 0.5), s.width * 0.3, const Color(0xFFE6D2F7), const Color(0x00E6D2F7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TrophyPainter extends CustomPainter {
  const TrophyPainter();
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final gold = Paint()..shader = const LinearGradient(colors: [Color(0xFFFFE27A), Color(0xFFF5A300), Color(0xFFFFD040)]).createShader(Offset.zero & s);
    final handle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..color = const Color(0xFFF2A400);
    c.drawArc(Rect.fromLTWH(0, h * 0.08, w * 0.4, h * 0.36), 1.4, 3.2, false, handle);
    c.drawArc(Rect.fromLTWH(w * 0.6, h * 0.08, w * 0.4, h * 0.36), -1.7, 3.2, false, handle);
    c.drawPath(
        Path()
          ..moveTo(w * 0.15, h * 0.04)
          ..lineTo(w * 0.85, h * 0.04)
          ..quadraticBezierTo(w * 0.85, h * 0.6, w * 0.5, h * 0.64)
          ..quadraticBezierTo(w * 0.15, h * 0.6, w * 0.15, h * 0.04)
          ..close(),
        gold);
    c.drawRect(Rect.fromLTWH(w * 0.44, h * 0.62, w * 0.12, h * 0.16), gold);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.2, h * 0.78, w * 0.6, h * 0.18), Radius.circular(w * 0.05)), Paint()..color = const Color(0xFFD98A00));
    c.drawOval(Rect.fromLTWH(w * 0.28, h * 0.12, w * 0.14, h * 0.28), Paint()..color = Colors.white.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MedalPainter extends CustomPainter {
  const MedalPainter(this.rank);
  final int rank;
  @override
  void paint(Canvas c, Size s) {
    final colors = switch (rank) {
      1 => const [Color(0xFFFFE066), Color(0xFFF2A900)],
      2 => const [Color(0xFFF2F4F8), Color(0xFFA8AEC0)],
      _ => const [Color(0xFFFFB066), Color(0xFFD9701E)],
    };
    final ribbon = switch (rank) { 1 => const Color(0xFF3B6FE0), 2 => const Color(0xFFE0457A), _ => const Color(0xFFE0457A) };
    final w = s.width, h = s.height;
    c.drawPath(Path()..moveTo(w * 0.2, h * 0.6)..lineTo(w * 0.12, h)..lineTo(w * 0.32, h * 0.9)..lineTo(w * 0.45, h * 0.7)..close(), Paint()..color = ribbon);
    c.drawPath(Path()..moveTo(w * 0.8, h * 0.6)..lineTo(w * 0.88, h)..lineTo(w * 0.68, h * 0.9)..lineTo(w * 0.55, h * 0.7)..close(), Paint()..color = ribbon);
    final o = Offset(w / 2, h * 0.42);
    c.drawCircle(o, w * 0.4, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(Rect.fromCircle(center: o, radius: w * 0.4)));
    c.drawCircle(o, w * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.25));
    final tp = TextPainter(text: TextSpan(text: '$rank', style: BoomText.ui800(w * 0.42, color: const Color(0xFF5A3A10))), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant MedalPainter old) => old.rank != rank;
}
