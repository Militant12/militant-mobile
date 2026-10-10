import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:militant/services/language_service.dart';
import 'package:militant/utils/page_categories.dart';

/// Every key passed to `translate(...)` by these screens must exist in each
/// fully translated language, so that nothing silently falls back to French.
void main() {
  const screens = [
    'lib/screens/moderation_screen.dart',
    'lib/screens/live_screen.dart',
    'lib/screens/pages_screen.dart',
    'lib/screens/page_detail_screen.dart',
    'lib/screens/create_page_screen.dart',
  ];
  const languages = ['fr', 'en', 'es'];
  // Catches plain keys as well as `translate(cond ? 'a' : 'b')`.
  final callPattern = RegExp(r'translate\(([^()]*)\)');
  final keyPattern = RegExp(r"'([a-z0-9_]+)'");

  List<String> missingKeys(Iterable<String> keys) => [
    for (final key in keys)
      for (final lang in languages)
        if (!LanguageService.hasTranslation(lang, key)) '$lang:$key',
  ];

  for (final path in screens) {
    test('$path keys exist in ${languages.join(', ')}', () {
      final keys = {
        for (final call in callPattern.allMatches(
          File(path).readAsStringSync(),
        ))
          for (final key in keyPattern.allMatches(call.group(1)!))
            key.group(1)!,
      };
      expect(keys, isNotEmpty);
      expect(missingKeys(keys), isEmpty);
    });
  }

  test('page category keys exist in ${languages.join(', ')}', () {
    expect(missingKeys(pageCategoryKeys.values), isEmpty);
  });
}
