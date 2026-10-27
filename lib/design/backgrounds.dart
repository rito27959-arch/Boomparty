import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Nuage cartoon : grappe de cercles avec ombrage doux en bas.
void paintCloud(Canvas c, Offset center, double w, Color top, Color bottom) {
  final h = w * 0.42;
  final rect = Rect.fromCenter(center: center, width: w, height: h);
  final paint = Paint()
    ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom])
        .createShader(rect);
  final path = Path()
    ..addOval(Rect.fromCircle(center: center + Offset(-w * 0.26, h * 0.12), radius: h * 0.42))
    ..addOval(Rect.fromCircle(center: center + Offset(-w * 0.04, -h * 0.12), radius: h * 0.55))
    ..addOval(Rect.fromCircle(center: center + Offset(w * 0.22, h * 0.02), radius: h * 0.46))
    ..addOval(Rect.fromCircle(center: center + Offset(w * 0.38, h * 0.2), radius: h * 0.3))
    ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(center.dx - w * 0.5, center.dy + h * 0.02, center.dx + w * 0.5, center.dy + h * 0.5),
        Radius.circular(h * 0.3)));
  c.drawPath(path, paint);
}

/// Étoile-étincelle à 8 branches avec halo.
void paintSpark(Canvas c, Offset center, double r, {double rotation = 0}) {
  c.drawCircle(center, r * 1.3,
      Paint()..shader = const RadialGradient(colors: [Color(0xCCFFF6A0), Color(0x00FFC020)]).createShader(Rect.fromCircle(center: center, radius: r * 1.3)));
  final path = Path();
  const n = 8;
  for (var i = 0; i < n * 2; i++) {
    final a = rotation + i * math.pi / n;
    final rr = i.isEven ? r : r * 0.42;
    final p = center + Offset(math.cos(a) * rr, math.sin(a) * rr);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  c.drawPath(path, Paint()..color = const Color(0xFFFFC21A));
  c.drawCircle(center, r * 0.32, Paint()..color = const Color(0xFFFFFDE8));
}

/// Fond de l'écran d'accueil : ciel, rayons, nuages, sol sablé, crème en bas.
class HomeBackgroundPainter extends CustomPainter {
  const HomeBackgroundPainter();

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final full = Offset.zero & s;
    // dégradé principal ciel → pêche → sable → crème
    c.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            BoomColors.skyTop, Color(0xFF55CCFD), BoomColors.skyMid, Color(0xFFFAD3EE),
            Color(0xFFFDE6A0), Color(0xFFFEE07A), Color(0xFFFEE9B0), BoomColors.cream,
          ],
          stops: [0.0, 0.14, 0.24, 0.36, 0.5, 0.64, 0.76, 0.84],
        ).createShader(full),
    );
    // rayons de lumière rose derrière la bombe
    final ray = Paint()..color = const Color(0x88FFC3E6);
    for (final x in [0.36, 0.46, 0.56]) {
      final path = Path()
        ..moveTo(w * x, h * 0.28)
        ..lineTo(w * (x + 0.07), h * 0.28)
        ..lineTo(w * (x + 0.1), h * 0.48)
        ..lineTo(w * (x - 0.03), h * 0.48)
        ..close();
      c.drawPath(path, ray);
    }
    // halo du sol
    c.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.62), width: w * 1.1, height: h * 0.16),
      Paint()..shader = const RadialGradient(colors: [Color(0xFFFFE97A), Color(0x00FFD86A)])
          .createShader(Rect.fromCenter(center: Offset(w * 0.5, h * 0.62), width: w * 1.1, height: h * 0.16)),
    );
    // nuages
    paintCloud(c, Offset(w * 0.12, h * 0.065), w * 0.34, Colors.white, const Color(0xFFDDEFFF));
    paintCloud(c, Offset(w * 0.93, h * 0.36), w * 0.36, Colors.white, const Color(0xFFF7D6F2));
    paintCloud(c, Offset(w * 0.06, h * 0.45), w * 0.42, const Color(0xFFFBC9EE), const Color(0xFFF58BCB));
    paintCloud(c, Offset(w * 0.96, h * 0.5), w * 0.4, const Color(0xFFE6B4F5), const Color(0xFFB57EE6));
    paintCloud(c, Offset(w * 0.04, h * 0.66), w * 0.36, Colors.white, const Color(0xFFFCE6D8));
    paintCloud(c, Offset(w * 0.98, h * 0.655), w * 0.4, Colors.white, const Color(0xFFFCE6D8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Petite bombe décorative derrière le logo (capuchon + mèche + étincelle).
class LogoBombPainter extends CustomPainter {
  const LogoBombPainter();

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    // capuchon
    final cap = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.38, h * 0.42, w * 0.2, h * 0.2), Radius.circular(w * 0.03));
    c.drawRRect(cap, Paint()..shader = const LinearGradient(colors: [Color(0xFF3B3F57), Color(0xFF14121E)]).createShader(cap.outerRect));
    // mèche torsadée
    final fuse = Path()
      ..moveTo(w * 0.5, h * 0.45)
      ..quadraticBezierTo(w * 0.52, h * 0.1, w * 0.66, h * 0.16);
    c.drawPath(
        fuse,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.035
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFD9822B));
    paintSpark(c, Offset(w * 0.68, h * 0.15), w * 0.13, rotation: 0.2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
