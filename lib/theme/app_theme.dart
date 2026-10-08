import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Thèmes clair et sombre de Militant.
///
/// Les thèmes de composants (cartes, champs, chips, barre du bas…) seront
/// ajoutés au fur et à mesure de la migration des écrans, pour ne pas
/// modifier le rendu des écrans pas encore migrés.
abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.militantRed,
      onPrimary: Colors.white,
      secondary: AppColors.militantRed,
      onSecondary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: Colors.black,
      onSurfaceVariant: Color(0xFF757575),
      surfaceContainerLow: AppColors.lightSurfaceLow,
      surfaceContainer: AppColors.lightSurfaceHigh,
      surfaceContainerHigh: AppColors.greyE3,
      outline: Color(0xFFBDBDBD),
      outlineVariant: AppColors.greyE3,
    );
    return _build(
      scheme: scheme,
      scaffold: AppColors.lightBackground,
      appBarBackground: Colors.white,
      appBarForeground: Colors.black,
      tokens: AppTokens.light,
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.militantRed,
      onPrimary: Colors.white,
      secondary: AppColors.militantRed,
      onSecondary: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: Colors.white,
      onSurfaceVariant: AppColors.grey888,
      surfaceContainerLow: AppColors.darkSurfaceLow,
      surfaceContainer: AppColors.darkSurface,
      surfaceContainerHigh: AppColors.darkSurfaceHigh,
      outline: Color(0xFF555555),
      outlineVariant: AppColors.darkSurfaceHigh,
    );
    return _build(
      scheme: scheme,
      scaffold: AppColors.darkBackground,
      appBarBackground: AppColors.darkSurface,
      appBarForeground: Colors.white,
      tokens: AppTokens.dark,
    );
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required Color scaffold,
    required Color appBarBackground,
    required Color appBarForeground,
    required AppTokens tokens,
  }) {
    final base = ThemeData(
      brightness: scheme.brightness,
      colorScheme: scheme,
      useMaterial3: true,
    );
    return base.copyWith(
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        elevation: 0,
        iconTheme: IconThemeData(color: appBarForeground),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      extensions: [tokens],
    );
  }
}
