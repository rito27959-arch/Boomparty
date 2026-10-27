import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Packs voix hors ligne publiés dans la release GitHub `voice-pack-v1`
/// (construits par tools/voice/make_voice_packs.sh) :
/// - `asr` : reconnaissance vocale streaming française (≈ 130 Mo) ;
/// - `tts` : voix de synthèse pour les répliques dynamiques (≈ 80 Mo).
/// Sans pack, le jeu reste jouable : reconnaissance du système en secours,
/// répliques fixes préenregistrées et sous-titres.
enum VoicePackKind { asr, tts }

enum PackStatus { absent, downloading, verifying, extracting, ready, failed }

class PackState {
  const PackState(this.status, {this.progress = 0, this.error});
  final PackStatus status;
  final double progress; // 0..1
  final String? error;
}

class VoicePackManager {
  VoicePackManager({required this.rootDir, this.baseUrl = defaultBaseUrl});

  static const defaultBaseUrl = 'https://github.com/rito27959-arch/Boomparty/releases/download/voice-pack-v1';
  final String rootDir;
  final String baseUrl;

  final Map<VoicePackKind, ValueNotifier<PackState>> state = {
    for (final k in VoicePackKind.values) k: ValueNotifier(const PackState(PackStatus.absent)),
  };

  String dirOf(VoicePackKind k) => '$rootDir/voice/${k.name}';
  bool isReady(VoicePackKind k) => File('${dirOf(k)}/.ready').existsSync();

  /// À appeler au démarrage : marque les packs déjà installés.
  void refresh() {
    for (final k in VoicePackKind.values) {
      if (isReady(k)) state[k]!.value = const PackState(PackStatus.ready, progress: 1);
    }
  }

  /// Télécharge, vérifie (SHA-256 du manifeste) puis extrait un pack.
  /// Reprend un téléchargement interrompu (en-tête Range).
  Future<bool> install(VoicePackKind k) async {
    final st = state[k]!;
    if (st.value.status == PackStatus.downloading || st.value.status == PackStatus.extracting) return false;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      st.value = const PackState(PackStatus.downloading);
      final manifest = jsonDecode(await _getString(client, '$baseUrl/voice_packs.json')) as Map<String, dynamic>;
      final info = (manifest['packs'] as Map<String, dynamic>)[k.name] as Map<String, dynamic>;
      final file = info['file'] as String;
      final total = info['bytes'] as int;
      final sha = info['sha256'] as String;
      final zip = File('$rootDir/voice/$file.part');
      await zip.parent.create(recursive: true);
      var have = zip.existsSync() ? zip.lengthSync() : 0;
      if (have > total) {
        zip.deleteSync();
        have = 0;
      }
      if (have < total) {
        final req = await client.getUrl(Uri.parse('$baseUrl/$file'));
        if (have > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');
        final res = await req.close();
        if (res.statusCode != 200 && res.statusCode != 206) throw HttpException('HTTP ${res.statusCode}');
        if (res.statusCode == 200) have = 0; // le serveur a ignoré la reprise
        final sink = zip.openWrite(mode: have > 0 ? FileMode.append : FileMode.write);
        var got = have;
        await for (final chunk in res) {
          sink.add(chunk);
          got += chunk.length;
          st.value = PackState(PackStatus.downloading, progress: got / total);
        }
        await sink.close();
      }
      st.value = const PackState(PackStatus.verifying, progress: 1);
      final digest = await compute(_sha256File, zip.path);
      if (digest != sha) {
        zip.deleteSync();
        throw const FormatException('Somme de contrôle incorrecte : fichier corrompu, à retélécharger');
      }
      st.value = const PackState(PackStatus.extracting, progress: 1);
      final dir = Directory(dirOf(k));
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await compute(_extract, [zip.path, dir.path]);
      File('${dir.path}/.ready').writeAsStringSync(sha);
      zip.deleteSync();
      st.value = const PackState(PackStatus.ready, progress: 1);
      return true;
    } catch (e) {
      st.value = PackState(PackStatus.failed, error: '$e');
      return false;
    } finally {
      client.close();
    }
  }

  Future<void> remove(VoicePackKind k) async {
    final dir = Directory(dirOf(k));
    if (dir.existsSync()) await dir.delete(recursive: true);
    state[k]!.value = const PackState(PackStatus.absent);
  }

  static Future<String> _getString(HttpClient c, String url) async {
    final res = await (await c.getUrl(Uri.parse(url))).close();
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode} sur $url');
    return res.transform(utf8.decoder).join();
  }
}

Future<String> _sha256File(String path) async => (await sha256.bind(File(path).openRead()).first).toString();

Future<void> _extract(List<String> a) async {
  await extractFileToDisk(a[0], a[1]);
}
