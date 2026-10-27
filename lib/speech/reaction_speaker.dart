import 'package:flutter/foundation.dart';

import '../personality/personality_engine.dart';
import 'lip_sync.dart';

/// Ce qui fait parler la bombe (implémenté par SpeechEngine ; les tests
/// utilisent [SilentSpeaker]).
abstract class ReactionSpeaker {
  ValueListenable<bool> get speaking;
  ValueListenable<String> get subtitle;
  LipSyncController get lipSync;
  Future<void> speak(Reaction r, PersonalityId profile);
  Future<void> stop();
}

/// Haut-parleur muet : sous-titres seulement, aucune durée de parole.
class SilentSpeaker implements ReactionSpeaker {
  final _speaking = ValueNotifier(false);
  final _subtitle = ValueNotifier('');
  @override
  final LipSyncController lipSync = LipSyncController();
  @override
  ValueListenable<bool> get speaking => _speaking;
  @override
  ValueListenable<String> get subtitle => _subtitle;
  @override
  Future<void> speak(Reaction r, PersonalityId profile) async => _subtitle.value = r.text;
  @override
  Future<void> stop() async {}
}
