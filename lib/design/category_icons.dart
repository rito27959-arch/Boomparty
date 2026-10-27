import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'illustrations.dart';

/// Icônes « 3D » des catégories, en vectoriel avec dégradés et reflets.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.id, {super.key, required this.size});
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: id == 'pays' ? const GlobePainter() : _CatPainter(id)),
      );
}

Paint _grad(Rect r, List<Color> c, {Alignment b = Alignment.topCenter, Alignment e = Alignment.bottomCenter}) =>
    Paint()..shader = LinearGradient(begin: b, end: e, colors: c).createShader(r);

void _gloss(Canvas c, Rect r) => c.drawOval(
    Rect.fromLTWH(r.left + r.width * 0.18, r.top + r.height * 0.08, r.width * 0.35, r.height * 0.18),
    Paint()..color = Colors.white.withValues(alpha: 0.45));

class _CatPainter extends CustomPainter {
  const _CatPainter(this.id);
  final String id;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.03);
    switch (id) {
      case 'animaux':
        final pad = Rect.fromCenter(center: Offset(w * 0.5, h * 0.66), width: w * 0.56, height: h * 0.46);
        final toes = [Offset(w * 0.2, h * 0.38), Offset(w * 0.38, h * 0.2), Offset(w * 0.62, h * 0.2), Offset(w * 0.8, h * 0.38)];
        c.drawOval(pad.shift(Offset(0, h * 0.04)), shadow);
        final p = _grad(Offset.zero & s, const [Color(0xFFFFC2EC), Color(0xFFE77FD3)]);
        c.drawOval(pad, p);
        for (final t in toes) {
          c.drawOval(Rect.fromCenter(center: t, width: w * 0.22, height: h * 0.26), p);
        }
        c.drawOval(pad.deflate(w * 0.06), Paint()..color = Colors.white.withValues(alpha: 0.18));
        c.drawPath(
            Path()
              ..addOval(pad)
              ..addOval(Rect.fromCenter(center: toes[0], width: w * 0.22, height: h * 0.26)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.035
              ..color = const Color(0xFF8B3FD0));
      case 'objets':
        final front = Path()
          ..moveTo(w * 0.12, h * 0.38)
          ..lineTo(w * 0.5, h * 0.52)
          ..lineTo(w * 0.5, h * 0.95)
          ..lineTo(w * 0.12, h * 0.8)
          ..close();
        final side = Path()
          ..moveTo(w * 0.5, h * 0.52)
          ..lineTo(w * 0.88, h * 0.38)
          ..lineTo(w * 0.88, h * 0.8)
          ..lineTo(w * 0.5, h * 0.95)
          ..close();
        final top = Path()
          ..moveTo(w * 0.12, h * 0.38)
          ..lineTo(w * 0.5, h * 0.24)
          ..lineTo(w * 0.88, h * 0.38)
          ..lineTo(w * 0.5, h * 0.52)
          ..close();
        c.drawPath(front, _grad(Offset.zero & s, const [Color(0xFFF7B23C), Color(0xFFE08A1C)]));
        c.drawPath(side, _grad(Offset.zero & s, const [Color(0xFFE59A2A), Color(0xFFC46F12)]));
        c.drawPath(top, Paint()..color = const Color(0xFFFFD27A));
        // rabats
        c.drawPath(
            Path()
              ..moveTo(w * 0.12, h * 0.38)
              ..lineTo(w * 0.04, h * 0.2)
              ..lineTo(w * 0.42, h * 0.08)
              ..lineTo(w * 0.5, h * 0.24)
              ..close(),
            Paint()..color = const Color(0xFFFFC55A));
        c.drawPath(
            Path()
              ..moveTo(w * 0.88, h * 0.38)
              ..lineTo(w * 0.96, h * 0.2)
              ..lineTo(w * 0.6, h * 0.1)
              ..lineTo(w * 0.5, h * 0.24)
              ..close(),
            Paint()..color = const Color(0xFFF2A940));
        c.drawLine(Offset(w * 0.5, h * 0.52), Offset(w * 0.5, h * 0.95), Paint()..color = const Color(0x33000000)..strokeWidth = w * 0.02);
      case 'nourriture':
        final bunTop = Rect.fromLTWH(w * 0.1, h * 0.12, w * 0.8, h * 0.5);
        c.drawOval(Rect.fromLTWH(w * 0.1, h * 0.62, w * 0.8, h * 0.3).shift(Offset(0, h * 0.03)), shadow);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.68, w * 0.76, h * 0.2), Radius.circular(h * 0.1)),
            _grad(Offset.zero & s, const [Color(0xFFF2A646), Color(0xFFD6802A)]));
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.1, h * 0.56, w * 0.8, h * 0.14), Radius.circular(h * 0.07)), Paint()..color = const Color(0xFF6E3214));
        c.drawPath(
            Path()
              ..moveTo(w * 0.08, h * 0.54)
              ..quadraticBezierTo(w * 0.25, h * 0.66, w * 0.4, h * 0.54)
              ..quadraticBezierTo(w * 0.55, h * 0.66, w * 0.7, h * 0.54)
              ..quadraticBezierTo(w * 0.85, h * 0.66, w * 0.92, h * 0.54)
              ..close(),
            Paint()..color = const Color(0xFF6ACB3A));
        c.drawRect(Rect.fromLTWH(w * 0.12, h * 0.5, w * 0.76, h * 0.05), Paint()..color = const Color(0xFFFFC928));
        c.drawArc(bunTop, math.pi, math.pi, true, _grad(bunTop, const [Color(0xFFFCC163), Color(0xFFE48E2C)]));
        final seed = Paint()..color = const Color(0xFFFFF1C8);
        for (final p in [const Offset(0.35, 0.24), const Offset(0.55, 0.2), const Offset(0.66, 0.3), const Offset(0.45, 0.32)]) {
          c.drawOval(Rect.fromCenter(center: Offset(w * p.dx, h * p.dy), width: w * 0.06, height: h * 0.035), seed);
        }
      case 'metiers':
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.36, h * 0.12, w * 0.28, h * 0.2), Radius.circular(w * 0.05)),
            Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.06..color = const Color(0xFF173E9E));
        final body = Rect.fromLTWH(w * 0.08, h * 0.26, w * 0.84, h * 0.62);
        c.drawRRect(RRect.fromRectAndRadius(body.shift(Offset(0, h * 0.03)), Radius.circular(w * 0.1)), shadow);
        c.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(w * 0.1)), _grad(body, const [Color(0xFF4F8DFF), Color(0xFF1E4FD6)]));
        c.drawRect(Rect.fromLTWH(w * 0.08, h * 0.5, w * 0.84, h * 0.04), Paint()..color = const Color(0xFF173E9E));
        c.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.07, Paint()..color = Colors.white);
        _gloss(c, body);
      case 'sports':
        final o = Offset(w / 2, h / 2);
        final r = w * 0.44;
        c.drawCircle(o + Offset(0, h * 0.03), r, shadow);
        c.drawCircle(o, r, Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Colors.white, Color(0xFFD9DDE3)]).createShader(Rect.fromCircle(center: o, radius: r)));
        final dark = Paint()..color = const Color(0xFF1E3A2A);
        Path pent(Offset center, double rr, double rot) {
          final p = Path();
          for (var i = 0; i < 5; i++) {
            final a = rot + i * 2 * math.pi / 5;
            final pt = center + Offset(math.cos(a) * rr, math.sin(a) * rr);
            i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
          }
          return p..close();
        }
        c.drawPath(pent(o, r * 0.32, -math.pi / 2), Paint()..color = const Color(0xFF178A3C));
        c.save();
        c.clipPath(Path()..addOval(Rect.fromCircle(center: o, radius: r)));
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5 + math.pi / 5;
          c.drawPath(pent(o + Offset(math.cos(a), math.sin(a)) * r * 0.92, r * 0.3, a), dark);
        }
        c.restore();
      case 'films':
        final body = Rect.fromLTWH(w * 0.12, h * 0.42, w * 0.76, h * 0.48);
        c.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(w * 0.06)), _grad(body, const [Color(0xFF8E4BE8), Color(0xFF5A22B8)]));
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.42, h * 0.6, w * 0.16, h * 0.035), Radius.circular(2)), Paint()..color = Colors.white70);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.42, h * 0.68, w * 0.16, h * 0.035), Radius.circular(2)), Paint()..color = Colors.white70);
        c.save();
        c.translate(w * 0.12, h * 0.36);
        c.rotate(-0.22);
        final clap = Rect.fromLTWH(0, -h * 0.14, w * 0.8, h * 0.14);
        c.drawRect(clap, Paint()..color = const Color(0xFF2A1A44));
        for (var i = 0; i < 4; i++) {
          c.drawPath(
              Path()
                ..moveTo(w * (0.05 + i * 0.2), 0)
                ..lineTo(w * (0.13 + i * 0.2), -h * 0.14)
                ..lineTo(w * (0.21 + i * 0.2), -h * 0.14)
                ..lineTo(w * (0.13 + i * 0.2), 0)
                ..close(),
              Paint()..color = Colors.white);
        }
        c.restore();
      case 'musique':
        final p = _grad(Offset.zero & s, const [Color(0xFFFFB2E6), Color(0xFFE56CC8)]);
        c.drawOval(Rect.fromCenter(center: Offset(w * 0.3, h * 0.78), width: w * 0.32, height: h * 0.24), p);
        c.drawOval(Rect.fromCenter(center: Offset(w * 0.74, h * 0.68), width: w * 0.32, height: h * 0.24), p);
        c.drawRect(Rect.fromLTWH(w * 0.4, h * 0.2, w * 0.08, h * 0.58), p);
        c.drawRect(Rect.fromLTWH(w * 0.84, h * 0.1, w * 0.08, h * 0.58), p);
        c.drawPath(
            Path()
              ..moveTo(w * 0.4, h * 0.2)
              ..lineTo(w * 0.92, h * 0.1)
              ..lineTo(w * 0.92, h * 0.26)
              ..lineTo(w * 0.4, h * 0.36)
              ..close(),
            p);
      case 'vehicules':
        final body = Rect.fromLTWH(w * 0.04, h * 0.42, w * 0.92, h * 0.32);
        c.drawOval(Rect.fromLTWH(w * 0.08, h * 0.78, w * 0.84, h * 0.12), shadow);
        c.drawPath(
            Path()
              ..moveTo(w * 0.22, h * 0.44)
              ..quadraticBezierTo(w * 0.3, h * 0.16, w * 0.52, h * 0.16)
              ..quadraticBezierTo(w * 0.74, h * 0.16, w * 0.8, h * 0.44)
              ..close(),
            Paint()..color = const Color(0xFFE53935));
        c.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(h * 0.14)), _grad(body, const [Color(0xFFFF5A4E), Color(0xFFD02A24)]));
        final glass = Paint()..color = const Color(0xFF8ED8FF);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.3, h * 0.22, w * 0.18, h * 0.2), Radius.circular(w * 0.04)), glass);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.52, h * 0.22, w * 0.2, h * 0.2), Radius.circular(w * 0.04)), glass);
        for (final x in [0.26, 0.74]) {
          c.drawCircle(Offset(w * x, h * 0.76), w * 0.12, Paint()..color = const Color(0xFF2B2B33));
          c.drawCircle(Offset(w * x, h * 0.76), w * 0.05, Paint()..color = const Color(0xFFCFD3DA));
        }
        c.drawCircle(Offset(w * 0.92, h * 0.54), w * 0.04, Paint()..color = const Color(0xFFFFE27A));
      case 'autres':
        final path = Path();
        final o = Offset(w * 0.5, h * 0.52);
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + i * math.pi / 5;
          final rr = i.isEven ? w * 0.46 : w * 0.22;
          final p = o + Offset(math.cos(a) * rr, math.sin(a) * rr);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
        c.drawPath(path.shift(Offset(0, h * 0.03)), shadow);
        c.drawPath(path, _grad(Offset.zero & s, const [Color(0xFFFFE04A), Color(0xFFF59E0B)]));
        c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round..strokeWidth = w * 0.03..color = const Color(0xFFE8890A));
    }
  }

  @override
  bool shouldRepaint(covariant _CatPainter old) => old.id != id;
}
