/// États d'animation de la bombe (section 5 de la directive).
///
/// Chaque état a sa propre animation rendue depuis le modèle 3D Blender
/// (tools/blender/render_anims.py).
enum BombState {
  idle,
  listening,
  thinking,
  talking,
  happy,
  laughing,
  angry,
  confused,
  panic,
  countdown,
  explosion,
  defeated,
  celebration;

  /// Nom de la spritesheet utilisée pour cet état (une par état, rendue dans Blender).
  String get sheet => name;
}
