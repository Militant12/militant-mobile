String fediverseDecodeHtmlEntities(String input) {
  return input
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
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
