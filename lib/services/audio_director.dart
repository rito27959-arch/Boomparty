/// Les quatre voix de l'écran Paramètres (identifiants = [BombVoice]).
class VoicePack {
  const VoicePack({required this.id, required this.label});
  final String id;
  final String label;
}

const voicePacks = <VoicePack>[
  VoicePack(id: 'classique', label: 'Classique'),
  VoicePack(id: 'drole', label: 'Drôle'),
  VoicePack(id: 'serieuse', label: 'Sérieuse'),
  VoicePack(id: 'robot', label: 'Robot'),
];
