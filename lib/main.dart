import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'character/bomb_game.dart';
import 'services/settings_store.dart';
import 'services/wallet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  await Future.wait([
    BombAssets.ensureLoaded(), // spritesheets chargées une seule fois au démarrage
    SettingsStore.instance.load(),
    Wallet.instance.load(),
  ]);
  runApp(const BoomPartyApp());
}
