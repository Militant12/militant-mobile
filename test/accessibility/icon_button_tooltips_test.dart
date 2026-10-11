import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:militant/services/language_service.dart';

/// Un `IconButton` sans `tooltip` est annoncé « bouton » sans nom par les
/// lecteurs d'écran (TalkBack, VoiceOver). Ces tests empêchent d'en rajouter.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// Arguments de chaque appel à [pattern], parenthèses équilibrées.
  Iterable<String> callArguments(String source, RegExp pattern) sync* {
    for (final match in pattern.allMatches(source)) {
      var depth = 1;
      var i = match.end;
      while (depth > 0 && i < source.length) {
        final char = source[i];
        if (char == '(') depth++;
        if (char == ')') depth--;
        i++;
      }
      yield source.substring(match.end, i);
    }
  }

  test('chaque IconButton a un tooltip', () {
    final pattern = RegExp(
      r'\bIconButton(\.filled|\.outlined|\.filledTonal)?\(',
    );
    final missing = <String>[];
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final args in callArguments(source, pattern)) {
        if (!args.contains('tooltip:')) {
          final icon = RegExp(r'Icons\.\w+').firstMatch(args)?.group(0);
          missing.add('${file.path} (${icon ?? '?'})');
        }
      }
    }
    expect(missing, isEmpty, reason: 'IconButton sans tooltip');
  });

  test('les clés a11y_* existent en fr, en, es', () {
    final keyPattern = RegExp(r"'(a11y_[a-z0-9_]+)'");
    final keys = {
      for (final file in dartFiles)
        if (!file.path.endsWith('language_service.dart'))
          for (final match in keyPattern.allMatches(file.readAsStringSync()))
            match.group(1)!,
    };
    expect(keys, isNotEmpty);
    final missing = [
      for (final key in keys)
        for (final lang in const ['fr', 'en', 'es'])
          if (!LanguageService.hasTranslation(lang, key)) '$lang:$key',
    ];
    expect(missing, isEmpty);
  });
}
