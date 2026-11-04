import 'package:flutter/widgets.dart';

/// Durées et courbes des animations de la charte.
///
/// Les animations confirment un geste ou accompagnent un changement de
/// place ; elles sont courtes et s'arrêtent quand le système demande moins
/// d'animations : passer les durées par [of].
abstract final class AppMotion {
  /// Retour d'appui.
  static const Duration instant = Duration(milliseconds: 100);

  /// Changement d'état : J'aime, chip, onglet, compteur.
  static const Duration quick = Duration(milliseconds: 200);

  /// Entrées et sorties : snackbar, feuille, bandeau.
  static const Duration base = Duration(milliseconds: 300);

  /// Apparition d'un état vide, rebond d'une réaction, tampon.
  static const Duration slow = Duration(milliseconds: 450);

  /// Par défaut, pour ce qui change de place ou de taille.
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// Ce qui arrive.
  static const Curve enter = Cubic(0.05, 0.7, 0.1, 1);

  /// Ce qui part, plus vite qu'il n'est arrivé.
  static const Curve exit = Cubic(0.3, 0, 0.8, 0.15);

  /// Petit rebond, réservé aux réactions (J'aime, Enregistrer).
  static const Curve pop = Cubic(0.34, 1.56, 0.64, 1);

  /// Vrai quand le système demande moins d'animations.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], ou zéro si le système demande moins d'animations.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
