import 'package:flutter/material.dart';

/// Skins de la bombe : même personnage (mêmes sprites, mêmes animations),
/// teinte différente. Garantit la cohérence exigée par la directive §4.
class BombSkin {
  const BombSkin({
    required this.id,
    required this.label,
    required this.cardTop,
    required this.cardBottom,
    this.tint,
    this.price = 0,
  });

  final String id;
  final String label;
  final Color cardTop, cardBottom;

  /// Couleur appliquée aux zones sombres (null = bombe d'origine).
  final Color? tint;

  /// Prix en gemmes (0 = débloqué d'office).
  final int price;

  /// Filtre : les noirs prennent la teinte, les blancs restent blancs
  /// (yeux, gants) pour préserver l'expression.
  ColorFilter? get filter {
    final c = tint;
    if (c == null) return null;
    return ColorFilter.matrix([
      0.8, 0, 0, 0, c.r * 255 * 0.55,
      0, 0.85, 0, 0, c.g * 255 * 0.55,
      0, 0, 0.8, 0, c.b * 255 * 0.55,
      0, 0, 0, 1, 0,
    ]);
  }
}

const bombSkins = <BombSkin>[
  BombSkin(id: 'classique', label: 'Classique', cardTop: Color(0xFFFFD43A), cardBottom: Color(0xFF6FBE3A)),
  BombSkin(id: 'glace', label: 'Glace', cardTop: Color(0xFF7FE0FF), cardBottom: Color(0xFF2FA6E8), tint: Color(0xFF7FC8FF)),
  BombSkin(id: 'ninja', label: 'Ninja', cardTop: Color(0xFFB9B4C8), cardBottom: Color(0xFF6B6680), tint: Color(0xFFB0202E)),
  BombSkin(id: 'citrouille', label: 'Citrouille', cardTop: Color(0xFFFFC23A), cardBottom: Color(0xFFFF8A1E), tint: Color(0xFFFF6A10)),
  BombSkin(id: 'arc', label: 'Arc-en-ciel', cardTop: Color(0xFF4FD8FF), cardBottom: Color(0xFFB04CF0), tint: Color(0xFFFF7AD0)),
  BombSkin(id: 'galaxie', label: 'Galaxie', cardTop: Color(0xFF8A5CFF), cardBottom: Color(0xFF4A2AC8), tint: Color(0xFF7A3CFF)),
  BombSkin(id: 'acier', label: 'Acier', cardTop: Color(0xFF9A9AAE), cardBottom: Color(0xFF5E5E74), tint: Color(0xFF8A90A8), price: 150),
  BombSkin(id: 'bonbon', label: 'Bonbon', cardTop: Color(0xFFFF9AD0), cardBottom: Color(0xFFC85AA8), tint: Color(0xFFFFB0DA), price: 200),
  BombSkin(id: 'lave', label: 'Lave', cardTop: Color(0xFFE85A1A), cardBottom: Color(0xFF7A1A0E), tint: Color(0xFFFF3A0A), price: 300),
];

BombSkin skinById(String id) => bombSkins.firstWhere((s) => s.id == id, orElse: () => bombSkins.first);
