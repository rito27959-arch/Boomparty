import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../personality/personality_engine.dart';
import '../services/app_services.dart';
import '../services/settings_store.dart';
import '../voice/voice_pack_manager.dart';

/// Réglages avancés de la voix : personnalité de la bombe et packs hors ligne.
Future<void> showVoiceSettings(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BoomColors.creamLight,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => const _VoiceSettings(),
    );

class _VoiceSettings extends StatelessWidget {
  const _VoiceSettings();

  static const _personas = <PersonalityId, (String, String)>{
    PersonalityId.classic: ('BOOM CLASSIC', 'Moqueur et bon joueur'),
    PersonalityId.crazy: ('BOOM CRAZY', 'Imprévisible et survolté'),
    PersonalityId.drama: ('BOOM DRAMA', 'Théâtral, tout est une tragédie'),
  };

  @override
  Widget build(BuildContext context) {
    final s = SettingsStore.instance;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Personnalité de la bombe', style: BoomText.ui800(20)),
            const SizedBox(height: 8),
            for (final e in _personas.entries)
              RadioListTile<String>(
                value: e.key.name,
                groupValue: s.personality,
                onChanged: (v) => s.update((x) => x.personality = v!),
                contentPadding: EdgeInsets.zero,
                title: Text(e.value.$1, style: BoomText.ui800(17)),
                subtitle: Text(e.value.$2, style: BoomText.ui600(14, color: const Color(0xFF6B5E8A))),
              ),
            const Divider(height: 24),
            Text('Voix hors ligne', style: BoomText.ui800(20)),
            const SizedBox(height: 4),
            Text('Téléchargées une seule fois (Wi-Fi conseillé), puis tout fonctionne sans Internet. '
                'Aucun enregistrement de voix n’est conservé.',
                style: BoomText.ui600(13.5, color: const Color(0xFF6B5E8A))),
            const SizedBox(height: 10),
            const _PackTile(kind: VoicePackKind.asr, title: 'Reconnaissance vocale', size: '≈ 130 Mo',
                fallback: 'Sans ce pack : reconnaissance du téléphone (peut demander Internet).'),
            const _PackTile(kind: VoicePackKind.tts, title: 'Voix dynamique (prénoms, mots)', size: '≈ 80 Mo',
                fallback: 'Sans ce pack : répliques préenregistrées et sous-titres.'),
          ]),
        ),
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({required this.kind, required this.title, required this.size, required this.fallback});
  final VoicePackKind kind;
  final String title, size, fallback;

  @override
  Widget build(BuildContext context) {
    final packs = AppServices.packs;
    return ValueListenableBuilder<PackState>(
      valueListenable: packs.state[kind]!,
      builder: (context, st, _) {
        final busy = st.status == PackStatus.downloading || st.status == PackStatus.verifying || st.status == PackStatus.extracting;
        final label = switch (st.status) {
          PackStatus.ready => 'Installé',
          PackStatus.downloading => 'Téléchargement… ${(st.progress * 100).round()} %',
          PackStatus.verifying => 'Vérification…',
          PackStatus.extracting => 'Installation…',
          PackStatus.failed => 'Échec : ${st.error ?? ''}',
          PackStatus.absent => '$size — $fallback',
        };
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: BoomText.ui800(16)),
                Text(label, maxLines: 3, overflow: TextOverflow.ellipsis, style: BoomText.ui600(13, color: const Color(0xFF6B5E8A))),
                if (busy) Padding(padding: const EdgeInsets.only(top: 6), child: LinearProgressIndicator(value: st.progress)),
              ]),
            ),
            const SizedBox(width: 10),
            if (st.status == PackStatus.ready)
              TextButton(onPressed: () => packs.remove(kind), child: Text('Supprimer', style: BoomText.ui700(14)))
            else if (!busy)
              FilledButton(
                onPressed: () => packs.install(kind),
                child: Text(st.status == PackStatus.failed ? 'Réessayer' : 'Installer', style: BoomText.ui700(14, color: Colors.white)),
              ),
          ]),
        );
      },
    );
  }
}
