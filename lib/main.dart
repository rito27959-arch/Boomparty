import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'character/bomb_game.dart';
import 'services/app_services.dart';
import 'services/settings_store.dart';
import 'services/wallet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  await Future.wait([SettingsStore.instance.load(), Wallet.instance.load()]);
  // qualité graphique adaptative : planches décodées à 50 % si « graphismes allégés »
  BombAssets.quality = SettingsStore.instance.lowGraphics ? 0.5 : 1.0;
  await BombAssets.ensureLoaded();
  await AppServices.init();
  SettingsStore.instance.addListener(AppServices.applySettings);
  runApp(const BoomPartyApp());
}
