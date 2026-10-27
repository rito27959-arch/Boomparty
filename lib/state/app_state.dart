import 'package:flutter/foundation.dart';

import '../engine/game_engine.dart';
import '../engine/word_bank.dart';

/// État de préparation de la partie, partagé entre les écrans de menu.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  GameMode mode = GameMode.cultureGenerale;
  final List<Player> players = [
    Player(id: 'p1', name: 'Emma', avatar: 0),
    Player(id: 'p2', name: 'Léo', avatar: 1),
    Player(id: 'p3', name: 'Sarah', avatar: 2),
    Player(id: 'p4', name: 'Max', avatar: 3),
    Player(id: 'p5', name: 'Inès', avatar: 4),
  ];
  final Set<String> selectedCategories = {};

  /// Résultat de la dernière partie (pour classement et célébration).
  GameFinished? lastResult;

  void setMode(GameMode m) {
    mode = m;
    notifyListeners();
  }

  void addPlayer(String name) {
    players.add(Player(id: 'p${DateTime.now().microsecondsSinceEpoch}', name: name, avatar: players.length % 5));
    notifyListeners();
  }

  void renamePlayer(Player p, String name) {
    p.name = name;
    notifyListeners();
  }

  void removePlayer(Player p) {
    if (players.length <= 2) return;
    players.remove(p);
    notifyListeners();
  }

  void reorderPlayers(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    players.insert(newIndex, players.removeAt(oldIndex));
    notifyListeners();
  }

  void toggleCategory(String id) {
    if (selectedCategories.contains(id)) {
      selectedCategories.remove(id);
    } else {
      selectedCategories.add(id);
    }
    notifyListeners();
  }

  List<WordCategory> get categoriesForGame => [for (final c in categories) if (selectedCategories.contains(c.id)) c];
}
