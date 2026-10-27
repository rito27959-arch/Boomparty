"""Génère les cas de test de normalisation (rejoués côté Dart pour garantir la parité)."""
import json
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from normalize import fold, normalize, singular  # noqa: E402

INPUTS = ["Le Réfrigérateur", "un frigo", "Une télé !", "Des casseroles", "le Cameroun", "Une voiture.",
          "Un ordinateur portable", "une table à manger", "L'Éléphant", "l’eau", "Euh… le frigo", "ben des œufs",
          "La Paz", "Le Caire", "Côte d'Ivoire", "c'est un chien", "Pommes de terre", "CHEVAUX", "gâteaux",
          "Ça va", "Ndolé", "États-Unis", "tee-shirt", "  hum   la   télévision  ", "de la soupe", "du café",
          "mon chat", "je dis la guitare", "4x4", "Saint-Étienne"]

cases = [{'input': s, 'fold': fold(s), 'normalize': normalize(s), 'singular': singular(normalize(s))} for s in INPUTS]
Path(sys.argv[1]).write_text(json.dumps(cases, ensure_ascii=False, indent=1))
print(json.dumps(cases[:6], ensure_ascii=False, indent=1))
