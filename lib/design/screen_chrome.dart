import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'backgrounds.dart';
import 'tokens.dart';

/// Conversion des coordonnées relevées sur une référence (px) vers l'écran (dp).
class RefScale {
  RefScale(this.size, this.refW, this.refH);
  final Size size;
  final double refW, refH;
  double get k => size.width / refW;
  double x(double v) => v * k;
  double y(double v) => v * size.height / refH;
}

/// Écran à fond crème/pastel avec en-tête (retour + titre), commun aux menus.
class PastelScreen extends StatelessWidget {
  const PastelScreen({
    super.key,
    required this.refW,
    required this.refH,
    required this.title,
    required this.builder,
    this.titleCenterX,
    this.titleSize = 15.5,
    this.headerY = 52,
    this.decor = PastelDecor.blueCloudRight,
  });

  final double refW, refH;
  final String title;
  final double? titleCenterX;
  final double titleSize;
  final double headerY;
  final PastelDecor decor;
  final List<Widget> Function(BuildContext, RefScale) builder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final r = RefScale(c.biggest, refW, refH);
        // expand : l'écran occupe toujours toute la surface, même si un
        // enfant conditionnel non positionné est vide (bug Catégories).
        return Stack(fit: StackFit.expand, children: [
          Positioned.fill(child: CustomPaint(painter: PastelBackgroundPainter(decor))),
          Positioned(
            left: r.x(8), top: r.y(headerY) - r.x(11.5),
            child: RoundBackButton(size: r.x(23)),
          ),
          Positioned(
            left: titleCenterX == null ? 0 : r.x(titleCenterX! - 100),
            width: titleCenterX == null ? r.size.width : r.x(200),
            top: r.y(headerY) - r.x(titleSize * 0.75),
            child: Text(title, textAlign: TextAlign.center, style: BoomText.ui800(titleSize * r.k, color: const Color(0xFF14123A))),
          ),
          ...builder(context, r),
        ]);
      }),
    );
  }
}

class RoundBackButton extends StatelessWidget {
  const RoundBackButton({super.key, required this.size, this.dark = true});
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Retour',
      button: true,
      child: GestureDetector(
        onTap: () => Navigator.maybePop(context),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? const Color(0xFF3B2A55) : Colors.white.withValues(alpha: 0.85),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: size * 0.2, offset: Offset(0, size * 0.06))],
          ),
          child: CustomPaint(painter: _ChevronPainter(dark ? Colors.white : const Color(0xFF3B2A55))),
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.color);
  final Color color;
  @override
  void paint(Canvas c, Size s) {
    final p = Path()
      ..moveTo(s.width * 0.56, s.height * 0.3)
      ..lineTo(s.width * 0.38, s.height * 0.5)
      ..lineTo(s.width * 0.56, s.height * 0.7);
    c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.11
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color);
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter old) => old.color != color;
}

enum PastelDecor { blueCloudRight, pinkCloudRight, none }

/// Fond crème chaud des écrans de menu, avec nuages pastel en haut.
class PastelBackgroundPainter extends CustomPainter {
  const PastelBackgroundPainter(this.decor);
  final PastelDecor decor;

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
            colors: [Color(0xFFFEDCAA), Color(0xFFFEE6CC), Color(0xFFFDE9DA), Color(0xFFFDE7DA)],
            stops: [0.0, 0.1, 0.5, 1.0],
          ).createShader(full));
    // voile rose sur le bord gauche
    c.drawRect(
        Rect.fromLTWH(0, 0, w * 0.08, h),
        Paint()
          ..shader = const LinearGradient(colors: [Color(0x55F7B3D2), Color(0x00F7B3D2)]).createShader(Rect.fromLTWH(0, 0, w * 0.08, h)));
    switch (decor) {
      case PastelDecor.blueCloudRight:
        paintCloud(c, Offset(w * 0.86, h * 0.055), w * 0.62, const Color(0xFF48C8FD), const Color(0xFF7DD8FB));
        paintCloud(c, Offset(w * 0.02, h * 0.105), w * 0.3, const Color(0xFFF7A6C8), const Color(0x00F7A6C8));
        _confetti(c, s, [Offset(w * 0.9, h * 0.11), Offset(w * 0.86, h * 0.135), Offset(w * 0.78, h * 0.15)]);
      case PastelDecor.pinkCloudRight:
        paintCloud(c, Offset(w * 0.9, h * 0.05), w * 0.5, const Color(0xFFFBB6D9), const Color(0x00FBB6D9));
      case PastelDecor.none:
        break;
    }
  }

  void _confetti(Canvas c, Size s, List<Offset> pts) {
    const colors = [Color(0xFFFF4F9A), Color(0xFF8C5CF0), Color(0xFFFF8A2A)];
    for (var i = 0; i < pts.length; i++) {
      c.save();
      c.translate(pts[i].dx, pts[i].dy);
      c.rotate(i * 0.9 + 0.3);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s.width * 0.028, height: s.width * 0.016), const Radius.circular(2)),
          Paint()..color = colors[i % colors.length]);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant PastelBackgroundPainter old) => old.decor != decor;
}

/// Carte colorée « bonbon » (modes de jeu, catégories) : dégradé, reflet
/// en haut, liseré lumineux, tranche plus sombre en bas.
class CandyCard extends StatelessWidget {
  const CandyCard({
    super.key,
    required this.top,
    required this.bottom,
    required this.edge,
    required this.radius,
    required this.child,
    this.onTap,
    this.selected = false,
    this.depth = 3,
  });

  final Color top, bottom, edge;
  final double radius, depth;
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: r,
          color: edge,
          boxShadow: [BoxShadow(color: edge.withValues(alpha: 0.35), blurRadius: radius * 0.6, offset: Offset(0, radius * 0.25))],
          border: selected ? Border.all(color: Colors.white, width: radius * 0.18) : null,
        ),
        padding: EdgeInsets.only(bottom: depth),
        child: ClipRRect(
          borderRadius: r,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
            ),
            child: Stack(children: [
              Positioned(
                left: radius * 0.6, right: radius * 0.6, top: radius * 0.18,
                height: radius * 1.4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: child),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Disque d'icône brillant (globe, cœurs, éclair) des cartes de mode.
class GlossyDisc extends StatelessWidget {
  const GlossyDisc({super.key, required this.size, required this.color, required this.child});
  final double size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Color.lerp(color, Colors.white, 0.35)!, color, Color.lerp(color, Colors.black, 0.25)!],
          stops: const [0.0, 0.6, 1.0],
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: size * 0.12, offset: Offset(0, size * 0.06))],
      ),
      child: Padding(padding: EdgeInsets.all(size * 0.16), child: child),
    );
  }
}

double degToRad(double d) => d * math.pi / 180;
