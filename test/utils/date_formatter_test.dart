import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:militant/services/language_service.dart';
import 'package:militant/utils/date_formatter.dart';

void main() {
  final lang = LanguageService.instance;
  final now = DateTime.now();

  tearDown(() => lang.value = const Locale('fr'));

  test('format court en français', () {
    expect(DateFormatter.formatRelative(now), 'À l\'instant');
    expect(
      DateFormatter.formatRelative(now.subtract(const Duration(minutes: 5))),
      '5min',
    );
    expect(
      DateFormatter.formatRelative(now.subtract(const Duration(hours: 22))),
      '22h',
    );
    expect(
      DateFormatter.formatRelative(now.subtract(const Duration(days: 2))),
      '2j',
    );
  });

  test('format court traduit', () {
    lang.value = const Locale('en');
    expect(DateFormatter.formatRelative(now), 'Just now');
    expect(
      DateFormatter.formatRelative(now.subtract(const Duration(days: 2))),
      '2d',
    );
  });

  test('au-delà d’une semaine : date complète', () {
    final date = DateTime(2026, 3, 18);
    expect(DateFormatter.formatRelative(date), '18/3/2026');
  });
}
