#!/usr/bin/env bash
# Construit les packs voix téléchargeables au premier lancement (stockés sans
# compression : extraction rapide sur téléphone) et leur manifeste.
#   boom_asr_fr_v1.zip : reconnaissance vocale streaming (zipformer FR, int8, Apache-2.0)
#   boom_tts_fr_v1.zip : synthèse vocale Piper fr_FR siwis medium (corpus CC BY 4.0)
set -euo pipefail
OUT=$(realpath -m "${1:-voice_packs}")
REL=https://github.com/k2-fsa/sherpa-onnx/releases/download
WORK=$(mktemp -d)
mkdir -p "$OUT" && cd "$WORK"
curl -fsSL "$REL/asr-models/sherpa-onnx-streaming-zipformer-fr-2023-04-14.tar.bz2" | tar xj
curl -fsSL "$REL/tts-models/vits-piper-fr_FR-siwis-medium.tar.bz2" | tar xj

Z=sherpa-onnx-streaming-zipformer-fr-2023-04-14
mkdir -p asr && cp $Z/encoder-*.int8.onnx asr/encoder.onnx && cp $Z/decoder-*.int8.onnx asr/decoder.onnx \
  && cp $Z/joiner-*.int8.onnx asr/joiner.onnx && cp $Z/tokens.txt asr/tokens.txt
cat > asr/LICENSE.txt <<'TXT'
Modèle : streaming zipformer français (icefall, Common Voice), exporté par k2-fsa/sherpa-onnx.
Licence : Apache-2.0. Source : https://huggingface.co/shaojieli/icefall-asr-commonvoice-fr-pruned-transducer-stateless7-streaming-2023-04-02
TXT
P=vits-piper-fr_FR-siwis-medium
mkdir -p tts && cp $P/fr_FR-siwis-medium.onnx tts/model.onnx && cp $P/tokens.txt tts/tokens.txt \
  && cp -r $P/espeak-ng-data tts/espeak-ng-data && cp $P/MODEL_CARD tts/MODEL_CARD
cat > tts/LICENSE.txt <<'TXT'
Voix : Piper fr_FR siwis (medium). Corpus SIWIS, licence CC BY 4.0 (https://datashare.is.ed.ac.uk/handle/10283/2353).
espeak-ng-data : GPL-3.0 (données de phonétisation, fichiers non modifiés, https://github.com/espeak-ng/espeak-ng).
TXT
(cd asr && zip -q -0 -r "$OUT/boom_asr_fr_v1.zip" .)
(cd tts && zip -q -0 -r "$OUT/boom_tts_fr_v1.zip" .)
cd "$OUT"
python3 - <<'PY'
import hashlib, json, os
packs = {}
for name, f in (('asr', 'boom_asr_fr_v1.zip'), ('tts', 'boom_tts_fr_v1.zip')):
    h = hashlib.sha256(open(f, 'rb').read()).hexdigest()
    packs[name] = {'file': f, 'sha256': h, 'bytes': os.path.getsize(f), 'version': 1}
json.dump({'packs': packs}, open('voice_packs.json', 'w'), indent=1)
print(json.dumps(packs, indent=1))
PY
