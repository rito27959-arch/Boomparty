import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'backgrounds.dart';

/// Salon chaleureux de l'écran de jeu (05) : murs orangés, fenêtre à gauche,
/// plante à droite, parquet, lumière chaude derrière la bombe.
class RoomScenePainter extends CustomPainter {
  const RoomScenePainter();

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final full = Offset.zero & s;
    c.drawRect(
        full,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6A2A1C), Color(0xFF9A4A30), Color(0xFFB0603E), Color(0xFFC0623A), Color(0xFF9A3A16), Color(0xFFB5521E)],
            stops: [0.0, 0.12, 0.3, 0.55, 0.78, 1.0],
          ).createShader(full));
    // poutres du plafond
    final beam = Paint()..color = const Color(0x33200800);
    for (var i = 0; i < 4; i++) {
      c.drawRect(Rect.fromLTWH(0, h * (0.02 + i * 0.045), w, h * 0.012), beam);
    }
    // fenêtre lumineuse (gauche)
    final win = Rect.fromLTWH(-w * 0.04, h * 0.38, w * 0.3, h * 0.32);
    c.drawRect(win, Paint()..shader = const LinearGradient(colors: [Color(0xFFF4E6D2), Color(0xFFE3B98F)]).createShader(win));
    final frame = Paint()
      ..color = const Color(0xFF6E3820)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018;
    c.drawRect(win, frame);
    c.drawLine(Offset(win.center.dx, win.top), Offset(win.center.dx, win.bottom), frame);
    c.drawLine(Offset(win.left, win.center.dy), Offset(win.right, win.center.dy), frame);
    // lumière chaude centrale
    final glowC = Offset(w * 0.55, h * 0.55);
    c.drawCircle(
        glowC,
        w * 0.8,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0x99FFB066), Color(0x00FF8A3A)])
              .createShader(Rect.fromCircle(center: glowC, radius: w * 0.8)));
    // plante (droite)
    final pot = Rect.fromLTWH(w * 0.78, h * 0.6, w * 0.16, h * 0.07);
    c.drawRRect(RRect.fromRectAndRadius(pot, Radius.circular(w * 0.02)), Paint()..color = const Color(0xFFC0622C));
    final leaf = Paint()..color = const Color(0xFF3F7A2A);
    for (var i = 0; i < 7; i++) {
      final a = -math.pi / 2 + (i - 3) * 0.32;
      final base = Offset(pot.center.dx, pot.top);
      c.save();
      c.translate(base.dx, base.dy);
      c.rotate(a + math.pi / 2);
      c.drawOval(Rect.fromCenter(center: Offset(0, -h * 0.06), width: w * 0.06, height: h * 0.11), leaf);
      c.restore();
    }
    // parquet
    final floor = Rect.fromLTWH(0, h * 0.74, w, h * 0.26);
    c.drawRect(floor, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8E3A16), Color(0xFFB6582A)]).createShader(floor));
    final plank = Paint()..color = const Color(0x22000000)..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      c.drawLine(Offset(0, h * (0.74 + i * 0.045)), Offset(w, h * (0.74 + i * 0.045)), plank);
    }
    // poussières lumineuses
    final dot = Paint()..color = const Color(0x66FFE7B0);
    final r = math.Random(3);
    for (var i = 0; i < 18; i++) {
      c.drawCircle(Offset(r.nextDouble() * w, h * (0.1 + r.nextDouble() * 0.6)), w * (0.004 + r.nextDouble() * 0.006), dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Fond en éclat radial (bonne réponse, déjà dit, trop lent, explosion).
class BurstScenePainter extends CustomPainter {
  const BurstScenePainter({
    required this.center,
    required this.inner,
    required this.outer,
    required this.ray,
    this.focus = const Alignment(0, -0.05),
    this.rays = 16,
    this.bottomClouds = const [],
    this.sparkles = const [],
    this.seed = 1,
  });

  final Alignment focus;
  final Color center, inner, outer, ray;
  final int rays;
  final List<Color> bottomClouds;
  final List<Color> sparkles;
  final int seed;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final full = Offset.zero & s;
    final f = focus.alongSize(s);
    c.drawRect(
        full,
        Paint()
          ..shader = RadialGradient(
            center: focus,
            radius: 1.0,
            colors: [center, inner, outer],
            stops: const [0.0, 0.35, 1.0],
          ).createShader(full));
    // rayons
    final rp = Paint()..color = ray;
    final len = math.max(w, h) * 1.2;
    for (var i = 0; i < rays; i++) {
      final a0 = i * 2 * math.pi / rays;
      final a1 = a0 + math.pi / rays * 0.55;
      c.drawPath(
          Path()
            ..moveTo(f.dx, f.dy)
            ..lineTo(f.dx + math.cos(a0) * len, f.dy + math.sin(a0) * len)
            ..lineTo(f.dx + math.cos(a1) * len, f.dy + math.sin(a1) * len)
            ..close(),
          rp);
    }
    // éclats / confettis étoilés
    if (sparkles.isNotEmpty) {
      final r = math.Random(seed);
      for (var i = 0; i < 16; i++) {
        final p = Offset(r.nextDouble() * w, h * (0.05 + r.nextDouble() * 0.75));
        final col = sparkles[i % sparkles.length];
        c.save();
        c.translate(p.dx, p.dy);
        c.rotate(r.nextDouble() * math.pi);
        final sz = w * (0.02 + r.nextDouble() * 0.03);
        if (i.isEven) {
          final star = Path();
          for (var k = 0; k < 10; k++) {
            final a = -math.pi / 2 + k * math.pi / 5;
            final rr = k.isEven ? sz : sz * 0.45;
            final pt = Offset(math.cos(a) * rr, math.sin(a) * rr);
            k == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
          }
          c.drawPath(star..close(), Paint()..color = col);
        } else {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: sz * 1.6, height: sz * 0.9), Radius.circular(sz * 0.3)),
              Paint()..color = col);
        }
        c.restore();
      }
    }
    // nuages colorés en bas
    for (var i = 0; i < bottomClouds.length; i++) {
      final x = w * (i / math.max(1, bottomClouds.length - 1));
      final col = bottomClouds[i];
      paintCloud(c, Offset(x, h * (0.97 - (i.isEven ? 0.01 : 0.03))), w * 0.55, Color.lerp(col, Colors.white, 0.2)!, col);
    }
  }

  @override
  bool shouldRepaint(covariant BurstScenePainter old) =>
      old.center != center || old.inner != inner || old.outer != outer || old.focus != focus;
}

