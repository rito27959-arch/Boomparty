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

## Architecture

| Dossier | Rôle |
|---|---|
| `lib/engine/` | Règles pures (aucune dépendance UI) : tours, validation, mots déjà dits, mèche, explosion, score. Testé dans `test/unit/`. |
| `lib/game/game_controller.dart` | Relie moteur ↔ saisie ↔ audio ↔ affichage. L'UI lit des phases, ne décide jamais des règles. |
| `lib/services/answer_input.dart` | Reconnaissance vocale continue FR (`speech_to_text`) + saisie clavier de secours. |
| `lib/services/audio_director.dart` | Répliques par événement, priorités, interruptions, sous-titres, packs de voix. |
| `lib/services/settings_store.dart` | Paramètres persistés. |
| `lib/services/wallet.dart` | Monétisation : gemmes gagnées en jeu, skins débloqués. |
| `lib/character/` | Bombe Flame : spritesheets par état, mouvement secondaire procédural, explosion (flash, onde de choc, débris, fumée), skins par teinte. |
| `lib/design/` | Design system : couleurs relevées sur la maquette, boutons « bonbon » en relief, titres cartoon, décors et icônes vectoriels. |
| `lib/screens/` | Les 14 écrans. |
| `reference/` | Écrans extraits de la maquette, source de vérité des comparaisons. |
| `tools/` | Découpe/nettoyage des planches, spritesheets, comparaison visuelle, patch Android. |

## Ressources manquantes (signalées, non simulées)

- **Voix enregistrées** : aucune fournie. L'architecture (packs, priorités, sous-titres) est prête ; seuls les sous-titres s'affichent.
- **Effets sonores** : aucun fourni.
- **Poses de la bombe absentes des planches** : LISTENING et CONFUSED (réutilisent idle/talking), héros « qui court avec micro » de l'accueil, visèmes de synchro labiale.
- **Illustrations HD** : visages des joueurs, foule de la célébration, icônes 3D des catégories, mascottes des modes — redessinés en vectoriel faute de fichiers sources.
- **Décors supplémentaires** (onglet Arrière-plans) et **langues autres que le français**.
- La maquette ne contient pas d'écran « Réponse incorrecte » : il reprend la mise en page « Mot déjà dit ».
