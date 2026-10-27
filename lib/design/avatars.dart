import 'package:flutter/material.dart';

/// Avatars cartoon des joueurs, dessinés en vectoriel (pas d'asset fourni
/// en haute définition pour les visages de la maquette).
class AvatarSpec {
  const AvatarSpec({required this.ring, required this.skin, required this.hair, required this.style, this.accent});
  final Color ring, skin, hair;
  final HairStyle style;
  final Color? accent; // élastiques / pompons
}

enum HairStyle { pigtails, shortBoy, buns, curlyBoy, sidePigtails }

const avatarSpecs = <AvatarSpec>[
  AvatarSpec(ring: Color(0xFFF55BA8), skin: Color(0xFFFCD2B4), hair: Color(0xFF3B2316), style: HairStyle.pigtails, accent: Color(0xFFF7A21B)),
  AvatarSpec(ring: Color(0xFF6D8DF0), skin: Color(0xFFC98656), hair: Color(0xFF241812), style: HairStyle.shortBoy),
  AvatarSpec(ring: Color(0xFF4FA8F5), skin: Color(0xFFFBD0B2), hair: Color(0xFF5A2E1A), style: HairStyle.buns, accent: Color(0xFF8E4FD8)),
  AvatarSpec(ring: Color(0xFF7FCB5A), skin: Color(0xFFB8744A), hair: Color(0xFF1E1410), style: HairStyle.curlyBoy),
  AvatarSpec(ring: Color(0xFFF7B620), skin: Color(0xFFFBD3B5), hair: Color(0xFF8A3A16), style: HairStyle.sidePigtails, accent: Color(0xFFE2661D)),
];

/// Avatar d'un joueur : buste 3D rendu dans Blender (tools/blender/render_avatars.py)
/// dans un médaillon à anneau coloré.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.index, required this.size});
  final int index;
  final double size;

  static const _files = ['emma', 'leo', 'sarah', 'max', 'ines'];

  @override
  Widget build(BuildContext context) {
    final spec = avatarSpecs[index % avatarSpecs.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [Color.lerp(spec.ring, Colors.white, 0.25)!, spec.ring]),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: size * 0.08, offset: Offset(0, size * 0.04))],
      ),
      padding: EdgeInsets.all(size * 0.07),
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(color: Color.lerp(spec.ring, Colors.white, 0.72)),
          child: Transform.scale(
            scale: 1.25,
            alignment: const Alignment(0, -0.2),
            child: Image.asset('assets/illustrations/avatar_${_files[index % _files.length]}.png',
                fit: BoxFit.cover, filterQuality: FilterQuality.medium),
          ),
        ),
      ),
    );
  }
}

class AvatarPainter extends CustomPainter {
  const AvatarPainter(this.s);
  final AvatarSpec s;

