import 'package:flutter/widgets.dart';

/// Illustration HD rendue dans Blender (assets/illustrations/<name>.png),
/// fond transparent. Voir tools/blender/render_illustrations.py et render_icons.py.
class Illustration extends StatelessWidget {
  const Illustration(this.name, {super.key, this.fit = BoxFit.contain, this.alignment = Alignment.center, this.scale = 1});
  final String name;
  final BoxFit fit;
  final Alignment alignment;

  /// Agrandit le sujet dans sa case (les rendus gardent une marge autour).
  final double scale;

  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset('assets/illustrations/$name.png', fit: fit, alignment: alignment, filterQuality: FilterQuality.medium);
    if (scale != 1) img = Transform.scale(scale: scale, alignment: alignment, child: img);
    return img;
  }
}
