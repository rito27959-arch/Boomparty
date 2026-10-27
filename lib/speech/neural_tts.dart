import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

class TtsAudio {
  const TtsAudio(this.samples, this.sampleRate);
  final Float32List samples;
  final int sampleRate;
}

/// Synthèse vocale locale (sherpa-onnx + voix Piper fr_FR siwis du pack `tts`)
/// pour les répliques dynamiques (prénoms, mots cités). Le calcul tourne dans
/// un isolate : la partie ne se fige jamais pendant la génération.
class NeuralTts {
  NeuralTts(this.modelDir);
  final String modelDir;

  Isolate? _iso;
  SendPort? _to;
  final _pending = <int, Completer<TtsAudio?>>{};
  int _next = 0;
  bool _ready = false;

  bool get ready => _ready;

  Future<bool> init() async {
    if (_ready) return true;
    final port = ReceivePort();
    _iso = await Isolate.spawn(_ttsMain, [port.sendPort, modelDir]);
    final started = Completer<bool>();
    port.listen((m) {
      if (m is SendPort) {
        _to = m;
      } else if (m == 'ready') {
        _ready = true;
        started.complete(true);
      } else if (m is String && m.startsWith('error:')) {
        if (!started.isCompleted) started.complete(false);
      } else if (m is List) {
        final c = _pending.remove(m[0] as int);
        if (c == null) return;
        c.complete(m[1] == null ? null : TtsAudio((m[1] as TransferableTypedData).materialize().asFloat32List(), m[2] as int));
      }
    });
    return started.future.timeout(const Duration(seconds: 30), onTimeout: () => false);
  }

  Future<TtsAudio?> synthesize(String text, {double speed = 1.0}) {
    if (!_ready || _to == null) return Future.value();
    final id = _next++;
    final c = _pending[id] = Completer<TtsAudio?>();
    _to!.send([id, text, speed]);
    return c.future.timeout(const Duration(seconds: 8), onTimeout: () {
      _pending.remove(id);
      return null;
    });
  }

  void dispose() {
    _to?.send('quit');
    _iso = null;
    _ready = false;
  }
}

void _ttsMain(List<Object> a) {
  final out = a[0] as SendPort;
  final dir = a[1] as String;
  final inbox = ReceivePort();
  out.send(inbox.sendPort);
  so.OfflineTts tts;
  try {
    so.initBindings();
    tts = so.OfflineTts(so.OfflineTtsConfig(
      model: so.OfflineTtsModelConfig(
        vits: so.OfflineTtsVitsModelConfig(model: '$dir/model.onnx', tokens: '$dir/tokens.txt', dataDir: '$dir/espeak-ng-data'),
        numThreads: 2,
        debug: false,
      ),
    ));
  } catch (e) {
    out.send('error:$e');
    return;
  }
  out.send('ready');
  inbox.listen((m) {
    if (m == 'quit') {
      tts.free();
      inbox.close();
      return;
    }
    final req = m as List;
    try {
      final g = tts.generate(text: req[1] as String, speed: (req[2] as num).toDouble());
      out.send([req[0], TransferableTypedData.fromList([g.samples]), g.sampleRate]);
    } catch (_) {
      out.send([req[0], null, 0]);
    }
  });
}