  @override
  void paint(Canvas c, Size size) {
    final w = size.width;
    final o = Offset(w / 2, w / 2);
    final r = w / 2;
    // anneau coloré + fond
    c.drawCircle(o, r, Paint()..shader = RadialGradient(colors: [Color.lerp(s.ring, Colors.white, 0.25)!, s.ring]).createShader(Rect.fromCircle(center: o, radius: r)));
    c.drawCircle(o, r * 0.86, Paint()..color = Color.lerp(s.ring, Colors.white, 0.75)!);
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: o, radius: r * 0.86)));
    final hair = Paint()..color = s.hair;
    final skin = Paint()..color = s.skin;
    final face = Rect.fromCenter(center: o + Offset(0, r * 0.08), width: r * 1.1, height: r * 1.2);
    // cheveux arrière
    switch (s.style) {
      case HairStyle.pigtails || HairStyle.sidePigtails:
        c.drawOval(Rect.fromCenter(center: o + Offset(0, -r * 0.05), width: r * 1.35, height: r * 1.45), hair);
      case HairStyle.buns:
        c.drawOval(Rect.fromCenter(center: o + Offset(0, -r * 0.02), width: r * 1.35, height: r * 1.5), hair);
      default:
        break;
    }
    // corps / t-shirt
    c.drawOval(Rect.fromCenter(center: o + Offset(0, r * 1.05), width: r * 1.5, height: r * 0.9), Paint()..color = Color.lerp(s.ring, Colors.black, 0.1)!);
    // cou + visage + oreilles
    c.drawRect(Rect.fromCenter(center: o + Offset(0, r * 0.62), width: r * 0.36, height: r * 0.3), skin);
    c.drawCircle(o + Offset(-r * 0.56, r * 0.12), r * 0.14, skin);
    c.drawCircle(o + Offset(r * 0.56, r * 0.12), r * 0.14, skin);
    c.drawOval(face, skin);
    // frange / dessus
    final top = Path();
    switch (s.style) {
      case HairStyle.shortBoy || HairStyle.curlyBoy:
        top
          ..moveTo(o.dx - r * 0.6, o.dy)
          ..quadraticBezierTo(o.dx - r * 0.7, o.dy - r * 0.75, o.dx, o.dy - r * 0.62)
          ..quadraticBezierTo(o.dx + r * 0.7, o.dy - r * 0.75, o.dx + r * 0.6, o.dy)
          ..quadraticBezierTo(o.dx + r * 0.3, o.dy - r * 0.35, o.dx - r * 0.1, o.dy - r * 0.3)
          ..quadraticBezierTo(o.dx - r * 0.45, o.dy - r * 0.25, o.dx - r * 0.6, o.dy)
          ..close();
      default:
        top
          ..moveTo(o.dx - r * 0.62, o.dy + r * 0.1)
          ..quadraticBezierTo(o.dx - r * 0.7, o.dy - r * 0.72, o.dx, o.dy - r * 0.62)
          ..quadraticBezierTo(o.dx + r * 0.7, o.dy - r * 0.72, o.dx + r * 0.62, o.dy + r * 0.1)
          ..quadraticBezierTo(o.dx + r * 0.35, o.dy - r * 0.35, o.dx + r * 0.05, o.dy - r * 0.32)
          ..quadraticBezierTo(o.dx - r * 0.4, o.dy - r * 0.2, o.dx - r * 0.62, o.dy + r * 0.1)
          ..close();
    }
    c.drawPath(top, hair);
    if (s.style == HairStyle.curlyBoy) {
      for (var i = -2; i <= 2; i++) {
        c.drawCircle(o + Offset(i * r * 0.2, -r * 0.6), r * 0.16, hair);
      }
    }
    // couettes / chignons
    final acc = Paint()..color = s.accent ?? s.hair;
    switch (s.style) {
      case HairStyle.pigtails || HairStyle.sidePigtails:
        for (final sx in [-1.0, 1.0]) {
          c.drawCircle(o + Offset(sx * r * 0.72, r * 0.48), r * 0.22, hair);
          c.drawCircle(o + Offset(sx * r * 0.62, r * 0.3), r * 0.1, acc);
        }
      case HairStyle.buns:
        for (final sx in [-1.0, 1.0]) {
          c.drawCircle(o + Offset(sx * r * 0.62, r * 0.62), r * 0.2, acc);
        }
      default:
        break;
    }
    // yeux
    for (final sx in [-1.0, 1.0]) {
      final e = o + Offset(sx * r * 0.22, r * 0.08);
      c.drawOval(Rect.fromCenter(center: e, width: r * 0.24, height: r * 0.28), Paint()..color = Colors.white);
      c.drawCircle(e + Offset(0, r * 0.02), r * 0.09, Paint()..color = const Color(0xFF3A2414));
      c.drawCircle(e + Offset(-r * 0.03, -r * 0.02), r * 0.03, Paint()..color = Colors.white);
    }
    // joues + sourire
    final blush = Paint()..color = const Color(0x55FF6B7A);
    c.drawCircle(o + Offset(-r * 0.36, r * 0.3), r * 0.08, blush);
    c.drawCircle(o + Offset(r * 0.36, r * 0.3), r * 0.08, blush);
    final mouth = Path()
      ..moveTo(o.dx - r * 0.18, o.dy + r * 0.34)
      ..quadraticBezierTo(o.dx, o.dy + r * 0.55, o.dx + r * 0.18, o.dy + r * 0.34)
      ..close();
    c.drawPath(mouth, Paint()..color = const Color(0xFF8E2A2A));
    c.drawPath(
        Path()
          ..moveTo(o.dx - r * 0.13, o.dy + r * 0.36)
          ..lineTo(o.dx + r * 0.13, o.dy + r * 0.36)
          ..lineTo(o.dx + r * 0.1, o.dy + r * 0.4)
          ..lineTo(o.dx - r * 0.1, o.dy + r * 0.4)
          ..close(),
        Paint()..color = Colors.white);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant AvatarPainter old) => old.s != s;
}
