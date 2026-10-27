import 'package:flutter/material.dart';

import 'tokens.dart';

/// Pastille « lecture » du bouton Jouer : disque bordeaux, anneau sombre,
/// triangle jaune avec reflet.
class PlayBadge extends StatelessWidget {
  const PlayBadge({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: size, child: const CustomPaint(painter: _PlayPainter()));
}

class _PlayPainter extends CustomPainter {
  const _PlayPainter();
  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final o = Offset(r, r);
    c.drawCircle(o, r, Paint()..color = const Color(0xFF5C0E12));
    c.drawCircle(
        o,
        r * 0.84,
        Paint()
          ..shader = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFB8262C), BoomColors.playRed])
              .createShader(Rect.fromCircle(center: o, radius: r)));
    final tri = Path()
      ..moveTo(r * 0.78, r * 0.52)
      ..lineTo(r * 1.5, r)
      ..lineTo(r * 0.78, r * 1.48)
      ..close();
    c.drawPath(tri, Paint()..color = const Color(0xFFFFD21F));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum MenuIcon { gamepad, shirt, help }

/// Icônes violettes pleines du menu d'accueil, dessinées en vectoriel.
class MenuIconPainter extends CustomPainter {
  const MenuIconPainter(this.icon);
  final MenuIcon icon;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final rect = Offset.zero & s;
    final fill = Paint()
      ..shader = const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6A43B0), BoomColors.iconPurple])
          .createShader(rect);
    final hole = Paint()..color = const Color(0xFFEDE4FA);
    switch (icon) {
      case MenuIcon.gamepad:
        final body = Path()
          ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, h * 0.15, w, h * 0.6), Radius.circular(h * 0.3)))
          ..addOval(Rect.fromLTWH(0, h * 0.3, w * 0.38, h * 0.68))
          ..addOval(Rect.fromLTWH(w * 0.62, h * 0.3, w * 0.38, h * 0.68));
        c.drawPath(body, fill);
        // croix directionnelle
        c.drawRect(Rect.fromCenter(center: Offset(w * 0.25, h * 0.45), width: w * 0.2, height: h * 0.08), hole);
        c.drawRect(Rect.fromCenter(center: Offset(w * 0.25, h * 0.45), width: w * 0.07, height: h * 0.26), hole);
        c.drawCircle(Offset(w * 0.72, h * 0.38), w * 0.05, hole);
        c.drawCircle(Offset(w * 0.8, h * 0.52), w * 0.05, hole);
      case MenuIcon.shirt:
        final p = Path()
          ..moveTo(w * 0.32, 0)
          ..quadraticBezierTo(w * 0.5, h * 0.18, w * 0.68, 0)
          ..lineTo(w, h * 0.2)
          ..lineTo(w * 0.86, h * 0.48)
          ..lineTo(w * 0.76, h * 0.42)
          ..lineTo(w * 0.76, h)
          ..lineTo(w * 0.24, h)
          ..lineTo(w * 0.24, h * 0.42)
          ..lineTo(w * 0.14, h * 0.48)
          ..lineTo(0, h * 0.2)
          ..close();
        c.drawPath(p, fill);
      case MenuIcon.help:
        final o = Offset(w / 2, h / 2);
        final r = h / 2;
        c.drawCircle(o, r, Paint()..color = const Color(0xFF8C73C8));
        c.drawCircle(o, r * 0.82, Paint()..color = const Color(0xFFB9A6E6));
        final tp = TextPainter(
          text: TextSpan(text: '?', style: BoomText.ui800(r * 1.3, color: BoomColors.iconPurple)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant MenuIconPainter old) => old.icon != icon;
}
