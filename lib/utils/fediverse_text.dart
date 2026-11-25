const Map<String, String> _namedHtmlEntities = {
  'nbsp': ' ',
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'rsquo': '’',
  'lsquo': '‘',
  'rdquo': '”',
  'ldquo': '“',
  'hellip': '…',
  'mdash': '—',
  'ndash': '–',
  'laquo': '«',
  'raquo': '»',
  'euro': '€',
};

final RegExp _htmlEntityPattern = RegExp(
  r'&(#\d+|#[xX][0-9a-fA-F]+|[a-zA-Z]+);',
);

String _decodeHtmlEntitiesOnce(String input) {
  return input.replaceAllMapped(_htmlEntityPattern, (match) {
    final entity = match.group(1) ?? '';
    if (entity.startsWith('#x') || entity.startsWith('#X')) {
      final cp = int.tryParse(entity.substring(2), radix: 16);
      if (cp != null &&
          ((cp >= 1 && cp <= 0xD7FF) || (cp >= 0xE000 && cp <= 0x10FFFF))) {
        return String.fromCharCode(cp);
      }
      return match.group(0) ?? '';
    }
    if (entity.startsWith('#')) {
      final cp = int.tryParse(entity.substring(1), radix: 10);
      if (cp != null &&
          ((cp >= 1 && cp <= 0xD7FF) || (cp >= 0xE000 && cp <= 0x10FFFF))) {
        return String.fromCharCode(cp);
      }
      return match.group(0) ?? '';
    }
    return _namedHtmlEntities[entity] ?? match.group(0) ?? '';
  });
}

String fediverseDecodeHtmlEntities(String input) {
  return _decodeHtmlEntitiesOnce(_decodeHtmlEntitiesOnce(input));
}

String fediverseHtmlToText(String? html) {
  if (html == null || html.trim().isEmpty) {
    return '';
  }

  final normalized = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li\s*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ');

  return fediverseDecodeHtmlEntities(normalized).trim();
}
