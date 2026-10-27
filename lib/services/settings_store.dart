import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_director.dart';

/// Paramètres persistés (écran 13).
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  SharedPreferences? _prefs;

  String voice = 'classique';
  double voiceVolume = 0.8;
  double fxVolume = 0.7;
  bool vibrations = true;
  bool subtitles = true;
  bool darkMode = false;
  bool reducedMotion = false;
  bool lowGraphics = false;
  String language = 'fr';
  String skin = 'classique';

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    voice = p.getString('voice') ?? voice;
    voiceVolume = p.getDouble('voiceVolume') ?? voiceVolume;
    fxVolume = p.getDouble('fxVolume') ?? fxVolume;
    vibrations = p.getBool('vibrations') ?? vibrations;
    subtitles = p.getBool('subtitles') ?? subtitles;
    darkMode = p.getBool('darkMode') ?? darkMode;
    reducedMotion = p.getBool('reducedMotion') ?? reducedMotion;
    lowGraphics = p.getBool('lowGraphics') ?? lowGraphics;
    language = p.getString('language') ?? language;
    skin = p.getString('skin') ?? skin;
    notifyListeners();
  }

  Future<void> update(void Function(SettingsStore s) change) async {
    change(this);
    notifyListeners();
    final p = _prefs ??= await SharedPreferences.getInstance();
    await Future.wait([
      p.setString('voice', voice),
      p.setDouble('voiceVolume', voiceVolume),
      p.setDouble('fxVolume', fxVolume),
      p.setBool('vibrations', vibrations),
      p.setBool('subtitles', subtitles),
      p.setBool('darkMode', darkMode),
      p.setBool('reducedMotion', reducedMotion),
      p.setBool('lowGraphics', lowGraphics),
      p.setString('language', language),
      p.setString('skin', skin),
    ]);
  }

  AudioDirector buildAudio() => AudioDirector(
        pack: voicePacks.firstWhere((v) => v.id == voice, orElse: () => voicePacks.first),
        voiceVolume: voiceVolume,
        fxVolume: fxVolume,
      );
}
