import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import '../knowledge/text_normalizer.dart';
import '../services/answer_input.dart';

/// Reconnaissance vocale 100 % hors ligne (sherpa-onnx, zipformer français
/// streaming) : le micro est lu en PCM 16 kHz, décodé dans un isolate dédié
/// (l'interface reste fluide), avec détection de fin de phrase et un
/// vocabulaire favorisé par catégorie (hotwords).
///
/// Aucun enregistrement n'est conservé : l'audio ne quitte jamais la mémoire.
class OfflineAsrInput extends AnswerInput {
  OfflineAsrInput({required this.modelDir});

  final String modelDir;
  final _rec = AudioRecorder();
  final _ctl = StreamController<HeardAnswer>.broadcast();
  final _level = ValueNotifier<double>(0);
  final _partial = ValueNotifier<String>('');
  Isolate? _iso;
  SendPort? _toIso;
  StreamSubscription<Uint8List>? _mic;
  bool _muted = false;
  DateTime _unmutedAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _hotwords = '';
  List<String>? _tokens;

  @override
  Stream<HeardAnswer> get answers => _ctl.stream;
  @override
  ValueListenable<double> get level => _level;
  @override
  ValueListenable<String> get partial => _partial;

  @override
  bool get muted => _muted;
  @override
  set muted(bool v) {
    if (v == _muted) return;
    _muted = v;
    if (!v) {
      _unmutedAt = DateTime.now();
      _toIso?.send(const _Reset()); // oublie tout ce qui a été entendu pendant que la bombe parlait
    }
    _partial.value = '';
  }

  /// Vocabulaire de la catégorie en cours : favorisé par le décodeur.
  /// Les mots sont découpés en pièces BPE du modèle (même découpage que
  /// tools/voice/asr_benchmark.py).
  @override
  Future<void> setVocabulary(Iterable<String> words) async {
    _tokens ??= await _loadTokens('$modelDir/tokens.txt');
    final seen = <String>{};
    final parts = <String>[];
    for (final w in words) {
      final t = bpeTokenize(w, _tokens!);
      if (t.isNotEmpty && seen.add(t)) parts.add(t);
      if (parts.length >= 800) break;
    }
    _hotwords = parts.join('/');
    _toIso?.send(_Hotwords(_hotwords));
  }

