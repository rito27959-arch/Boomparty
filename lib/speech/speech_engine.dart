import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../personality/personality_engine.dart';
import 'lip_sync.dart';
import 'neural_tts.dart';
import 'reaction_speaker.dart';

/// Voix de la bombe (écran Paramètres). Les répliques sont toutes produites
/// avec la même voix de base ; la personnalité vocale est obtenue par un
/// traitement (hauteur/vitesse, modulation « robot ») appliqué à la génération.
enum BombVoice { classique, drole, serieuse, robot }

/// Priorité d'une réplique : une réplique plus prioritaire interrompt la courante.
int priorityOf(ReactionEvent e) => switch (e) {
      ReactionEvent.explosion => 5,
      ReactionEvent.gameEnd || ReactionEvent.hurry => 4,
      ReactionEvent.duplicate || ReactionEvent.duplicateSynonym || ReactionEvent.wrongCategory => 3,
      ReactionEvent.accepted || ReactionEvent.acceptedFast || ReactionEvent.acceptedStreak || ReactionEvent.unknown => 2,
      ReactionEvent.ambiguous || ReactionEvent.recognitionError => 2,
      _ => 1,
    };

/// BOOM SPEECH ENGINE — hybride :
/// 1. répliques fixes : fichiers audio prégénérés (assets/voice/<profil>/<id>.ogg)
///    + piste de visèmes calculée à l'avance ;
/// 2. répliques dynamiques (prénoms, mots) : synthèse locale sherpa-onnx (Piper)
///    si le pack voix est installé, mise en cache sur disque ;
/// 3. sinon : sous-titres seuls, bouche animée d'après le texte.
class SpeechEngine implements ReactionSpeaker {
  SpeechEngine({required this.cacheDir, this.tts});

  final String cacheDir;
  final NeuralTts? tts;
  final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  @override
  final LipSyncController lipSync = LipSyncController();
  @override
  final ValueNotifier<String> subtitle = ValueNotifier('');
  final ValueNotifier<bool> isSpeaking = ValueNotifier(false);
  @override
  ValueListenable<bool> get speaking => isSpeaking;

  BombVoice voice = BombVoice.classique;
  double volume = 0.8;
  int _currentPriority = 0;
  int _token = 0;
  final Map<String, (String, VisemeTrack)> _memCache = {};
  Set<String>? _assets;

  /// Indique si la voix de la bombe est en train de jouer (le micro ignore
  /// alors ce qu'il entend : pas de transcription de la voix de la bombe).
  bool get busy => isSpeaking.value;

  Future<void> _loadAssetList() async {
    if (_assets != null) return;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _assets = manifest.listAssets().where((a) => a.startsWith('assets/voice/')).toSet();
    } catch (_) {
      _assets = {};
    }
  }

  @override
  Future<void> speak(Reaction r, PersonalityId profile) async {
    final prio = priorityOf(r.event);
    if (busy && prio < _currentPriority) return; // une réplique importante est en cours
    final token = ++_token;
    _currentPriority = prio;
    subtitle.value = r.text;
    await _loadAssetList();

    String? file;
    VisemeTrack? track;
    final base = 'assets/voice/${voice.name}/${profile.name}/${r.line.id}';
    if (r.line.isStatic && _assets!.contains('$base.ogg')) {
      file = '$base.ogg';
      track = VisemeTrack.fromJson(jsonDecode(await rootBundle.loadString('$base.vis.json')) as Map<String, dynamic>);
    } else if (tts != null && tts!.ready) {
      final res = await _dynamic(r.text);
      if (token != _token) return;
      if (res != null) (file, track) = res;
    }
    track ??= VisemeTrack.fromText(r.text);
    if (token != _token) return;

    await _player.stop();
    isSpeaking.value = true;
    lipSync.start(track);
    if (file != null) {
      await _player.setVolume(volume);
      if (file.startsWith('assets/')) {
        await _player.play(AssetSource(file.substring('assets/'.length)));
      } else {
        await _player.play(DeviceFileSource(file));
      }
      await _player.onPlayerComplete.first.timeout(Duration(milliseconds: track.durationMs + 1500), onTimeout: () {});
    } else {
      await Future<void>.delayed(Duration(milliseconds: track.durationMs));
    }
    if (token == _token) {
      lipSync.stop();
      isSpeaking.value = false;
      _currentPriority = 0;
    }
  }

  /// Synthèse locale + traitement de voix, mise en cache (même texte → même fichier).
  Future<(String, VisemeTrack)?> _dynamic(String text) async {
    final key = '${voice.name}|$text';
    final cached = _memCache[key];
    if (cached != null && File(cached.$1).existsSync()) return cached;
    final f = File('$cacheDir/tts_${_stableHash(key)}.wav');
    final vis = File('${f.path}.vis.json');
    if (f.existsSync() && vis.existsSync()) {
      try {
        f.setLastModifiedSync(DateTime.now()); // fraîcheur pour le nettoyage du cache
        return _memCache[key] = (f.path, VisemeTrack.fromJson(jsonDecode(vis.readAsStringSync()) as Map<String, dynamic>));
      } catch (_) {}
    }
    final out = await tts!.synthesize(text, speed: _speed);
    if (out == null) return null;
    var samples = out.samples;
    if (voice == BombVoice.robot) samples = robotize(samples, out.sampleRate);
    if (_pitch != 1.0) samples = pitchShift(samples, _pitch);
    await f.writeAsBytes(wav(samples, out.sampleRate), flush: true);
    final track = VisemeTrack.fromSamples(samples, out.sampleRate);
    await vis.writeAsString(jsonEncode(track.toJson()));
    return _memCache[key] = (f.path, track);
  }

  /// Hachage FNV-1a stable d'une session à l'autre (String.hashCode ne l'est pas).
  static String _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in utf8.encode(s)) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16);
  }

  double get _speed => switch (voice) { BombVoice.drole => 1.12, BombVoice.serieuse => 0.9, _ => 1.0 };
  double get _pitch => switch (voice) { BombVoice.drole => 1.18, BombVoice.serieuse => 0.88, _ => 1.0 };

  @override
  Future<void> stop() async {
    _token++;
    await _player.stop();
    lipSync.stop();
    isSpeaking.value = false;
    _currentPriority = 0;
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  // ------------------------------------------------------------ traitement du signal
  /// Modulation en anneau (voix de robot), identique à tools/voice/voice_fx.py.
  static Float32List robotize(Float32List x, int sr) {
    final y = Float32List(x.length);
    for (var i = 0; i < x.length; i++) {
      final m = 0.5 + 0.5 * _sin(2 * 3.141592653589793 * 55 * i / sr);
      y[i] = x[i] * (0.35 + 0.65 * m);
    }
    return y;
  }

  /// Changement de hauteur par rééchantillonnage (modifie aussi légèrement la
  /// durée, ce qui convient au style cartoon de la voix « drôle »).
  static Float32List pitchShift(Float32List x, double factor) {
    final n = (x.length / factor).floor();
    final y = Float32List(n);
    for (var i = 0; i < n; i++) {
      final p = i * factor;
      final j = p.floor();
      final f = p - j;
      final a = x[j.clamp(0, x.length - 1)];
      final b = x[(j + 1).clamp(0, x.length - 1)];
      y[i] = a + (b - a) * f;
    }
    return y;
  }

  static double _sin(double v) => math.sin(v);

  static Uint8List wav(Float32List samples, int sr) {
    final data = ByteData(44 + samples.length * 2);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + samples.length * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sr, Endian.little);
    data.setUint32(28, sr * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, samples.length * 2, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      data.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }
}
