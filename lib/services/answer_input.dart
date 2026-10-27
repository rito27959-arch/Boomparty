import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Réponse entendue : texte + confiance de la reconnaissance (null = saisie
/// au clavier, donc certaine).
class HeardAnswer {
  const HeardAnswer(this.text, {this.confidence, this.alternatives = const []});
  final String text;
  final double? confidence;

  /// Autres hypothèses de la reconnaissance (essayées si la première échoue).
  final List<String> alternatives;
}

/// Source des réponses des joueurs (voix ou clavier). Séparée du moteur
/// de règles : elle ne fait que produire des mots.
abstract class AnswerInput {
  Stream<HeardAnswer> get answers;

  /// Quand vrai, ce qui est entendu est ignoré (la bombe parle : on ne
  /// transcrit jamais sa propre voix).
  bool muted = false;

  /// Vocabulaire attendu pour la manche (favorisé par la reconnaissance
  /// hors ligne ; ignoré par les autres sources).
  Future<void> setVocabulary(Iterable<String> words) async {}

  /// Niveau sonore normalisé 0..1, pour l'onde du micro.
  ValueListenable<double> get level;

  /// Texte partiel en cours de reconnaissance (sous-titres).
  ValueListenable<String> get partial;

  Future<bool> start();
  Future<void> stop();
  void dispose();
}

/// Saisie manuelle (clavier de secours, tests).
class ManualAnswerInput extends AnswerInput {
  final _ctl = StreamController<HeardAnswer>.broadcast();
  final _level = ValueNotifier<double>(0);
  final _partial = ValueNotifier<String>('');

  @override
  Stream<HeardAnswer> get answers => _ctl.stream;
  @override
  ValueListenable<double> get level => _level;
  @override
  ValueListenable<String> get partial => _partial;

  /// Saisie clavier (toujours acceptée, même quand la bombe parle).
  void submit(String word, {double? confidence}) => _ctl.add(HeardAnswer(word, confidence: confidence));
  set debugLevel(double v) => _level.value = v;

  @override
  Future<bool> start() async => true;
  @override
  Future<void> stop() async {}
  @override
  void dispose() {
    _ctl.close();
    _level.dispose();
    _partial.dispose();
  }
}

/// Reconnaissance vocale du système (speech_to_text), utilisée en secours si
/// le pack voix hors ligne n'est pas installé.
/// Android coupe l'écoute après un silence : on relance tant que la partie écoute.
class SpeechAnswerInput extends AnswerInput {
  final _stt = SpeechToText();
  final _ctl = StreamController<HeardAnswer>.broadcast();
  final _level = ValueNotifier<double>(0);
  final _partial = ValueNotifier<String>('');
  bool _wanted = false;
  bool _ready = false;
  String? _locale;

  @override
  Stream<HeardAnswer> get answers => _ctl.stream;
  @override
  ValueListenable<double> get level => _level;
  @override
  ValueListenable<String> get partial => _partial;

  @override
  Future<bool> start() async {
    _wanted = true;
    if (!_ready) {
      _ready = await _stt.initialize(onStatus: _onStatus, onError: (_) => _restartSoon());
      if (!_ready) return false;
      final locales = await _stt.locales();
      _locale = locales.where((l) => l.localeId.toLowerCase().startsWith('fr')).map((l) => l.localeId).firstOrNull;
    }
    await _listen();
    return true;
  }

  Future<void> _listen() async {
    if (!_wanted || _stt.isListening) return;
    await _stt.listen(
      onResult: _onResult,
      localeId: _locale,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 3),
      onSoundLevelChange: (db) => _level.value = ((db + 2) / 12).clamp(0.0, 1.0),
      listenOptions: SpeechListenOptions(partialResults: true, cancelOnError: false, listenMode: ListenMode.dictation),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    if (muted) {
      _partial.value = '';
      return;
    }
    _partial.value = r.recognizedWords;
    if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
      final alts = [for (final a in r.alternates.skip(1)) a.recognizedWords.trim()];
      _ctl.add(HeardAnswer(r.recognizedWords.trim(), confidence: r.hasConfidenceRating ? r.confidence : null, alternatives: alts));
      _partial.value = '';
    }
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) _restartSoon();
  }

  void _restartSoon() {
    if (_wanted) Future<void>.delayed(const Duration(milliseconds: 250), _listen);
  }

  @override
  Future<void> stop() async {
    _wanted = false;
    _level.value = 0;
    if (_stt.isListening) await _stt.stop();
  }

  @override
  void dispose() {
    _wanted = false;
    _stt.cancel();
    _ctl.close();
    _level.dispose();
    _partial.dispose();
  }
}
