import 'package:flutter/material.dart';

/// Palette brute de Militant.
///
/// Les valeurs reprennent celles déjà utilisées dans l'appli pour ne pas
/// changer son identité. Dans les écrans, préférer `context.colors` /
/// `context.tokens` (voir `theme_context.dart`) plutôt que ces constantes.
abstract final class AppColors {
  // Rouge Militant
  static const Color militantRed = Color(0xFFBE1E1E);
  static const Color militantRedLight = Color(0xFFFFE5E5);

  // Fonds et surfaces (sombre)
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceHigh = Color(0xFF2A2A2A);
  static const Color darkSurfaceLow = Color(0xFF171717);

  // Fonds et surfaces (clair)
  static const Color lightBackground = Colors.white;
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceHigh = Color(0xFFF5F5F5);
  static const Color lightSurfaceLow = Color(0xFFF1F3F4);

  // Gris de texte
  static const Color grey888 = Color(0xFF888888);
  static const Color greyAAA = Color(0xFFAAAAAA);
  static const Color grey666 = Color(0xFF666666);
  static const Color greyE3 = Color(0xFFE3E3E3);

  // Couleurs d'état
  static const Color success = Color(0xFF35D07F);
  static const Color gold = Color(0xFFDAA520);
}
