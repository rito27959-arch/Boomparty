import 'package:flutter/material.dart';

/// Petites illustrations vectorielles (globe, cœurs, éclair, couronne, cornes).
/// Dessinées en code pour rester nettes à toutes les densités.

class GlobePainter extends CustomPainter {
  const GlobePainter();
  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final o = Offset(r, r);
    final circle = Rect.fromCircle(center: o, radius: r);
    c.drawCircle(o, r, Paint()..shader = const RadialGradient(center: Alignment(-0.35, -0.4), colors: [Color(0xFF6FD3FF), Color(0xFF1C8DE8), Color(0xFF0B5CB8)], stops: [0, 0.6, 1]).createShader(circle));
    c.save();
    c.clipPath(Path()..addOval(circle));
    final land = Paint()..color = const Color(0xFF4CCB5A);
    // continents stylisés
    c.drawPath(
        Path()
          ..moveTo(r * 0.35, r * 0.45)
          ..cubicTo(r * 0.7, r * 0.2, r * 1.0, r * 0.45, r * 0.9, r * 0.75)
          ..cubicTo(r * 0.8, r * 1.0, r * 1.0, r * 1.2, r * 0.85, r * 1.5)
          ..cubicTo(r * 0.6, r * 1.3, r * 0.45, r * 1.0, r * 0.2, r * 0.9)
          ..close(),
        land);
    c.drawPath(
        Path()
          ..moveTo(r * 1.15, r * 0.35)
          ..cubicTo(r * 1.5, r * 0.3, r * 1.8, r * 0.6, r * 1.7, r * 0.9)
          ..cubicTo(r * 1.55, r * 1.1, r * 1.35, r * 0.85, r * 1.2, r * 0.75)
          ..close(),
        land);
    c.drawPath(
        Path()
          ..moveTo(r * 1.25, r * 1.15)
          ..cubicTo(r * 1.55, r * 1.1, r * 1.65, r * 1.4, r * 1.45, r * 1.65)
          ..cubicTo(r * 1.3, r * 1.55, r * 1.2, r * 1.35, r * 1.25, r * 1.15)
          ..close(),
        land);
    c.restore();
    c.drawCircle(Offset(r * 0.62, r * 0.5), r * 0.22, Paint()..color = Colors.white.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Path heartPath(Rect b) {
  final w = b.width, h = b.height;
  return Path()
    ..moveTo(b.left + w * 0.5, b.top + h * 0.95)
    ..cubicTo(b.left - w * 0.05, b.top + h * 0.55, b.left + w * 0.05, b.top - h * 0.05, b.left + w * 0.5, b.top + h * 0.25)
    ..cubicTo(b.left + w * 0.95, b.top - h * 0.05, b.left + w * 1.05, b.top + h * 0.55, b.left + w * 0.5, b.top + h * 0.95)
    ..close();
}

class HeartsPainter extends CustomPainter {
  const HeartsPainter();
  @override
  void paint(Canvas c, Size s) {
    final back = Rect.fromLTWH(0, s.height * 0.05, s.width * 0.62, s.height * 0.6);
    c.drawPath(heartPath(back), Paint()..shader = const LinearGradient(colors: [Color(0xFFB38CFF), Color(0xFF7A4CE0)]).createShader(back));
    final front = Rect.fromLTWH(s.width * 0.3, s.height * 0.3, s.width * 0.7, s.height * 0.68);
    c.drawPath(heartPath(front), Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF7A7A), Color(0xFFE8304A)]).createShader(front));
    c.drawOval(Rect.fromLTWH(s.width * 0.42, s.height * 0.4, s.width * 0.16, s.height * 0.1), Paint()..color = Colors.white.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BoltPainter extends CustomPainter {
  const BoltPainter(this.top, this.bottom);
  final Color top, bottom;
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final p = Path()
      ..moveTo(w * 0.62, 0)
      ..lineTo(w * 0.18, h * 0.58)
      ..lineTo(w * 0.47, h * 0.58)
      ..lineTo(w * 0.34, h)
      ..lineTo(w * 0.84, h * 0.4)
      ..lineTo(w * 0.54, h * 0.4)
      ..close();
    c.drawPath(p.shift(Offset(w * 0.03, h * 0.04)), Paint()..color = Colors.black.withValues(alpha: 0.2));
    c.drawPath(p, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]).createShader(Offset.zero & s));
  }

  @override
  bool shouldRepaint(covariant BoltPainter old) => old.top != top || old.bottom != bottom;
}

class CrownPainter extends CustomPainter {
  const CrownPainter();
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final p = Path()
      ..moveTo(w * 0.05, h * 0.95)
      ..lineTo(0, h * 0.25)
      ..lineTo(w * 0.3, h * 0.55)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w * 0.7, h * 0.55)
      ..lineTo(w, h * 0.25)
      ..lineTo(w * 0.95, h * 0.95)
      ..close();
    c.drawPath(p, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE45C), Color(0xFFF5A500)]).createShader(Offset.zero & s));
    c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.04..color = const Color(0xFFC77700));
    c.drawCircle(Offset(w * 0.5, h * 0.72), w * 0.08, Paint()..color = const Color(0xFFE8304A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HornsPainter extends CustomPainter {
  const HornsPainter();
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final paint = Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5B2BB0), Color(0xFF2E1068)]).createShader(Offset.zero & s);
    c.drawPath(
        Path()
          ..moveTo(w * 0.05, h)
          ..quadraticBezierTo(-w * 0.02, h * 0.3, w * 0.12, 0)
          ..quadraticBezierTo(w * 0.15, h * 0.55, w * 0.3, h * 0.85)
          ..close(),
        paint);
    c.drawPath(
        Path()
          ..moveTo(w * 0.95, h)
          ..quadraticBezierTo(w * 1.02, h * 0.3, w * 0.88, 0)
          ..quadraticBezierTo(w * 0.85, h * 0.55, w * 0.7, h * 0.85)
          ..close(),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
