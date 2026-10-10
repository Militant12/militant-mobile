import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:militant/services/language_service.dart';

/// Every `translate('key')` used by these screens must exist in each fully
/// translated language, so that nothing silently falls back to French.
void main() {
  const screens = [
    'lib/screens/moderation_screen.dart',
    'lib/screens/live_screen.dart',
  ];
  const languages = ['fr', 'en', 'es'];
  final keyPattern = RegExp(r"translate\(\s*'([a-z0-9_]+)'");

  for (final path in screens) {
    test('$path keys exist in ${languages.join(', ')}', () {
      final keys = keyPattern
          .allMatches(File(path).readAsStringSync())
          .map((m) => m.group(1)!)
          .toSet();
      expect(keys, isNotEmpty);

      final missing = [
        for (final key in keys)
          for (final lang in languages)
            if (!LanguageService.hasTranslation(lang, key)) '$lang:$key',
      ];
      expect(missing, isEmpty);
    });
  }
}
