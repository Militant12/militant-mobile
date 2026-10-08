import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Valeurs de design que `ColorScheme` ne couvre pas.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.textMuted,
    required this.cardShadow,
    required this.success,
    required this.badgeGold,
  });

  /// Texte secondaire (dates, compteurs, sous-titres).
  final Color textMuted;

  /// Ombre des cartes (transparente en sombre).
  final List<BoxShadow> cardShadow;

  final Color success;
  final Color badgeGold;

  // Espacements
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;

  // Rayons
  static const double radius8 = 8;
  static const double radius12 = 12;
  static const double radius16 = 16;
  static const double radiusPill = 999;

  static const AppTokens light = AppTokens(
    textMuted: Color(0xFF757575), // grey[600]
    cardShadow: [
      BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
    success: AppColors.success,
    badgeGold: AppColors.gold,
  );

  static const AppTokens dark = AppTokens(
    textMuted: AppColors.grey888,
    cardShadow: [],
    success: AppColors.success,
    badgeGold: AppColors.gold,
  );

  @override
  AppTokens copyWith({
    Color? textMuted,
    List<BoxShadow>? cardShadow,
    Color? success,
    Color? badgeGold,
  }) {
    return AppTokens(
      textMuted: textMuted ?? this.textMuted,
      cardShadow: cardShadow ?? this.cardShadow,
      success: success ?? this.success,
      badgeGold: badgeGold ?? this.badgeGold,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t) ?? const [],
      success: Color.lerp(success, other.success, t)!,
      badgeGold: Color.lerp(badgeGold, other.badgeGold, t)!,
    );
  }
}
