import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Formes de bouche disponibles (frames de la planche « visemes » rendue dans Blender).
enum Viseme { rest, e, a, o, m }

/// Piste de visèmes : instants (ms) et forme de bouche correspondante.
class VisemeTrack {
  const VisemeTrack(this.times, this.visemes);
  final List<int> times;
  final List<Viseme> visemes;

  int get durationMs => times.isEmpty ? 0 : times.last + frameMs;
  static const frameMs = 40;

  Viseme at(int ms) {
    if (times.isEmpty || ms < 0 || ms >= durationMs) return Viseme.rest;
    final i = (ms ~/ frameMs).clamp(0, visemes.length - 1);
    return visemes[i];
  }

  factory VisemeTrack.fromJson(Map<String, dynamic> j) {
    final v = (j['v'] as String).split('');
    return VisemeTrack([for (var i = 0; i < v.length; i++) i * frameMs], [for (final c in v) Viseme.values[int.parse(c)]]);
  }

  Map<String, dynamic> toJson() => {'frameMs': frameMs, 'v': visemes.map((v) => v.index).join()};

  /// Analyse du signal (mêmes règles que tools/voice/visemes.py) :
  /// énergie RMS → ouverture ; taux de passage par zéro → voyelle arrondie (o)
  /// ou étirée (é) ; montées d'énergie après silence → lèvres fermées (m/b/p).
  factory VisemeTrack.fromSamples(Float32List samples, int sampleRate) {
    final hop = (sampleRate * frameMs / 1000).round();
    final n = (samples.length / hop).floor();
    final rms = List<double>.filled(n, 0);
    final zcr = List<double>.filled(n, 0);
    for (var f = 0; f < n; f++) {
      var e = 0.0;
      var z = 0;
      for (var i = f * hop; i < (f + 1) * hop; i++) {
        final s = samples[i];
        e += s * s;
        if (i > f * hop && (s >= 0) != (samples[i - 1] >= 0)) z++;
      }
      rms[f] = math.sqrt(e / hop);
      zcr[f] = z / hop;
    }
    final peak = rms.isEmpty ? 1.0 : rms.reduce(math.max);
    final out = <Viseme>[];
    for (var f = 0; f < n; f++) {
      final level = peak > 0 ? rms[f] / peak : 0.0;
      final prevLevel = f > 0 && peak > 0 ? rms[f - 1] / peak : 0.0;
      Viseme v;
      if (level < 0.08) {
        v = Viseme.rest;
      } else if (prevLevel < 0.08 && level > 0.25) {
        v = Viseme.m; // attaque : lèvres qui s'ouvrent
      } else if (level > 0.55) {
        v = zcr[f] < 0.045 ? Viseme.o : Viseme.a;
      } else if (level > 0.25) {
        v = zcr[f] > 0.12 ? Viseme.e : (zcr[f] < 0.04 ? Viseme.o : Viseme.a);
      } else {
        v = Viseme.e;
      }
      out.add(v);
    }
    return VisemeTrack([for (var i = 0; i < out.length; i++) i * frameMs], out);
  }

  /// Approximation à partir du texte seul (sous-titres sans audio) :
  /// une syllabe ≈ 180 ms, voyelle → forme de bouche.
  factory VisemeTrack.fromText(String text) {
    final out = <Viseme>[];
    for (final ch in text.toLowerCase().split('')) {
      final v = switch (ch) {
        'a' || 'à' || 'â' => Viseme.a,
        'o' || 'ô' || 'u' || 'ù' || 'û' => Viseme.o,
        'e' || 'é' || 'è' || 'ê' || 'i' || 'î' || 'y' => Viseme.e,
        'm' || 'b' || 'p' => Viseme.m,
        ' ' || ',' || '.' || '!' || '?' => Viseme.rest,
        _ => null,
      };
      if (v != null) out.addAll(List.filled(v == Viseme.rest ? 2 : 3, v));
    }
    return VisemeTrack([for (var i = 0; i < out.length; i++) i * frameMs], out);
  }
}

/// Fournit la forme de bouche courante pendant la lecture d'une réplique.
class LipSyncController {
  final ValueNotifier<Viseme?> current = ValueNotifier(null);
  VisemeTrack? _track;
  Stopwatch? _clock;

  void start(VisemeTrack track) {
    _track = track;
    _clock = Stopwatch()..start();
  }

  /// Avance l'horloge (appelé à chaque frame par Flame) ; [positionMs]
  /// permet de se recaler sur la position réelle du lecteur audio.
  void tick({int? positionMs}) {
    final t = _track;
    if (t == null) return;
    final ms = positionMs ?? _clock!.elapsedMilliseconds;
    if (ms >= t.durationMs) {
      stop();
      return;
    }
    final v = t.at(ms);
    if (current.value != v) current.value = v;
  }

  void stop() {
    _track = null;
    _clock = null;
    current.value = null;
  }

  bool get speaking => _track != null;
}
