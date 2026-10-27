import 'package:flutter/foundation.dart';

/// Répliques et effets que la bombe peut jouer (section 12 de la directive).
enum VoiceCue { yourTurn, correct, repeated, invalid, hurry, explosion, celebration }

/// Priorité : une réplique de priorité supérieure interrompt la courante.
const cuePriority = <VoiceCue, int>{
  VoiceCue.yourTurn: 1,
  VoiceCue.correct: 2,
  VoiceCue.invalid: 2,
  VoiceCue.repeated: 3,
  VoiceCue.hurry: 3,
  VoiceCue.celebration: 4,
  VoiceCue.explosion: 5,
};

/// Une « voix » de la bombe : un fichier audio enregistré par réplique,
/// plusieurs variantes possibles. Ajouter une voix = ajouter un pack.
class VoicePack {
  const VoicePack({required this.id, required this.label, required this.files});
  final String id;
  final String label;
  final Map<VoiceCue, List<String>> files;
  bool get hasRecordings => files.values.any((v) => v.isNotEmpty);
}

/// Les quatre voix de l'écran Paramètres. AUCUN enregistrement n'a été fourni :
/// les listes sont vides et signalées comme ressources manquantes.
const voicePacks = <VoicePack>[
  VoicePack(id: 'classique', label: 'Classique', files: {}),
  VoicePack(id: 'drole', label: 'Drôle', files: {}),
  VoicePack(id: 'serieuse', label: 'Sérieuse', files: {}),
  VoicePack(id: 'robot', label: 'Robot', files: {}),
];

/// Chef d'orchestre audio : choisit la réplique, gère les priorités et les
/// interruptions, publie le sous-titre et l'activité « parole » pour la
/// synchronisation labiale (animation TALKING).
class AudioDirector {
  AudioDirector({required this.pack, this.voiceVolume = 0.8, this.fxVolume = 0.7});
  factory AudioDirector.silent() => AudioDirector(pack: voicePacks.first);

  VoicePack pack;
  double voiceVolume, fxVolume;
  VoiceCue? _current;

  /// Sous-titre de la dernière réplique (option « Sous-titres »).
  final subtitle = ValueNotifier<String>('');

  /// Historique des répliques demandées (vérifiable par les tests).
  final List<VoiceCue> history = [];

  static String line(VoiceCue c, {String? name}) => switch (c) {
        VoiceCue.yourTurn => name == null ? 'À toi !' : 'À toi, $name !',
        VoiceCue.correct => 'Super !',
        VoiceCue.repeated => 'Oups ! Déjà dit !',
        VoiceCue.invalid => 'Hmm… ça ne rentre pas dans la catégorie !',
        VoiceCue.hurry => 'Trop lent… ça va exploser !',
        VoiceCue.explosion => 'BOOOOM !',
        VoiceCue.celebration => 'Soirée de légende !',
      };

  void cue(VoiceCue c, {String? name}) {
    if (_current != null && cuePriority[c]! < cuePriority[_current]!) return;
    _current = c;
    history.add(c);
    subtitle.value = line(c, name: name);
    // Lecture réelle : à brancher quand les enregistrements existeront
    // (pack.files[c]). Tant qu'ils manquent, seuls les sous-titres s'affichent.
    _current = null;
  }
}
