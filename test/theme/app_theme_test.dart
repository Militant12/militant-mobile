import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:militant/theme/app_colors.dart';
import 'package:militant/theme/app_theme.dart';
import 'package:militant/theme/app_tokens.dart';
import 'package:militant/theme/theme_context.dart';

/// Rapport de contraste WCAG 2.1 entre deux couleurs opaques.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('le rouge reste celui du logo, un peu éclairci en sombre', () {
    expect(AppTheme.light().colorScheme.primary, AppColors.militantRed);
    expect(AppTheme.dark().colorScheme.primary, AppColors.militantRedDark);
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
  });

  test('fonds paper, cartes surface', () {
    expect(AppTheme.light().scaffoldBackgroundColor, AppColors.lightBackground);
    expect(AppTheme.light().colorScheme.surface, Colors.white);
    expect(AppTheme.dark().scaffoldBackgroundColor, AppColors.darkBackground);
    expect(AppTheme.dark().colorScheme.surface, AppColors.darkSurface);
  });

  test('Archivo pour les titres, Atkinson Hyperlegible pour le reste', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final text = theme.textTheme;
      for (final style in [
        text.displayMedium,
        text.headlineMedium,
        text.titleLarge,
      ]) {
        expect(style?.fontFamily, AppFonts.display);
      }
      for (final style in [
        text.titleMedium,
        text.bodyLarge,
        text.bodyMedium,
        text.bodySmall,
        text.labelLarge,
      ]) {
        expect(style?.fontFamily, AppFonts.text);
        expect(style?.fontFamilyFallback, AppFonts.fallback);
      }
      expect(text.bodyLarge?.fontSize, 16);
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, AppFonts.display);
    }
  });

  group('contrastes de la charte', () {
    for (final (name, theme) in [
      ('clair', AppTheme.light()),
      ('sombre', AppTheme.dark()),
    ]) {
      final c = theme.colorScheme;
      final t = theme.extension<AppTokens>()!;
      final paper = theme.scaffoldBackgroundColor;
      final backgrounds = {
        'paper': paper,
        'surface': c.surface,
        'surface-alt': c.surfaceContainerHigh,
      };

      test('textes à 4,5:1 au moins ($name)', () {
        for (final MapEntry(key: bgName, value: bg) in backgrounds.entries) {
          expect(_contrast(c.onSurface, bg), greaterThan(4.5), reason: 'ink/$bgName');
          expect(_contrast(c.onSurfaceVariant, bg), greaterThan(4.5), reason: 'ink-muted/$bgName');
          expect(_contrast(c.onPrimaryContainer, bg), greaterThan(4.5), reason: 'brand-ink/$bgName');
          expect(_contrast(t.success, bg), greaterThan(4.5), reason: 'success/$bgName');
          expect(_contrast(t.warning, bg), greaterThan(4.5), reason: 'warning/$bgName');
        }
        expect(_contrast(c.onPrimary, c.primary), greaterThan(4.5), reason: 'on-brand/brand');
        expect(_contrast(c.onPrimaryContainer, c.primaryContainer), greaterThan(4.5), reason: 'brand-ink/brand-soft');
        expect(_contrast(c.onInverseSurface, c.inverseSurface), greaterThan(4.5), reason: 'snackbar');
      });

      test('texte secondaire au-delà de 6:1 ($name)', () {
        expect(_contrast(c.onSurfaceVariant, c.surface), greaterThan(6));
      });

      test('contour des contrôles et focus à 3:1 au moins ($name)', () {
        for (final MapEntry(key: bgName, value: bg) in backgrounds.entries) {
          expect(_contrast(c.outline, bg), greaterThan(3), reason: 'line-strong/$bgName');
          expect(_contrast(t.focus, bg), greaterThan(3), reason: 'focus/$bgName');
        }
      });
    }
  });

  testWidgets('context.tokens suit le mode clair / sombre', (tester) async {
    late AppTokens tokens;
    late bool isDark;
    Future<void> pumpWith(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(builder: (context) {
            tokens = context.tokens;
            isDark = context.isDark;
            return const SizedBox();
          }),
        ),
      );
      // MaterialApp anime le changement de thème.
      await tester.pumpAndSettle();
    }

    await pumpWith(AppTheme.dark());
    expect(isDark, isTrue);
    expect(tokens.textMuted, AppTokens.dark.textMuted);

    await pumpWith(AppTheme.light());
    expect(isDark, isFalse);
    expect(tokens.textMuted, AppTokens.light.textMuted);
  });

  test('ink-muted et onSurfaceVariant sont le même gris', () {
    expect(AppTheme.light().colorScheme.onSurfaceVariant, AppTokens.light.textMuted);
    expect(AppTheme.dark().colorScheme.onSurfaceVariant, AppTokens.dark.textMuted);
  });
}
