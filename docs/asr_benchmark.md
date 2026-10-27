# Banc d'essai ASR (français, réponses courtes)

| modèle | brut propre | brut 10 dB | brut 5 dB | **en jeu** propre | **en jeu** 10 dB | **en jeu** 5 dB | CER propre | RTF (x86, 2 cœurs) | taille |
|---|---|---|---|---|---|---|---|---|---|
| whisper-tiny-int8 | 10% | 12% | 12% | **17%** | **17%** | **12%** | 0.64 | 0.142 | 102.8 Mo |
| whisper-base-int8 | 15% | 19% | 12% | **23%** | **27%** | **17%** | 0.69 | 0.246 | 159.8 Mo |
| canary-180m-flash-int8 | 56% | 23% | 25% | **60%** | **25%** | **25%** | 0.30 | 0.14 | 207.5 Mo |
| zipformer-fr-streaming-int8 | 46% | 48% | 46% | **52%** | **48%** | **48%** | 0.41 | 0.201 | 129.0 Mo |
| zipformer-fr-int8 + vocabulaire catégorie | 50% | 48% | 46% | **54%** | **54%** | **52%** | 0.37 | 0.468 | 129.0 Mo |

## Justesse en jeu par voix de synthèse (toutes conditions)

| modèle | gilles | siwis | tom | upmc |
|---|---|---|---|---|
| whisper-tiny-int8 | 6% | 22% | 28% | 6% |
| whisper-base-int8 | 14% | 42% | 22% | 11% |
| canary-180m-flash-int8 | 6% | 83% | 36% | 22% |
| zipformer-fr-streaming-int8 | 3% | 92% | 69% | 33% |
| zipformer-fr-int8 + vocabulaire catégorie | 11% | 89% | 75% | 39% |

> Voix de test synthétiques (Piper). Une voix de mauvaise qualité fait échouer tous les modèles :
> ces chiffres sont un classement relatif, pas une mesure de la justesse sur de vraies voix.
