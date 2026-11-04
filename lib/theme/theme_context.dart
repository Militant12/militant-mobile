import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'app_tokens.dart';

/// Raccourcis d'accès au thème depuis un `BuildContext`.
///
/// Échelle de texte : utiliser `context.text` (Material 3) plutôt que des
/// `fontSize` en dur. Correspondance avec les tailles utilisées jusqu'ici :
/// 11 → labelSmall, 12 → bodySmall / labelMedium, 14 → bodyMedium / titleSmall,
/// 16 → bodyLarge / titleMedium, 22 → titleLarge, 24 → headlineSmall.
///
/// Rouge : `colors.primary` pour un aplat (avec `onPrimary` dessus),
/// `colors.onPrimaryContainer` pour du texte ou une icône rouge, sur
/// `colors.primaryContainer` pour un fond teinté.
extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppTokens get tokens => Theme.of(this).extension<AppTokens>() ?? AppTokens.dark;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Étiquette en capitales (`eyebrow`) : passer le texte par `toUpperCase()`.
  TextStyle get eyebrow => AppTheme.eyebrow(Theme.of(this).textTheme);
}
