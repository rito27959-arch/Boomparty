/// Tuiles de l'écran « Choix de catégorie ». Chaque tuile regroupe une ou
/// plusieurs catégories de la base de connaissances (colonne
/// `categories.game_category`), ex. « Nourriture » = fruits, légumes, plats, boissons.
class GameTile {
  const GameTile(this.id, this.label);
  final String id;
  final String label;
}

const gameTiles = <GameTile>[
  GameTile('animaux', 'Animaux'),
  GameTile('pays', 'Pays'),
  GameTile('objets', 'Objets'),
  GameTile('nourriture', 'Nourriture'),
  GameTile('metiers', 'Métiers'),
  GameTile('sports', 'Sports'),
  GameTile('films', 'Films / Séries'),
  GameTile('musique', 'Musique'),
  GameTile('vehicules', 'Véhicules'),
  GameTile('autres', 'Autres'),
];
