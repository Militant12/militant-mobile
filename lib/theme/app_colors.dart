import 'package:flutter/material.dart';

/// Palette brute de Militant, d'après la charte graphique (ticket #2).
///
/// Le rouge et le noir du logo, des neutres légèrement chauds, et des
/// couleurs d'état qui ne se confondent pas avec le rouge. Dans les écrans,
/// préférer `context.colors` / `context.tokens` (voir `theme_context.dart`)
/// plutôt que ces constantes : elles suivent le thème clair ou sombre.
abstract final class AppColors {
  // Rouge Militant (`brand`) : le rouge du logo, en aplat (bouton principal,
  // bouton flottant, pastilles). Toujours avec du blanc dessus.
  static const Color militantRed = Color(0xFFBE1E1E);

  /// `brand` en sombre, un peu plus clair pour rester à 3:1 du fond.
  static const Color militantRedDark = Color(0xFFCC2424);

  /// `brand-ink` : le rouge pour du texte ou une icône (liens, J'aime actif,
  /// onglet actif). Plus clair en sombre pour rester lisible.
  static const Color brandInkLight = Color(0xFFB01B1B);
  static const Color brandInkDark = Color(0xFFFF6B6B);

  /// `brand-soft` : fond teinté derrière du `brand-ink` (chip sélectionnée,
  /// indicateur de l'onglet actif, bouton tonal).
  static const Color brandSoftLight = Color(0xFFFCE9E9);
  static const Color brandSoftDark = Color(0xFF3A1517);

  /// `noir` : le noir du logo, en aplat (bandeau hors ligne, vignettes).
  static const Color noir = Color(0xFF141112);

  // Fonds et surfaces (sombre)
  static const Color darkBackground = Color(0xFF121011); // paper
  static const Color darkSurface = Color(0xFF1C191A); // surface
  static const Color darkSurfaceHigh = Color(0xFF2A2526); // surface-alt
  static const Color darkSurfaceLow = Color(0xFF171415);

  // Fonds et surfaces (clair)
  static const Color lightBackground = Color(0xFFFBFAFA); // paper
  static const Color lightSurface = Colors.white; // surface
  static const Color lightSurfaceHigh = Color(0xFFF3F1F1); // surface-alt
  static const Color lightSurfaceLow = Color(0xFFF7F5F5);

  // Encre : texte principal (`ink`) et secondaire (`ink-muted`). Tout gris de
  // texte de l'application est l'un des deux.
  static const Color inkLight = Color(0xFF141112);
  static const Color inkDark = Color(0xFFF4F0F0);
  static const Color inkMutedLight = Color(0xFF5F5759);
  static const Color inkMutedDark = Color(0xFFADA4A6);

  // Traits : séparateurs (`line`) et contour des contrôles (`line-strong`).
  static const Color lineLight = Color(0xFFE4DFE0);
  static const Color lineDark = Color(0xFF3A3335);
  static const Color lineStrongLight = Color(0xFF8C8385);
  static const Color lineStrongDark = Color(0xFF7A7072);

  // Couleurs d'état (vert franc pour le statut en ligne et les validations).
  static const Color successLight = Color(0xFF166534);
  static const Color successDark = Color(0xFF35D07F);
  static const Color successSoftLight = Color(0xFFDCFCE7);
  static const Color successSoftDark = Color(0xFF0D2B1D);
  static const Color warningLight = Color(0xFF8A5300);
  static const Color warningDark = Color(0xFFF2B84B);
  static const Color warningSoftLight = Color(0xFFFBF0DD);
  static const Color warningSoftDark = Color(0xFF33240A);

  /// Anneau de focus clavier : bleu, pour se voir sur le rouge comme sur le
  /// noir.
  static const Color focusLight = Color(0xFF1257D6);
  static const Color focusDark = Color(0xFF8AB4FF);

  static const Color gold = Color(0xFFDAA520);
}
