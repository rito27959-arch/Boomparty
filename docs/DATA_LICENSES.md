# Données, modèles et licences

| Élément | Source | Licence | Où |
|---|---|---|---|
| Base de connaissances (concepts, libellés, alias, formes féminines) | Wikidata, requêtes SPARQL (`tools/kb/`) | CC0 | `assets/knowledge/boom_kb.db` (embarquée) |
| Listes d'amorçage et synonymes de jeu (frigo = réfrigérateur…) | Rédigées pour BOOM PARTY (`tools/kb/kb_config.py`) | Propriété du projet | idem |
| Reconnaissance vocale : streaming zipformer français (int8) | icefall / k2-fsa sherpa-onnx | Apache-2.0 | Pack `boom_asr_fr_v1.zip`, téléchargé au premier lancement |
| Moteur d'inférence | sherpa-onnx, onnxruntime | Apache-2.0 / MIT | Bibliothèque de l'application |
| Voix de la bombe (répliques fixes) : voix du concepteur, utilisée avec son accord, générée avec Chatterbox Multilingual | Resemble AI | MIT (filigrane audio Perth inaudible) | `assets/voice/` |
| Voix de secours (répliques dynamiques) : Piper fr_FR siwis medium | Corpus SIWIS (Univ. d'Édimbourg) | CC BY 4.0 : attribution affichée dans `assets/voice/CREDITS.txt` | Pack `boom_tts_fr_v1.zip` |
| espeak-ng-data (phonétisation pour Piper) | espeak-ng | GPL-3.0 | Pack `boom_tts_fr_v1.zip`, fichiers de données non modifiés, distribués séparément de l'application |

## Sources étudiées mais non intégrées

- **Wiktionnaire / Kaikki** (CC BY-SA) : les synonymes y sont nombreux mais la clause de partage à l'identique s'appliquerait à la base dérivée. On ne l'a pas fusionnée. Les synonymes « de jeu » ont été rédigés à la main.
- **ConceptNet 5** (CC BY-SA 4.0) : même contrainte, et un bruit important en français.
- **WOLF** (WordNet Libre du Français, CeCILL-C) : couverture et qualité des synsets trop inégales pour juger des réponses sans relecture humaine.
- **Voix Piper « tom »** : la plus naturelle à l'écoute, mais sous licence AGPL-3.0, incompatible avec une application distribuée fermée. Écartée.
- **Kokoro v1.0 (ff_siwis)** : Apache-2.0 et intelligible, mais trop lente pour le temps réel (RTF ≈ 1,6 sur CPU x86 à 2 cœurs). Écartée.

## Contenus exclus

Le jeu est familial. Le pipeline écarte les contenus adultes et l'armement (`EXCLUDE_QIDS`, `EXCLUDE_PATTERN`). Chaque exclusion est tracée dans `docs/kb_report.md`.
