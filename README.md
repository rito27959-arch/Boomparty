# BOOM PARTY

Jeu de soirée cartoon pour Android — Flutter + Flame.

## Compiler

```bash
flutter create --platforms=android --project-name boom_party --org com.boomparty .   # génère android/ s'il manque
python3 tools/patch_android.py .        # micro, vibrations, portrait, nom affiché
flutter pub get
flutter run                             # appareil ou émulateur
flutter build apk --release --split-per-abi
```

La CI (`.github/workflows/captures.yml`) fait tout cela à chaque push sur `main` et publie
sur la branche **`ci-results`** :

- `captures/` — rendu réel de chaque écran (Flutter test, 390 dp de large, ×2) ;
- `compare/` — planches référence | capture | superposition | carte des écarts, et `report.md` (SSIM, ΔE, F1 des contours) ;
- `logs/` — analyse statique, tests unitaires, captures ;
- `boom_party-arm64.apk` — uniquement si le message de commit contient `[apk]` (ou lancement manuel).

## Graphismes 3D (Blender)

Le personnage et toutes les illustrations sont **modélisés, animés et rendus dans Blender**
(module Python `bpy`, moteur Cycles). Aucune image n'est collée ou découpée : chaque frame est un
rendu du même modèle 3D, ce qui garantit la cohérence du personnage.

```bash
pip install bpy==5.2.3            # Blender en module Python (Python 3.13)
tools/blender/render_all.sh 20 64 # animations, spritesheets, illustrations, icônes, avatars, vidéos
```

| Fichier | Rôle |
|---|---|
| `tools/blender/bomb_rig.py` | Modèle 3D paramétrique de la bombe : corps noir brillant violacé, yeux en relief, paupières, sourcils, bouche (dents, langue), gants à 4 doigts articulés, chaussures, mèche torsadée, étincelle, sueur, suie, explosion (flash, boule de feu, fumée, débris, onde de choc), étoiles d'étourdissement. Éclairage : clé chaude, liserés bleu et orangé. |
| `tools/blender/poses.py` | Expressions clés (repères du visage relevés sur l'image de référence HD). |
| `tools/blender/render_anims.py` | 12 animations (anticipation, squash & stretch, clignements, visèmes de parole, sauts, tremblements…), 12 i/s. |
| `tools/blender/pack_blender.py` | Spritesheets en grille (≤ 8 colonnes) + `bomb_animations.json` pour Flame. |
| `tools/blender/render_illustrations.py`, `props.py` | Héros de l'accueil (micro), mascottes des 5 modes (couronne, cornes), 9 skins (glace, ninja, citrouille, arc-en-ciel, galaxie, acier, bonbon, lave), 4 voix (robot à antenne…). |
| `tools/blender/render_icons.py` | Icônes 3D : 10 catégories, trophée, médailles, gemme, couronne, cœurs, éclairs. |
| `tools/blender/render_avatars.py` | Bustes 3D des 5 joueurs. |
| `tools/blender/make_videos.py` | Vidéos de contrôle par état, séquence de transitions IDLE → … → EXPLOSION, planches « pelures d'oignon ». |
| `tools/blender/ghost.py`, `grid_overlay.py` | Comparaison du rendu avec l'image de référence (superposition calée sur le corps, grille en unités du corps). |

## Architecture

| Dossier | Rôle |
|---|---|
| `lib/engine/` | Règles pures (aucune dépendance UI) : tours, validation, mots déjà dits, mèche, explosion, score. Testé dans `test/unit/`. |
| `lib/game/game_controller.dart` | Relie moteur ↔ saisie ↔ audio ↔ affichage. L'UI lit des phases, ne décide jamais des règles. |
| `lib/services/answer_input.dart` | Reconnaissance vocale continue FR (`speech_to_text`) + saisie clavier de secours. |
| `lib/services/audio_director.dart` | Répliques par événement, priorités, interruptions, sous-titres, packs de voix. |
| `lib/services/settings_store.dart` | Paramètres persistés. |
| `lib/services/wallet.dart` | Monétisation : gemmes gagnées en jeu, skins débloqués. |
| `lib/character/` | Bombe Flame : une animation par état (rendue dans Blender), chargement à la demande par écran, qualité basse (planches à 50 %), « pop » de transition, flash + onde de choc, skins. |
| `lib/design/` | Design system : typographie unique Lilita One, couleurs relevées sur la maquette, boutons « bonbon » en relief, titres cartoon, décors vectoriels ; illustrations HD rendues dans Blender (`assets/illustrations/`). |
| `lib/screens/` | Les 14 écrans. |
| `reference/` | Écrans extraits de la maquette, source de vérité des comparaisons. |
| `tools/` | Découpe/nettoyage des planches, spritesheets, comparaison visuelle, patch Android. |

## Ressources manquantes (signalées, non simulées)

- **Voix enregistrées** : aucune fournie. L'architecture (packs, priorités, sous-titres) est prête ; seuls les sous-titres s'affichent.
- **Effets sonores** : aucun fourni.
- **Synchro labiale** : 4 visèmes (a, e, o, m) rendus ; la synchronisation fine sur une piste vocale attendra les enregistrements.
- **Foule de la célébration** : composée des 5 avatars 3D autour de la bombe animée (pas de scène de foule unique).
- **Décors supplémentaires** (onglet Arrière-plans) et **langues autres que le français**.
- La maquette ne contient pas d'écran « Réponse incorrecte » : il reprend la mise en page « Mot déjà dit ».
