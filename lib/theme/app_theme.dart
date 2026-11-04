import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'cut_corner_border.dart';

/// Polices de la charte, embarquées dans `assets/fonts/` (licence OFL) plutôt
/// que téléchargées au lancement.
abstract final class AppFonts {
  /// Titres : une linéale franche qui rappelle l'affiche.
  static const String display = 'Archivo';

  /// Tout le reste. Dessinée par le Braille Institute pour les personnes
  /// malvoyantes : I, l et 1 se distinguent, comme 0 et O.
  static const String text = 'Atkinson Hyperlegible Next';

  /// Codes de double authentification.
  static const String mono = 'Atkinson Hyperlegible Mono';

  /// Pour les alphabets que les deux polices ne couvrent pas (cyrillique,
  /// grec, arabe…), fournie par le système.
  static const List<String> fallback = ['Noto Sans'];
}

/// Thèmes clair et sombre de Militant.
abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.militantRed,
      onPrimary: Colors.white,
      primaryContainer: AppColors.brandSoftLight,
      onPrimaryContainer: AppColors.brandInkLight,
      secondary: AppColors.militantRed,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.brandSoftLight,
      onSecondaryContainer: AppColors.brandInkLight,
      error: AppColors.brandInkLight,
      onError: Colors.white,
      errorContainer: AppColors.brandSoftLight,
      onErrorContainer: AppColors.brandInkLight,
      surface: AppColors.lightSurface,
      onSurface: AppColors.inkLight,
      onSurfaceVariant: AppColors.inkMutedLight,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.lightSurfaceLow,
      surfaceContainer: AppColors.lightSurfaceLow,
      surfaceContainerHigh: AppColors.lightSurfaceHigh,
      surfaceContainerHighest: AppColors.lightSurfaceHigh,
      outline: AppColors.lineStrongLight,
      outlineVariant: AppColors.lineLight,
      inverseSurface: AppColors.inkLight,
      onInverseSurface: AppColors.lightBackground,
      inversePrimary: AppColors.brandInkDark,
      scrim: Color(0x7A141112),
      // Pas de teinte rouge sur les surfaces surélevées : les fonds restent
      // neutres, le rouge sert à agir.
      surfaceTint: Colors.transparent,
    );
    return _build(
      scheme: scheme,
      scaffold: AppColors.lightBackground,
      tokens: AppTokens.light,
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.militantRedDark,
      onPrimary: Colors.white,
      primaryContainer: AppColors.brandSoftDark,
      onPrimaryContainer: AppColors.brandInkDark,
      secondary: AppColors.militantRedDark,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.brandSoftDark,
      onSecondaryContainer: AppColors.brandInkDark,
      error: AppColors.brandInkDark,
      onError: AppColors.noir,
      errorContainer: AppColors.brandSoftDark,
      onErrorContainer: AppColors.brandInkDark,
      surface: AppColors.darkSurface,
      onSurface: AppColors.inkDark,
      onSurfaceVariant: AppColors.inkMutedDark,
      surfaceContainerLowest: AppColors.darkBackground,
      surfaceContainerLow: AppColors.darkSurfaceLow,
      surfaceContainer: AppColors.darkSurface,
      surfaceContainerHigh: AppColors.darkSurfaceHigh,
      surfaceContainerHighest: AppColors.darkSurfaceHigh,
      outline: AppColors.lineStrongDark,
      outlineVariant: AppColors.lineDark,
      inverseSurface: AppColors.inkDark,
      onInverseSurface: AppColors.darkBackground,
      inversePrimary: AppColors.militantRed,
      scrim: Color(0xA3000000),
      surfaceTint: Colors.transparent,
    );
    return _build(
      scheme: scheme,
      scaffold: AppColors.darkBackground,
      tokens: AppTokens.dark,
    );
  }

  /// Étiquette en capitales (`eyebrow`) : pastille En direct, intitulés de
  /// section. Le texte est mis en capitales par le code, jamais dans les
  /// traductions.
  static TextStyle eyebrow(TextTheme text) => text.labelSmall!.copyWith(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.88,
  );

  static ThemeData _build({
    required ColorScheme scheme,
    required Color scaffold,
    required AppTokens tokens,
  }) {
    final base = ThemeData(
      brightness: scheme.brightness,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: AppFonts.text,
      fontFamilyFallback: AppFonts.fallback,
    );
    final text = _textTheme(base.textTheme);
    return base.copyWith(
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: scaffold,
      textTheme: text,
      dividerColor: scheme.outlineVariant,
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      // Dialogues et feuilles du bas sur `surface`, plutôt que les teintes
      // Material 3 par défaut.
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radius20),
          ),
        ),
      ),
      // Cartes : quatre coins arrondis (on ne les déclenche pas d'un appui
      // comme un bouton), filet `line`, pas d'ombre Material.
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      // Le coin coupé sur tout ce qu'on peut toucher. Les couleurs des
      // boutons restent celles de Material 3 (primary, tonal, contour…).
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(text).copyWith(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonStyle(text).copyWith(
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(text).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: 0.38)
                : scheme.onSurface,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? scheme.onSurface.withValues(alpha: 0.12)
                  : scheme.outline,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: _cutShape(AppShapes.medium),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: 0.38)
                : scheme.onPrimaryContainer,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: AppShapes.large,
      ),
      chipTheme: ChipThemeData(
        shape: AppShapes.small,
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide(color: scheme.primaryContainer)
              : BorderSide(color: scheme.outline),
        ),
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
        showCheckmark: true,
        labelStyle: text.labelLarge?.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurface,
          ),
        ),
      ),
      // Barre du bas : indicateur brand-soft au coin coupé, icône et libellé
      // en brand-ink, plus d'aplat rouge plein.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: AppShapes.small,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
      ),
      extensions: [tokens],
    );
  }

  /// La coupe s'ouvre de 4px au survol et au focus clavier ; `Material`
  /// anime le passage d'une forme à l'autre.
  static WidgetStateProperty<OutlinedBorder> _cutShape(CutCornerBorder shape) {
    final open = shape.copyWith(cut: shape.cut + 4);
    return WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)
          ? open
          : shape,
    );
  }

  /// Bouton de 48px de haut, libellé en `label`, coin coupé `cut-md`.
  static ButtonStyle _buttonStyle(TextTheme text) => ButtonStyle(
    shape: _cutShape(AppShapes.medium),
    minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
    textStyle: WidgetStatePropertyAll(text.labelLarge),
  );

  /// Archivo pour les titres (`display*`, `headline*`, `titleLarge`),
  /// Atkinson Hyperlegible Next pour le reste, sur l'échelle Material 3.
  static TextTheme _textTheme(TextTheme base) {
    TextStyle display(
      TextStyle? style,
      double size,
      double lineHeight,
      FontWeight weight,
      double tracking,
    ) => style!.copyWith(
      fontFamily: AppFonts.display,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: tracking * size,
    );

    TextStyle text(
      TextStyle? style,
      double size,
      double lineHeight,
      FontWeight weight, [
      double tracking = 0,
    ]) => style!.copyWith(
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: tracking * size,
    );

    const w400 = FontWeight.w400;
    const w700 = FontWeight.w700;
    const w800 = FontWeight.w800;
    return base.copyWith(
      displayLarge: display(base.displayLarge, 57, 64, w800, -0.02),
      displayMedium: display(base.displayMedium, 45, 50, w800, -0.02),
      displaySmall: display(base.displaySmall, 36, 44, w800, -0.02),
      headlineLarge: display(base.headlineLarge, 32, 38, w800, -0.01),
      headlineMedium: display(base.headlineMedium, 28, 34, w800, -0.01),
      headlineSmall: display(base.headlineSmall, 24, 30, w800, -0.01),
      titleLarge: display(base.titleLarge, 22, 28, w700, -0.005),
      titleMedium: text(base.titleMedium, 16, 22, w700),
      titleSmall: text(base.titleSmall, 14, 20, w700),
      bodyLarge: text(base.bodyLarge, 16, 24, w400),
      bodyMedium: text(base.bodyMedium, 14, 20, w400),
      bodySmall: text(base.bodySmall, 12, 16, w400),
      labelLarge: text(base.labelLarge, 14, 20, w700, 0.01),
      labelMedium: text(base.labelMedium, 12, 16, w700, 0.01),
      labelSmall: text(base.labelSmall, 11, 16, w400, 0.01),
    );
  }
}
