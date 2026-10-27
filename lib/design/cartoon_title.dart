import 'package:flutter/material.dart';

/// Texte titre cartoon : remplissage en dégradé, contour épais,
/// extrusion 3D vers le bas et petit reflet.
class CartoonTitle extends StatelessWidget {
  const CartoonTitle(
    this.text, {
    super.key,
    required this.fontSize,
    required this.fill,
    required this.outline,
    this.fontFamily = 'Lilita',
    this.strokeWidth,
    this.depth,
    this.letterSpacing = 0,
    this.extrusion,
    this.textAlign = TextAlign.center,
    this.height = 1.0,
  });

  final String text;
  final double fontSize;
  final List<Color> fill;
  final Color outline;
  final Color? extrusion;
  final String fontFamily;
  final double? strokeWidth;
  final double? depth;
  final double letterSpacing;
  final TextAlign textAlign;
  final double height;

  TextStyle _base() => TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        height: height,
      );

  @override
  Widget build(BuildContext context) {
    final sw = strokeWidth ?? fontSize * 0.16;
    final d = depth ?? fontSize * 0.09;
    Widget stroked(Color c, double w) => Text(
          text,
          textAlign: textAlign,
          style: _base().copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w
              ..strokeJoin = StrokeJoin.round
              ..color = c,
          ),
        );
    return Stack(clipBehavior: Clip.none, children: [
      // extrusion (plusieurs couches pour un volume continu)
      for (var i = 1; i <= 4; i++)
        Transform.translate(offset: Offset(0, d * i / 4), child: stroked(extrusion ?? outline, sw)),
      stroked(outline, sw),
      ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: fill,
        ).createShader(r),
        child: Text(text, textAlign: textAlign, style: _base().copyWith(color: Colors.white)),
      ),
      // reflet en haut des lettres
      ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.32, 0.33],
          colors: [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0.12), Colors.transparent],
        ).createShader(r),
        child: Text(text, textAlign: textAlign, style: _base().copyWith(color: Colors.white)),
      ),
    ]);
  }
}
