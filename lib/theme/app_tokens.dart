import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Valeurs de design que `ColorScheme` ne couvre pas.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.textMuted,
    required this.cardShadow,
    required this.floatShadow,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.noir,
    required this.focus,
    required this.badgeGold,
  });

  /// Texte secondaire (`ink-muted` : dates, compteurs, sous-titres). Même
  /// valeur que `ColorScheme.onSurfaceVariant`.
  final Color textMuted;

  /// Ombre des cartes (`shadow-card`), transparente en sombre : la carte s'y
  /// détache par sa couleur.
  final List<BoxShadow> cardShadow;

  /// Ombre de ce qui flotte au-dessus du contenu (`shadow-float`).
  final List<BoxShadow> floatShadow;

  /// Confirmation (enregistré, envoyé, en ligne), toujours avec une icône.
  final Color success;
  final Color successSoft;

  /// Avertissement (contenu signalé, demande en attente), avec une icône.
  final Color warning;
  final Color warningSoft;

  /// Le noir du logo, en aplat. Texte posé dessus : `onPrimary`.
  final Color noir;

  /// Anneau de focus clavier.
  final Color focus;

  final Color badgeGold;

  // Espacements
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;

  // Tailles de texte : l'échelle Material 3 (mêmes valeurs que
  // `context.text`), utilisable dans les `const TextStyle`.
  static const double fontLabelSmall = 11;
  static const double fontBodySmall = 12;
  static const double fontBodyMedium = 14;
  static const double fontBodyLarge = 16;
  static const double fontTitleLarge = 22;
  static const double fontHeadlineSmall = 24;
  static const double fontHeadlineMedium = 28;
  static const double fontHeadlineLarge = 32;
  static const double fontDisplayMedium = 45;

  // Rayons : chips et images dans une carte (8), boutons, champs et
  // snackbars (12), cartes, feuilles et dialogues (20).
  static const double radius8 = 8;
  static const double radius12 = 12;
  static const double radius16 = 16;
  static const double radius20 = 20;
  static const double radiusPill = 999;

  static const AppTokens light = AppTokens(
    textMuted: AppColors.inkMutedLight,
    cardShadow: [
      BoxShadow(color: Color(0x0F141112), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0A141112), blurRadius: 8, offset: Offset(0, 2)),
    ],
    floatShadow: [
      BoxShadow(color: Color(0x29141112), blurRadius: 20, offset: Offset(0, 6)),
    ],
    success: AppColors.successLight,
    successSoft: AppColors.successSoftLight,
    warning: AppColors.warningLight,
    warningSoft: AppColors.warningSoftLight,
    noir: AppColors.noir,
    focus: AppColors.focusLight,
    badgeGold: AppColors.gold,
  );

  static const AppTokens dark = AppTokens(
    textMuted: AppColors.inkMutedDark,
    cardShadow: [],
    floatShadow: [
      BoxShadow(color: Color(0x80000000), blurRadius: 20, offset: Offset(0, 6)),
    ],
    success: AppColors.successDark,
    successSoft: AppColors.successSoftDark,
    warning: AppColors.warningDark,
    warningSoft: AppColors.warningSoftDark,
    noir: Colors.black,
    focus: AppColors.focusDark,
    badgeGold: AppColors.gold,
  );

  @override
  AppTokens copyWith({
    Color? textMuted,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? floatShadow,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? noir,
    Color? focus,
    Color? badgeGold,
  }) {
    return AppTokens(
      textMuted: textMuted ?? this.textMuted,
      cardShadow: cardShadow ?? this.cardShadow,
      floatShadow: floatShadow ?? this.floatShadow,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      noir: noir ?? this.noir,
      focus: focus ?? this.focus,
      badgeGold: badgeGold ?? this.badgeGold,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      cardShadow:
          BoxShadow.lerpList(cardShadow, other.cardShadow, t) ?? const [],
      floatShadow:
          BoxShadow.lerpList(floatShadow, other.floatShadow, t) ?? const [],
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      noir: Color.lerp(noir, other.noir, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      badgeGold: Color.lerp(badgeGold, other.badgeGold, t)!,
    );
  }
}
