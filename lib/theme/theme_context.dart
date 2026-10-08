import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Raccourcis d'accès au thème depuis un `BuildContext`.
///
/// Échelle de texte : utiliser `context.text` (Material 3) plutôt que des
/// `fontSize` en dur. Correspondance avec les tailles utilisées jusqu'ici :
/// 11 → labelSmall, 12 → bodySmall / labelMedium, 14 → bodyMedium / titleSmall,
/// 16 → bodyLarge / titleMedium, 22 → titleLarge, 24 → headlineSmall.
extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppTokens get tokens => Theme.of(this).extension<AppTokens>() ?? AppTokens.dark;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
