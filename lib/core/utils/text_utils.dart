const Map<String, String> _diacritics = <String, String>{
  'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
  'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
  'ä': 'a', 'ë': 'e', 'ï': 'i', 'ö': 'o', 'ü': 'u',
  'â': 'a', 'ê': 'e', 'î': 'i', 'ô': 'o', 'û': 'u',
  'ã': 'a', 'õ': 'o', 'ñ': 'n', 'ç': 'c',
};

/// Lowercase-free diacritic stripper: removes accents from [input].
/// Combine with toLowerCase() for case-insensitive comparisons.
String removeDiacritics(String input) {
  String result = input;
  _diacritics.forEach((String from, String to) {
    result = result.replaceAll(from, to);
  });
  return result;
}