  @override
  Future<bool> start() async {
    if (_mic != null) return true;
    if (!await _rec.hasPermission()) return false;
    if (_iso == null) {
      final fromIso = ReceivePort();
      _iso = await Isolate.spawn(_asrMain, [fromIso.sendPort, modelDir, _hotwords]);
      final ready = Completer<void>();
      fromIso.listen((m) {
        if (m is SendPort) {
          _toIso = m;
          ready.complete();
        } else if (m is _Partial) {
          if (!_muted) _partial.value = m.text;
        } else if (m is _Final) {
          _partial.value = '';
          // garde-fou : rien de ce qui commence pendant / juste après la voix de la bombe
          if (_muted || DateTime.now().difference(_unmutedAt).inMilliseconds < 250) return;
          if (m.text.trim().isEmpty) return;
          _ctl.add(HeardAnswer(m.text.trim(), confidence: m.confidence));
        } else if (m is String) {
          debugPrint('ASR : $m');
        }
      });
      await ready.future.timeout(const Duration(seconds: 30));
    }
    final stream = await _rec.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      autoGain: true,
      echoCancel: true,
      noiseSuppress: true,
    ));
    _mic = stream.listen((bytes) {
      final x = pcm16ToFloat(bytes);
      var e = 0.0;
      for (final s in x) {
        e += s * s;
      }
      final rms = math.sqrt(e / math.max(1, x.length));
      _level.value = (rms * 6).clamp(0.0, 1.0);
      if (_muted) return; // la bombe parle : on n'écoute pas
      _toIso?.send(TransferableTypedData.fromList([x]));
    });
    return true;
  }

  @override
  Future<void> stop() async {
    await _mic?.cancel();
    _mic = null;
    _level.value = 0;
    _partial.value = '';
    if (await _rec.isRecording()) await _rec.stop();
    _toIso?.send(const _Reset());
  }

  @override
  void dispose() {
    stop();
    _toIso?.send(const _Quit());
    _iso = null;
    _rec.dispose();
    _ctl.close();
  }

  static Float32List pcm16ToFloat(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    final out = Float32List(bytes.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  static Future<List<String>> _loadTokens(String path) async {
    final lines = await File(path).readAsLines();
    return [
      for (final l in lines)
        if (l.isNotEmpty && !l.startsWith('<')) l.split(' ').first,
    ];
  }

  /// Découpage glouton (plus long morceau d'abord) en pièces BPE majuscules.
  static String bpeTokenize(String word, List<String> vocab) {
    const n = TextNormalizer();
    final w = '▁${n.fold(word).toUpperCase().replaceAll(' ', '▁')}';
    final vs = vocab.toSet().toList()..sort((a, b) => b.length.compareTo(a.length));
    final out = <String>[];
    var i = 0;
    while (i < w.length) {
      final hit = vs.firstWhere((v) => w.startsWith(v, i), orElse: () => '');
      if (hit.isEmpty) {
        i++;
      } else {
        out.add(hit);
        i += hit.length;
      }
    }
    return out.join(' ');
  }
}

// ---------------------------------------------------------------- isolate
class _Reset {
  const _Reset();
}

class _Quit {
  const _Quit();
}

class _Hotwords {
  const _Hotwords(this.text);
  final String text;
}

class _Partial {
  const _Partial(this.text);
  final String text;
}

class _Final {
  const _Final(this.text, this.confidence);
  final String text;
  final double confidence;
}

void _asrMain(List<Object> args) {
  final out = args[0] as SendPort;
  final dir = args[1] as String;
  var hot = args[2] as String;
  so.initBindings();
  final rec = so.OnlineRecognizer(so.OnlineRecognizerConfig(
    model: so.OnlineModelConfig(
      transducer: so.OnlineTransducerModelConfig(encoder: '$dir/encoder.onnx', decoder: '$dir/decoder.onnx', joiner: '$dir/joiner.onnx'),
      tokens: '$dir/tokens.txt',
      numThreads: 2,
      debug: false,
    ),
    decodingMethod: 'modified_beam_search',
    maxActivePaths: 4,
    hotwordsScore: 2.0,
    enableEndpoint: true,
    rule1MinTrailingSilence: 2.0, // rien de reconnu : on attend
    rule2MinTrailingSilence: 0.7, // réponse courte terminée
    rule3MinUtteranceLength: 8,
  ));
  var stream = rec.createStream(hotwords: hot);
  final quality = _Snr();
  final inbox = ReceivePort();
  out.send(inbox.sendPort);
  var last = '';
  inbox.listen((m) {
    if (m is TransferableTypedData) {
      final x = m.materialize().asFloat32List();
      quality.add(x);
      stream.acceptWaveform(samples: x, sampleRate: 16000);
      while (rec.isReady(stream)) {
        rec.decode(stream);
      }
      final text = rec.getResult(stream).text;
      if (text != last) {
        last = text;
        out.send(_Partial(text));
      }
      if (rec.isEndpoint(stream)) {
        if (text.trim().isNotEmpty) out.send(_Final(text, quality.confidence()));
        rec.reset(stream);
        quality.resetUtterance();
        last = '';
      }
    } else if (m is _Reset) {
      rec.reset(stream);
      quality.resetUtterance();
      last = '';
    } else if (m is _Hotwords) {
      if (m.text != hot) {
        hot = m.text;
        stream.free();
        stream = rec.createStream(hotwords: hot);
        last = '';
      }
    } else if (m is _Quit) {
      stream.free();
      rec.free();
      inbox.close();
    }
  });
}

/// Estimation grossière de la qualité d'écoute : rapport entre l'énergie de
/// la parole (trames fortes) et le bruit de fond (trames faibles) sur
/// l'énoncé. La reconnaissance streaming ne fournit pas de score : cette
/// confiance sert seulement à demander de répéter quand la salle est trop
/// bruyante (jamais à pénaliser le joueur).
class _Snr {
  final _frames = <double>[];

  void add(Float32List x) {
    for (var i = 0; i + 320 <= x.length; i += 320) {
      var e = 0.0;
      for (var j = i; j < i + 320; j++) {
        e += x[j] * x[j];
      }
      final r = math.sqrt(e / 320);
      _frames.add(r);
    }
  }

  double confidence() {
    if (_frames.isEmpty) return 0;
    final s = [..._frames]..sort();
    final speech = s[(s.length * 0.9).floor().clamp(0, s.length - 1)];
    final noise = math.max(1e-4, s[(s.length * 0.2).floor()]);
    final snrDb = 20 * math.log(speech / noise) / math.ln10;
    return ((snrDb - 3) / 15).clamp(0.2, 1.0);
  }

  void resetUtterance() => _frames.clear();
}
