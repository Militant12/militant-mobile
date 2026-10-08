import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:militant/theme/app_colors.dart';
import 'package:militant/theme/app_theme.dart';
import 'package:militant/theme/app_tokens.dart';
import 'package:militant/theme/theme_context.dart';

void main() {
  test('les deux thèmes utilisent le rouge Militant', () {
    expect(AppTheme.light().colorScheme.primary, AppColors.militantRed);
    expect(AppTheme.dark().colorScheme.primary, AppColors.militantRed);
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
  });

  test('les fonds reprennent les valeurs existantes', () {
    expect(AppTheme.light().scaffoldBackgroundColor, Colors.white);
    expect(AppTheme.dark().scaffoldBackgroundColor, AppColors.darkBackground);
    expect(AppTheme.dark().colorScheme.surface, AppColors.darkSurface);
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
}
