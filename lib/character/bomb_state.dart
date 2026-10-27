/// États d'animation de la bombe (section 5 de la directive).
///
/// [listening] et [confused] n'ont pas encore de poses dédiées dans les
/// planches fournies : ils réutilisent des poses proches (voir [fallback])
/// et sont signalés dans assets/sprites/bomb_animations.json → "missing".
enum BombState {
  idle,
  listening,
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

  /// Nom de la spritesheet utilisée pour cet état.
  String get sheet => switch (this) {
        BombState.listening => 'idle',
        BombState.confused => 'talking',
        _ => name,
      };

  bool get isFallback => this == BombState.listening || this == BombState.confused;
}
