import 'package:flutter/material.dart';

/// Couleurs relevées par échantillonnage de la maquette (reference/*.png).
class BoomColors {
  BoomColors._();

  // Texte
  static const ink = Color(0xFF221440); // texte principal bleu-violet très sombre
  static const inkSoft = Color(0xFF3A2E5C);

  // Fonds crème
  static const cream = Color(0xFFFDEEDB);
  static const creamLight = Color(0xFFFEF6EE);

  // Ciel de l'accueil
  static const skyTop = Color(0xFF22AEF7);
  static const skyMid = Color(0xFF6DD5FE);

  // Bouton jaune « Jouer » / « Continuer »
  static const yellowTop = Color(0xFFFFE02A);
  static const yellowBottom = Color(0xFFFDB904);
  static const yellowEdge = Color(0xFFE88A06);

  // Bouton rose « Continuer » / « Réessaie »
  static const pinkTop = Color(0xFFFF6FA5);
  static const pinkBottom = Color(0xFFF2387E);
  static const pinkEdge = Color(0xFFC21E5E);

  // Bouton violet « Partager »
  static const purpleTop = Color(0xFF9B5CFF);
  static const purpleBottom = Color(0xFF6E35E8);
  static const purpleEdge = Color(0xFF4A1DB0);

  // Titre BOOM PARTY
  static const titleOutline = Color(0xFF3B1470);
  static const titleYellow = Color(0xFFFFD33B);
  static const titleOrange = Color(0xFFF7900F);
  static const titleLavender = Color(0xFFE6D9FF);

  static const iconPurple = Color(0xFF4B2A86);
  static const playRed = Color(0xFF8E1B1F);
}

class BoomText {
  BoomText._();
  static const display = 'Lilita';
  static const ui = 'Baloo';

  static TextStyle ui700(double size, {Color color = BoomColors.ink, double height = 1.1}) =>
      TextStyle(fontFamily: ui, fontWeight: FontWeight.w700, fontSize: size, color: color, height: height);
  static TextStyle ui800(double size, {Color color = BoomColors.ink, double height = 1.1}) =>
      TextStyle(fontFamily: ui, fontWeight: FontWeight.w800, fontSize: size, color: color, height: height);
  static TextStyle ui600(double size, {Color color = BoomColors.ink, double height = 1.1}) =>
      TextStyle(fontFamily: ui, fontWeight: FontWeight.w600, fontSize: size, color: color, height: height);
}
