import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bouton « bonbon » en relief : dégradé, tranche inférieure plus sombre,
/// reflet brillant en haut, ombre portée. S'enfonce à l'appui.
class CandyButton extends StatefulWidget {
  const CandyButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.top,
    required this.bottom,
    required this.edge,
    this.height = 64,
    this.depth = 6,
    this.radius,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color top, bottom, edge;
  final double height;
  final double depth;
  final double? radius;

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius ?? widget.height / 2);
    final press = _down ? widget.depth * 0.7 : 0.0;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              },
        child: SizedBox(
          height: widget.height + widget.depth,
          child: Stack(children: [
            // tranche + ombre
            Positioned.fill(
              top: widget.depth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.edge,
                  borderRadius: r,
                  boxShadow: [
                    BoxShadow(color: widget.edge.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
                  ],
                ),
              ),
            ),
            // face
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: press,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: r,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [widget.top, widget.bottom],
                  ),
                ),
                child: Stack(children: [
                  // reflet brillant supérieur
                  Positioned(
                    left: widget.height * 0.3,
                    right: widget.height * 0.3,
                    top: widget.height * 0.07,
                    height: widget.height * 0.36,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.height),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0.0)],
                        ),
                      ),
                    ),
                  ),
                  Center(child: widget.child),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
