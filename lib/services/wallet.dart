import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Monétisation (séparée du jeu) : gemmes gagnées en jouant, skins débloqués.
/// Aucun achat intégré réel n'est branché : les gemmes se gagnent en partie.
class Wallet extends ChangeNotifier {
  Wallet._();
  static final Wallet instance = Wallet._();

  static const gemsPerGame = 10;
  static const gemsForWinner = 25;

  int gems = 0;
  final Set<String> unlocked = {};
  SharedPreferences? _p;

  Future<void> load() async {
    final p = _p = await SharedPreferences.getInstance();
    gems = p.getInt('gems') ?? 0;
    unlocked
      ..clear()
      ..addAll(p.getStringList('unlocked') ?? const []);
    notifyListeners();
  }

  bool isUnlocked(String skinId, int price) => price == 0 || unlocked.contains(skinId);

  Future<bool> buy(String skinId, int price) async {
    if (isUnlocked(skinId, price)) return true;
    if (gems < price) return false;
    gems -= price;
    unlocked.add(skinId);
    await _save();
    return true;
  }

  Future<void> reward({required bool winnerOnDevice}) async {
    gems += gemsPerGame + (winnerOnDevice ? gemsForWinner : 0);
    await _save();
  }

  Future<void> _save() async {
    notifyListeners();
    final p = _p ??= await SharedPreferences.getInstance();
    await p.setInt('gems', gems);
    await p.setStringList('unlocked', unlocked.toList());
  }
}