/// Bulle de dialogue blanche avec pointe, légèrement inclinée.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.child,
    this.angle = 0,
    this.tailX = 0.3,
    this.tailDown = true,
    this.radius = 22,
    this.padding = const EdgeInsets.fromLTRB(14, 10, 14, 12),
  });

  final Widget child;
  final double angle;
  final double tailX; // position horizontale de la pointe (0..1)
  final bool tailDown;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: CustomPaint(
        painter: _BubblePainter(radius: radius, tailX: tailX, tailDown: tailDown),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.radius, required this.tailX, required this.tailDown});
  final double radius, tailX;
  final bool tailDown;

  @override
  void paint(Canvas c, Size s) {
    final body = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(radius));
    final tw = radius * 0.9;
    final tx = s.width * tailX;
    final tail = tailDown
        ? (Path()
          ..moveTo(tx - tw * 0.5, s.height - 2)
          ..lineTo(tx - tw * 0.15, s.height + tw * 0.75)
          ..lineTo(tx + tw * 0.5, s.height - 2)
          ..close())
        : Path();
    final path = Path()
      ..addRRect(body)
      ..addPath(tail, Offset.zero);
    c.drawShadow(path, const Color(0xFF000000), radius * 0.35, false);
    final paint = Paint()..color = Colors.white;
    c.drawRRect(body, paint);
    c.drawPath(tail, paint);
    // léger dégradé crème en bas pour le volume
    c.drawRRect(
        body,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00FFFFFF), Color(0x14C9A98E)])
              .createShader(Offset.zero & s));
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => old.radius != radius || old.tailX != tailX || old.tailDown != tailDown;
}
