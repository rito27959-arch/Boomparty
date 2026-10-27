import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'character/bomb_game.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  await BombAssets.ensureLoaded(); // spritesheets chargées une seule fois au démarrage
  runApp(const BoomPartyApp());
}
