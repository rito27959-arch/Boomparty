/// Normalisation du texte — portage exact de tools/kb/normalize.py.
/// La parité est vérifiée par test/unit/knowledge_test.dart sur les cas
/// générés par tools/kb/make_normalize_cases.py.
class TextNormalizer {
  const TextNormalizer();

  static const _ligatures = {'œ': 'oe', 'æ': 'ae', 'ß': 'ss', 'Œ': 'oe', 'Æ': 'ae'};

  // Lettres latines accentuées → lettre de base (équivalent du NFKD + retrait des diacritiques).
  static const _accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
    'ç': 'c', 'ć': 'c', 'ĉ': 'c', 'ċ': 'c', 'č': 'c', 'ď': 'd',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
    'ĝ': 'g', 'ğ': 'g', 'ġ': 'g', 'ģ': 'g', 'ĥ': 'h',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ĩ': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i',
    'ĵ': 'j', 'ķ': 'k', 'ĺ': 'l', 'ļ': 'l', 'ľ': 'l',
    'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ō': 'o', 'ŏ': 'o', 'ő': 'o',
    'ŕ': 'r', 'ŗ': 'r', 'ř': 'r', 'ś': 's', 'ŝ': 's', 'ş': 's', 'š': 's', 'ţ': 't', 'ť': 't',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ũ': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
    'ŵ': 'w', 'ý': 'y', 'ÿ': 'y', 'ŷ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z',
  };

  static const leading = [
    'de la ', "de l' ", 'les ', 'le ', 'la ', "l' ", 'un ', 'une ', 'des ', 'du ', "d' ", 'de ',
    'mon ', 'ma ', 'mes ', 'ton ', 'ta ', 'tes ', 'son ', 'sa ', 'ses ', 'ce ', 'cet ', 'cette ', 'ces ',
  ];

  static const fillers = [
    'euh', 'heu', 'hum', 'ben', 'bah', 'alors', 'bon', 'ok', 'okay', 'donc', 'voila',
    "c' est", "c' etait", 'je dis', 'je pense', 'je crois', 'moi je dis', 'mmh', 'hein',
  ];

  static final _nonWord = RegExp(r"[^a-z0-9' ]+");
  static final _apos = RegExp(r"'\s*");
  static final _spaces = RegExp(r'\s+');

  String fold(String text) {
    final b = StringBuffer();
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final lig = _ligatures[ch];
      if (lig != null) {
        b.write(lig);
        continue;
      }
      final low = ch.toLowerCase();
      b.write(_accents[low] ?? low);
    }
    var s = b.toString().replaceAll('’', "'").replaceAll('`', "'").replaceAll('‘', "'");
    s = s.replaceAll(_nonWord, ' ');
    s = s.replaceAll(_apos, "' ");
    return s.replaceAll(_spaces, ' ').trim();
  }

  String stripFillers(String s) {
    var changed = true;
    while (changed) {
      changed = false;
      for (final f in fillers) {
        if (s == f) return '';
        if (s.startsWith('$f ')) {
          s = s.substring(f.length + 1);
          changed = true;
        }
        if (s.endsWith(' $f')) {
          s = s.substring(0, s.length - f.length - 1);
          changed = true;
        }
      }
    }
    return s.trim();
  }

  String stripLeading(String s) {
    for (final a in leading) {
      if (s.startsWith(a) && s.length > a.length) return s.substring(a.length).trim();
    }
    return s;
  }

  String normalize(String text) => stripLeading(stripFillers(fold(text)));

  String singularWord(String w) {
    if (w.length <= 3) return w;
    if (w.endsWith('eaux') || (w.endsWith('eux') && w.length > 4)) return w.substring(0, w.length - 1);
    if (w.endsWith('aux') && w.length > 4) return '${w.substring(0, w.length - 3)}al';
    if (w.endsWith('s') || w.endsWith('x')) return w.substring(0, w.length - 1);
    return w;
  }

  String singular(String s) => s.split(' ').map(singularWord).join(' ');

  /// Clé phonétique française simplifiée, pour tolérer les erreurs de
  /// transcription (« réfrijérateur », « kasserole »…). Dart uniquement.
  String phonetic(String folded) {
    var s = folded.replaceAll(' ', '').replaceAll("'", '');
    const rules = [
      ['eaux', 'o'], ['eau', 'o'], ['aux', 'o'], ['au', 'o'], ['ph', 'f'], ['qu', 'k'], ['ck', 'k'],
      ['ch', 'C'], ['sh', 'C'], ['gn', 'N'], ['ge', 'je'], ['gi', 'ji'], ['ce', 'se'], ['ci', 'si'],
      ['ai', 'e'], ['ei', 'e'], ['er', 'e'], ['ez', 'e'], ['et', 'e'], ['an', 'A'], ['am', 'A'],
      ['en', 'A'], ['em', 'A'], ['on', 'O'], ['om', 'O'], ['in', 'I'], ['im', 'I'], ['ain', 'I'],
      ['ein', 'I'], ['un', 'I'], ['ou', 'U'], ['oi', 'wa'], ['y', 'i'], ['c', 'k'], ['q', 'k'],
      ['h', ''], ['z', 's'], ['x', 'ks'], ['w', 'v'],
    ];
    for (final r in rules) {
      s = s.replaceAll(r[0], r[1]);
    }
    // lettres finales muettes + doubles lettres
    s = s.replaceAll(RegExp(r'[stdpe]+$'), '');
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i == 0 || s[i] != s[i - 1]) b.write(s[i]);
    }
    return b.toString();
  }

  /// Distance de Damerau-Levenshtein (transpositions adjacentes).
  static int distance(String a, String b, {int max = 3}) {
    if ((a.length - b.length).abs() > max) return max + 1;
    final d = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      var rowMin = 1 << 30;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var v = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost].reduce((x, y) => x < y ? x : y);
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          v = v < d[i - 2][j - 2] + 1 ? v : d[i - 2][j - 2] + 1;
        }
        d[i][j] = v;
        if (v < rowMin) rowMin = v;
      }
      if (rowMin > max) return max + 1;
    }
    return d[a.length][b.length];
  }
}
