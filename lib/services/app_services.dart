import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../knowledge/knowledge_repository.dart';
import '../personality/personality_engine.dart';
import '../speech/neural_tts.dart';
import '../speech/speech_engine.dart';
import '../state/app_state.dart';
import '../voice/offline_asr_input.dart';
import '../voice/voice_pack_manager.dart';
import 'answer_input.dart';
import 'settings_store.dart';

/// Services partagés, initialisés une fois au démarrage : base de
/// connaissances, packs voix, moteur de parole de la bombe.
class AppServices {
  AppServices._();

  static late final String supportDir;
  static late final VoicePackManager packs;
  static late final SpeechEngine speech;
  static NeuralTts? _tts;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    supportDir = (await getApplicationSupportDirectory()).path;
    final cache = Directory('$supportDir/tts_cache')..createSync(recursive: true);
    _trimCache(cache);

    final data = await rootBundle.load('assets/knowledge/boom_kb.db');
    AppState.instance.kb = await KnowledgeRepository.fromBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), supportDir);

    packs = VoicePackManager(rootDir: supportDir)..refresh();
    speech = SpeechEngine(cacheDir: cache.path, tts: _tts = NeuralTts(packs.dirOf(VoicePackKind.tts)));
    applySettings();
    if (packs.isReady(VoicePackKind.tts)) {
      // en arrière-plan : la synthèse n'est utile qu'en partie
      _tts!.init().then((ok) => debugPrint('Synthèse locale : ${ok ? 'prête' : 'indisponible'}'));
    }
    packs.state[VoicePackKind.tts]!.addListener(() {
      if (packs.state[VoicePackKind.tts]!.value.status == PackStatus.ready && !_tts!.ready) _tts!.init();
    });
  }

  static void applySettings() {
    final s = SettingsStore.instance;
    speech.voice = BombVoice.values.firstWhere((v) => v.name == s.voice, orElse: () => BombVoice.classique);
    speech.volume = s.voiceVolume;
  }

  static PersonalityId get personality =>
      PersonalityId.values.firstWhere((p) => p.name == SettingsStore.instance.personality, orElse: () => PersonalityId.classic);

  /// Reconnaissance hors ligne si le pack est installé, sinon celle du système.
  static AnswerInput createInput() =>
      packs.isReady(VoicePackKind.asr) ? OfflineAsrInput(modelDir: packs.dirOf(VoicePackKind.asr)) : SpeechAnswerInput();

  /// Le cache des répliques synthétisées est borné (≈ 300 fichiers).
  static void _trimCache(Directory d) {
    try {
      final files = d.listSync().whereType<File>().toList()..sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      for (final f in files.take(files.length - 300 > 0 ? files.length - 300 : 0)) {
        f.deleteSync();
      }
    } catch (_) {}
  }
}
