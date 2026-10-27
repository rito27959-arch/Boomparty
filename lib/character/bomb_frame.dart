import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'bomb_game.dart';
import 'bomb_state.dart';

/// Une pose fixe de la bombe, tirée des mêmes spritesheets que l'animation
/// (cohérence du personnage). Utilisée pour les vignettes : cartes de mode,
/// skins, voix, etc.
class BombFrame extends StatelessWidget {
  const BombFrame({super.key, required this.state, this.frame = 0, this.tint, this.mirror = false, this.zoom = 1});
  final BombState state;
  final int frame;
  final ColorFilter? tint;
  final bool mirror;

  /// Agrandit le personnage dans sa case (les frames ont une marge transparente).
  final double zoom;

  /// Teinte « skin » : les zones sombres prennent la couleur, le blanc reste blanc.
  static ColorFilter skin(Color c, {double strength = 1}) {
    final s = strength;
    return ColorFilter.matrix([
      1 - 0.2 * s, 0, 0, 0, c.r * 255 * 0.45 * s,
      0, 1 - 0.06 * s, 0, 0, c.g * 255 * 0.45 * s,
      0, 0, 1 - 0.2 * s, 0, c.b * 255 * 0.45 * s,
      0, 0, 0, 1, 0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final meta = BombAssets.meta;
    final m = (meta['states'] as Map<String, dynamic>)[state.sheet] as Map<String, dynamic>;
    final img = BombAssets.images.fromCache(m['image'] as String);
    final fw = (meta['frameWidth'] as num).toDouble(), fh = (meta['frameHeight'] as num).toDouble();
    final f = frame % (m['frames'] as int);
    Widget w = AspectRatio(
      aspectRatio: fw / fh,
      child: CustomPaint(painter: _FramePainter(img, Rect.fromLTWH(f * fw, 0, fw, fh))),
    );
    if (tint != null) w = ColorFiltered(colorFilter: tint!, child: w);
    if (mirror) w = Transform.flip(flipX: true, child: w);
    if (zoom != 1) w = Transform.scale(scale: zoom, alignment: const Alignment(0, 0.55), child: w);
    return w;
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.image, this.src);
  final ui.Image image;
  final Rect src;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(image, src, Offset.zero & size,
        Paint()..filterQuality = FilterQuality.medium..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => old.image != image || old.src != src;
}
