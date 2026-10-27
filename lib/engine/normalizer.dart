/// Normalise une réponse prononcée ou tapée pour la comparer au dictionnaire
/// et détecter les répétitions : minuscules, sans accents, sans article,
/// singulier simple.
class WordNormalizer {
  const WordNormalizer();

  static const _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
    'ç': 'c',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'í': 'i',
    'ô': 'o', 'ö': 'o', 'ó': 'o', 'õ': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
    'ÿ': 'y', 'œ': 'oe', 'æ': 'ae', 'ñ': 'n',
  };

  static final _articles = RegExp(r"^(le |la |les |un |une |des |du |de la |de l'|l'|d')");
  static final _punct = RegExp(r"[^a-z0-9' -]");
  static final _spaces = RegExp(r'\s+');

  String normalize(String raw) {
    var s = raw.toLowerCase().trim().replaceAll('’', "'");
    final b = StringBuffer();
    for (final ch in s.split('')) {
      b.write(_accents[ch] ?? ch);
    }
    s = b.toString().replaceAll(_punct, ' ').replaceAll('-', ' ').replaceAll(_spaces, ' ').trim();
    s = s.replaceFirst(_articles, '').trim();
    return s.split(' ').map(_singular).join(' ');
  }

  String _singular(String w) {
    if (w.length <= 3) return w;
    if (w.endsWith('eaux')) return w.substring(0, w.length - 1); // gâteaux → gateau
    if (w.endsWith('aux') && w.length > 4) return '${w.substring(0, w.length - 3)}al'; // chevaux → cheval
    if (w.endsWith('s') || w.endsWith('x')) return w.substring(0, w.length - 1);
    return w;
  }
}
